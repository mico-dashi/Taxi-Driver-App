-- Car photos uploaded by owners (public URLs in the "car-photos" bucket).

alter table public.cars
  add column if not exists photos text[] not null default '{}'
  check (cardinality(photos) <= 8);

-- search_cars() now returns the photos too (return type changes, so drop
-- and recreate with the same body).
drop function if exists public.search_cars(double precision, double precision,
  timestamptz, timestamptz, double precision, text);

create function public.search_cars(p_lat double precision, p_lng double precision,
                                   p_start timestamptz, p_end timestamptz,
                                   p_radius_km double precision default 30,
                                   p_category text default null)
returns table (
  id uuid, owner_id uuid, owner_name text, owner_rating numeric,
  make text, model text, year integer, plate text, color bigint, category_id text,
  transmission text, fuel text, seats integer, price_per_day integer, deposit integer,
  loc_name text, loc_subtitle text, lat double precision, lng double precision,
  delivery boolean, delivery_fee integer, min_days integer, km_per_day integer,
  description text, rating numeric, trips integer, distance_km double precision,
  photos text[]
)
language sql stable security definer set search_path = public as $$
  select c.id, c.owner_id, p.full_name, p.rating,
         c.make, c.model, c.year, c.plate, c.color, c.category_id,
         c.transmission, c.fuel, c.seats, c.price_per_day, c.deposit,
         c.loc_name, c.loc_subtitle, c.lat, c.lng,
         c.delivery, c.delivery_fee, c.min_days, c.km_per_day,
         c.description, c.rating, c.trips,
         distance_km(p_lat, p_lng, c.lat, c.lng),
         c.photos
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

-- Storage: a public bucket; owners write only inside their own folder
-- (<user id>/<file>). Skipped on plain PostgreSQL (no storage schema).
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'storage') then
    insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    values ('car-photos', 'car-photos', true, 5242880,
            array['image/jpeg', 'image/png', 'image/webp'])
    on conflict (id) do nothing;

    execute $p$
      create policy "car photos: owners upload" on storage.objects
        for insert to authenticated
        with check (bucket_id = 'car-photos'
                    and (storage.foldername(name))[1] = auth.uid()::text)
    $p$;
    execute $p$
      create policy "car photos: owners delete" on storage.objects
        for delete to authenticated
        using (bucket_id = 'car-photos'
               and (storage.foldername(name))[1] = auth.uid()::text)
    $p$;
  end if;
end $$;
