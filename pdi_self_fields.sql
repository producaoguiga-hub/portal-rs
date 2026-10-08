-- ============================================================
-- Autoavaliação "Self" pública (pdi_self.html) + colunas novas
-- Rode no SQL Editor do Supabase DEPOIS de já ter rodado profiles_photo.sql
-- ============================================================

-- 1) Novas colunas no PDI, pros campos do formulário de autoavaliação
--    que não existiam ainda na tabela.
alter table public.pdi add column if not exists gestor_email text;
alter table public.pdi add column if not exists objetivo_carreira text;   -- "onde você quer estar em 2-3 anos" (Bloco 2)
alter table public.pdi add column if not exists diagnostico text;         -- "o que hoje não está funcionando" (Bloco 3)
alter table public.pdi add column if not exists sabe_acao_imediata text;  -- "já sabe qual ação quer fazer" Sim/Não (Bloco 6)

-- 2) Permite que QUALQUER UM (sem login) crie uma ação de PDI do tipo
--    autoavaliação, de forma bem restrita: só pode marcar como
--    "Iniciativa do Gestor" / canal "Self" / status "Não iniciado".
--    Não dá pra ler, editar nem apagar nada — só inserir esse tipo
--    específico de registro. É o que o formulário público usa.
drop policy if exists "Autoavaliação pública (Self)" on public.pdi;
create policy "Autoavaliação pública (Self)" on public.pdi
  for insert to anon
  with check (
    origem_acao = 'Iniciativa do Gestor'
    and canal_mapeamento = 'Self'
    and status_acao = 'Não iniciado'
    and gestor_nome is not null and length(trim(gestor_nome)) > 0
  );

-- 3) Permite que um usuário recém-criado (pelo próprio formulário público,
--    via auto-cadastro) registre o PRÓPRIO perfil como gestor — nunca como
--    admin, e sempre vinculado ao próprio id de login.
drop policy if exists "Usuário cria o próprio perfil (gestor)" on public.profiles;
create policy "Usuário cria o próprio perfil (gestor)" on public.profiles
  for insert to authenticated
  with check (id = auth.uid() and role = 'gestor');

-- 4) Correção de segurança (reforço): garante que ninguém autenticado
--    consiga atualizar role/gestor_nome via UPDATE direto na API, mesmo
--    que o projeto tenha concedido privilégio amplo por padrão. Revoga
--    tudo e re-concede só a coluna de foto, explicitamente.
revoke update on public.profiles from authenticated;
grant update (foto_url) on public.profiles to authenticated;
