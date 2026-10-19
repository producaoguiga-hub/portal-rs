-- ============================================================
-- Conclusão de ação de PDI pelo próprio gestor
-- (anexo/certificado + comentário + NPS da ação)
-- Rode no SQL Editor do Supabase DEPOIS de já ter rodado pdi_self_fields.sql
-- ============================================================

alter table public.pdi add column if not exists conclusao_comentario text;
alter table public.pdi add column if not exists conclusao_nps int;
alter table public.pdi add column if not exists conclusao_anexo_url text;
alter table public.pdi add column if not exists concluido_em timestamptz;

-- Até aqui o gestor só podia LER o próprio PDI. Agora ele também pode
-- atualizar a própria ação (pra marcar como concluída) — mas o que ele
-- pode de fato mudar é travado pelo trigger logo abaixo, não só pela
-- policy: RLS trabalha por LINHA, não por coluna, e "authenticated" é o
-- mesmo papel do Postgres usado tanto pelo admin quanto pelo gestor.
drop policy if exists "Gestor conclui sua própria ação de PDI" on public.pdi;
create policy "Gestor conclui sua própria ação de PDI" on public.pdi
  for update to authenticated
  using (gestor_nome = my_gestor_nome())
  with check (gestor_nome = my_gestor_nome());

create or replace function public.pdi_restringe_conclusao_gestor() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then
    if NEW.gestor_nome is distinct from OLD.gestor_nome
      or NEW.unidade is distinct from OLD.unidade
      or NEW.canal_mapeamento is distinct from OLD.canal_mapeamento
      or NEW.origem_acao is distinct from OLD.origem_acao
      or NEW.evidencia_link is distinct from OLD.evidencia_link
      or NEW.competencia_desenvolvimento is distinct from OLD.competencia_desenvolvimento
      or NEW.tipo_necessidade is distinct from OLD.tipo_necessidade
      or NEW.direcao_crescimento is distinct from OLD.direcao_crescimento
      or NEW.acao is distinct from OLD.acao
      or NEW.acao_pdi_link is distinct from OLD.acao_pdi_link
      or NEW.detalhe_desenvolvimento is distinct from OLD.detalhe_desenvolvimento
      or NEW.data_inicio is distinct from OLD.data_inicio
      or NEW.data_termino_programada is distinct from OLD.data_termino_programada
      or NEW.ano is distinct from OLD.ano
      or NEW.feedback_dre is distinct from OLD.feedback_dre
      or NEW.gestor_email is distinct from OLD.gestor_email
      or NEW.objetivo_carreira is distinct from OLD.objetivo_carreira
      or NEW.diagnostico is distinct from OLD.diagnostico
      or NEW.sabe_acao_imediata is distinct from OLD.sabe_acao_imediata
    then
      raise exception 'Gestor só pode preencher a conclusão da própria ação, não editar os outros campos.';
    end if;
    if NEW.status_acao is distinct from OLD.status_acao and NEW.status_acao <> 'Concluído' then
      raise exception 'Gestor só pode marcar a ação como Concluído.';
    end if;
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_pdi_restringe_conclusao_gestor on public.pdi;
create trigger trg_pdi_restringe_conclusao_gestor
  before update on public.pdi
  for each row execute function public.pdi_restringe_conclusao_gestor();
