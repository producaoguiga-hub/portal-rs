-- ============================================================
-- Monitoria: o gestor passa a ver só um CONSOLIDADO (pilares, resumo
-- executivo, pontos positivos e a desenvolver), nunca as respostas dos
-- monitores. O RH gera o rascunho com IA, revisa e publica.
-- Rode no SQL Editor do Supabase DEPOIS de monitoria_schema.sql.
-- Pode rodar de novo sem problema.
-- ============================================================

-- 1) Consolidado por gestor -----------------------------------------
-- pilares / media_geral / n_monitorias são uma FOTO tirada na hora em
-- que o RH publica: o gestor não lê nada calculado em cima das respostas
-- brutas. Se chegar monitoria nova, o painel do RH avisa que o
-- consolidado ficou desatualizado.
create table if not exists public.monitoria_consolidado (
  gestor_nome text primary key,          -- igual a monitorias.gestor_nome
  pilares jsonb,                         -- [{ "pilar": "...", "media": 4.2 }, ...]
  media_geral numeric,
  n_monitorias integer,
  resumo text,
  pontos_positivos jsonb not null default '[]'::jsonb,   -- ["...", "..."]
  pontos_desenvolver jsonb not null default '[]'::jsonb,
  status text not null default 'rascunho' check (status in ('rascunho','publicado')),
  publicado_em timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.monitoria_consolidado enable row level security;

drop policy if exists "Admin acessa monitoria_consolidado" on public.monitoria_consolidado;
create policy "Admin acessa monitoria_consolidado" on public.monitoria_consolidado
  for all to authenticated using (is_admin()) with check (is_admin());

-- Gestor: só o próprio, e só depois que o RH publicou.
drop policy if exists "Gestor vê o próprio consolidado publicado" on public.monitoria_consolidado;
create policy "Gestor vê o próprio consolidado publicado" on public.monitoria_consolidado
  for select to authenticated
  using (status = 'publicado' and gestor_nome = my_gestor_nome());

-- 2) Gestor deixa de ler as respostas brutas dos monitores -------------
-- Antes ele lia (pela API, mesmo sem tela) nome do monitor, nota por
-- pergunta e comentário literal. Agora só o admin lê "monitorias".
drop policy if exists "Gestor vê sua própria monitoria" on public.monitorias;
