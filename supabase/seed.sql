-- Car categories with suggested prices in Lekë (ALL). Owners set their own
-- price per day; these are only the defaults shown when listing a car.
insert into public.car_categories (id, name, suggested_per_day, suggested_deposit, seats) values
  ('economy', 'Economy', 3000, 20000, 5),
  ('suv',     'SUV',     5500, 40000, 5),
  ('luxury',  'Luxury', 12000, 100000, 5),
  ('van',     'Van',     7000, 50000, 8)
on conflict (id) do update set
  suggested_per_day = excluded.suggested_per_day,
  suggested_deposit = excluded.suggested_deposit,
  seats = excluded.seats;

insert into public.promo_codes (code, percent, first_rental_only) values
  ('QIRA20', 20, true)
on conflict (code) do nothing;
