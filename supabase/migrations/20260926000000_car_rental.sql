-- Rent AL: peer-to-peer car rental for Albania.
-- Schema, row level security and the booking RPCs.
-- Apply with `supabase db push` or paste into the Supabase SQL editor.

create extension if not exists btree_gist;

-- =========================================================================
-- Tables
-- =========================================================================

create table public.profiles (
  id           uuid primary key references auth.users on delete cascade,
  phone        text,
  full_name    text not null default '',
  role         text not null default 'renter'
               check (role in ('renter', 'owner', 'admin')),
  rating       numeric(3,2) not null default 5.00,
  rating_count integer not null default 0,
  -- Set by an admin after checking the renter's driving licence.
  licence_verified boolean not null default false,
  is_blocked   boolean not null default false,
  created_at   timestamptz not null default now()
);

create table public.car_categories (
  id                text primary key,
  name              text not null,
  suggested_per_day integer not null,
  suggested_deposit integer not null,
  seats             integer not null default 5,
  active            boolean not null default true
);

create table public.cars (
  id            uuid primary key default gen_random_uuid(),
  owner_id      uuid not null references public.profiles on delete cascade,
  make          text not null,
  model         text not null,
  year          integer not null check (year between 1990 and 2100),
  plate         text not null unique,
  color         bigint not null default 4293520367, -- 0xFFE9EBEF
  category_id   text not null references public.car_categories,
  transmission  text not null default 'manual' check (transmission in ('manual', 'automatic')),
  fuel          text not null default 'diesel' check (fuel in ('petrol', 'diesel', 'hybrid', 'electric')),
  seats         integer not null default 5 check (seats between 1 and 9),
  price_per_day integer not null check (price_per_day > 0),
  deposit       integer not null default 0 check (deposit >= 0),
  loc_name      text not null,
  loc_subtitle  text not null default '',
  lat           double precision not null,
  lng           double precision not null,
  delivery      boolean not null default false,
  delivery_fee  integer not null default 0 check (delivery_fee >= 0),
  min_days      integer not null default 1 check (min_days >= 1),
  km_per_day    integer not null default 250,
  description   text not null default '',
  listed        boolean not null default true,
  -- Set by an admin after checking registration and insurance.
  approved      boolean not null default false,
  rating        numeric(3,2) not null default 5.00,
  rating_count  integer not null default 0,
  trips         integer not null default 0,
  created_at    timestamptz not null default now()
);
create index on public.cars (listed, approved);

create table public.app_settings (
  id                         boolean primary key default true check (id),
  require_owner_subscription boolean not null default false,
  -- Renters may offer down to this share of the listed daily price.
  min_offer_percent          integer not null default 70,
  -- Unanswered requests expire after this many hours.
  request_ttl_hours          integer not null default 24
);
insert into public.app_settings default values;

create table public.owner_subscriptions (
  owner_id    uuid primary key references public.profiles on delete cascade,
  plan        text not null default 'monthly',
  valid_until timestamptz not null,
  updated_at  timestamptz not null default now()
);

create table public.promo_codes (
  code             text primary key,
  percent          integer not null check (percent between 1 and 100),
  first_rental_only boolean not null default true,
  active           boolean not null default true,
  expires_at       timestamptz
);

create table public.bookings (
  id               uuid primary key default gen_random_uuid(),
  car_id           uuid not null references public.cars,
  renter_id        uuid not null references public.profiles,
  owner_id         uuid not null references public.profiles,
  start_at         timestamptz not null,
  end_at           timestamptz not null,
  offered_per_day  integer not null check (offered_per_day > 0),
  counter_per_day  integer,
  agreed_per_day   integer,
  promo_percent    integer not null default 0,
  status           text not null default 'requested'
                   check (status in ('requested', 'countered', 'confirmed', 'active',
                                     'completed', 'declined', 'cancelled', 'expired')),
  pickup           text not null default 'atOwner' check (pickup in ('atOwner', 'delivery')),
  delivery_address text not null default '',
  payment          text not null default 'cash'
                   check (payment in ('cash', 'card', 'applePay', 'googlePay')),
  note             text not null default '',
  total            integer,
  cancel_reason    text,
  cancelled_by     uuid,
  rating           integer check (rating between 1 and 5),
  comment          text,
  created_at       timestamptz not null default now(),
  expires_at       timestamptz not null default now() + interval '24 hours',
  check (end_at > start_at),
  -- The database itself guarantees a car is never double-booked.
  constraint no_double_booking exclude using gist (
    car_id with =,
    tstzrange(start_at, end_at) with &&
  ) where (status in ('confirmed', 'active'))
);
create index on public.bookings (renter_id, created_at desc);
create index on public.bookings (owner_id, created_at desc);

create table public.messages (
  id         uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings on delete cascade,
  sender_id  uuid not null references public.profiles,
  body       text not null check (length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);
create index on public.messages (booking_id, created_at);

-- =========================================================================
-- Helpers
-- =========================================================================

create or replace function public.distance_km(lat1 double precision, lng1 double precision,
                                              lat2 double precision, lng2 double precision)
returns double precision language sql immutable as $$
  select 6371 * 2 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2)
  ));
$$;

-- Started 24-hour periods, at least one (same rule as the app).
create or replace function public.rental_days(p_start timestamptz, p_end timestamptz)
returns integer language sql immutable as $$
  select greatest(1, ceil(floor(extract(epoch from (p_end - p_start)) / 3600) / 24.0))::integer;
$$;

-- Same formula as Pricing.quote() in the app: 7+ days -10%, 28+ days -20%,
-- then the promo, rounded to 100 L, plus the delivery fee.
create or replace function public.rental_total(p_per_day integer, p_days integer,
                                               p_delivery_fee integer, p_promo integer)
returns integer language sql immutable as $$
  with t as (
    select (p_per_day * p_days)::numeric
           * (100 - case when p_days >= 28 then 20 when p_days >= 7 then 10 else 0 end) / 100
           as after_long
  )
  select (round((after_long - after_long * p_promo / 100) / 100) * 100)::integer + p_delivery_fee
  from t;
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'admin');
$$;

create or replace function public.is_booking_party(p_booking uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from bookings where id = p_booking and auth.uid() in (renter_id, owner_id)
  );
$$;

-- Users may edit their name / switch renter<->owner, nothing else.
create or replace function public.protect_profile_fields()
returns trigger language plpgsql set search_path = public as $$
begin
  -- Direct writes from the app run as 'authenticated'; our RPCs run as owner.
  if current_user in ('authenticated', 'anon') and not public.is_admin() then
    new.rating := old.rating;
    new.rating_count := old.rating_count;
    new.licence_verified := old.licence_verified;
    new.is_blocked := old.is_blocked;
    new.phone := old.phone;
    if new.role = 'admin' or old.role = 'admin' then
      new.role := old.role;
    end if;
  end if;
  return new;
end;
$$;

create trigger protect_profile_fields
  before update on public.profiles
  for each row execute function public.protect_profile_fields();

-- Owners edit their listing; approval, rating and trip count are protected.
-- Changing make / model / plate sends the car back for approval.
create or replace function public.protect_car_fields()
returns trigger language plpgsql set search_path = public as $$
begin
  if current_user in ('authenticated', 'anon') and not public.is_admin() then
    if tg_op = 'INSERT' then
      new.approved := false;
      new.rating := 5.00;
      new.rating_count := 0;
      new.trips := 0;
    else
      new.owner_id := old.owner_id;
      new.rating := old.rating;
      new.rating_count := old.rating_count;
      new.trips := old.trips;
      if (new.make, new.model, new.plate) is distinct from (old.make, old.model, old.plate) then
        new.approved := false;
      else
        new.approved := old.approved;
      end if;
    end if;
  end if;
  return new;
end;
$$;

create trigger protect_car_fields
  before insert or update on public.cars
  for each row execute function public.protect_car_fields();

-- Create a profile automatically when someone signs up with their phone.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, phone) values (new.id, new.phone)
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- =========================================================================
-- Row level security
-- =========================================================================

alter table public.profiles            enable row level security;
alter table public.car_categories      enable row level security;
alter table public.cars                enable row level security;
alter table public.app_settings        enable row level security;
alter table public.owner_subscriptions enable row level security;
alter table public.promo_codes         enable row level security;
alter table public.bookings            enable row level security;
alter table public.messages            enable row level security;

create policy "profiles: read own" on public.profiles
  for select using (id = auth.uid());
create policy "profiles: read booking partner" on public.profiles
  for select using (exists (
    select 1 from public.bookings b
    where auth.uid() in (b.renter_id, b.owner_id)
      and profiles.id in (b.renter_id, b.owner_id)
  ));
create policy "profiles: update own" on public.profiles
  for update using (id = auth.uid())
  with check (id = auth.uid() and role in ('renter', 'owner'));

create policy "categories: readable" on public.car_categories
  for select using (true);
create policy "settings: readable" on public.app_settings
  for select using (true);

-- Listed + approved cars are public (search goes through search_cars()).
create policy "cars: read listed" on public.cars
  for select to authenticated using ((listed and approved) or owner_id = auth.uid());
create policy "cars: read booked" on public.cars
  for select using (exists (
    select 1 from public.bookings b where b.car_id = cars.id and b.renter_id = auth.uid()
  ));
create policy "cars: owner inserts" on public.cars
  for insert with check (owner_id = auth.uid());
create policy "cars: owner updates" on public.cars
  for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy "subscriptions: read own" on public.owner_subscriptions
  for select using (owner_id = auth.uid());

create policy "bookings: parties read" on public.bookings
  for select using (auth.uid() in (renter_id, owner_id));

create policy "messages: parties read" on public.messages
  for select using (public.is_booking_party(booking_id));
create policy "messages: parties send" on public.messages
  for insert with check (sender_id = auth.uid() and public.is_booking_party(booking_id));

-- Bookings change only through the RPCs below.
revoke insert, update, delete on public.bookings from anon, authenticated;

-- =========================================================================
-- RPCs
-- =========================================================================

-- Cars free for the whole period near a point, with owner name and rating.
create or replace function public.search_cars(p_lat double precision, p_lng double precision,
                                              p_start timestamptz, p_end timestamptz,
                                              p_radius_km double precision default 30,
                                              p_category text default null)
returns table (
  id uuid, owner_id uuid, owner_name text, owner_rating numeric,
  make text, model text, year integer, plate text, color bigint, category_id text,
  transmission text, fuel text, seats integer, price_per_day integer, deposit integer,
  loc_name text, loc_subtitle text, lat double precision, lng double precision,
  delivery boolean, delivery_fee integer, min_days integer, km_per_day integer,
  description text, rating numeric, trips integer, distance_km double precision
)
language sql stable security definer set search_path = public as $$
  select c.id, c.owner_id, p.full_name, p.rating,
         c.make, c.model, c.year, c.plate, c.color, c.category_id,
         c.transmission, c.fuel, c.seats, c.price_per_day, c.deposit,
         c.loc_name, c.loc_subtitle, c.lat, c.lng,
         c.delivery, c.delivery_fee, c.min_days, c.km_per_day,
         c.description, c.rating, c.trips,
         distance_km(p_lat, p_lng, c.lat, c.lng)
  from cars c
  join profiles p on p.id = c.owner_id and not p.is_blocked
  where c.listed and c.approved
    and c.owner_id is distinct from auth.uid()
    and (p_category is null or c.category_id = p_category)
    and distance_km(p_lat, p_lng, c.lat, c.lng) <= p_radius_km
    and not exists (
      select 1 from bookings b
      where b.car_id = c.id and b.status in ('confirmed', 'active')
        and tstzrange(b.start_at, b.end_at) && tstzrange(p_start, p_end)
    )
  order by distance_km(p_lat, p_lng, c.lat, c.lng)
  limit 100;
$$;

create or replace function public.apply_promo(p_code text)
returns integer language plpgsql stable security definer set search_path = public as $$
declare
  v_promo promo_codes;
begin
  select * into v_promo from promo_codes
  where upper(code) = upper(trim(p_code)) and active and (expires_at is null or expires_at > now());
  if v_promo.code is null then
    return 0;
  end if;
  if v_promo.first_rental_only and exists (
    select 1 from bookings where renter_id = auth.uid() and status = 'completed'
  ) then
    return 0;
  end if;
  return v_promo.percent;
end;
$$;

create or replace function public.request_booking(
  p_car uuid, p_start timestamptz, p_end timestamptz, p_offered integer,
  p_pickup text default 'atOwner', p_payment text default 'cash',
  p_address text default '', p_note text default '', p_promo text default '')
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_car cars;
  v_settings app_settings;
  v_id uuid;
begin
  select * into v_settings from app_settings limit 1;
  select * into v_car from cars where id = p_car;
  if v_car.id is null or not v_car.listed or not v_car.approved then
    raise exception 'car_unavailable';
  end if;
  if v_car.owner_id = auth.uid() then
    raise exception 'own_car';
  end if;
  if exists (select 1 from profiles where id = auth.uid() and is_blocked) then
    raise exception 'not_allowed';
  end if;
  if p_end <= p_start or p_start < now() - interval '1 hour' then
    raise exception 'invalid_dates';
  end if;
  if rental_days(p_start, p_end) < v_car.min_days then
    raise exception 'min_days';
  end if;
  if p_offered * 100 < v_car.price_per_day * v_settings.min_offer_percent then
    raise exception 'offer_too_low';
  end if;
  if p_pickup = 'delivery' and not v_car.delivery then
    raise exception 'not_allowed';
  end if;
  if v_settings.require_owner_subscription and not exists (
    select 1 from owner_subscriptions where owner_id = v_car.owner_id and valid_until > now()
  ) then
    raise exception 'car_unavailable';
  end if;
  if exists (
    select 1 from bookings b
    where b.car_id = p_car and b.status in ('confirmed', 'active')
      and tstzrange(b.start_at, b.end_at) && tstzrange(p_start, p_end)
  ) then
    raise exception 'car_unavailable';
  end if;

  insert into bookings (car_id, renter_id, owner_id, start_at, end_at, offered_per_day,
                        pickup, delivery_address, payment, note, promo_percent, expires_at)
  values (p_car, auth.uid(), v_car.owner_id, p_start, p_end, p_offered,
          p_pickup, coalesce(p_address, ''), p_payment, coalesce(p_note, ''),
          case when coalesce(p_promo, '') = '' then 0 else apply_promo(p_promo) end,
          now() + make_interval(hours => v_settings.request_ttl_hours))
  returning id into v_id;
  return v_id;
end;
$$;

-- Fixes the price and confirms; the exclusion constraint rejects overlaps.
create or replace function public.confirm_booking_internal(p_id uuid, p_per_day integer)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_b bookings;
  v_car cars;
begin
  select * into v_b from bookings where id = p_id;
  select * into v_car from cars where id = v_b.car_id;
  update bookings
  set status = 'confirmed',
      agreed_per_day = p_per_day,
      total = rental_total(p_per_day, rental_days(v_b.start_at, v_b.end_at),
                           case when v_b.pickup = 'delivery' then v_car.delivery_fee else 0 end,
                           v_b.promo_percent)
  where id = p_id;
exception when exclusion_violation then
  raise exception 'car_unavailable';
end;
$$;
revoke execute on function public.confirm_booking_internal(uuid, integer) from public, anon, authenticated;

-- Owner answers a request: accept, decline or counter-offer.
create or replace function public.respond_booking(p_id uuid, p_action text, p_price integer default null)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_b bookings;
begin
  select * into v_b from bookings where id = p_id for update;
  if v_b.id is null or v_b.owner_id <> auth.uid() then
    raise exception 'not_allowed';
  end if;
  if v_b.expires_at < now() and v_b.status in ('requested', 'countered') then
    update bookings set status = 'expired' where id = p_id;
    raise exception 'request_expired';
  end if;

  if p_action = 'accept' then
    if v_b.status <> 'requested' then raise exception 'not_allowed'; end if;
    perform confirm_booking_internal(p_id, v_b.offered_per_day);
  elsif p_action = 'counter' then
    if v_b.status <> 'requested' then raise exception 'not_allowed'; end if;
    if p_price is null or p_price <= v_b.offered_per_day then
      raise exception 'counter_too_low';
    end if;
    update bookings set status = 'countered', counter_per_day = p_price where id = p_id;
  elsif p_action = 'decline' then
    if v_b.status not in ('requested', 'countered') then raise exception 'not_allowed'; end if;
    update bookings set status = 'declined' where id = p_id;
  else
    raise exception 'not_allowed';
  end if;
end;
$$;

-- Renter accepts the owner's counter-offer.
create or replace function public.accept_counter(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_b bookings;
begin
  select * into v_b from bookings where id = p_id for update;
  if v_b.id is null or v_b.renter_id <> auth.uid() or v_b.status <> 'countered' then
    raise exception 'not_allowed';
  end if;
  perform confirm_booking_internal(p_id, v_b.counter_per_day);
end;
$$;

-- Either party can cancel before the handover.
create or replace function public.cancel_booking(p_id uuid, p_reason text default null)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_b bookings;
begin
  select * into v_b from bookings where id = p_id for update;
  if v_b.id is null or auth.uid() not in (v_b.renter_id, v_b.owner_id) then
    raise exception 'not_allowed';
  end if;
  if v_b.status not in ('requested', 'countered', 'confirmed') then
    raise exception 'cannot_cancel';
  end if;
  update bookings set status = 'cancelled', cancel_reason = p_reason, cancelled_by = auth.uid()
  where id = p_id;
end;
$$;

-- Handover done (either party confirms in the app).
create or replace function public.mark_picked_up(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_b bookings;
begin
  select * into v_b from bookings where id = p_id for update;
  if v_b.id is null or auth.uid() not in (v_b.renter_id, v_b.owner_id) then
    raise exception 'not_allowed';
  end if;
  if v_b.status <> 'confirmed' then
    raise exception 'invalid_transition';
  end if;
  update bookings set status = 'active' where id = p_id;
end;
$$;

create or replace function public.mark_returned(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_b bookings;
begin
  select * into v_b from bookings where id = p_id for update;
  if v_b.id is null or auth.uid() not in (v_b.renter_id, v_b.owner_id) then
    raise exception 'not_allowed';
  end if;
  if v_b.status <> 'active' then
    raise exception 'invalid_transition';
  end if;
  update bookings set status = 'completed' where id = p_id;
  update cars set trips = trips + 1 where id = v_b.car_id;
end;
$$;

-- Renter reviews the car and owner once, after the rental.
create or replace function public.rate_booking(p_id uuid, p_stars integer, p_comment text default '')
returns void language plpgsql security definer set search_path = public as $$
declare
  v_b bookings;
begin
  select * into v_b from bookings where id = p_id for update;
  if v_b.id is null or v_b.renter_id <> auth.uid() or v_b.status <> 'completed'
     or v_b.rating is not null or p_stars not between 1 and 5 then
    raise exception 'not_allowed';
  end if;
  update bookings set rating = p_stars, comment = p_comment where id = p_id;
  update cars
  set rating = round(((rating * rating_count) + p_stars)::numeric / (rating_count + 1), 2),
      rating_count = rating_count + 1
  where id = v_b.car_id;
  update profiles
  set rating = round(((rating * rating_count) + p_stars)::numeric / (rating_count + 1), 2),
      rating_count = rating_count + 1
  where id = v_b.owner_id;
end;
$$;

create or replace function public.owner_earnings()
returns table (this_month bigint, all_time bigint, rentals_this_month bigint, days_this_month bigint)
language sql stable security definer set search_path = public as $$
  select
    coalesce(sum(total) filter (where end_at >= date_trunc('month', now() at time zone 'Europe/Tirane') at time zone 'Europe/Tirane'), 0),
    coalesce(sum(total), 0),
    count(*) filter (where end_at >= date_trunc('month', now() at time zone 'Europe/Tirane') at time zone 'Europe/Tirane'),
    coalesce(sum(rental_days(start_at, end_at)) filter (where end_at >= date_trunc('month', now() at time zone 'Europe/Tirane') at time zone 'Europe/Tirane'), 0)
  from bookings
  where owner_id = auth.uid() and status = 'completed';
$$;

-- Housekeeping: expire unanswered requests. Schedule with pg_cron:
--   select cron.schedule('expire-requests', '*/15 * * * *', 'select public.expire_stale_requests()');
create or replace function public.expire_stale_requests()
returns void language sql security definer set search_path = public as $$
  update bookings set status = 'expired'
  where status in ('requested', 'countered') and expires_at < now();
$$;
revoke execute on function public.expire_stale_requests() from public, anon, authenticated;

-- =========================================================================
-- Realtime
-- =========================================================================

alter publication supabase_realtime add table public.bookings, public.messages, public.cars;
