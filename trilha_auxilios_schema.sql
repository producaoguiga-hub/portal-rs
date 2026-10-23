-- ============================================================
-- Minha Trajetória: Trilha de Conhecimento + Auxílios e incentivos
-- Rode no SQL Editor do Supabase DEPOIS de pessoas_schema.sql e
-- trajetoria_schema.sql (usa my_pessoa_id()). Pode rodar de novo.
--
-- 1. trilha_etapas: a matriz de treinamento do gestor (catálogo que o RH
--    edita no portal). Já vem com os 51 cursos da "MATRIZ DE TREINAMENTO -
--    CURSOS DE INOVAÇÃO" (rev. 13) aplicáveis ao Gestor Júnior —
--    Direção Defensiva e NR 20 aparecem duas vezes, como na matriz:
--    Presencial (Externo) e EAD.
--    Pontos = carga horária de capacitação × 10 (mínimo 10).
-- 2. trilha_progresso: o que cada gestor concluiu (data, foto, comentário).
--    Os pontos contam na hora; o RH acompanha e pode desfazer.
-- 3. auxilios: Auxílio Moradia / Mobilidade / bônus / incentivos por pessoa
--    (política PI-023). O gestor vê só os dele; o RH vê e edita todos.
-- ============================================================

-- 1) Matriz ---------------------------------------------------------
create table if not exists public.trilha_etapas (
  id uuid primary key default gen_random_uuid(),
  ordem int not null default 0,
  categoria text not null,
  nome text not null unique,
  requisito text,
  instituicao text,
  modalidade text,
  instrutor text,          -- qualificação de entidade/instrutor
  carga_horaria int,       -- horas de capacitação
  validade_anos int,       -- null = sem validade definida na matriz
  pontos int not null default 10,
  ativo boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.trilha_etapas enable row level security;
drop policy if exists "Logado lê trilha_etapas" on public.trilha_etapas;
create policy "Logado lê trilha_etapas" on public.trilha_etapas for select to authenticated using (true);
drop policy if exists "Admin edita trilha_etapas" on public.trilha_etapas;
create policy "Admin edita trilha_etapas" on public.trilha_etapas for all to authenticated using (is_admin()) with check (is_admin());

insert into public.trilha_etapas (ordem, categoria, nome, requisito, instituicao, modalidade, instrutor, carga_horaria, validade_anos, pontos) values
  ( 1, 'Capacitação',     'ROTAÇÃO DE TRABALHO PERBRAS.INFO', 'Capacitação', 'Interno', 'Online', 'Desenvolvedor do sistema', 1, 7, 10),
  ( 2, 'Diretriz de SMS', 'DIREÇÃO DEFENSIVA - PRESENCIAL (EXTERNO)', 'Função', 'Externo', 'Presencial', 'Terceiros', 8, 2, 80),
  ( 3, 'Diretriz de SMS', 'DIREÇÃO DEFENSIVA - EAD', 'Função', 'Interno', 'EAD', 'Perbras EAD', 8, 2, 80),
  ( 4, 'Extra',           'AUDITOR INTERNO ISO', 'Corporativo', 'Externo', 'Presencial', 'Terceiros', 16, null, 160),
  ( 5, 'Extra',           'BOAS PRÁTICAS EM UMA REUNIÃO', 'Função', 'Interno', 'EAD', 'Diretoria', 1, 2, 10),
  ( 6, 'Normativo',       'NR 17 - ERGONOMIA', 'Corporativo', 'Interno', 'EAD', 'Perbras EAD', 1, 1, 10),
  ( 7, 'Normativo',       'NR 20 - SEGURANÇA E SAÚDE NO TRABALHO COM INFLAMÁVEIS E COMBUSTÍVEIS - PRESENCIAL (EXTERNO)', 'Normativo', 'Externo', 'Presencial', 'Terceiros', 16, 3, 160),
  ( 8, 'Normativo',       'NR 20 - SEGURANÇA E SAÚDE NO TRABALHO COM INFLAMÁVEIS E COMBUSTÍVEIS - EAD', 'Normativo', 'Interno', 'EAD', 'Perbras EAD', 16, 3, 160),
  ( 9, 'Normativo',       'NR-5 - CIPA', 'Normativo', 'Interno', 'EAD', 'Perbras EAD', 4, 2, 40),
  (10, 'Normativo',       'PROGRAMA DE CONFORMIDADE PERBRAS', 'Corporativo', 'Interno', 'EAD', 'Perbras EAD', 1, 1, 10),
  (11, 'Operacional',     'RT - ACESSOS E SISTEMAS INICIAIS', 'Função', 'Interno', 'Presencial', 'TIC', 2, 1, 20),
  (12, 'Operacional',     'RT - CONHECENDO O PERBRAS INFO', 'Função', 'Interno', 'Presencial', 'Gestor de Unidade', 2, 1, 20),
  (13, 'Operacional',     'RT - CONHECENDO O SISMAN', 'Função', 'Interno', 'Presencial', 'TIC', 2, 1, 20),
  (14, 'Operacional',     'RT - CONHECENDO OS PRINCIPAIS SISTEMAS', 'Função', 'Interno', 'Presencial', 'TIC', 2, 1, 20),
  (15, 'Operacional',     'RT - PREPOSTO TRABALHISTA', 'Função', 'Interno', 'Presencial', 'Diretoria', 2, 1, 20),
  (16, 'Operacional',     'RT A POSTURA DO GESTOR NAS RELAÇÕES DE TRABALHO', 'Função', 'Interno', 'Presencial', 'Gestor de Unidade', 2, 1, 20),
  (17, 'Operacional',     'RT APRENDENDO A UTILIZAR A GUPY', 'Função', 'Interno', 'Presencial', 'Diretoria', 2, 1, 20),
  (18, 'Operacional',     'RT COMO CONTRATO PESSOAS', 'Função', 'Interno', 'Presencial', 'Diretoria', 2, 1, 20),
  (19, 'Operacional',     'RT COMO FAÇO FOLHA DE PAGAMENTO', 'Função', 'Interno', 'Presencial', 'Gestor de Unidade', 2, 1, 20),
  (20, 'Operacional',     'RT COMO FAÇO MEU ORÇAMENTO E ACOMPANHO', 'Função', 'Interno', 'Presencial', 'Gestor de Unidade', 2, 1, 20),
  (21, 'Operacional',     'RT COMO FAÇO UMA RESCISÃO DE TRABALHO', 'Função', 'Interno', 'Presencial', 'Gestor de Unidade', 2, 1, 20),
  (22, 'Operacional',     'RT COMO MOBILIZO CONTRATOS', 'Função', 'Interno', 'Presencial', 'Gestor de Unidade', 2, 1, 20),
  (23, 'Operacional',     'RT COMO NASCEM NOVOS CONTRATOS', 'Função', 'Interno', 'Presencial', 'Comercial', 4, 1, 40),
  (24, 'Operacional',     'RT COMO NEGOCIO COM SINDICATO', 'Função', 'Interno', 'Presencial', 'Gestor de Unidade', 2, 1, 20),
  (25, 'Operacional',     'RT CONHECENDO A FABRICAÇÃO', 'Corporativo', 'Interno', 'Presencial', 'Gestor de Unidade', 2, 1, 20),
  (26, 'Operacional',     'RT CONHECENDO O NEGÓCIO INTERSERVICE', 'Corporativo', 'Interno', 'Presencial', 'Gestor de Unidade', 2, 1, 20),
  (27, 'Operacional',     'RT CONHECENDO O PROCONPH E O SOGI', 'Função', 'Interno', 'Presencial', 'NAC', 2, 1, 20),
  (28, 'Operacional',     'RT CONHECENDO UM CONTRATO DE SPT', 'Função', 'Interno', 'Presencial', 'Gestor de Unidade', 4, 1, 40),
  (29, 'Operacional',     'RT CONHECENDO UMA OS', 'Função', 'Interno', 'Presencial', 'Gestor de Unidade', 2, 1, 20),
  (30, 'Operacional',     'RT CONTÁBIL', 'Função', 'Interno', 'Presencial', 'Controladoria', 4, 1, 40),
  (31, 'Operacional',     'RT CULTURA PERBRAS', 'Função', 'Interno', 'Presencial', 'Diretoria', 3, 1, 30),
  (32, 'Operacional',     'RT DE BENEFÍCIOS - PLUXEE/CAJU', 'Função', 'Interno', 'Presencial', 'Gestor de Unidade', 2, 1, 20),
  (33, 'Operacional',     'RT EXECUTANDO A ESTRATÉGIA', 'Função', 'Interno', 'Presencial', 'ISP', 4, 1, 40),
  (34, 'Operacional',     'RT FINANCEIRA', 'Função', 'Interno', 'Presencial', 'Controladoria', 4, 1, 40),
  (35, 'Operacional',     'RT FISCAL', 'Função', 'Interno', 'Presencial', 'Controladoria', 4, 1, 40),
  (36, 'Operacional',     'RT GESTÃO DE AFASTADOS', 'Função', 'Interno', 'Presencial', 'Diretoria', 2, 1, 20),
  (37, 'Operacional',     'RT GESTÃO DE PLANOS DE SAÚDE, SEGURO DE VIDA, ODONTO', 'Função', 'Interno', 'Presencial', 'Comissão', 2, 1, 20),
  (38, 'Operacional',     'RT JOVEM APRENDIZ', 'Função', 'Interno', 'Presencial', 'Diretoria', 2, 1, 20),
  (39, 'Operacional',     'RT JURÍDICA', 'Função', 'Interno', 'Presencial', 'Diretoria', 4, 1, 40),
  (40, 'Operacional',     'RT MEDICINA OCUPACIONAL E PCMSO', 'Função', 'Interno', 'Presencial', 'NAC', 4, 1, 40),
  (41, 'Operacional',     'RT PLANEJAMENTO EMPRESARIAL', 'Corporativo', 'Interno', 'Presencial', 'ISP', 2, 1, 20),
  (42, 'Operacional',     'RT PLANO DE CARGOS E SALÁRIOS', 'Função', 'Interno', 'Presencial', 'Comissão', 2, 1, 20),
  (43, 'Operacional',     'RT PLR', 'Corporativo', 'Interno', 'Presencial', 'Comissão', 2, 1, 20),
  (44, 'Operacional',     'RT PROGRAMAS DE SMS', 'Função', 'Interno', 'Presencial', 'NAC', 4, 1, 40),
  (45, 'Operacional',     'RT SEGURO DE EQUIPAMENTOS', 'Função', 'Interno', 'Presencial', 'Comissão', 2, 1, 20),
  (46, 'Operacional',     'RT SEGURO DE VEÍCULOS', 'Função', 'Interno', 'Presencial', 'Comissão', 2, 1, 20),
  (47, 'Operacional',     'RT SISTEMA DE GESTÃO INTEGRADO - SGI', 'Função', 'Interno', 'Presencial', 'NAC', 4, 1, 40),
  (48, 'Saúde',           'ASO ANUAL - ATESTADO DE SAÚDE OCUPACIONAL', 'Legal', 'Externo', 'Presencial', 'Não aplicável', 0, 1, 10),
  (49, 'Segurança',       'PRIMEIROS SOCORROS', 'Corporativo', 'Interno', 'EAD', 'Perbras EAD', 1, 1, 10),
  (50, 'Segurança',       'REGRAS DE OURO PETROBRAS', 'Corporativo', 'Interno', 'EAD', 'Perbras EAD', 4, null, 40),
  (51, 'Segurança',       'SISTEMA DE GESTÃO INTEGRADO - SGI', 'Corporativo', 'Interno', 'EAD', 'Perbras EAD', 1, 2, 10)
on conflict (nome) do nothing;

-- 2) Progresso de cada gestor ---------------------------------------
create table if not exists public.trilha_progresso (
  id uuid primary key default gen_random_uuid(),
  pessoa_id uuid not null references public.pessoas(id) on delete cascade,
  etapa_id uuid not null references public.trilha_etapas(id) on delete cascade,
  concluido_em date not null default current_date,
  foto_url text,
  comentario text,
  created_at timestamptz not null default now(),
  unique (pessoa_id, etapa_id)
);

alter table public.trilha_progresso enable row level security;
drop policy if exists "Admin acessa trilha_progresso" on public.trilha_progresso;
create policy "Admin acessa trilha_progresso" on public.trilha_progresso for all to authenticated using (is_admin()) with check (is_admin());
drop policy if exists "Gestor gerencia a própria trilha" on public.trilha_progresso;
create policy "Gestor gerencia a própria trilha" on public.trilha_progresso for all to authenticated
  using (pessoa_id = my_pessoa_id()) with check (pessoa_id = my_pessoa_id());

-- 3) Auxílios e incentivos -------------------------------------------
create table if not exists public.auxilios (
  id uuid primary key default gen_random_uuid(),
  pessoa_id uuid not null references public.pessoas(id) on delete cascade,
  tipo text not null,            -- Auxílio Moradia | Auxílio Mobilidade | Bônus | Incentivo | Outro
  valor numeric(12,2),
  recorrencia text not null default 'Mensal' check (recorrencia in ('Mensal','Pagamento único')),
  inicio date not null,          -- data de ativação
  fim date,                      -- fim da vigência (null = sem data definida)
  regiao text,
  cidade text,
  porte text,                    -- Capital | Médio porte | Pequeno porte
  encerrado_em date,             -- preenchido quando o RH encerra antes do fim
  observacao text,
  created_at timestamptz not null default now()
);

alter table public.auxilios enable row level security;
drop policy if exists "Admin acessa auxilios" on public.auxilios;
create policy "Admin acessa auxilios" on public.auxilios for all to authenticated using (is_admin()) with check (is_admin());
drop policy if exists "Gestor vê os próprios auxílios" on public.auxilios;
create policy "Gestor vê os próprios auxílios" on public.auxilios for select to authenticated using (pessoa_id = my_pessoa_id());
