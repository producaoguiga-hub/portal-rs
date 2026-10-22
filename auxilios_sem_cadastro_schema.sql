-- ============================================================
-- Auxílios de quem NÃO tem cadastro no portal
-- Rode no SQL Editor do Supabase (projeto do Mais Gestor), uma vez,
-- ANTES de auxilios_import_sem_cadastro.sql.
--
-- O auxílio pode ficar ligado a um cadastro (pessoa_id) OU só ao nome da
-- folha (nome_folha). Quem fica só com o nome não ganha login nem aparece
-- em PDI / monitoria / trilha: só no painel de auxílios do admin.
-- A política do gestor continua "pessoa_id = my_pessoa_id()", então essas
-- linhas nunca aparecem pra nenhum gestor.
-- ============================================================

alter table public.auxilios alter column pessoa_id drop not null;
alter table public.auxilios add column if not exists nome_folha text;

alter table public.auxilios drop constraint if exists auxilios_pessoa_ou_nome;
alter table public.auxilios add constraint auxilios_pessoa_ou_nome
  check (pessoa_id is not null or nullif(trim(nome_folha), '') is not null);

notify pgrst, 'reload schema';
