-- ============================================================
-- Foto de perfil dos gestores + admin enxergar todos os perfis
-- Rode no SQL Editor do Supabase DEPOIS de já ter rodado auth_schema.sql
-- ============================================================

-- Coluna de foto no perfil
alter table public.profiles add column if not exists foto_url text;

-- Admin (RH) passa a enxergar TODOS os perfis (antes só via Dashboard/Service Role).
-- Necessário pra mostrar a foto de cada gestor na visão "Por gestor" do admin.
drop policy if exists "Admin acessa profiles" on public.profiles;
create policy "Admin acessa profiles" on public.profiles
  for all to authenticated
  using (is_admin())
  with check (is_admin());

-- Cada gestor pode atualizar SÓ a própria foto — nunca o papel (role) nem o
-- nome vinculado (gestor_nome), mesmo tentando via chamada direta à API.
-- O grant abaixo restringe a nível de COLUNA: um UPDATE que tente tocar em
-- qualquer outra coluna é rejeitado pelo Postgres antes mesmo da política
-- de linha ser avaliada.
grant update (foto_url) on public.profiles to authenticated;

drop policy if exists "Usuário atualiza a própria foto" on public.profiles;
create policy "Usuário atualiza a própria foto" on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());
