-- ============================================================
-- Central de Recrutamento: "Entendendo a vaga" + teste de perfil (DISC)
-- Rodar uma vez no SQL Editor do Supabase.
--
-- vaga_ciente : a pessoa leu a descrição da vaga e confirmou com ✅
-- disc        : letra predominante no teste (D, I, S ou C)
-- disc_pontos : intensidade de cada fator, de 0 a 100. Ex.: {"D":71,"I":42,"S":38,"C":50}
--
-- Até rodar este arquivo o formulário continua funcionando: ele envia a
-- candidatura sem essas colunas e anota o resultado do teste no fim do
-- campo "O que facilita a mudança".
-- ============================================================

alter table public.recrutamento add column if not exists vaga_ciente boolean;
alter table public.recrutamento add column if not exists disc text;
alter table public.recrutamento add column if not exists disc_pontos jsonb;

-- Só aceita as letras do DISC
alter table public.recrutamento drop constraint if exists recrutamento_disc_chk;
alter table public.recrutamento add constraint recrutamento_disc_chk check (disc is null or disc in ('D','I','S','C'));
