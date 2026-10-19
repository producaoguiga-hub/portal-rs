-- ============================================================
-- Tabela central "pessoas" — unifica a identidade de alguém entre
-- Admitidos (candidatos), PDI, Monitoria e login (profiles).
--
-- Rode no SQL Editor do Supabase DEPOIS de já ter rodado pdi_schema.sql,
-- auth_schema.sql, pdi_self_fields.sql e monitoria_schema.sql.
--
-- O que isso faz:
--   1. Cria "pessoas": um registro por pessoa de verdade, com um ID
--      estável — em vez do nome ficar repetido (e podendo divergir)
--      em profiles.gestor_nome, pdi.gestor_nome e monitorias.gestor_nome.
--   2. Liga profiles / pdi / monitorias / candidatos a essa tabela via
--      "pessoa_id", preenchendo automaticamente pra tudo que já existe.
--   3. Dali em diante, qualquer INSERT ou troca de gestor_nome em pdi/
--      monitorias/profiles resolve (ou cria) a pessoa correspondente
--      sozinho, via trigger — nenhum formulário existente precisa mudar.
--
-- Isso NÃO troca o jeito como o app lê/mostra os dados hoje (continua
-- tudo funcionando via gestor_nome, igual já era) — é a fundação pra
-- construir em cima (ex: "Minha Trajetória") sem repetir o problema de
-- nomes divergentes que já resolvemos na mão algumas vezes.
-- ============================================================

create table if not exists public.pessoas (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  email text,
  foto_url text,
  candidato_id uuid references public.candidatos(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.pessoas enable row level security;

drop policy if exists "Autenticado lê pessoas" on public.pessoas;
create policy "Autenticado lê pessoas" on public.pessoas
  for select to authenticated using (true);

drop policy if exists "Admin acessa pessoas" on public.pessoas;
create policy "Admin acessa pessoas" on public.pessoas
  for all to authenticated using (is_admin()) with check (is_admin());

-- Colunas de vínculo nas tabelas existentes --------------------------
alter table public.profiles   add column if not exists pessoa_id uuid references public.pessoas(id) on delete set null;
alter table public.pdi        add column if not exists pessoa_id uuid references public.pessoas(id) on delete set null;
alter table public.monitorias add column if not exists pessoa_id uuid references public.pessoas(id) on delete set null;
alter table public.candidatos add column if not exists pessoa_id uuid references public.pessoas(id) on delete set null;

-- Migração do que já existe hoje -------------------------------------
-- Cria uma "pessoa" pra cada nome distinto já usado (os nomes já foram
-- unificados nas limpezas anteriores — Igor Franca/França, Danilo
-- Cogo/Lampier etc. — então isso não deve recriar duplicata).
insert into public.pessoas (nome)
select distinct t.nome from (
  select gestor_nome as nome from public.profiles   where gestor_nome is not null
  union
  select gestor_nome as nome from public.pdi        where gestor_nome is not null
  union
  select gestor_nome as nome from public.monitorias where gestor_nome is not null
) t
where not exists (select 1 from public.pessoas p where p.nome = t.nome);

update public.profiles   pr set pessoa_id = p.id from public.pessoas p where p.nome = pr.gestor_nome and pr.pessoa_id is null;
update public.pdi        d  set pessoa_id = p.id from public.pessoas p where p.nome = d.gestor_nome  and d.pessoa_id  is null;
update public.monitorias m  set pessoa_id = p.id from public.pessoas p where p.nome = m.gestor_nome  and m.pessoa_id  is null;

-- Aproveita e-mail e foto já conhecidos, se tiver, só pra começar com
-- algo preenchido (não sobrescreve nada que a pessoa já tenha).
update public.pessoas p set email = d.gestor_email
  from public.pdi d where d.gestor_nome = p.nome and d.gestor_email is not null and p.email is null;
update public.pessoas p set foto_url = pr.foto_url
  from public.profiles pr where pr.gestor_nome = p.nome and pr.foto_url is not null and p.foto_url is null;

-- Resolução automática dali em diante ---------------------------------
-- Toda vez que um gestor_nome for definido ou mudar em pdi/monitorias/
-- profiles, acha (ou cria) a pessoa correspondente e já linka o pessoa_id
-- — funciona pra inserções feitas pelo app, pelo admin, e pelos
-- formulários públicos (o trigger roda com privilégio próprio, então o
-- "anon" não precisa de permissão direta na tabela "pessoas").
create or replace function public.resolve_pessoa_id() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  pid uuid;
begin
  if NEW.gestor_nome is not null and (TG_OP = 'INSERT' or NEW.gestor_nome is distinct from OLD.gestor_nome) then
    select id into pid from public.pessoas where nome = NEW.gestor_nome limit 1;
    if pid is null then
      insert into public.pessoas (nome) values (NEW.gestor_nome) returning id into pid;
    end if;
    NEW.pessoa_id := pid;
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_pdi_resolve_pessoa on public.pdi;
create trigger trg_pdi_resolve_pessoa
  before insert or update on public.pdi
  for each row execute function public.resolve_pessoa_id();

drop trigger if exists trg_monitorias_resolve_pessoa on public.monitorias;
create trigger trg_monitorias_resolve_pessoa
  before insert or update on public.monitorias
  for each row execute function public.resolve_pessoa_id();

drop trigger if exists trg_profiles_resolve_pessoa on public.profiles;
create trigger trg_profiles_resolve_pessoa
  before insert or update on public.profiles
  for each row execute function public.resolve_pessoa_id();
