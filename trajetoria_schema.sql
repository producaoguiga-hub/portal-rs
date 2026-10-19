-- ============================================================
-- Minha Trajetória: marcos pessoais (linha do tempo com fotos) +
-- acesso do gestor aos próprios dados de admissão (Admitidos)
-- Rode no SQL Editor do Supabase DEPOIS de já ter rodado pessoas_schema.sql
-- ============================================================

create or replace function public.my_pessoa_id() returns uuid
  language sql stable security definer set search_path = public as $$
  select pessoa_id from public.profiles where id = auth.uid();
$$;

-- 1) Marcos da trajetória (criados pelo próprio gestor) ----------------
create table if not exists public.trajetoria_marcos (
  id uuid primary key default gen_random_uuid(),
  pessoa_id uuid not null references public.pessoas(id) on delete cascade,
  data date,
  titulo text,
  descricao text,
  foto_url text,
  created_at timestamptz not null default now()
);

alter table public.trajetoria_marcos enable row level security;

drop policy if exists "Admin acessa marcos" on public.trajetoria_marcos;
create policy "Admin acessa marcos" on public.trajetoria_marcos
  for all to authenticated using (is_admin()) with check (is_admin());

-- Cada gestor cria/edita/apaga só os próprios marcos — é conteúdo dela,
-- sobre a jornada dela, sem informação sensível/avaliativa envolvida.
drop policy if exists "Gestor gerencia os próprios marcos" on public.trajetoria_marcos;
create policy "Gestor gerencia os próprios marcos" on public.trajetoria_marcos
  for all to authenticated
  using (pessoa_id = my_pessoa_id())
  with check (pessoa_id = my_pessoa_id());

-- 2) Gestor lê o PRÓPRIO registro de admissão (Admitidos) --------------
-- Hoje só o admin lê "candidatos". Isso abre só leitura, só da própria
-- linha, só pra quem já foi vinculado (candidatos.pessoa_id setado).
drop policy if exists "Gestor vê o próprio registro de admissão" on public.candidatos;
create policy "Gestor vê o próprio registro de admissão" on public.candidatos
  for select to authenticated
  using (pessoa_id = my_pessoa_id());
