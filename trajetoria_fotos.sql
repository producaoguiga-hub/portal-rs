-- ============================================================
-- Minha Trajetória: várias fotos por marco
-- Rode no SQL Editor do Supabase (projeto do Mais Gestor).
-- "foto_url" continua sendo a foto de capa (a primeira da lista).
-- ============================================================

alter table public.trajetoria_marcos add column if not exists fotos text[];

-- Marcos antigos: a foto que já existia vira a primeira da lista.
update public.trajetoria_marcos
   set fotos = array[foto_url]
 where foto_url is not null and (fotos is null or cardinality(fotos) = 0);

-- Pro REST enxergar a coluna nova na hora
notify pgrst, 'reload schema';
