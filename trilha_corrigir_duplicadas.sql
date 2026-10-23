-- ============================================================
-- Trilha: corrige Direção Defensiva e NR 20 aparecendo 3 vezes
-- (a etapa antiga "Presencial ou EAD" ficou junto das duas novas).
-- Rode no SQL Editor do Supabase (projeto do Mais Gestor). Pode rodar de novo.
--
-- 1. Quem marcou a etapa antiga como concluída passa a ter a versão
--    PRESENCIAL (EXTERNO) concluída — ninguém perde pontos.
-- 2. Apaga as etapas antigas.
-- 3. Reorganiza a ordem das etapas igual à matriz (rev. 13); etapas que o
--    RH criou no portal ficam no fim, na ordem em que já estavam.
-- ============================================================

-- 1) Leva as conclusões da etapa antiga pra versão presencial
with pares (antigo, novo) as (values
    ('DIREÇÃO DEFENSIVA', 'DIREÇÃO DEFENSIVA - PRESENCIAL (EXTERNO)'),
    ('NR 20 - SEGURANÇA E SAÚDE NO TRABALHO COM INFLAMÁVEIS E COMBUSTÍVEIS', 'NR 20 - SEGURANÇA E SAÚDE NO TRABALHO COM INFLAMÁVEIS E COMBUSTÍVEIS - PRESENCIAL (EXTERNO)')
),
ids as (
  select a.id as antigo_id, n.id as novo_id
  from pares p
  join public.trilha_etapas a on a.nome = p.antigo
  join public.trilha_etapas n on n.nome = p.novo
)
insert into public.trilha_progresso (pessoa_id, etapa_id, concluido_em, foto_url, comentario)
select tp.pessoa_id, ids.novo_id, tp.concluido_em, tp.foto_url, tp.comentario
from public.trilha_progresso tp join ids on ids.antigo_id = tp.etapa_id
on conflict (pessoa_id, etapa_id) do nothing;

-- 2) Apaga as etapas antigas (só se a versão presencial nova existir)
delete from public.trilha_etapas a
where a.nome in ('DIREÇÃO DEFENSIVA', 'NR 20 - SEGURANÇA E SAÚDE NO TRABALHO COM INFLAMÁVEIS E COMBUSTÍVEIS')
  and exists (select 1 from public.trilha_etapas n where n.nome = a.nome || ' - PRESENCIAL (EXTERNO)');

-- 3) Ordem igual à matriz
with matriz (ordem, nome) as (values
    ( 1, 'ROTAÇÃO DE TRABALHO PERBRAS.INFO'),
    ( 2, 'DIREÇÃO DEFENSIVA - PRESENCIAL (EXTERNO)'),
    ( 3, 'DIREÇÃO DEFENSIVA - EAD'),
    ( 4, 'AUDITOR INTERNO ISO'),
    ( 5, 'BOAS PRÁTICAS EM UMA REUNIÃO'),
    ( 6, 'NR 17 - ERGONOMIA'),
    ( 7, 'NR 20 - SEGURANÇA E SAÚDE NO TRABALHO COM INFLAMÁVEIS E COMBUSTÍVEIS - PRESENCIAL (EXTERNO)'),
    ( 8, 'NR 20 - SEGURANÇA E SAÚDE NO TRABALHO COM INFLAMÁVEIS E COMBUSTÍVEIS - EAD'),
    ( 9, 'NR-5 - CIPA'),
    (10, 'PROGRAMA DE CONFORMIDADE PERBRAS'),
    (11, 'RT - ACESSOS E SISTEMAS INICIAIS'),
    (12, 'RT - CONHECENDO O PERBRAS INFO'),
    (13, 'RT - CONHECENDO O SISMAN'),
    (14, 'RT - CONHECENDO OS PRINCIPAIS SISTEMAS'),
    (15, 'RT - PREPOSTO TRABALHISTA'),
    (16, 'RT A POSTURA DO GESTOR NAS RELAÇÕES DE TRABALHO'),
    (17, 'RT APRENDENDO A UTILIZAR A GUPY'),
    (18, 'RT COMO CONTRATO PESSOAS'),
    (19, 'RT COMO FAÇO FOLHA DE PAGAMENTO'),
    (20, 'RT COMO FAÇO MEU ORÇAMENTO E ACOMPANHO'),
    (21, 'RT COMO FAÇO UMA RESCISÃO DE TRABALHO'),
    (22, 'RT COMO MOBILIZO CONTRATOS'),
    (23, 'RT COMO NASCEM NOVOS CONTRATOS'),
    (24, 'RT COMO NEGOCIO COM SINDICATO'),
    (25, 'RT CONHECENDO A FABRICAÇÃO'),
    (26, 'RT CONHECENDO O NEGÓCIO INTERSERVICE'),
    (27, 'RT CONHECENDO O PROCONPH E O SOGI'),
    (28, 'RT CONHECENDO UM CONTRATO DE SPT'),
    (29, 'RT CONHECENDO UMA OS'),
    (30, 'RT CONTÁBIL'),
    (31, 'RT CULTURA PERBRAS'),
    (32, 'RT DE BENEFÍCIOS - PLUXEE/CAJU'),
    (33, 'RT EXECUTANDO A ESTRATÉGIA'),
    (34, 'RT FINANCEIRA'),
    (35, 'RT FISCAL'),
    (36, 'RT GESTÃO DE AFASTADOS'),
    (37, 'RT GESTÃO DE PLANOS DE SAÚDE, SEGURO DE VIDA, ODONTO'),
    (38, 'RT JOVEM APRENDIZ'),
    (39, 'RT JURÍDICA'),
    (40, 'RT MEDICINA OCUPACIONAL E PCMSO'),
    (41, 'RT PLANEJAMENTO EMPRESARIAL'),
    (42, 'RT PLANO DE CARGOS E SALÁRIOS'),
    (43, 'RT PLR'),
    (44, 'RT PROGRAMAS DE SMS'),
    (45, 'RT SEGURO DE EQUIPAMENTOS'),
    (46, 'RT SEGURO DE VEÍCULOS'),
    (47, 'RT SISTEMA DE GESTÃO INTEGRADO - SGI'),
    (48, 'ASO ANUAL - ATESTADO DE SAÚDE OCUPACIONAL'),
    (49, 'PRIMEIROS SOCORROS'),
    (50, 'REGRAS DE OURO PETROBRAS'),
    (51, 'SISTEMA DE GESTÃO INTEGRADO - SGI')
),
nova as (
  select e.id, row_number() over (order by coalesce(m.ordem, 1000), e.ordem, e.created_at) as n
  from public.trilha_etapas e left join matriz m on m.nome = e.nome
)
update public.trilha_etapas e set ordem = nova.n from nova where nova.id = e.id and e.ordem <> nova.n;

-- Conferência: devem aparecer 4 linhas (2 de Direção Defensiva, 2 de NR 20)
select ordem, categoria, nome, modalidade, pontos,
       (select count(*) from public.trilha_etapas where ativo) as total_etapas_ativas
from public.trilha_etapas
where nome like 'DIREÇÃO DEFENSIVA%' or nome like 'NR 20%'
order by ordem;
