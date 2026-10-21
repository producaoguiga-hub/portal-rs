-- ============================================================
-- Dados de RH por pessoa: nome completo, cargo, data de admissão e salário.
-- Rode no SQL Editor do Supabase DEPOIS de pessoas_schema.sql e
-- trajetoria_schema.sql (usa my_pessoa_id()). Pode rodar de novo.
--
-- Fica numa tabela à parte (e não em "pessoas", que todo logado lê) porque
-- tem salário: só o RH lê a tabela inteira; o gestor lê só a própria linha
-- (o portal usa dela o cargo e a admissão — salário não aparece em tela).
-- Os dados vêm de pessoas_rh_import*.sql (fora do git).
-- ============================================================

create table if not exists public.pessoas_rh (
  pessoa_id uuid primary key references public.pessoas(id) on delete cascade,
  nome_completo text,
  cargo text,            -- como na folha: "GESTOR JUNIOR 2", "GESTOR MASTER 1"...
  admissao date,
  salario numeric(12,2),
  atualizado_em timestamptz not null default now()
);

alter table public.pessoas_rh enable row level security;

drop policy if exists "Admin acessa pessoas_rh" on public.pessoas_rh;
create policy "Admin acessa pessoas_rh" on public.pessoas_rh
  for all to authenticated using (is_admin()) with check (is_admin());

drop policy if exists "Pessoa lê os próprios dados de RH" on public.pessoas_rh;
create policy "Pessoa lê os próprios dados de RH" on public.pessoas_rh
  for select to authenticated using (pessoa_id = my_pessoa_id());
