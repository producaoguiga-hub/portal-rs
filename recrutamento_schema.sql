-- ============================================================
-- Central de Recrutamento (R&S > Recrutamento)
-- Rodar uma vez no SQL Editor do Supabase.
--
-- O questionário público (candidatura.html) grava aqui sem login.
-- Quem não está logado só consegue INSERIR (nunca ler, editar ou apagar).
-- Só admin (RH) vê e mexe nas candidaturas.
-- ============================================================

create table if not exists public.recrutamento (
  id                uuid primary key default gen_random_uuid(),
  created_at        timestamptz not null default now(),

  -- LGPD
  lgpd_autoriza     boolean not null default false,

  -- Vida pessoal
  nome              text not null,
  data_nascimento   date,
  telefone          text,
  email             text,
  naturalidade      text,
  cidade            text,
  uf                text,
  estado_civil      text,
  filhos            text,

  -- Hobbies e life style
  dias_livres       text,
  canais_info       text,
  metas             text,
  atividade_fisica  text,

  -- Vida profissional
  curso             text,       -- Administração / Ciências Contábeis / Engenharia Mecânica / Engenharia de Petróleo / Outro: ...
  universidade      text,
  tipo_univ         text,       -- Federal / Estadual / Particular
  graduacao         text,       -- Concluída / Em andamento
  ano_conclusao     int,
  empresa_atual     text,
  gostou_trabalho   text,
  experiencia       text,
  salario_atual     text,
  pretensao         text,
  idioma            text,
  intercambio       text,

  -- Requisitos da vaga
  mobilidade        boolean,
  mobilidade_obs    text,
  diploma           boolean,
  cnh_b             boolean,
  cnh_validade      date,
  fonte             text,       -- Como soube da vaga (mesmas opções de "Fonte de captação" dos admitidos)

  -- Documentos (caminhos no bucket privado "recrutamento")
  curriculo_path    text,
  diploma_path      text,
  cnh_path          text,

  -- Uso do RH
  status            text not null default 'novo',  -- novo / triagem / entrevista / individual / aprovado / contratado / banco / reprovado
  entrevista_em     timestamptz,
  notas_rh          text,
  atualizado_em     timestamptz
);

create index if not exists recrutamento_created_idx on public.recrutamento (created_at desc);
create index if not exists recrutamento_status_idx  on public.recrutamento (status);

alter table public.recrutamento enable row level security;

-- Candidato (sem login): só envia. Não pode já chegar "aprovado" nem com anotação do RH.
drop policy if exists recrutamento_insert_publico on public.recrutamento;
create policy recrutamento_insert_publico on public.recrutamento
  for insert to anon, authenticated
  with check (status = 'novo' and notas_rh is null and entrevista_em is null and lgpd_autoriza = true);

drop policy if exists recrutamento_admin_select on public.recrutamento;
create policy recrutamento_admin_select on public.recrutamento
  for select to authenticated using (public.is_admin());

drop policy if exists recrutamento_admin_update on public.recrutamento;
create policy recrutamento_admin_update on public.recrutamento
  for update to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists recrutamento_admin_delete on public.recrutamento;
create policy recrutamento_admin_delete on public.recrutamento
  for delete to authenticated using (public.is_admin());

-- ── Documentos: bucket PRIVADO (currículo, diploma e CNH não ficam com link público) ──
insert into storage.buckets (id, name, public, file_size_limit)
values ('recrutamento', 'recrutamento', false, 10485760)   -- 10 MB por arquivo
on conflict (id) do update set public = false, file_size_limit = 10485760;

drop policy if exists recrutamento_docs_upload on storage.objects;
create policy recrutamento_docs_upload on storage.objects
  for insert to anon, authenticated
  with check (bucket_id = 'recrutamento');

drop policy if exists recrutamento_docs_admin_le on storage.objects;
create policy recrutamento_docs_admin_le on storage.objects
  for select to authenticated
  using (bucket_id = 'recrutamento' and public.is_admin());

drop policy if exists recrutamento_docs_admin_apaga on storage.objects;
create policy recrutamento_docs_admin_apaga on storage.objects
  for delete to authenticated
  using (bucket_id = 'recrutamento' and public.is_admin());
