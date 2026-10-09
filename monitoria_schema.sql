-- ============================================================
-- Monitorias de Gestores em Treinamento
-- Rode no SQL Editor do Supabase DEPOIS de já ter rodado os scripts
-- anteriores (pdi_schema.sql, auth_schema.sql, profiles_photo.sql,
-- pdi_self_fields.sql)
-- ============================================================

create table if not exists public.monitorias (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),

  monitor_nome text,
  monitor_email text,
  gestor_nome text,     -- o "monitorando" (gestor novo avaliado) — deve bater com pdi.gestor_nome
  unidade text,
  duracao text,         -- texto livre: "2 meses", "21/07/2025 a 24/11/2025" etc.

  nota_postura int,              coment_postura text,
  nota_busca_info int,           coment_busca_info text,
  nota_organizacao int,          coment_organizacao text,
  nota_resolutivo int,           coment_resolutivo text,
  nota_questionamento int,       coment_questionamento text,
  nota_lideranca int,            coment_lideranca text,
  nota_comunicacao int,          coment_comunicacao text,
  nota_aprendizado int,          coment_aprendizado text,
  nota_humildade int,            coment_humildade text,
  nota_perfil_valores int,       coment_perfil_valores text,

  pontos_melhoria text,  -- "quais áreas tem como ponto de melhoria / treinamentos sugeridos"
  nps int                -- "o quanto você recomendaria o monitorando" (0-10)
);

alter table public.monitorias enable row level security;

-- Permissão de base pra inserir (grant), separada da regra de conteúdo (policy) logo abaixo.
grant insert on public.monitorias to anon;

-- Formulário público: qualquer um pode registrar uma avaliação de monitoria,
-- contanto que informe quem é o monitor e quem é o gestor avaliado.
-- Não dá pra ler, editar nem apagar — só inserir.
drop policy if exists "Avaliação pública de monitoria" on public.monitorias;
create policy "Avaliação pública de monitoria" on public.monitorias
  for insert to anon
  with check (
    monitor_nome is not null and length(trim(monitor_nome)) > 0
    and gestor_nome is not null and length(trim(gestor_nome)) > 0
  );

-- Admin (RH) tem acesso total.
drop policy if exists "Admin acessa monitorias" on public.monitorias;
create policy "Admin acessa monitorias" on public.monitorias
  for all to authenticated
  using (is_admin())
  with check (is_admin());

-- Cada gestor enxerga (só leitura) as próprias avaliações de monitoria.
drop policy if exists "Gestor vê sua própria monitoria" on public.monitorias;
create policy "Gestor vê sua própria monitoria" on public.monitorias
  for select to authenticated
  using (gestor_nome = my_gestor_nome());
