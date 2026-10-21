-- ============================================================
-- "Avaliar seu Monitor": o gestor monitorado avalia o monitor (sentido
-- inverso da monitoria). Mesmas perguntas do Forms "Sobre a Monitoria".
-- Rode no SQL Editor do Supabase DEPOIS de monitoria_schema.sql.
-- Pode rodar de novo sem problema.
-- ============================================================

create table if not exists public.monitoria_avaliacao_monitor (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),

  gestor_nome text not null,     -- quem avaliou (o monitorado) — vem do login
  monitor_nome text not null,
  unidade text,
  periodo text,                  -- "12/02/2026 x 18/05/2026" ou "Em andamento"

  nota_acolhimento int,      coment_acolhimento text,
  nota_organizacao int,      coment_organizacao text,
  nota_didatica int,         coment_didatica text,
  nota_disponibilidade int,  coment_disponibilidade text,
  nota_respeito int,         coment_respeito text,
  nota_comunicacao int,      coment_comunicacao text,
  nota_feedback int,         coment_feedback text,
  nota_autonomia int,        coment_autonomia text,
  nota_ambiente int,         coment_ambiente text,
  nota_integracao int,       coment_integracao text,
  nota_exemplo int,          coment_exemplo text,
  nota_resultado int,        coment_resultado text,

  nps int check (nps between 0 and 10),   -- recomendaria este monitor (0 a 10)
  melhoria text,                           -- o que poderia ser melhorado
  comentarios text                         -- espaço livre
);

alter table public.monitoria_avaliacao_monitor enable row level security;

drop policy if exists "Admin acessa avaliacao_monitor" on public.monitoria_avaliacao_monitor;
create policy "Admin acessa avaliacao_monitor" on public.monitoria_avaliacao_monitor
  for all to authenticated using (is_admin()) with check (is_admin());

-- O gestor registra a avaliação sempre em nome dele mesmo e só relê as
-- que ele fez. O monitor avaliado NÃO tem acesso (só o RH).
drop policy if exists "Gestor registra avaliação do monitor" on public.monitoria_avaliacao_monitor;
create policy "Gestor registra avaliação do monitor" on public.monitoria_avaliacao_monitor
  for insert to authenticated with check (gestor_nome = my_gestor_nome());

drop policy if exists "Gestor vê as próprias avaliações do monitor" on public.monitoria_avaliacao_monitor;
create policy "Gestor vê as próprias avaliações do monitor" on public.monitoria_avaliacao_monitor
  for select to authenticated using (gestor_nome = my_gestor_nome());

-- Sugestões pro formulário: monitores e unidades que já avaliaram este
-- gestor (sem expor nota nem comentário — só nome e unidade).
create or replace function public.meus_monitores()
  returns table (monitor_nome text, unidade text, duracao text)
  language sql stable security definer set search_path = public as $$
  select distinct on (m.monitor_nome) m.monitor_nome, m.unidade, m.duracao
  from public.monitorias m
  where m.gestor_nome = my_gestor_nome() and m.monitor_nome is not null
  order by m.monitor_nome, m.created_at desc;
$$;
revoke execute on function public.meus_monitores() from public, anon;
grant execute on function public.meus_monitores() to authenticated;
