-- =====================================================================
--  LIMONE BISTRO ESPOO - hallintapaneelin tietokanta
--  Aja tama Supabasen SQL Editorissa (Supabase -> SQL Editor -> New query)
-- =====================================================================

-- ---------- 1. SISALTO ----------
-- Vapaamuotoiset sivun tekstit avain-arvo -pareina.
create table if not exists public.site_content (
  key         text primary key,
  value       jsonb not null default '{}'::jsonb,
  updated_at  timestamptz not null default now()
);

-- Oletussisalto (voi muokata paneelista)
insert into public.site_content (key, value) values
  ('hero',    '{"eyebrow":"Limone Bistro · Espoo","line1":"Cucina","line2":"italiana","lead":"Rapeapohjaiset pizzat, tuoreet pastat ja kermaiset risotot — aamusta iltaan, joka päivä."}'::jsonb),
  ('info',    '{"phone":"045 140 8686","address":"Rusthollarinkatu 6, 02270 Espoo","order_url":"https://limoneespoo.cityfood.fi/","lunch_hours":"Ma–Pe 10.30–14.00"}'::jsonb),
  ('hours',   '{"mon_fri":"9.00–19.30","sat":"10.00–17.30","sun":"11.00–17.30"}'::jsonb),
  ('intro',   '{"title":"Italian klassikot keskellä arkea.","title_em":"Rauhassa lounaalla, kiireettä illalla.","body":"Limone Bistro palvelee Bauhausin tiloissa Espoossa joka päivä."}'::jsonb)
on conflict (key) do nothing;

-- ---------- 2. LOUNASLISTA ----------
create table if not exists public.lunch_weeks (
  id          uuid primary key default gen_random_uuid(),
  week_start  date not null unique,          -- viikon maanantai
  label       text,                          -- esim. "7.9.–11.9.2026"
  published   boolean not null default false,
  source      text,                          -- 'manual' | 'pdf' | 'image'
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists public.lunch_items (
  id          uuid primary key default gen_random_uuid(),
  week_id     uuid not null references public.lunch_weeks(id) on delete cascade,
  weekday     smallint not null check (weekday between 1 and 5),  -- 1 = maanantai
  sort        smallint not null default 0,
  kind        text,                          -- Pizza | Pasta | Risotto | Insalata
  name        text not null,
  description text,
  price       numeric(6,2),
  diet        text                           -- "L", "G", "L G"
);

create index if not exists lunch_items_week_idx on public.lunch_items (week_id, weekday, sort);

-- ---------- 3. KAVIJATILASTOT ----------
create table if not exists public.page_views (
  id           bigserial primary key,
  created_at   timestamptz not null default now(),
  day          date not null default (now() at time zone 'Europe/Helsinki')::date,
  path         text not null,
  referrer     text,
  device       text,                         -- mobile | desktop | tablet
  country      text,
  visitor_hash text not null                 -- paivittain vaihtuva hash, ei IP-osoitetta
);

create index if not exists page_views_day_idx  on public.page_views (day);
create index if not exists page_views_path_idx on public.page_views (day, path);

-- Paivakohtainen yhteenveto
create or replace view public.stats_daily as
select
  day,
  count(*)                        as views,
  count(distinct visitor_hash)    as visitors
from public.page_views
group by day
order by day desc;

-- Suosituimmat sivut viimeisen 30 pv ajalta
create or replace view public.stats_pages as
select
  path,
  count(*)                     as views,
  count(distinct visitor_hash) as visitors
from public.page_views
where day >= (now() at time zone 'Europe/Helsinki')::date - 30
group by path
order by views desc;

-- Laitejakauma
create or replace view public.stats_devices as
select
  coalesce(device,'tuntematon') as device,
  count(*) as views
from public.page_views
where day >= (now() at time zone 'Europe/Helsinki')::date - 30
group by 1
order by views desc;

-- ---------- 4. KAYTTOOIKEUDET (RLS) ----------
alter table public.site_content enable row level security;
alter table public.lunch_weeks  enable row level security;
alter table public.lunch_items  enable row level security;
alter table public.page_views   enable row level security;

-- Sivusto saa lukea sisallon ja julkaistun lounaslistan ilman kirjautumista
drop policy if exists "sisalto luettavissa" on public.site_content;
create policy "sisalto luettavissa" on public.site_content
  for select using (true);

drop policy if exists "julkaistu lounas luettavissa" on public.lunch_weeks;
create policy "julkaistu lounas luettavissa" on public.lunch_weeks
  for select using (published = true);

drop policy if exists "julkaistun viikon annokset luettavissa" on public.lunch_items;
create policy "julkaistun viikon annokset luettavissa" on public.lunch_items
  for select using (
    exists (select 1 from public.lunch_weeks w where w.id = week_id and w.published)
  );

-- Kirjautunut henkilokunta saa muokata kaikkea
drop policy if exists "henkilokunta hallitsee sisaltoa" on public.site_content;
create policy "henkilokunta hallitsee sisaltoa" on public.site_content
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

drop policy if exists "henkilokunta hallitsee viikkoja" on public.lunch_weeks;
create policy "henkilokunta hallitsee viikkoja" on public.lunch_weeks
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

drop policy if exists "henkilokunta hallitsee annoksia" on public.lunch_items;
create policy "henkilokunta hallitsee annoksia" on public.lunch_items
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- Tilastot: vain kirjautuneet lukevat. Kirjaus tapahtuu palvelimen kautta.
drop policy if exists "henkilokunta lukee tilastot" on public.page_views;
create policy "henkilokunta lukee tilastot" on public.page_views
  for select using (auth.role() = 'authenticated');

-- ---------- 5. APUFUNKTIO: paivita updated_at ----------
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists site_content_touch on public.site_content;
create trigger site_content_touch before update on public.site_content
  for each row execute function public.touch_updated_at();

drop trigger if exists lunch_weeks_touch on public.lunch_weeks;
create trigger lunch_weeks_touch before update on public.lunch_weeks
  for each row execute function public.touch_updated_at();
