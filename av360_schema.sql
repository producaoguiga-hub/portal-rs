-- ============================================================
-- Avaliação 360º dentro do Portal (Gestor+)
-- Rode no SQL Editor do Supabase DEPOIS de já ter rodado auth_schema.sql
-- e pessoas_schema.sql. Projeto: gahrfavjcdgwjmlsajeo
--
-- O que isso faz:
--   1. Cria as tabelas da 360 aqui no banco do portal, com prefixo av360_
--      (mesma estrutura do banco antigo emyqazkwzeubltemefcs, mesmos IDs
--      — a importação dos dados antigos vem em av360_import.sql).
--   2. Troca o login próprio da 360 (tabela "users" com senha em texto)
--      pelo login do portal: quem entra é identificado pelo e-mail da conta
--      do portal, casado com av360_managers.email. Admin do portal = admin
--      da 360.
--   3. Liga RLS de verdade. No banco antigo qualquer pessoa com a chave
--      pública lia tudo, inclusive QUEM avaliou QUEM. Aqui:
--        - admin (RH): acesso total;
--        - gestor: grava as próprias avaliações, vê as que ELE fez, e vê os
--          resultados liberados (grupo com is_results_released + permissão
--          can_see_results) SEM o nome/ID de quem avaliou — via as views
--          av360_evaluations_visiveis / av360_answers_visiveis.
--
-- Pode rodar de novo sem problema (idempotente).
-- ============================================================

-- 0) Papel "participante" no portal ---------------------------------
-- Profissionais (ex.: SMS) que participam da 360 mas não são gestores: têm
-- login e senha, mas no portal só enxergam a aba Avaliação 360º — sem PDI,
-- Monitoria ou Trajetória. Para o banco, não são admin nem gestor: as
-- políticas de PDI/Monitoria não liberam nada pra eles.
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check
  check (role in ('admin','gestor','participante'));

-- 1) Tabelas ----------------------------------------------------------

create table if not exists public.av360_managers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  unit text,
  email text,
  role_type text,
  unit_type text,
  category text default 'Gestão',
  photo_url text,
  pessoa_id uuid references public.pessoas(id) on delete set null,
  created_at timestamptz not null default now()
);
create unique index if not exists av360_managers_email_key on public.av360_managers (lower(trim(email)));

create table if not exists public.av360_cycles (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  is_active boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.av360_groups (
  id uuid primary key default gen_random_uuid(),
  cycle_id uuid not null references public.av360_cycles(id) on delete cascade,
  name text not null,
  is_results_released boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.av360_group_members (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.av360_groups(id) on delete cascade,
  manager_id uuid not null references public.av360_managers(id) on delete cascade,
  can_evaluate boolean not null default true,
  is_evaluated boolean not null default true,
  can_see_results boolean not null default true,
  created_at timestamptz not null default now()
);

-- cycle_id é texto (não FK) de propósito: avaliações antigas, de antes dos
-- ciclos existirem, têm cycle_id = 'default' e o app as conta no ciclo mais
-- antigo. Mantido igual ao banco antigo pra não perder esse histórico.
create table if not exists public.av360_evaluations (
  id uuid primary key default gen_random_uuid(),
  evaluator_id uuid references public.av360_managers(id) on delete set null,
  evaluated_id uuid not null references public.av360_managers(id) on delete restrict,
  evaluator_name text,
  evaluated_name text,
  evaluator_unit text,
  evaluator_unit_type text,
  evaluator_role_type text,
  cycle_id text not null default 'default',
  created_at timestamptz not null default now()
);
create index if not exists av360_evaluations_evaluated_idx on public.av360_evaluations (evaluated_id);
create index if not exists av360_evaluations_evaluator_idx on public.av360_evaluations (evaluator_id);

create table if not exists public.av360_answers (
  id uuid primary key default gen_random_uuid(),
  evaluation_id uuid not null references public.av360_evaluations(id) on delete restrict,
  question_id integer not null,
  value numeric,
  comment text,
  target_name text,
  created_at timestamptz not null default now()
);
create index if not exists av360_answers_evaluation_idx on public.av360_answers (evaluation_id);

-- Diagnóstico de IA: um por gestor por ciclo ('legacy' = gerado antes dos
-- diagnósticos serem separados por ciclo).
create table if not exists public.av360_ai_diagnoses (
  manager_id uuid not null references public.av360_managers(id) on delete cascade,
  cycle_id text not null,
  general_summary text,
  pillar_summaries jsonb,
  pdi jsonb,
  categorized_comments jsonb,
  eval_count integer,
  updated_at timestamptz not null default now(),
  primary key (manager_id, cycle_id)
);

-- Histórico dos diagnósticos de IA: o app REGERA o diagnóstico quando entram
-- avaliações novas (sobrescrevendo o anterior). Antes de qualquer troca ou
-- exclusão, a versão antiga é copiada pra cá — nenhuma análise se perde.
create table if not exists public.av360_ai_diagnoses_historico (
  id bigint generated always as identity primary key,
  manager_id uuid not null,
  cycle_id text not null,
  general_summary text,
  pillar_summaries jsonb,
  pdi jsonb,
  categorized_comments jsonb,
  eval_count integer,
  updated_at timestamptz,
  arquivado_em timestamptz not null default now()
);

create or replace function public.av360_arquivar_diagnostico() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  insert into public.av360_ai_diagnoses_historico
    (manager_id, cycle_id, general_summary, pillar_summaries, pdi, categorized_comments, eval_count, updated_at)
  values
    (OLD.manager_id, OLD.cycle_id, OLD.general_summary, OLD.pillar_summaries, OLD.pdi, OLD.categorized_comments, OLD.eval_count, OLD.updated_at);
  return case when TG_OP = 'DELETE' then OLD else NEW end;
end;
$$;

drop trigger if exists trg_av360_arquivar_diagnostico on public.av360_ai_diagnoses;
create trigger trg_av360_arquivar_diagnostico
  before update or delete on public.av360_ai_diagnoses
  for each row execute function public.av360_arquivar_diagnostico();

-- Exclusão de gestor/avaliação continua possível pelo admin, mas só de
-- forma explícita (o app apaga respostas → avaliações nessa ordem). As FKs
-- com "restrict" acima impedem que apagar um gestor leve junto, sem querer,
-- as avaliações que ele RECEBEU.

-- 2) Funções auxiliares (usadas nas políticas e nas views) -------------

-- Gestor da 360 correspondente ao usuário logado (pelo e-mail da conta).
create or replace function public.av360_my_manager_id() returns uuid
  language sql stable security definer set search_path = public as $$
  select id from public.av360_managers
  where lower(trim(email)) = lower(trim(auth.jwt() ->> 'email'))
  limit 1;
$$;

-- 'default' / 'legacy' = histórico de antes dos ciclos: pertence ao ciclo
-- mais antigo (mesma regra que o app usa na tela).
create or replace function public.av360_resolve_cycle(p_cycle text) returns text
  language sql stable security definer set search_path = public as $$
  select case
    when p_cycle is null or p_cycle in ('default','legacy')
      then (select id::text from public.av360_cycles order by created_at asc limit 1)
    else p_cycle
  end;
$$;

-- O usuário logado pode ver o resultado do gestor p_manager no ciclo p_cycle?
-- Regra igual à do app: estar num grupo LIBERADO desse ciclo com
-- can_see_results, e o gestor ser "avaliado" nesse mesmo grupo.
create or replace function public.av360_pode_ver_resultado(p_manager uuid, p_cycle text) returns boolean
  language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from public.av360_group_members eu
    join public.av360_groups g on g.id = eu.group_id and g.is_results_released
    join public.av360_group_members alvo
      on alvo.group_id = g.id and alvo.manager_id = p_manager and alvo.is_evaluated
    where eu.manager_id = public.av360_my_manager_id()
      and eu.can_see_results
      and g.cycle_id::text = public.av360_resolve_cycle(p_cycle)
  );
$$;

-- 3) RLS -----------------------------------------------------------------

alter table public.av360_managers      enable row level security;
alter table public.av360_cycles        enable row level security;
alter table public.av360_groups        enable row level security;
alter table public.av360_group_members enable row level security;
alter table public.av360_evaluations   enable row level security;
alter table public.av360_answers       enable row level security;
alter table public.av360_ai_diagnoses  enable row level security;
alter table public.av360_ai_diagnoses_historico enable row level security;

do $$
declare pol record;
begin
  for pol in select policyname, tablename from pg_policies
    where schemaname = 'public' and tablename like 'av360\_%'
  loop
    execute format('drop policy %I on public.%I', pol.policyname, pol.tablename);
  end loop;
end $$;

-- Admin: tudo, em todas as tabelas da 360.
create policy "Admin acessa av360_managers"      on public.av360_managers      for all to authenticated using (is_admin()) with check (is_admin());
create policy "Admin acessa av360_cycles"        on public.av360_cycles        for all to authenticated using (is_admin()) with check (is_admin());
create policy "Admin acessa av360_groups"        on public.av360_groups        for all to authenticated using (is_admin()) with check (is_admin());
create policy "Admin acessa av360_group_members" on public.av360_group_members for all to authenticated using (is_admin()) with check (is_admin());
create policy "Admin acessa av360_evaluations"   on public.av360_evaluations   for all to authenticated using (is_admin()) with check (is_admin());
create policy "Admin acessa av360_answers"       on public.av360_answers       for all to authenticated using (is_admin()) with check (is_admin());
create policy "Admin acessa av360_ai_diagnoses"  on public.av360_ai_diagnoses  for all to authenticated using (is_admin()) with check (is_admin());
-- Histórico: só leitura, só admin (quem grava é o trigger).
create policy "Admin lê av360_ai_diagnoses_historico" on public.av360_ai_diagnoses_historico for select to authenticated using (is_admin());

-- Estrutura (quem participa, ciclos, grupos): qualquer logado lê — o app
-- precisa disso pra montar a lista de quem avaliar e o painel.
create policy "Logado lê av360_managers"      on public.av360_managers      for select to authenticated using (true);
create policy "Logado lê av360_cycles"        on public.av360_cycles        for select to authenticated using (true);
create policy "Logado lê av360_groups"        on public.av360_groups        for select to authenticated using (true);
create policy "Logado lê av360_group_members" on public.av360_group_members for select to authenticated using (true);

-- Avaliações: o gestor grava só como ele mesmo, nunca sobre si mesmo, e na
-- tabela crua só enxerga as que ELE fez (resultados recebidos vêm pelas views).
create policy "Gestor vê as avaliações que fez" on public.av360_evaluations
  for select to authenticated using (evaluator_id = av360_my_manager_id());
create policy "Gestor registra a própria avaliação" on public.av360_evaluations
  for insert to authenticated
  with check (evaluator_id = av360_my_manager_id() and evaluated_id <> evaluator_id);

create policy "Gestor vê as respostas que deu" on public.av360_answers
  for select to authenticated
  using (exists (select 1 from public.av360_evaluations e
                 where e.id = evaluation_id and e.evaluator_id = av360_my_manager_id()));
create policy "Gestor registra as próprias respostas" on public.av360_answers
  for insert to authenticated
  with check (exists (select 1 from public.av360_evaluations e
                      where e.id = evaluation_id and e.evaluator_id = av360_my_manager_id()));

-- Diagnóstico de IA: quem pode ver o resultado pode ler (e o app gera/salva
-- o diagnóstico na hora em que alguém abre o resultado).
create policy "Gestor lê diagnóstico liberado" on public.av360_ai_diagnoses
  for select to authenticated using (av360_pode_ver_resultado(manager_id, cycle_id));
create policy "Gestor grava diagnóstico liberado" on public.av360_ai_diagnoses
  for insert to authenticated with check (av360_pode_ver_resultado(manager_id, cycle_id));
create policy "Gestor atualiza diagnóstico liberado" on public.av360_ai_diagnoses
  for update to authenticated
  using (av360_pode_ver_resultado(manager_id, cycle_id))
  with check (av360_pode_ver_resultado(manager_id, cycle_id));

-- 4) Views de leitura (anonimato de quem avaliou) ------------------------
-- Rodam com o privilégio do dono (não do usuário), por isso o filtro de
-- quem-vê-o-quê está no WHERE. Nome/ID de quem avaliou só aparece pro admin
-- ou pra própria pessoa que avaliou.

drop view if exists public.av360_answers_visiveis;
drop view if exists public.av360_evaluations_visiveis;

create view public.av360_evaluations_visiveis with (security_barrier = true) as
select
  e.id,
  case when is_admin() or e.evaluator_id = av360_my_manager_id() then e.evaluator_id end   as evaluator_id,
  case when is_admin() or e.evaluator_id = av360_my_manager_id() then e.evaluator_name end as evaluator_name,
  e.evaluated_id,
  e.evaluated_name,
  e.evaluator_unit,
  e.evaluator_unit_type,
  e.evaluator_role_type,
  e.cycle_id,
  e.created_at
from public.av360_evaluations e
where auth.uid() is not null
  and (is_admin()
       or e.evaluator_id = av360_my_manager_id()
       or av360_pode_ver_resultado(e.evaluated_id, e.cycle_id));

create view public.av360_answers_visiveis with (security_barrier = true) as
select a.id, a.evaluation_id, a.question_id, a.value, a.comment, a.target_name, a.created_at
from public.av360_answers a
join public.av360_evaluations_visiveis v on v.id = a.evaluation_id;

revoke all on public.av360_evaluations_visiveis from anon;
revoke all on public.av360_answers_visiveis     from anon;
grant select on public.av360_evaluations_visiveis to authenticated;
grant select on public.av360_answers_visiveis     to authenticated;

-- 5) Vínculo com "pessoas" --------------------------------------------
-- Liga cada participante da 360 à pessoa do portal: primeiro pela conta de
-- login com o mesmo e-mail (o nome costuma estar escrito diferente no PDI e
-- na 360 — "Sabrina Cavalcante" x "Sabrina Canavarro Cavalcante"), depois
-- pelo e-mail em "pessoas", por último pelo nome. Não cria pessoa nova:
-- quem não casar aparece em av360_relatorio_acessos.sql.
create or replace function public.av360_vincular_pessoas() returns integer
  language plpgsql security definer set search_path = public, auth as $$
declare n integer;
begin
  update public.av360_managers m set pessoa_id = pr.pessoa_id
    from auth.users u
    join public.profiles pr on pr.id = u.id
   where m.pessoa_id is null and pr.pessoa_id is not null
     and lower(trim(u.email)) = lower(trim(m.email));
  update public.av360_managers m set pessoa_id = p.id
    from public.pessoas p
   where m.pessoa_id is null and p.email is not null
     and lower(trim(p.email)) = lower(trim(m.email));
  update public.av360_managers m set pessoa_id = p.id
    from public.pessoas p
   where m.pessoa_id is null
     and lower(trim(p.nome)) = lower(trim(m.name));
  select count(*) into n from public.av360_managers where pessoa_id is not null;
  return n;
end;
$$;
-- Só o SQL Editor e a ferramenta de admin (service role) rodam isso.
revoke execute on function public.av360_vincular_pessoas() from public, anon, authenticated;
