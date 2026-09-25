-- Default tariffs in Lekë (ALL). Change them any time; the app reads this table.
insert into public.fare_settings (category_id, name, base_fare, per_km, per_minute, min_fare, seats) values
  ('standard', 'Standard', 300, 100, 10, 400, 4),
  ('luxury',   'Luxury',   600, 220, 20, 1000, 4),
  ('van',      'Van',      500, 160, 15, 800, 7)
on conflict (category_id) do update set
  base_fare = excluded.base_fare, per_km = excluded.per_km, per_minute = excluded.per_minute,
  min_fare = excluded.min_fare, seats = excluded.seats;

insert into public.promo_codes (code, percent, first_ride_only) values
  ('TAKSI30', 30, true)
on conflict (code) do nothing;
