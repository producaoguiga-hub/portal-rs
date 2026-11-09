-- ============================================================
-- Monitorias: campo "ano"
-- Rodar uma vez no SQL Editor do Supabase.
--
-- Novas monitorias (portal ou formulário do monitor) já entram com o ano atual.
-- Para as que já existem, o ano é tirado da "duração" quando ela tem uma data
-- (ex.: "21/07/2025 a 24/11/2025" -> 2025); senão, do dia em que foi cadastrada.
-- As importadas do Forms entram com o ano da importação: confira e ajuste no
-- portal (Monitorias > abrir a avaliação > Editar > Ano).
-- ============================================================

alter table public.monitorias add column if not exists ano int;
alter table public.monitorias alter column ano set default extract(year from now())::int;

update public.monitorias
set ano = coalesce(
  (select max(m[1])::int from regexp_matches(coalesce(duracao, ''), '(20[0-9]{2})', 'g') as m),
  extract(year from created_at)::int
)
where ano is null;

select ano, count(*) as monitorias from public.monitorias group by ano order by ano;
