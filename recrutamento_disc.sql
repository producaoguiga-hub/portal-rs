-- ============================================================
-- Central de Recrutamento: "Entendendo a vaga" + teste de perfil (DISC)
-- Rodar no SQL Editor do Supabase. Pode rodar de novo sem problema
-- (se já rodou a versão anterior, rode esta também: ela cria as funções).
--
-- vaga_ciente : a pessoa leu a descrição da vaga e confirmou com ✅
-- disc        : letra predominante no teste (D, I, S ou C)
-- disc_pontos : intensidade de cada fator, de 0 a 100. Ex.: {"D":71,"I":42,"S":38,"C":50}
--
-- O teste é a "Etapa 2": aparece logo depois que a candidatura é enviada,
-- ou pelo link que o RH copia no portal (candidatura.html?teste=<id>).
-- Quem não está logado continua sem poder ler ou editar candidaturas; as
-- funções abaixo só deixam GRAVAR O TESTE, uma única vez, na candidatura
-- daquele link (o id é um código aleatório, impossível de adivinhar).
-- ============================================================

alter table public.recrutamento add column if not exists vaga_ciente boolean;
alter table public.recrutamento add column if not exists disc text;
alter table public.recrutamento add column if not exists disc_pontos jsonb;

alter table public.recrutamento drop constraint if exists recrutamento_disc_chk;
alter table public.recrutamento add constraint recrutamento_disc_chk check (disc is null or disc in ('D','I','S','C'));

-- Para a página do teste cumprimentar pelo nome e saber se já foi feito.
-- Devolve só o primeiro nome, nada além disso.
create or replace function public.rec_teste_info(p_id uuid)
returns table (primeiro_nome text, feito boolean)
language sql stable security definer set search_path = public as $$
  select split_part(trim(nome), ' ', 1), disc is not null
  from public.recrutamento where id = p_id;
$$;

-- Grava o resultado do teste. Só funciona se o teste ainda não foi feito.
create or replace function public.rec_salvar_disc(p_id uuid, p_disc text, p_pontos jsonb)
returns boolean
language plpgsql security definer set search_path = public as $$
declare n int; k text;
begin
  if p_disc is null or p_disc not in ('D','I','S','C') then raise exception 'perfil inválido'; end if;
  if jsonb_typeof(p_pontos) <> 'object' or not (p_pontos ?& array['D','I','S','C']) then raise exception 'pontos inválidos'; end if;
  foreach k in array array['D','I','S','C'] loop
    if jsonb_typeof(p_pontos->k) <> 'number' or (p_pontos->>k)::numeric not between 0 and 100 then raise exception 'pontos inválidos'; end if;
  end loop;
  update public.recrutamento
     set disc = p_disc,
         disc_pontos = jsonb_build_object('D', (p_pontos->>'D')::int, 'I', (p_pontos->>'I')::int, 'S', (p_pontos->>'S')::int, 'C', (p_pontos->>'C')::int),
         atualizado_em = now()
   where id = p_id and disc is null;
  get diagnostics n = row_count;
  return n = 1;
end;
$$;

revoke all on function public.rec_teste_info(uuid) from public;
revoke all on function public.rec_salvar_disc(uuid, text, jsonb) from public;
grant execute on function public.rec_teste_info(uuid) to anon, authenticated;
grant execute on function public.rec_salvar_disc(uuid, text, jsonb) to anon, authenticated;
