-- =====================================================================
--  Yağan Dijital · Anı Kamerası — Veritabanı şeması (Supabase)
--  Supabase panelinde: SQL Editor → New query → bu dosyanın tamamını
--  yapıştırın → Run. Bir kez çalıştırmanız yeterli.
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------
-- 1) TABLOLAR
-- ---------------------------------------------------------------------

-- Markalar (Yağan Dijital, Latife, ...). Kodun ön eki markayı belirler.
create table if not exists public.ak_brands (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  code_prefix   text not null unique check (code_prefix ~ '^[A-Z]{2,4}$'),
  primary_color text not null default '#e2552d' check (primary_color ~ '^#[0-9a-fA-F]{6}$'),
  logo_url      text,
  domain        text unique,              -- örn. latife.com.tr (www olmadan)
  tagline       text,
  is_default    boolean not null default false,
  created_at    timestamptz not null default now()
);
create unique index if not exists ak_brands_one_default on public.ak_brands (is_default) where is_default;

-- Paketler: kodun türü hangi özelliklerin açılacağını belirler.
create table if not exists public.ak_packages (
  id             text primary key,
  name           text not null,
  photo_limit    int check (photo_limit is null or photo_limit > 0),  -- null = sınırsız
  retention_days int not null default 90 check (retention_days between 1 and 3650),
  live_screen    boolean not null default false,
  sort           int not null default 0
);

-- Firmalar: salonlar, bayiler, organizasyon şirketleri.
create table if not exists public.ak_firms (
  id           uuid primary key default gen_random_uuid(),
  brand_id     uuid not null references public.ak_brands(id) on delete restrict,
  name         text not null,
  kind         text not null default 'salon' check (kind in ('salon','bayi','organizasyon','diger')),
  city         text,
  phone        text,
  email        text,
  storage_mode text not null default 'managed' check (storage_mode in ('managed','own')),
  notes        text,
  created_at   timestamptz not null default now()
);

-- Panel kullanıcılarının yetkisi.
--  super : her şeyi görür (Yağan Dijital yönetimi)
--  brand : sadece kendi markasını (örn. Latife yönetimi)
--  firm  : sadece kendi firmasının kodlarını ve etkinliklerini (salon/bayi)
create table if not exists public.ak_profiles (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  role       text not null check (role in ('super','brand','firm')),
  brand_id   uuid references public.ak_brands(id),
  firm_id    uuid references public.ak_firms(id),
  full_name  text,
  created_at timestamptz not null default now()
);

-- Aktivasyon kodları. Her kod 1 etkinlik açar.
create table if not exists public.ak_activation_codes (
  code        text primary key,                                   -- YGN-7K4P-2M9X
  code_plain  text generated always as (replace(code, '-', '')) stored unique,
  brand_id    uuid not null references public.ak_brands(id),
  package_id  text not null references public.ak_packages(id),
  firm_id     uuid references public.ak_firms(id) on delete set null,
  batch       text,
  status      text not null default 'new' check (status in ('new','used','void')),
  expires_at  timestamptz,
  created_by  uuid,
  created_at  timestamptz not null default now(),
  used_at     timestamptz,
  event_id    uuid
);
create index if not exists ak_activation_codes_brand_idx on public.ak_activation_codes (brand_id, status);
create index if not exists ak_activation_codes_firm_idx  on public.ak_activation_codes (firm_id);

-- Etkinlikler (düğün, nişan, kına ...).
create table if not exists public.ak_events (
  id            uuid primary key default gen_random_uuid(),
  slug          text not null unique,
  brand_id      uuid not null references public.ak_brands(id),
  firm_id       uuid references public.ak_firms(id) on delete set null,
  package_id    text not null references public.ak_packages(id),
  code          text references public.ak_activation_codes(code),
  name_a        text not null,
  name_b        text,
  event_type    text not null default 'Düğün',
  event_date    date not null,
  venue         text,
  photo_limit   int,
  live_screen   boolean not null default false,
  reveal_at     timestamptz,                 -- null: fotoğraflar hemen görünür
  album_key     text not null default encode(extensions.gen_random_bytes(16), 'hex'),
  contact_email text,
  status        text not null default 'active' check (status in ('active','closed')),
  expires_at    timestamptz not null,        -- bu tarihten sonra fotoğraflar silinir
  created_at    timestamptz not null default now()
);
create index if not exists ak_events_brand_idx on public.ak_events (brand_id, event_date desc);
create index if not exists ak_events_firm_idx  on public.ak_events (firm_id);

do $$ begin
  alter table public.ak_activation_codes
    add constraint ak_activation_codes_event_fk foreign key (event_id)
    references public.ak_events(id) on delete set null;
exception when duplicate_object then null; end $$;

-- Fotoğraflar.
create table if not exists public.ak_photos (
  id           uuid primary key default gen_random_uuid(),
  event_id     uuid not null references public.ak_events(id) on delete cascade,
  guest_token  text not null,
  guest_name   text not null,
  storage_path text not null unique,
  status       text not null default 'pending' check (status in ('pending','ok','hidden')),
  created_at   timestamptz not null default now()
);
create index if not exists ak_photos_event_idx on public.ak_photos (event_id, status, created_at desc);
create index if not exists ak_photos_guest_idx on public.ak_photos (event_id, guest_token);

-- Hatalı kod denemeleri (kaba kuvvet saldırısına karşı).
create table if not exists public.ak_activation_attempts (
  id  bigserial primary key,
  ip  text not null,
  at  timestamptz not null default now()
);
create index if not exists ak_activation_attempts_idx on public.ak_activation_attempts (ip, at);

-- ---------------------------------------------------------------------
-- 2) BAŞLANGIÇ VERİLERİ
-- ---------------------------------------------------------------------
insert into public.ak_packages (id, name, photo_limit, retention_days, live_screen, sort) values
  ('standart', 'Standart', 24,   90,  false, 1),
  ('premium',  'Premium',  null, 365, true,  2)
on conflict (id) do nothing;

insert into public.ak_brands (name, code_prefix, primary_color, tagline, is_default) values
  ('Yağan Dijital', 'YGN', '#e2552d', 'Anı Kamerası', true),
  ('Latife',        'LTF', '#8a5a44', 'Anı Kamerası', false)
on conflict (code_prefix) do nothing;

-- ---------------------------------------------------------------------
-- 3) YARDIMCI FONKSİYONLAR
-- ---------------------------------------------------------------------
create or replace function public.ak_my_role() returns text
language sql stable security definer set search_path = public as $$
  select role from public.ak_profiles where user_id = auth.uid()
$$;

create or replace function public.ak_my_brand() returns uuid
language sql stable security definer set search_path = public as $$
  select brand_id from public.ak_profiles where user_id = auth.uid()
$$;

create or replace function public.ak_my_firm() returns uuid
language sql stable security definer set search_path = public as $$
  select firm_id from public.ak_profiles where user_id = auth.uid()
$$;

create or replace function public.ak_my_firm_brand() returns uuid
language sql stable security definer set search_path = public as $$
  select f.brand_id from public.ak_firms f
  join public.ak_profiles p on p.firm_id = f.id
  where p.user_id = auth.uid()
$$;

create or replace function public.ak_is_super() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.ak_my_role() = 'super', false)
$$;

-- Kullanıcı bu marka/firmaya ait kaydı görebilir mi?
create or replace function public.ak_can_see(p_brand uuid, p_firm uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(
       public.ak_my_role() = 'super'
    or (public.ak_my_role() = 'brand' and public.ak_my_brand() = p_brand)
    or (public.ak_my_role() = 'firm'  and p_firm is not null and public.ak_my_firm() = p_firm),
  false)
$$;

-- Marka düzeyinde yönetim yetkisi (super veya o markanın yöneticisi).
create or replace function public.ak_can_admin_brand(p_brand uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(
       public.ak_my_role() = 'super'
    or (public.ak_my_role() = 'brand' and public.ak_my_brand() = p_brand),
  false)
$$;

create or replace function public.ak_slugify(t text) returns text
language sql immutable as $$
  select trim(both '-' from regexp_replace(
    lower(translate(coalesce(t, ''), 'ÇĞİIÖŞÜçğıöşüÂâÎîÛû', 'CGIIOSUcgiosuAaIiUu')),
    '[^a-z0-9]+', '-', 'g'))
$$;

create or replace function public.ak_random_chars(n int) returns text
language plpgsql volatile set search_path = public, extensions as $$
declare
  a text  := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';   -- karışan karakterler (0,O,1,I,L) yok
  b bytea := extensions.gen_random_bytes(n);
  r text  := '';
begin
  for i in 0 .. n - 1 loop
    r := r || substr(a, (get_byte(b, i) % 31) + 1, 1);
  end loop;
  return r;
end $$;

create or replace function public.ak_client_ip() returns text
language plpgsql stable as $$
declare v text;
begin
  begin
    v := split_part(nullif(current_setting('request.headers', true), '')::json ->> 'x-forwarded-for', ',', 1);
  exception when others then v := null;
  end;
  return coalesce(nullif(trim(v), ''), 'bilinmiyor');
end $$;

create or replace function public.ak_brand_json(b public.ak_brands) returns json
language sql stable as $$
  select json_build_object(
    'id', b.id, 'name', b.name, 'code_prefix', b.code_prefix,
    'primary_color', b.primary_color, 'logo_url', b.logo_url,
    'tagline', b.tagline, 'domain', b.domain)
$$;

create or replace function public.ak_event_json(ev public.ak_events) returns json
language sql stable set search_path = public as $$
  select json_build_object(
    'slug', ev.slug,
    'name_a', ev.name_a, 'name_b', ev.name_b,
    'event_type', ev.event_type, 'event_date', ev.event_date, 'venue', ev.venue,
    'photo_limit', ev.photo_limit, 'live_screen', ev.live_screen,
    'reveal_at', ev.reveal_at,
    'revealed', (ev.reveal_at is null or now() >= ev.reveal_at),
    'accepting', (ev.status = 'active' and now() < ev.expires_at),
    'status', ev.status, 'expires_at', ev.expires_at,
    'brand', (select public.ak_brand_json(b) from public.ak_brands b where b.id = ev.brand_id))
$$;

-- ---------------------------------------------------------------------
-- 4) GÜVENLİK KURALLARI (RLS)
-- ---------------------------------------------------------------------
alter table public.ak_brands              enable row level security;
alter table public.ak_packages            enable row level security;
alter table public.ak_firms               enable row level security;
alter table public.ak_profiles            enable row level security;
alter table public.ak_activation_codes    enable row level security;
alter table public.ak_events              enable row level security;
alter table public.ak_photos              enable row level security;
alter table public.ak_activation_attempts enable row level security;

drop policy if exists brands_select on public.ak_brands;
create policy brands_select on public.ak_brands for select to authenticated
  using (public.ak_is_super() or id = public.ak_my_brand() or id = public.ak_my_firm_brand());
drop policy if exists brands_write on public.ak_brands;
create policy brands_write on public.ak_brands for all to authenticated
  using (public.ak_is_super()) with check (public.ak_is_super());

drop policy if exists packages_select on public.ak_packages;
create policy packages_select on public.ak_packages for select to anon, authenticated using (true);
drop policy if exists packages_write on public.ak_packages;
create policy packages_write on public.ak_packages for all to authenticated
  using (public.ak_is_super()) with check (public.ak_is_super());

drop policy if exists firms_select on public.ak_firms;
create policy firms_select on public.ak_firms for select to authenticated
  using (public.ak_can_see(brand_id, id));
drop policy if exists firms_write on public.ak_firms;
create policy firms_write on public.ak_firms for all to authenticated
  using (public.ak_can_admin_brand(brand_id)) with check (public.ak_can_admin_brand(brand_id));

drop policy if exists profiles_select on public.ak_profiles;
create policy profiles_select on public.ak_profiles for select to authenticated
  using (user_id = auth.uid() or public.ak_is_super());
drop policy if exists profiles_write on public.ak_profiles;
create policy profiles_write on public.ak_profiles for all to authenticated
  using (public.ak_is_super()) with check (public.ak_is_super());

drop policy if exists codes_select on public.ak_activation_codes;
create policy codes_select on public.ak_activation_codes for select to authenticated
  using (public.ak_can_see(brand_id, firm_id));
drop policy if exists codes_update on public.ak_activation_codes;
create policy codes_update on public.ak_activation_codes for update to authenticated
  using (public.ak_can_admin_brand(brand_id)) with check (public.ak_can_admin_brand(brand_id));

drop policy if exists events_select on public.ak_events;
create policy events_select on public.ak_events for select to authenticated
  using (public.ak_can_see(brand_id, firm_id));
drop policy if exists events_update on public.ak_events;
create policy events_update on public.ak_events for update to authenticated
  using (public.ak_can_see(brand_id, firm_id)) with check (public.ak_can_see(brand_id, firm_id));
drop policy if exists events_delete on public.ak_events;
create policy events_delete on public.ak_events for delete to authenticated
  using (public.ak_can_admin_brand(brand_id));

drop policy if exists photos_select on public.ak_photos;
create policy photos_select on public.ak_photos for select to authenticated
  using (exists (select 1 from public.ak_events e where e.id = event_id));
drop policy if exists photos_update on public.ak_photos;
create policy photos_update on public.ak_photos for update to authenticated
  using (exists (select 1 from public.ak_events e where e.id = event_id));
drop policy if exists photos_delete on public.ak_photos;
create policy photos_delete on public.ak_photos for delete to authenticated
  using (exists (select 1 from public.ak_events e where e.id = event_id));

-- Panel için etkinlik istatistikleri (görme yetkisi tablolardan gelir)
create or replace view public.ak_event_stats with (security_invoker = true) as
  select e.id as event_id,
         count(p.id) filter (where p.status = 'ok')                      as photos,
         count(distinct p.guest_token) filter (where p.status = 'ok')    as guests,
         max(p.created_at) filter (where p.status = 'ok')                as last_photo_at
  from public.ak_events e
  left join public.ak_photos p on p.event_id = e.id
  group by e.id;

-- ---------------------------------------------------------------------
-- 5) HERKESE AÇIK İŞLEMLER (misafir, çift, kod etkinleştirme)
-- ---------------------------------------------------------------------

-- Sitenin hangi markayla görüneceği (alan adına ya da kod önekine göre)
create or replace function public.ak_public_brand(p_host text default null, p_prefix text default null)
returns json language plpgsql stable security definer set search_path = public as $$
declare b public.ak_brands; v_host text := regexp_replace(lower(coalesce(p_host, '')), '^www\.', '');
begin
  if p_prefix is not null then
    select * into b from public.ak_brands where code_prefix = upper(p_prefix);
  end if;
  if b.id is null and v_host <> '' then
    select * into b from public.ak_brands where domain = v_host;
  end if;
  if b.id is null then select * into b from public.ak_brands where is_default; end if;
  if b.id is null then select * into b from public.ak_brands order by created_at limit 1; end if;
  return public.ak_brand_json(b);
end $$;

-- Kodu kontrol et (etkinleştirmeden önce). Hatalı denemeler sayılır.
create or replace function public.ak_check_code(p_code text)
returns json language plpgsql volatile security definer set search_path = public as $$
declare
  v_ip text := public.ak_client_ip();
  c public.ak_activation_codes;
  pk public.ak_packages;
begin
  if v_ip <> 'bilinmiyor' and (select count(*) from public.ak_activation_attempts
      where ip = v_ip and at > now() - interval '15 minutes') >= 10 then
    return json_build_object('error', 'Çok fazla hatalı deneme yapıldı. Lütfen 15 dakika sonra tekrar deneyin.');
  end if;
  select * into c from public.ak_activation_codes
   where code_plain = upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
  if c.code is null or c.status = 'void' then
    insert into public.ak_activation_attempts (ip) values (v_ip);
    return json_build_object('error', 'Kod bulunamadı. Lütfen kontrol edip tekrar deneyin.');
  end if;
  if c.status = 'used' then
    return json_build_object('error', 'Bu kod daha önce kullanılmış.');
  end if;
  if c.expires_at is not null and c.expires_at < now() then
    return json_build_object('error', 'Bu kodun süresi dolmuş.');
  end if;
  select * into pk from public.ak_packages where id = c.package_id;
  return json_build_object(
    'code', c.code,
    'package', json_build_object('id', pk.id, 'name', pk.name, 'photo_limit', pk.photo_limit,
                                 'retention_days', pk.retention_days, 'live_screen', pk.live_screen),
    'brand', (select public.ak_brand_json(b) from public.ak_brands b where b.id = c.brand_id));
end $$;

-- Kodu etkinleştir ve etkinliği oluştur.
create or replace function public.ak_activate_code(
  p_code text, p_name_a text, p_name_b text, p_event_type text, p_event_date date,
  p_venue text default null, p_email text default null, p_reveal_next_morning boolean default false)
returns json language plpgsql volatile security definer set search_path = public, extensions as $$
declare
  v_check json;
  c  public.ak_activation_codes;
  pk public.ak_packages;
  ev public.ak_events;
  v_base text; v_slug text;
begin
  -- girdileri kontrol et
  if length(trim(coalesce(p_name_a, ''))) not between 1 and 40
     or length(trim(coalesce(p_name_b, ''))) > 40 then
    raise exception 'İsimler 1–40 karakter olmalı.';
  end if;
  if p_event_date is null or p_event_date < current_date - 30 or p_event_date > current_date + 730 then
    raise exception 'Etkinlik tarihi geçerli değil.';
  end if;
  if coalesce(p_event_type, '') not in ('Düğün','Nişan','Kına','Söz','Doğum günü','Mezuniyet','Kurumsal','Diğer') then
    raise exception 'Etkinlik türü geçerli değil.';
  end if;

  v_check := public.ak_check_code(p_code);
  if v_check ->> 'error' is not null then return v_check; end if;

  select * into c from public.ak_activation_codes where code = v_check ->> 'code' for update;
  if c.status <> 'new' then
    return json_build_object('error', 'Bu kod daha önce kullanılmış.');
  end if;
  select * into pk from public.ak_packages where id = c.package_id;

  v_base := left(nullif(public.ak_slugify(trim(p_name_a) || '-' || coalesce(trim(p_name_b), '')), ''), 40);
  v_base := coalesce(v_base, 'etkinlik');
  loop
    v_slug := v_base || '-' || lower(public.ak_random_chars(4));
    exit when not exists (select 1 from public.ak_events where slug = v_slug);
  end loop;

  insert into public.ak_events (slug, brand_id, firm_id, package_id, code, name_a, name_b, event_type,
                             event_date, venue, photo_limit, live_screen, reveal_at, contact_email, expires_at)
  values (v_slug, c.brand_id, c.firm_id, c.package_id, c.code,
          trim(p_name_a), nullif(trim(coalesce(p_name_b, '')), ''), p_event_type, p_event_date,
          nullif(trim(coalesce(p_venue, '')), ''), pk.photo_limit, pk.live_screen,
          case when p_reveal_next_morning
               then ((p_event_date + 1)::timestamp + time '10:00') at time zone 'Europe/Istanbul' end,
          nullif(trim(coalesce(p_email, '')), ''),
          ((p_event_date + pk.retention_days)::timestamp + time '23:59') at time zone 'Europe/Istanbul')
  returning * into ev;

  update public.ak_activation_codes set status = 'used', used_at = now(), event_id = ev.id where code = c.code;

  return json_build_object('slug', ev.slug, 'album_key', ev.album_key, 'event', public.ak_event_json(ev));
end $$;

-- Misafir sayfası için etkinlik bilgisi
create or replace function public.ak_event_public(p_slug text)
returns json language plpgsql stable security definer set search_path = public as $$
declare ev public.ak_events;
begin
  select * into ev from public.ak_events where slug = p_slug;
  if ev.id is null then return json_build_object('error', 'Etkinlik bulunamadı.'); end if;
  return public.ak_event_json(ev);
end $$;

-- Misafirin kaç poz kullandığı ve kendi çektikleri
create or replace function public.ak_guest_status(p_slug text, p_token text)
returns json language plpgsql stable security definer set search_path = public as $$
declare ev public.ak_events; v_used int;
begin
  select * into ev from public.ak_events where slug = p_slug;
  if ev.id is null then return json_build_object('error', 'Etkinlik bulunamadı.'); end if;
  select count(*) into v_used from public.ak_photos
   where event_id = ev.id and guest_token = p_token
     and (status in ('ok','hidden') or (status = 'pending' and created_at > now() - interval '15 minutes'));
  return json_build_object(
    'used', v_used,
    'remaining', case when ev.photo_limit is null then null else greatest(ev.photo_limit - v_used, 0) end,
    'shots', coalesce((select json_agg(storage_path order by created_at desc) from public.ak_photos
                        where event_id = ev.id and guest_token = p_token and status = 'ok'), '[]'::json));
end $$;

-- Yükleme için yer ayır (poz sınırı burada uygulanır)
create or replace function public.ak_reserve_photo(p_slug text, p_token text, p_guest_name text)
returns json language plpgsql volatile security definer set search_path = public as $$
declare ev public.ak_events; v_used int; v_id uuid := gen_random_uuid(); v_path text;
begin
  select * into ev from public.ak_events where slug = p_slug;
  if ev.id is null then raise exception 'Etkinlik bulunamadı.'; end if;
  if ev.status <> 'active' or now() >= ev.expires_at then
    raise exception 'Bu etkinlik artık fotoğraf kabul etmiyor.';
  end if;
  if length(coalesce(p_token, '')) not between 16 and 64 then raise exception 'Geçersiz oturum.'; end if;
  if length(trim(coalesce(p_guest_name, ''))) not between 1 and 30 then
    raise exception 'Lütfen adınızı yazın.';
  end if;

  perform pg_advisory_xact_lock(hashtext(ev.id::text || p_token));
  select count(*) into v_used from public.ak_photos
   where event_id = ev.id and guest_token = p_token
     and (status in ('ok','hidden') or (status = 'pending' and created_at > now() - interval '15 minutes'));
  if ev.photo_limit is not null and v_used >= ev.photo_limit then
    raise exception 'Pozlarınız bitti.';
  end if;
  if (select count(*) from public.ak_photos where event_id = ev.id) >= 5000 then
    raise exception 'Bu albümün kapasitesi doldu.';
  end if;

  v_path := ev.id::text || '/' || v_id::text || '.jpg';
  insert into public.ak_photos (id, event_id, guest_token, guest_name, storage_path)
  values (v_id, ev.id, p_token, trim(p_guest_name), v_path);

  return json_build_object('photo_id', v_id, 'path', v_path,
    'remaining', case when ev.photo_limit is null then null else ev.photo_limit - v_used - 1 end);
end $$;

-- Yükleme bitti: fotoğrafı albüme ekle
create or replace function public.ak_confirm_photo(p_photo_id uuid, p_token text)
returns json language plpgsql volatile security definer set search_path = public as $$
declare v_path text;
begin
  select storage_path into v_path from public.ak_photos
   where id = p_photo_id and guest_token = p_token and status = 'pending';
  if v_path is null then raise exception 'Fotoğraf bulunamadı.'; end if;
  if not exists (select 1 from storage.objects where bucket_id = 'ak-photos' and name = v_path) then
    raise exception 'Fotoğraf yüklenemedi, lütfen tekrar deneyin.';
  end if;
  update public.ak_photos set status = 'ok' where id = p_photo_id;
  return json_build_object('ok', true, 'path', v_path);
end $$;

-- Depolama kuralı: sadece yeri ayrılmış dosya yüklenebilir
create or replace function public.ak_can_upload(p_name text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.ak_photos
                  where storage_path = p_name and status = 'pending'
                    and created_at > now() - interval '15 minutes')
$$;

-- Yönetici bu dosyayı silebilir mi?
create or replace function public.ak_can_manage_path(p_name text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.ak_events e
                  where e.id::text = split_part(p_name, '/', 1)
                    and public.ak_can_see(e.brand_id, e.firm_id))
$$;

-- Çiftin albümü (gizli anahtarla)
create or replace function public.ak_album(p_slug text, p_key text)
returns json language plpgsql stable security definer set search_path = public as $$
declare ev public.ak_events; v_revealed boolean;
begin
  select * into ev from public.ak_events where slug = p_slug and album_key = p_key;
  if ev.id is null then return json_build_object('error', 'Albüm bulunamadı ya da bağlantı hatalı.'); end if;
  v_revealed := ev.reveal_at is null or now() >= ev.reveal_at;
  return json_build_object(
    'event', public.ak_event_json(ev),
    'photo_count', (select count(*) from public.ak_photos where event_id = ev.id and status = 'ok'),
    'guest_count', (select count(distinct guest_token) from public.ak_photos where event_id = ev.id and status = 'ok'),
    'photos', case when v_revealed then coalesce((
        select json_agg(json_build_object('id', id, 'path', storage_path, 'guest', guest_name, 'at', created_at)
                        order by created_at desc)
          from public.ak_photos where event_id = ev.id and status = 'ok'), '[]'::json)
      else '[]'::json end);
end $$;

-- Çift bir fotoğrafı albümden gizleyebilir
create or replace function public.ak_album_hide_photo(p_slug text, p_key text, p_photo_id uuid)
returns json language plpgsql volatile security definer set search_path = public as $$
begin
  update public.ak_photos p set status = 'hidden'
    from public.ak_events e
   where p.id = p_photo_id and p.event_id = e.id and e.slug = p_slug and e.album_key = p_key;
  if not found then raise exception 'Fotoğraf bulunamadı.'; end if;
  return json_build_object('ok', true);
end $$;

-- Çift yüklemeyi kapatıp açabilir
create or replace function public.ak_album_set_accepting(p_slug text, p_key text, p_open boolean)
returns json language plpgsql volatile security definer set search_path = public as $$
begin
  update public.ak_events set status = case when p_open then 'active' else 'closed' end
   where slug = p_slug and album_key = p_key;
  if not found then raise exception 'Albüm bulunamadı.'; end if;
  return json_build_object('ok', true);
end $$;

-- ---------------------------------------------------------------------
-- 6) PANEL İŞLEMLERİ (giriş yapmış kullanıcılar)
-- ---------------------------------------------------------------------

-- Toplu kod üret
create or replace function public.ak_generate_codes(
  p_brand uuid, p_package text, p_count int,
  p_firm uuid default null, p_valid_days int default 365, p_batch text default null)
returns json language plpgsql volatile security definer set search_path = public, extensions as $$
declare v_prefix text; v_code text; v_codes text[] := '{}'; n int := 0; tries int := 0;
begin
  if not public.ak_can_admin_brand(p_brand) then raise exception 'Bu marka için kod üretme yetkiniz yok.'; end if;
  if p_count is null or p_count < 1 or p_count > 500 then raise exception 'Tek seferde 1–500 kod üretilebilir.'; end if;
  if not exists (select 1 from public.ak_packages where id = p_package) then raise exception 'Paket bulunamadı.'; end if;
  if p_firm is not null and not exists (select 1 from public.ak_firms where id = p_firm and brand_id = p_brand) then
    raise exception 'Seçilen firma bu markaya ait değil.';
  end if;
  select code_prefix into v_prefix from public.ak_brands where id = p_brand;

  while n < p_count and tries < p_count * 5 loop
    tries := tries + 1;
    v_code := v_prefix || '-' || public.ak_random_chars(4) || '-' || public.ak_random_chars(4);
    insert into public.ak_activation_codes (code, brand_id, package_id, firm_id, batch, expires_at, created_by)
    values (v_code, p_brand, p_package, p_firm, nullif(trim(coalesce(p_batch, '')), ''),
            case when p_valid_days is null then null else now() + make_interval(days => p_valid_days) end,
            auth.uid())
    on conflict do nothing;
    if found then n := n + 1; v_codes := v_codes || v_code; end if;
  end loop;
  return json_build_object('codes', to_json(v_codes));
end $$;

-- Kullanıcıya yetki ver (sadece super). Kullanıcı önce Authentication → Users'ta eklenmeli.
create or replace function public.ak_assign_role(p_email text, p_role text, p_brand uuid default null, p_firm uuid default null)
returns json language plpgsql volatile security definer set search_path = public as $$
declare v_uid uuid;
begin
  if not public.ak_is_super() then raise exception 'Yetkiniz yok.'; end if;
  select id into v_uid from auth.users where lower(email) = lower(trim(p_email));
  if v_uid is null then
    raise exception 'Bu e-posta ile kullanıcı yok. Önce Supabase → Authentication → Users bölümünden ekleyin.';
  end if;
  if p_role = 'brand' and p_brand is null then raise exception 'Marka seçin.'; end if;
  if p_role = 'firm' and p_firm is null then raise exception 'Firma seçin.'; end if;
  insert into public.ak_profiles (user_id, role, brand_id, firm_id)
  values (v_uid, p_role,
          case when p_role = 'firm' then (select brand_id from public.ak_firms where id = p_firm) else p_brand end,
          case when p_role = 'firm' then p_firm end)
  on conflict (user_id) do update set role = excluded.role, brand_id = excluded.brand_id, firm_id = excluded.firm_id;
  return json_build_object('ok', true);
end $$;

-- Panel kullanıcıları listesi (sadece super)
create or replace function public.ak_list_users()
returns json language plpgsql stable security definer set search_path = public as $$
begin
  if not public.ak_is_super() then raise exception 'Yetkiniz yok.'; end if;
  return coalesce((select json_agg(json_build_object(
      'email', u.email, 'role', p.role,
      'brand', (select name from public.ak_brands where id = p.brand_id),
      'firm',  (select name from public.ak_firms where id = p.firm_id)) order by u.email)
    from auth.users u join public.ak_profiles p on p.user_id = u.id), '[]'::json);
end $$;

-- ---------------------------------------------------------------------
-- 7) FOTOĞRAF DEPOLAMA
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('ak-photos', 'ak-photos', true, 10485760, array['image/jpeg'])
on conflict (id) do nothing;

drop policy if exists "ak photos guest insert" on storage.objects;
create policy "ak photos guest insert" on storage.objects for insert to anon, authenticated
  with check (bucket_id = 'ak-photos' and public.ak_can_upload(name));

drop policy if exists "ak photos guest select pending" on storage.objects;
create policy "ak photos guest select pending" on storage.objects for select to anon, authenticated
  using (bucket_id = 'ak-photos' and public.ak_can_upload(name));

drop policy if exists "ak photos admin delete" on storage.objects;
create policy "ak photos admin delete" on storage.objects for delete to authenticated
  using (bucket_id = 'ak-photos' and public.ak_can_manage_path(name));

drop policy if exists "ak photos admin select" on storage.objects;
create policy "ak photos admin select" on storage.objects for select to authenticated
  using (bucket_id = 'ak-photos' and public.ak_can_manage_path(name));

-- Bitti. Sonraki adım: KURULUM.md → "İlk yönetici hesabı".
