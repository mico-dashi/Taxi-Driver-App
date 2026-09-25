-- Taksi AL: schema, security (RLS) and ride-hailing RPCs.
-- Apply with `supabase db push` or paste into the Supabase SQL editor.

-- =========================================================================
-- Tables
-- =========================================================================

create table public.profiles (
  id           uuid primary key references auth.users on delete cascade,
  phone        text,
  full_name    text not null default '',
  role         text not null default 'passenger'
               check (role in ('passenger', 'driver', 'admin')),
  rating       numeric(3,2) not null default 5.00,
  rating_count integer not null default 0,
  is_blocked   boolean not null default false,
  created_at   timestamptz not null default now()
);

create table public.fare_settings (
  category_id text primary key,
  name        text not null,
  base_fare   integer not null,
  per_km      integer not null,
  per_minute  integer not null,
  min_fare    integer not null,
  seats       integer not null default 4,
  active      boolean not null default true
);

create table public.vehicles (
  id          uuid primary key default gen_random_uuid(),
  driver_id   uuid not null unique references public.profiles on delete cascade,
  make        text not null,
  model       text not null,
  plate       text not null unique,
  color       text not null default '',
  category_id text not null references public.fare_settings,
  seats       integer not null default 4,
  -- Set by an admin after checking licence / municipality taxi permit.
  approved    boolean not null default false,
  created_at  timestamptz not null default now()
);

create table public.driver_status (
  driver_id  uuid primary key references public.profiles on delete cascade,
  is_online  boolean not null default false,
  lat        double precision,
  lng        double precision,
  heading    double precision not null default 0,
  updated_at timestamptz not null default now()
);

-- Monthly subscription paid by drivers (the business model).
create table public.driver_subscriptions (
  driver_id   uuid primary key references public.profiles on delete cascade,
  plan        text not null default 'monthly',
  valid_until timestamptz not null,
  updated_at  timestamptz not null default now()
);

create table public.app_settings (
  id                          boolean primary key default true check (id),
  require_driver_subscription boolean not null default false,
  search_radius_km            numeric not null default 6,
  request_ttl_seconds         integer not null default 180
);
insert into public.app_settings default values;

create table public.ride_requests (
  id                uuid primary key default gen_random_uuid(),
  passenger_id      uuid not null references public.profiles on delete cascade,
  pickup_name       text not null,
  pickup_subtitle   text not null default '',
  pickup_lat        double precision not null,
  pickup_lng        double precision not null,
  dest_name         text not null,
  dest_subtitle     text not null default '',
  dest_lat          double precision not null,
  dest_lng          double precision not null,
  route             jsonb not null default '[]',  -- [[lat,lng], ...]
  distance_km       numeric not null,
  duration_min      numeric not null,
  category_id       text not null references public.fare_settings,
  offered_fare      integer not null check (offered_fare > 0),
  payment           text not null default 'cash'
                    check (payment in ('cash', 'card', 'applePay', 'googlePay')),
  status            text not null default 'searching'
                    check (status in ('searching', 'accepted', 'cancelled', 'expired')),
  created_at        timestamptz not null default now(),
  expires_at        timestamptz not null default now() + interval '3 minutes'
);
create index on public.ride_requests (status, created_at);

create table public.ride_offers (
  id          uuid primary key default gen_random_uuid(),
  request_id  uuid not null references public.ride_requests on delete cascade,
  driver_id   uuid not null references public.profiles on delete cascade,
  price       integer not null check (price > 0),
  eta_minutes integer not null default 5,
  status      text not null default 'pending'
              check (status in ('pending', 'accepted', 'declined', 'expired')),
  created_at  timestamptz not null default now(),
  unique (request_id, driver_id)
);
create index on public.ride_offers (request_id, status);

create table public.rides (
  id            uuid primary key default gen_random_uuid(),
  request_id    uuid not null unique references public.ride_requests,
  passenger_id  uuid not null references public.profiles,
  driver_id     uuid not null references public.profiles,
  price         integer not null,
  status        text not null default 'driver_on_the_way'
                check (status in ('driver_on_the_way', 'driver_arrived', 'in_progress', 'completed', 'cancelled')),
  cancel_reason text,
  cancelled_by  uuid,
  rating        integer check (rating between 1 and 5),
  comment       text,
  tip           integer not null default 0 check (tip >= 0),
  created_at    timestamptz not null default now(),
  arrived_at    timestamptz,
  started_at    timestamptz,
  completed_at  timestamptz
);
create index on public.rides (passenger_id, created_at desc);
create index on public.rides (driver_id, created_at desc);

create table public.messages (
  id         uuid primary key default gen_random_uuid(),
  ride_id    uuid not null references public.rides on delete cascade,
  sender_id  uuid not null references public.profiles,
  body       text not null check (length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);
create index on public.messages (ride_id, created_at);

create table public.promo_codes (
  code            text primary key,
  percent         integer not null check (percent between 1 and 100),
  first_ride_only boolean not null default true,
  active          boolean not null default true,
  expires_at      timestamptz
);

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

create or replace function public.is_ride_participant(p_ride uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from rides
    where id = p_ride and auth.uid() in (passenger_id, driver_id)
  );
$$;

create or replace function public.is_driver()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'driver' and not is_blocked);
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'admin');
$$;

-- Users may edit their name / switch passenger<->driver, nothing else.
create or replace function public.protect_profile_fields()
returns trigger language plpgsql set search_path = public as $$
begin
  -- Direct writes from the app run as 'authenticated'; our RPCs run as owner.
  if current_user in ('authenticated', 'anon') and not public.is_admin() then
    new.rating := old.rating;
    new.rating_count := old.rating_count;
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

-- Only an admin (or the service role) can approve a vehicle. Changing the
-- vehicle details sends it back for approval.
create or replace function public.protect_vehicle_approval()
returns trigger language plpgsql set search_path = public as $$
begin
  -- Direct writes from the app run as 'authenticated'; our RPCs run as owner.
  if current_user in ('authenticated', 'anon') and not public.is_admin() then
    if tg_op = 'INSERT' then
      new.approved := false;
    elsif (new.make, new.model, new.plate, new.category_id)
          is distinct from (old.make, old.model, old.plate, old.category_id) then
      new.approved := false;
    else
      new.approved := old.approved;
    end if;
  end if;
  return new;
end;
$$;

create trigger protect_vehicle_approval
  before insert or update on public.vehicles
  for each row execute function public.protect_vehicle_approval();

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

alter table public.profiles             enable row level security;
alter table public.fare_settings        enable row level security;
alter table public.vehicles             enable row level security;
alter table public.driver_status        enable row level security;
alter table public.driver_subscriptions enable row level security;
alter table public.app_settings         enable row level security;
alter table public.ride_requests        enable row level security;
alter table public.ride_offers          enable row level security;
alter table public.rides                enable row level security;
alter table public.messages             enable row level security;
alter table public.promo_codes          enable row level security;

-- Profiles: you see yourself, drivers are visible (name/rating on offers),
-- and ride participants see each other (to call / message).
create policy "profiles: read own" on public.profiles
  for select using (id = auth.uid());
create policy "profiles: read ride partner" on public.profiles
  for select using (exists (
    select 1 from public.rides r
    where auth.uid() in (r.passenger_id, r.driver_id)
      and profiles.id in (r.passenger_id, r.driver_id)
  ));
create policy "profiles: drivers read requesting passenger" on public.profiles
  for select using (public.is_driver() and exists (
    select 1 from public.ride_requests q
    where q.passenger_id = profiles.id and q.status = 'searching'
  ));
create policy "profiles: update own" on public.profiles
  for update using (id = auth.uid())
  with check (id = auth.uid() and role in ('passenger', 'driver'));

create policy "fares: readable" on public.fare_settings
  for select using (true);
create policy "settings: readable" on public.app_settings
  for select using (true);

create policy "vehicles: readable" on public.vehicles
  for select to authenticated using (true);
create policy "vehicles: driver inserts own" on public.vehicles
  for insert with check (driver_id = auth.uid());
create policy "vehicles: driver updates own" on public.vehicles
  for update using (driver_id = auth.uid())
  with check (driver_id = auth.uid());

create policy "driver_status: read online" on public.driver_status
  for select to authenticated using (is_online or driver_id = auth.uid());
create policy "driver_status: write own" on public.driver_status
  for insert with check (driver_id = auth.uid());
create policy "driver_status: update own" on public.driver_status
  for update using (driver_id = auth.uid()) with check (driver_id = auth.uid());

create policy "subscriptions: read own" on public.driver_subscriptions
  for select using (driver_id = auth.uid());

create policy "requests: passenger reads own" on public.ride_requests
  for select using (passenger_id = auth.uid());
create policy "requests: drivers read open" on public.ride_requests
  for select to authenticated using (
    status = 'searching' and public.is_driver()
  );
create policy "requests: driver reads accepted" on public.ride_requests
  for select using (exists (
    select 1 from public.rides r where r.request_id = ride_requests.id and r.driver_id = auth.uid()
  ));
create policy "requests: passenger creates" on public.ride_requests
  for insert with check (passenger_id = auth.uid() and status = 'searching');

create policy "offers: driver reads own" on public.ride_offers
  for select using (driver_id = auth.uid());
create policy "offers: passenger reads" on public.ride_offers
  for select using (exists (
    select 1 from public.ride_requests q where q.id = request_id and q.passenger_id = auth.uid()
  ));

create policy "rides: participants read" on public.rides
  for select using (auth.uid() in (passenger_id, driver_id));

create policy "messages: participants read" on public.messages
  for select using (public.is_ride_participant(ride_id));
create policy "messages: participants send" on public.messages
  for insert with check (sender_id = auth.uid() and public.is_ride_participant(ride_id));

-- Promo codes are validated through apply_promo(), not read directly.

-- =========================================================================
-- RPCs (all state changes go through these so they stay consistent)
-- =========================================================================

create or replace function public.nearby_drivers(p_lat double precision, p_lng double precision,
                                                 p_radius_km double precision default 6)
returns table (
  driver_id uuid, full_name text, phone text, rating numeric, trips bigint,
  lat double precision, lng double precision, heading double precision,
  make text, model text, plate text, color text, category_id text, seats integer
)
language sql stable security definer set search_path = public as $$
  select p.id, p.full_name, null::text, p.rating,
         (select count(*) from rides r where r.driver_id = p.id and r.status = 'completed'),
         s.lat, s.lng, s.heading,
         v.make, v.model, v.plate, v.color, v.category_id, v.seats
  from driver_status s
  join profiles p on p.id = s.driver_id and not p.is_blocked
  join vehicles v on v.driver_id = s.driver_id and v.approved
  where s.is_online
    and s.updated_at > now() - interval '2 minutes'
    and s.lat is not null
    and distance_km(p_lat, p_lng, s.lat, s.lng) <= p_radius_km
    and not exists (
      select 1 from rides r where r.driver_id = s.driver_id
        and r.status in ('driver_on_the_way', 'driver_arrived', 'in_progress')
    )
  order by distance_km(p_lat, p_lng, s.lat, s.lng)
  limit 30;
$$;

-- Offers for a request, with driver + vehicle details (for the passenger).
create or replace function public.request_offers(p_request_id uuid)
returns table (
  offer_id uuid, price integer, eta_minutes integer, created_at timestamptz,
  driver_id uuid, full_name text, phone text, rating numeric, trips bigint,
  lat double precision, lng double precision, heading double precision,
  make text, model text, plate text, color text, category_id text, seats integer
)
language sql stable security definer set search_path = public as $$
  select o.id, o.price, o.eta_minutes, o.created_at,
         p.id, p.full_name, null::text, p.rating,
         (select count(*) from rides r where r.driver_id = p.id and r.status = 'completed'),
         s.lat, s.lng, s.heading,
         v.make, v.model, v.plate, v.color, v.category_id, v.seats
  from ride_offers o
  join ride_requests q on q.id = o.request_id and q.passenger_id = auth.uid()
  join profiles p on p.id = o.driver_id
  join vehicles v on v.driver_id = o.driver_id
  left join driver_status s on s.driver_id = o.driver_id
  where o.request_id = p_request_id
    and o.status = 'pending'
    and o.created_at > now() - interval '20 seconds'
  order by o.created_at;
$$;

create or replace function public.send_offer(p_request_id uuid, p_price integer, p_eta integer)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_req ride_requests;
  v_vehicle vehicles;
  v_status driver_status;
  v_settings app_settings;
  v_id uuid;
begin
  select * into v_settings from app_settings limit 1;
  select * into v_req from ride_requests where id = p_request_id;
  if v_req.id is null or v_req.status <> 'searching' or v_req.expires_at < now() then
    raise exception 'request_closed';
  end if;
  select * into v_vehicle from vehicles where driver_id = auth.uid();
  if v_vehicle.id is null or not v_vehicle.approved then
    raise exception 'vehicle_not_approved';
  end if;
  if v_vehicle.category_id <> v_req.category_id then
    raise exception 'wrong_category';
  end if;
  select * into v_status from driver_status where driver_id = auth.uid();
  if v_status.driver_id is null or not v_status.is_online then
    raise exception 'driver_offline';
  end if;
  if v_settings.require_driver_subscription and not exists (
    select 1 from driver_subscriptions where driver_id = auth.uid() and valid_until > now()
  ) then
    raise exception 'subscription_expired';
  end if;
  if p_price < v_req.offered_fare then
    raise exception 'price_too_low';
  end if;

  insert into ride_offers (request_id, driver_id, price, eta_minutes)
  values (p_request_id, auth.uid(), p_price, greatest(1, p_eta))
  on conflict (request_id, driver_id)
    do update set price = excluded.price, eta_minutes = excluded.eta_minutes,
                  status = 'pending', created_at = now()
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.decline_offer(p_offer_id uuid)
returns void language sql security definer set search_path = public as $$
  update ride_offers o set status = 'declined'
  from ride_requests q
  where o.id = p_offer_id and q.id = o.request_id
    and q.passenger_id = auth.uid() and o.status = 'pending';
$$;

-- Atomically turns an offer into a ride. Only one offer can win.
create or replace function public.accept_offer(p_offer_id uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_offer ride_offers;
  v_req ride_requests;
  v_ride uuid;
begin
  select * into v_offer from ride_offers where id = p_offer_id for update;
  if v_offer.id is null or v_offer.status <> 'pending'
     or v_offer.created_at < now() - interval '20 seconds' then
    raise exception 'offer_expired';
  end if;
  select * into v_req from ride_requests where id = v_offer.request_id for update;
  if v_req.passenger_id <> auth.uid() then
    raise exception 'not_allowed';
  end if;
  if v_req.status <> 'searching' then
    raise exception 'request_closed';
  end if;
  if exists (select 1 from rides where driver_id = v_offer.driver_id
             and status in ('driver_on_the_way', 'driver_arrived', 'in_progress')) then
    update ride_offers set status = 'expired' where id = p_offer_id;
    raise exception 'driver_busy';
  end if;

  update ride_requests set status = 'accepted' where id = v_req.id;
  update ride_offers set status = case when id = p_offer_id then 'accepted' else 'declined' end
  where request_id = v_req.id and status = 'pending';
  insert into rides (request_id, passenger_id, driver_id, price)
  values (v_req.id, v_req.passenger_id, v_offer.driver_id, v_offer.price)
  returning id into v_ride;
  return v_ride;
end;
$$;

create or replace function public.cancel_request(p_request_id uuid)
returns void language sql security definer set search_path = public as $$
  update ride_requests set status = 'cancelled'
  where id = p_request_id and passenger_id = auth.uid() and status = 'searching';
  update ride_offers set status = 'expired'
  where request_id = p_request_id and status = 'pending';
$$;

-- Validated status transitions. Drivers move the ride forward; either side
-- can cancel before the trip starts.
create or replace function public.update_ride_status(p_ride_id uuid, p_status text, p_reason text default null)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_ride rides;
begin
  select * into v_ride from rides where id = p_ride_id for update;
  if v_ride.id is null or auth.uid() not in (v_ride.passenger_id, v_ride.driver_id) then
    raise exception 'not_allowed';
  end if;

  if p_status = 'cancelled' then
    if v_ride.status not in ('driver_on_the_way', 'driver_arrived') then
      raise exception 'cannot_cancel';
    end if;
    update rides set status = 'cancelled', cancel_reason = p_reason, cancelled_by = auth.uid()
    where id = p_ride_id;
    return;
  end if;

  if auth.uid() <> v_ride.driver_id then
    raise exception 'not_allowed';
  end if;

  if v_ride.status = 'driver_on_the_way' and p_status = 'driver_arrived' then
    update rides set status = p_status, arrived_at = now() where id = p_ride_id;
  elsif v_ride.status = 'driver_arrived' and p_status = 'in_progress' then
    update rides set status = p_status, started_at = now() where id = p_ride_id;
  elsif v_ride.status = 'in_progress' and p_status = 'completed' then
    update rides set status = p_status, completed_at = now() where id = p_ride_id;
  else
    raise exception 'invalid_transition';
  end if;
end;
$$;

create or replace function public.rate_ride(p_ride_id uuid, p_stars integer, p_tip integer default 0,
                                            p_comment text default '')
returns void language plpgsql security definer set search_path = public as $$
declare
  v_ride rides;
begin
  select * into v_ride from rides where id = p_ride_id for update;
  if v_ride.passenger_id <> auth.uid() or v_ride.status <> 'completed' or v_ride.rating is not null then
    raise exception 'not_allowed';
  end if;
  update rides set rating = p_stars, tip = greatest(0, p_tip), comment = p_comment
  where id = p_ride_id;
  update profiles
  set rating = round(((rating * rating_count) + p_stars)::numeric / (rating_count + 1), 2),
      rating_count = rating_count + 1
  where id = v_ride.driver_id;
end;
$$;

create or replace function public.apply_promo(p_code text)
returns integer language plpgsql stable security definer set search_path = public as $$
declare
  v_promo promo_codes;
begin
  select * into v_promo from promo_codes
  where upper(code) = upper(p_code) and active and (expires_at is null or expires_at > now());
  if v_promo.code is null then
    return 0;
  end if;
  if v_promo.first_ride_only and exists (
    select 1 from rides where passenger_id = auth.uid() and status = 'completed'
  ) then
    return 0;
  end if;
  return v_promo.percent;
end;
$$;

create or replace function public.driver_earnings()
returns table (today bigint, week bigint, trips_today bigint, trips_week bigint)
language sql stable security definer set search_path = public as $$
  select
    coalesce(sum(price + tip) filter (where completed_at >= date_trunc('day', now() at time zone 'Europe/Tirane') at time zone 'Europe/Tirane'), 0),
    coalesce(sum(price + tip) filter (where completed_at >= now() - interval '7 days'), 0),
    count(*) filter (where completed_at >= date_trunc('day', now() at time zone 'Europe/Tirane') at time zone 'Europe/Tirane'),
    count(*) filter (where completed_at >= now() - interval '7 days')
  from rides
  where driver_id = auth.uid() and status = 'completed';
$$;

-- Housekeeping: close requests nobody answered. Schedule with pg_cron:
--   select cron.schedule('expire-requests', '* * * * *', 'select public.expire_stale_requests()');
create or replace function public.expire_stale_requests()
returns void language sql security definer set search_path = public as $$
  update ride_requests set status = 'expired'
  where status = 'searching' and expires_at < now();
  update ride_offers set status = 'expired'
  where status = 'pending' and created_at < now() - interval '20 seconds';
$$;

-- Clients may only call the RPCs above for writes on these tables.
revoke insert, update, delete on public.ride_offers, public.rides from anon, authenticated;
revoke execute on function public.expire_stale_requests() from anon, authenticated;

-- =========================================================================
-- Realtime
-- =========================================================================

alter publication supabase_realtime add table
  public.ride_requests, public.ride_offers, public.rides, public.messages, public.driver_status;
