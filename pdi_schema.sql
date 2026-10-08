-- ============================================================
-- PDI Gestores — criação da tabela no Supabase
-- Rode este script UMA VEZ em: Supabase → SQL Editor → New query
-- Projeto: gahrfavjcdgwjmlsajeo
-- ============================================================

create table if not exists public.pdi (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),

  ano int,
  gestor_nome text,
  unidade text,

  canal_mapeamento text,              -- vários valores separados por vírgula, ex: "Avaliação 360°, Psicologia no Campo"
  origem_acao text,
  evidencia_link text,

  competencia_desenvolvimento text,
  tipo_necessidade text,
  direcao_crescimento text,

  acao text,
  acao_pdi_link text,
  detalhe_desenvolvimento text,

  data_inicio date,
  data_termino_programada date,
  status_acao text,

  feedback_dre text
);

alter table public.pdi enable row level security;

-- O portal acessa o Supabase direto do navegador usando a chave "anon",
-- então a tabela precisa permitir leitura/escrita pública — igual já deve
-- estar configurado em "candidatos", "turmas" e "custos". Se essas tabelas
-- usarem uma policy diferente/mais restrita, ajuste esta para ficar igual.
create policy "Acesso público pdi" on public.pdi
  for all
  to anon
  using (true)
  with check (true);
