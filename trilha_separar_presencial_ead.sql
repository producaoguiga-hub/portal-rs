-- ============================================================
-- Trilha: separa Direção Defensiva e NR 20 em Presencial (Externo) e EAD,
-- como estão na Matriz de Treinamento (rev. 13).
-- Rode no SQL Editor do Supabase (projeto do Mais Gestor). Pode rodar de novo.
--
-- A etapa que já existia vira a versão PRESENCIAL (EXTERNO) — quem já
-- marcou como concluída continua com ela. A versão EAD entra logo depois,
-- e a ordem das etapas seguintes anda uma posição.
-- ============================================================

do $$
declare
  cursos jsonb := '[
    {"antigo": "DIREÇÃO DEFENSIVA",
     "presencial": "DIREÇÃO DEFENSIVA - PRESENCIAL (EXTERNO)",
     "ead": "DIREÇÃO DEFENSIVA - EAD", "carga": 8, "validade": 2},
    {"antigo": "NR 20 - SEGURANÇA E SAÚDE NO TRABALHO COM INFLAMÁVEIS E COMBUSTÍVEIS",
     "presencial": "NR 20 - SEGURANÇA E SAÚDE NO TRABALHO COM INFLAMÁVEIS E COMBUSTÍVEIS - PRESENCIAL (EXTERNO)",
     "ead": "NR 20 - SEGURANÇA E SAÚDE NO TRABALHO COM INFLAMÁVEIS E COMBUSTÍVEIS - EAD", "carga": 16, "validade": 3}
  ]';
  c jsonb;
  v_ordem int;
begin
  for c in select * from jsonb_array_elements(cursos) loop
    if exists (select 1 from public.trilha_etapas where nome = c->>'ead') then continue; end if;

    update public.trilha_etapas
       set nome = c->>'presencial', instituicao = 'Externo', modalidade = 'Presencial', instrutor = 'Terceiros'
     where nome = c->>'antigo'
     returning ordem into v_ordem;
    if v_ordem is null then
      select ordem into v_ordem from public.trilha_etapas where nome = c->>'presencial';
    end if;
    if v_ordem is null then continue; end if;   -- curso não está na matriz desse banco

    update public.trilha_etapas set ordem = ordem + 1 where ordem > v_ordem;
    insert into public.trilha_etapas (ordem, categoria, nome, requisito, instituicao, modalidade, instrutor, carga_horaria, validade_anos, pontos)
    select v_ordem + 1, categoria, c->>'ead', requisito, 'Interno', 'EAD', 'Perbras EAD',
           (c->>'carga')::int, (c->>'validade')::int, greatest(10, (c->>'carga')::int * 10)
      from public.trilha_etapas where nome = c->>'presencial';
  end loop;
end $$;

-- Conferência: as 4 etapas, na ordem
select ordem, categoria, nome, modalidade, carga_horaria, validade_anos, pontos
  from public.trilha_etapas
 where nome like 'DIREÇÃO DEFENSIVA%' or nome like 'NR 20%'
 order by ordem;
