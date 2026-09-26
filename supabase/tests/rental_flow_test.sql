-- End-to-end test of the rental flow through RLS + RPCs.
\set ON_ERROR_STOP on
\set owner   '11111111-1111-1111-1111-111111111111'
\set renter  '22222222-2222-2222-2222-222222222222'
\set renter2 '33333333-3333-3333-3333-333333333333'
\set stranger '44444444-4444-4444-4444-444444444444'

insert into auth.users (id, phone) values
  (:'owner', '+355691111111'), (:'renter', '+355692222222'),
  (:'renter2', '+355693333333'), (:'stranger', '+355694444444');

create or replace function pg_temp.as_user(p uuid) returns void language sql as $$
  select set_config('request.jwt.claim.sub', p::text, false);
$$;
create or replace function pg_temp.as_service() returns void language sql as $$
  select set_config('request.jwt.claim.sub', '', false);
$$;
-- Expects the statement to raise the given error code.
create or replace function pg_temp.expect_error(p_sql text, p_code text) returns void
language plpgsql as $$
begin
  execute p_sql;
  raise exception 'expected % but the statement succeeded: %', p_code, p_sql;
exception when raise_exception then
  if sqlerrm <> p_code then
    raise exception 'expected %, got %', p_code, sqlerrm;
  end if;
end;
$$;

-- Owner lists a car; self-approval and fake ratings are ignored.
set role authenticated;
select pg_temp.as_user(:'owner');
update profiles set full_name = 'Arben Hoxha', role = 'owner', rating = 1 where id = auth.uid();
insert into cars (owner_id, make, model, year, plate, category_id, price_per_day, deposit,
                  loc_name, lat, lng, delivery, delivery_fee, min_days, approved, trips)
values (auth.uid(), 'Volkswagen', 'Golf 7', 2018, 'AA 482 TR', 'economy', 3000, 20000,
        'Blloku', 41.3197, 19.8150, true, 500, 2, true, 99);
reset role;
select pg_temp.as_service();
do $$ begin
  assert (select rating from profiles where full_name = 'Arben Hoxha') = 5, 'owner cannot set own rating';
  assert not (select approved from cars), 'self-approval ignored';
  assert (select trips from cars) = 0, 'trip count protected';
end $$;
update cars set approved = true; -- admin approves

-- Renter searches and books with a lower offer; owner counters.
set role authenticated;
select pg_temp.as_user(:'renter');
update profiles set full_name = 'Alda Renter' where id = auth.uid();
do $$
declare
  s timestamptz := date_trunc('day', now()) + interval '2 days 10 hours';
  car uuid;
  bk uuid;
begin
  assert (select count(*) from search_cars(41.3275, 19.8187, s, s + interval '3 days')) = 1, 'car found';
  assert (select count(*) from search_cars(40.4661, 19.4914, s, s + interval '3 days')) = 0, 'not in Vlora';
  select id into car from search_cars(41.3275, 19.8187, s, s + interval '3 days');
  perform pg_temp.expect_error(format('select request_booking(%L, %L, %L, 2000)', car, s, s + interval '3 days'), 'offer_too_low');
  perform pg_temp.expect_error(format('select request_booking(%L, %L, %L, 3000)', car, s, s + interval '1 day'), 'min_days');
  bk := request_booking(car, s, s + interval '3 days', 2700, 'delivery', 'cash', 'Rruga e Kavajës 10', '', 'qira20');
  assert (select status from bookings where id = bk) = 'requested';
  assert (select promo_percent from bookings where id = bk) = 20, 'promo stored';
end $$;

-- A stranger sees nothing.
select pg_temp.as_user(:'stranger');
do $$ begin
  assert (select count(*) from bookings) = 0, 'stranger sees no bookings';
end $$;

-- Second renter asks for overlapping dates while the first is still open.
select pg_temp.as_user(:'renter2');
update profiles set full_name = 'Besa Renter2' where id = auth.uid();
select request_booking((select id from cars), date_trunc('day', now()) + interval '3 days 10 hours',
                       date_trunc('day', now()) + interval '6 days 10 hours', 3000) is not null as requested2;

-- Owner counters the first and cannot counter below the offer.
select pg_temp.as_user(:'owner');
do $$
declare bk uuid;
begin
  select id into bk from bookings b where b.offered_per_day = 2700;
  perform pg_temp.expect_error(format('select respond_booking(%L, %L, 2500)', bk, 'counter'), 'counter_too_low');
  perform respond_booking(bk, 'counter', 2900);
  assert (select status from bookings where id = bk) = 'countered';
  assert (select phone from profiles where full_name = 'Alda Renter') = '+355692222222', 'owner sees renter';
end $$;

-- Renter accepts the counter: confirmed, total fixed by the server.
select pg_temp.as_user(:'renter');
do $$
declare bk uuid;
begin
  select id into bk from bookings;
  perform accept_counter(bk);
  assert (select status from bookings where id = bk) = 'confirmed';
  assert (select agreed_per_day from bookings where id = bk) = 2900;
  -- 3 days * 2900 = 8700, -20% promo = 6960 -> 7000, + 500 delivery
  assert (select total from bookings where id = bk) = 7500, 'total computed on server';
  assert rental_total(3000, 7, 0, 0) = 18900, 'weekly discount';
  assert (select count(*) from search_cars(41.3275, 19.8187, now() + interval '2 days', now() + interval '4 days')) = 0,
    'booked car hidden for those dates';
end $$;
insert into messages (booking_id, sender_id, body) values ((select id from bookings), auth.uid(), 'Jam te hyrja');

-- The overlapping request can no longer be confirmed: the database refuses.
select pg_temp.as_user(:'owner');
do $$
declare bk2 uuid;
begin
  select id into bk2 from bookings where status = 'requested';
  perform pg_temp.expect_error(format('select respond_booking(%L, %L)', bk2, 'accept'), 'car_unavailable');
  perform respond_booking(bk2, 'decline');
  assert (select status from bookings where id = bk2) = 'declined';
end $$;

-- Renter 2 cannot read the first renter's chat or booking.
select pg_temp.as_user(:'renter2');
do $$ begin
  assert (select count(*) from bookings) = 1, 'renter2 sees only own booking';
  assert (select count(*) from messages) = 0, 'renter2 sees no chat';
end $$;

-- Handover, return, review.
select pg_temp.as_user(:'renter');
do $$
declare bk uuid;
begin
  select id into bk from bookings;
  perform pg_temp.expect_error(format('select mark_returned(%L)', bk), 'invalid_transition');
  perform mark_picked_up(bk);
  perform pg_temp.expect_error(format('select cancel_booking(%L)', bk), 'cannot_cancel');
end $$;
select pg_temp.as_user(:'owner');
select mark_returned((select id from bookings where status = 'active'));
do $$ begin
  assert (select trips from cars) = 1, 'trip counted';
  -- The rental ends in the future, so it always counts in this month's earnings.
  assert (select rentals_this_month from owner_earnings()) = 1, 'earnings count the rental';
  assert (select this_month from owner_earnings()) = 7500, 'earnings sum the total';
end $$;
select pg_temp.as_user(:'renter');
do $$
declare bk uuid;
begin
  select id into bk from bookings where status = 'completed';
  perform rate_booking(bk, 4, 'Makinë e pastër');
  perform pg_temp.expect_error(format('select rate_booking(%L, 5)', bk), 'not_allowed');
  assert apply_promo('QIRA20') = 0, 'promo is first-rental only';
end $$;
reset role;
select pg_temp.as_service();
do $$ begin
  assert (select rating from cars) = 4.00, 'car rating averaged';
  assert (select rating from profiles where full_name = 'Arben Hoxha') = 4.00, 'owner rating averaged';
end $$;
select 'ALL RENTAL FLOW TESTS PASSED' as result;
