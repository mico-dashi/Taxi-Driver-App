-- End-to-end test of the booking flow through RLS + RPCs.
\set ON_ERROR_STOP on
\set passenger '11111111-1111-1111-1111-111111111111'
\set driver    '22222222-2222-2222-2222-222222222222'
\set driver2   '33333333-3333-3333-3333-333333333333'
\set stranger  '44444444-4444-4444-4444-444444444444'

insert into auth.users (id, phone) values
  (:'passenger', '+355691111111'), (:'driver', '+355692222222'),
  (:'driver2', '+355693333333'), (:'stranger', '+355694444444');

create or replace function pg_temp.as_user(p uuid) returns void language sql as $$
  select set_config('request.jwt.claim.sub', p::text, false);
$$;
-- The service role / SQL editor: no logged-in user.
create or replace function pg_temp.as_service() returns void language sql as $$
  select set_config('request.jwt.claim.sub', '', false);
$$;

-- Drivers register, add a vehicle, get approved by admin and go online.
set role authenticated;
select pg_temp.as_user(:'driver');
update profiles set full_name = 'Arben Hoxha', role = 'driver', rating = 1 where id = auth.uid();
insert into vehicles (driver_id, make, model, plate, color, category_id, approved)
  values (auth.uid(), 'Mercedes-Benz', 'E 220d', 'AA 482 TR', 'Black', 'standard', true);
insert into driver_status (driver_id, is_online, lat, lng) values (auth.uid(), true, 41.3200, 19.8150);
select pg_temp.as_user(:'driver2');
update profiles set full_name = 'Elira Kola', role = 'driver' where id = auth.uid();
insert into vehicles (driver_id, make, model, plate, category_id) values (auth.uid(), 'Toyota', 'Prius', 'AB 915 KL', 'standard');
insert into driver_status (driver_id, is_online, lat, lng) values (auth.uid(), true, 41.3210, 19.8160);
reset role;
select pg_temp.as_service();

do $$ begin
  assert (select rating from profiles where full_name = 'Arben Hoxha') = 5, 'driver must not change own rating';
  assert not (select bool_or(approved) from vehicles), 'self-approval must be ignored';
end $$;
update vehicles set approved = true;  -- admin approves both

-- Passenger books.
set role authenticated;
select pg_temp.as_user(:'passenger');
update profiles set full_name = 'Alda Passenger' where id = auth.uid();
do $$ begin
  assert (select count(*) from nearby_drivers(41.3275, 19.8187, 6)) = 2, 'two nearby drivers';
  assert (select apply_promo('taksi30')) = 30, 'promo applies to first ride';
end $$;
insert into ride_requests (passenger_id, pickup_name, pickup_lat, pickup_lng, dest_name, dest_lat, dest_lng,
                           distance_km, duration_min, category_id, offered_fare)
values (auth.uid(), 'Blloku', 41.3197, 19.8150, 'Aeroporti', 41.4147, 19.7206, 17, 25, 'standard', 2500);

-- Stranger (a passenger) cannot see the request.
select pg_temp.as_user(:'stranger');
do $$ begin
  assert (select count(*) from ride_requests) = 0, 'stranger sees no requests';
end $$;

-- Drivers see it and make offers; lowballing is rejected.
select pg_temp.as_user(:'driver');
do $$ declare r uuid; begin
  select id into r from ride_requests where status = 'searching';
  assert r is not null, 'driver sees open request';
  begin
    perform send_offer(r, 1000, 4);
    assert false, 'low price must fail';
  exception when raise_exception then null;
  end;
  perform send_offer(r, 2800, 4);
end $$;
select pg_temp.as_user(:'driver2');
select send_offer((select id from ride_requests limit 1), 2500, 3) is not null as offered;

-- Passenger sees both offers with driver details, declines one, accepts other.
select pg_temp.as_user(:'passenger');
do $$ declare o1 uuid; o2 uuid; ride uuid; begin
  assert (select count(*) from request_offers((select id from ride_requests limit 1))) = 2, 'two offers';
  select offer_id into o1 from request_offers((select id from ride_requests limit 1)) where price = 2800;
  select offer_id into o2 from request_offers((select id from ride_requests limit 1)) where price = 2500;
  perform decline_offer(o1);
  ride := accept_offer(o2);
  assert (select status from rides where id = ride) = 'driver_on_the_way';
  assert (select status from ride_requests limit 1) = 'accepted';
  begin
    perform accept_offer(o1);
    assert false, 'second accept must fail';
  exception when raise_exception then null;
  end;
  -- passenger can see the driver's profile (for the call button) now
  assert (select phone from profiles where full_name = 'Elira Kola') = '+355693333333';
  begin
    perform update_ride_status(ride, 'driver_arrived');
    assert false, 'passenger cannot mark arrived';
  exception when raise_exception then null;
  end;
end $$;
insert into messages (ride_id, sender_id, body) values ((select id from rides), auth.uid(), 'Jam te hyrja');

-- The driver who lost cannot read the ride or its chat.
select pg_temp.as_user(:'driver');
do $$ begin
  assert (select count(*) from rides) = 0, 'other driver sees no ride';
  assert (select count(*) from messages) = 0, 'other driver sees no messages';
end $$;

-- Winning driver completes the trip.
select pg_temp.as_user(:'driver2');
do $$ declare ride uuid; begin
  select id into ride from rides;
  assert (select count(*) from messages) = 1, 'driver sees chat';
  begin
    perform update_ride_status(ride, 'completed');
    assert false, 'cannot skip states';
  exception when raise_exception then null;
  end;
  perform update_ride_status(ride, 'driver_arrived');
  perform update_ride_status(ride, 'in_progress');
  perform update_ride_status(ride, 'completed');
  assert (select trips_today from driver_earnings()) = 1;
  assert (select today from driver_earnings()) = 2500;
end $$;

-- Passenger rates; rating moves the driver's average; promo no longer valid.
select pg_temp.as_user(:'passenger');
do $$ begin
  perform rate_ride((select id from rides), 4, 200, 'Faleminderit');
  assert (select apply_promo('TAKSI30')) = 0, 'promo is first-ride only';
end $$;
reset role;
select pg_temp.as_service();
do $$ begin
  assert (select rating from profiles where full_name = 'Elira Kola') = 4.00, 'first rating sets the average';
  assert (select tip from rides) = 200;
end $$;
select 'ALL RIDE FLOW TESTS PASSED' as result;
