-- ============================================================
-- PDI: pedido de +15 dias de prazo (gestor pede → RH aprova no portal)
-- Rode no SQL Editor do Supabase (projeto do Mais Gestor) — pode rodar de novo.
--
-- • O gestor pede +15 dias numa ação do próprio PDI (com o motivo).
-- • O RH recebe e-mail (Edge Function "pedido-prazo-email") e aprova ou
--   recusa no portal. Ao aprovar, o novo prazo é calculado e gravado sozinho:
--     - prazo ainda não venceu  → prazo atual + 15 dias
--     - prazo já venceu         → hoje + 15 dias (senão já nasceria atrasado)
-- • Um pedido pendente por ação; depois da decisão, pode pedir de novo.
-- ============================================================

create table if not exists public.pdi_prorrogacoes (
  id uuid primary key default gen_random_uuid(),
  pdi_id uuid not null references public.pdi(id) on delete cascade,
  gestor_nome text not null,
  dias int not null default 15,
  motivo text,
  prazo_anterior date,          -- prazo no momento do pedido (atualizado na decisão)
  prazo_novo date,              -- preenchido quando aprovado
  status text not null default 'pendente' check (status in ('pendente','aprovado','recusado')),
  resposta text,                -- comentário do RH pro gestor (opcional)
  solicitado_por uuid default auth.uid(),
  decidido_por uuid,
  decidido_em timestamptz,
  email_enviado boolean not null default false,
  created_at timestamptz not null default now()
);

create unique index if not exists pdi_prorrogacoes_um_pendente
  on public.pdi_prorrogacoes (pdi_id) where status = 'pendente';

alter table public.pdi_prorrogacoes enable row level security;

drop policy if exists "Admin acessa prorrogacoes" on public.pdi_prorrogacoes;
create policy "Admin acessa prorrogacoes" on public.pdi_prorrogacoes
  for all to authenticated using (is_admin()) with check (is_admin());

drop policy if exists "Gestor vê os próprios pedidos de prazo" on public.pdi_prorrogacoes;
create policy "Gestor vê os próprios pedidos de prazo" on public.pdi_prorrogacoes
  for select to authenticated using (gestor_nome = my_gestor_nome());

drop policy if exists "Gestor pede prazo nas próprias ações" on public.pdi_prorrogacoes;
create policy "Gestor pede prazo nas próprias ações" on public.pdi_prorrogacoes
  for insert to authenticated
  with check (
    gestor_nome = my_gestor_nome()
    and exists (select 1 from public.pdi p
                where p.id = pdi_id and p.gestor_nome = my_gestor_nome()
                  and coalesce(p.status_acao, '') not in ('Concluído', 'Descontinuado'))
  );

-- O pedido é sempre "+15 dias, pendente": o servidor completa os campos,
-- não importa o que o navegador mandou.
create or replace function public.pdi_prorrogacao_preenche() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  select p.gestor_nome, p.data_termino_programada into NEW.gestor_nome, NEW.prazo_anterior
    from public.pdi p where p.id = NEW.pdi_id;
  NEW.dias := 15;
  NEW.status := 'pendente';
  NEW.prazo_novo := null;
  NEW.resposta := null;
  NEW.decidido_por := null;
  NEW.decidido_em := null;
  NEW.email_enviado := false;
  NEW.solicitado_por := auth.uid();
  return NEW;
end;
$$;

drop trigger if exists trg_pdi_prorrogacao_preenche on public.pdi_prorrogacoes;
create trigger trg_pdi_prorrogacao_preenche
  before insert on public.pdi_prorrogacoes
  for each row execute function public.pdi_prorrogacao_preenche();

-- Decisão do RH: aprova (calcula e grava o novo prazo no PDI) ou recusa.
create or replace function public.decidir_prorrogacao(p_id uuid, p_aprovar boolean, p_resposta text default null)
  returns public.pdi_prorrogacoes
  language plpgsql security definer set search_path = public as $$
declare
  r public.pdi_prorrogacoes;
  v_prazo date;
  v_novo date;
begin
  if not is_admin() then raise exception 'Só o RH pode decidir pedidos de prazo.'; end if;
  select * into r from public.pdi_prorrogacoes where id = p_id for update;
  if not found then raise exception 'Pedido de prazo não encontrado.'; end if;
  if r.status <> 'pendente' then raise exception 'Esse pedido já foi %.', r.status; end if;

  if p_aprovar then
    select data_termino_programada into v_prazo from public.pdi where id = r.pdi_id for update;
    v_novo := greatest(coalesce(v_prazo, current_date), current_date) + r.dias;
    update public.pdi set data_termino_programada = v_novo where id = r.pdi_id;
    -- Prazo novo: os lembretes automáticos (15d / 7d / atrasado) valem de novo.
    if exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'pdi' and column_name = 'atrasado_enviado') then
      execute 'update public.pdi set lembrete_15d_enviado = false, lembrete_7d_enviado = false, atrasado_enviado = false where id = $1'
        using r.pdi_id;
    end if;
    update public.pdi_prorrogacoes
       set status = 'aprovado', prazo_anterior = v_prazo, prazo_novo = v_novo,
           resposta = nullif(trim(p_resposta), ''), decidido_por = auth.uid(), decidido_em = now()
     where id = p_id returning * into r;
  else
    update public.pdi_prorrogacoes
       set status = 'recusado', resposta = nullif(trim(p_resposta), ''), decidido_por = auth.uid(), decidido_em = now()
     where id = p_id returning * into r;
  end if;
  return r;
end;
$$;

grant execute on function public.decidir_prorrogacao(uuid, boolean, text) to authenticated;

-- E-mail pro RH assim que o pedido entra. Se a Edge Function ainda não
-- estiver publicada, o pedido é salvo normalmente (só o e-mail não sai) —
-- e aparece de qualquer jeito no portal, em PDI Gestão.
create extension if not exists pg_net;

create or replace function public.pdi_prorrogacao_avisa_rh() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  perform net.http_post(
    url := 'https://gahrfavjcdgwjmlsajeo.supabase.co/functions/v1/pedido-prazo-email',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdhaHJmYXZqY2Rnd2ptbHNhamVvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE3OTQzNzYsImV4cCI6MjA5NzM3MDM3Nn0.I5ozH_hPb4DT-PerlWwtpMKwBMXZnCQeNLu5rDs3tKY'
    ),
    body := jsonb_build_object('prorrogacao_id', NEW.id)
  );
  return NEW;
exception when others then
  return NEW;   -- e-mail nunca impede o pedido de ser salvo
end;
$$;

drop trigger if exists trg_pdi_prorrogacao_avisa_rh on public.pdi_prorrogacoes;
create trigger trg_pdi_prorrogacao_avisa_rh
  after insert on public.pdi_prorrogacoes
  for each row execute function public.pdi_prorrogacao_avisa_rh();

notify pgrst, 'reload schema';
