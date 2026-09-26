-- Security hardening from the Supabase advisors.

-- Logged-out visitors cannot call any app function; signed-in users keep
-- the ones the app uses. Trigger-only functions are not callable at all.
revoke execute on all functions in schema public from anon, public;
revoke execute on function public.handle_new_user() from authenticated;
grant execute on function
  public.search_cars(double precision, double precision, timestamptz, timestamptz, double precision, text),
  public.apply_promo(text),
  public.request_booking(uuid, timestamptz, timestamptz, integer, text, text, text, text, text),
  public.respond_booking(uuid, text, integer),
  public.accept_counter(uuid),
  public.cancel_booking(uuid, text),
  public.mark_picked_up(uuid),
  public.mark_returned(uuid),
  public.rate_booking(uuid, integer, text),
  public.owner_earnings(),
  public.is_admin(),
  public.is_booking_party(uuid),
  public.distance_km(double precision, double precision, double precision, double precision),
  public.rental_days(timestamptz, timestamptz),
  public.rental_total(integer, integer, integer, integer)
to authenticated;
alter default privileges in schema public revoke execute on functions from anon, public;

-- Fixed search_path for the pure helper functions.
alter function public.distance_km(double precision, double precision, double precision, double precision)
  set search_path = pg_catalog, public;
alter function public.rental_days(timestamptz, timestamptz) set search_path = pg_catalog, public;
alter function public.rental_total(integer, integer, integer, integer) set search_path = pg_catalog, public;
