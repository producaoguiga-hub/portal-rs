-- ============================================================
-- Atualização de andamento do PDI (o gestor conta "como está indo"
-- a qualquer momento, não só na conclusão)
-- Rode no SQL Editor DEPOIS de já ter rodado pdi_conclusao_fields.sql
--
-- Isso é independente do e-mail automático de acompanhamento (que
-- ainda está pausado, esperando o TI) — o campo já funciona no
-- portal mesmo sem o e-mail estar ativo.
-- ============================================================

alter table public.pdi add column if not exists acompanhamento_resumo text;
alter table public.pdi add column if not exists acompanhamento_resumo_em timestamptz;

-- Redefine a trava de "o que o gestor pode mexer" (criada em
-- pdi_conclusao_fields.sql) incluindo esses dois campos novos na lista
-- permitida — sem isso, a trigger bloquearia a atualização.
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
      raise exception 'Gestor só pode preencher a conclusão/acompanhamento da própria ação, não editar os outros campos.';
    end if;
    if NEW.status_acao is distinct from OLD.status_acao and NEW.status_acao <> 'Concluído' then
      raise exception 'Gestor só pode marcar a ação como Concluído.';
    end if;
  end if;
  return NEW;
end;
$$;
