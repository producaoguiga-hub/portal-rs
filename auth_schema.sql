-- ============================================================
-- Portal R&S — Login obrigatório + acesso restrito dos gestores
-- Rode no SQL Editor do Supabase DEPOIS de já ter rodado pdi_schema.sql
-- Projeto: gahrfavjcdgwjmlsajeo
-- ============================================================
-- O que isso faz:
--   1. Cria a tabela "profiles", ligando cada usuário logado a um papel
--      (admin = equipe de RH, com acesso total; gestor = só enxerga o
--      próprio PDI, em modo leitura).
--   2. Remove o acesso público (sem login) de candidatos/custos/turmas/pdi.
--   3. A partir de agora, TODO MUNDO precisa fazer login pra usar o portal
--      — inclusive a equipe de RH. As contas de usuário (e-mail/senha) são
--      criadas pelo Supabase (ver instruções no final do arquivo).
-- ============================================================

-- 1) Perfis -----------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'gestor' check (role in ('admin','gestor')),
  gestor_nome text,          -- tem que ser IGUAL ao nome usado em pdi.gestor_nome
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "Usuário vê o próprio perfil" on public.profiles;
create policy "Usuário vê o próprio perfil" on public.profiles
  for select to authenticated
  using (id = auth.uid());

-- 2) Funções auxiliares usadas nas políticas abaixo --------------
create or replace function public.is_admin() returns boolean
  language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

create or replace function public.my_gestor_nome() returns text
  language sql stable security definer set search_path = public as $$
  select gestor_nome from public.profiles where id = auth.uid();
$$;

-- 3) Garante RLS ligado nas tabelas sensíveis (não faz nada se já estava) --
alter table public.candidatos enable row level security;
alter table public.custos     enable row level security;
alter table public.turmas     enable row level security;
alter table public.pdi        enable row level security;

-- 4) Remove as políticas antigas (abertas pra qualquer um, inclusive sem login) --
do $$
declare pol record;
begin
  for pol in select policyname, tablename from pg_policies
    where schemaname = 'public' and tablename in ('candidatos','custos','turmas','pdi')
  loop
    execute format('drop policy %I on public.%I', pol.policyname, pol.tablename);
  end loop;
end $$;

-- 5) candidatos / custos / turmas: só admin (RH), e só logado -----
create policy "Admin acessa candidatos" on public.candidatos
  for all to authenticated using (is_admin()) with check (is_admin());

create policy "Admin acessa custos" on public.custos
  for all to authenticated using (is_admin()) with check (is_admin());

create policy "Admin acessa turmas" on public.turmas
  for all to authenticated using (is_admin()) with check (is_admin());

-- 6) pdi: admin tem acesso total; gestor só LÊ as próprias ações --
create policy "Admin acessa pdi" on public.pdi
  for all to authenticated using (is_admin()) with check (is_admin());

create policy "Gestor vê seu próprio PDI" on public.pdi
  for select to authenticated using (gestor_nome = my_gestor_nome());

-- ============================================================
-- COMO CRIAR OS ACESSOS (fazer manualmente no Dashboard, uma vez por pessoa):
--
-- 1. Supabase Dashboard → Authentication → Users → "Add user"
--    → preenche e-mail e senha (ou "Send invite" por e-mail) → Create.
--    Copie o "User UID" gerado (coluna da tabela de usuários).
--
-- 2. Supabase Dashboard → Table Editor → "profiles" → Insert row:
--    - id            → cole o User UID copiado no passo 1
--    - role          → 'admin' (equipe de RH) ou 'gestor'
--    - gestor_nome   → só pra quem for 'gestor': o nome EXATAMENTE
--                      igual ao que aparece em "Nome do gestor" no PDI
--                      dele (senão o filtro de RLS não vai casar e a
--                      pessoa vai logar e não ver nada).
--
-- Repita o passo 2 pra cada gestor que for receber acesso. A equipe de
-- RH (role = 'admin') não precisa preencher gestor_nome.
-- ============================================================
