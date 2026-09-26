-- Email login: keep the user's email on the profile and let people add a
-- contact phone once (so renter and owner can call each other). After that,
-- the phone is protected like before.

alter table public.profiles add column if not exists email text;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, phone, email) values (new.id, new.phone, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

create or replace function public.protect_profile_fields()
returns trigger language plpgsql set search_path = public as $$
begin
  -- Direct writes from the app run as 'authenticated'; our RPCs run as owner.
  if current_user in ('authenticated', 'anon') and not public.is_admin() then
    new.rating := old.rating;
    new.rating_count := old.rating_count;
    new.licence_verified := old.licence_verified;
    new.is_blocked := old.is_blocked;
    new.email := old.email;
    -- A contact phone can be added once; changing it later needs support.
    if coalesce(old.phone, '') <> '' then
      new.phone := old.phone;
    elsif new.phone is not null and new.phone !~ '^\+3556[0-9]{8}$' then
      raise exception 'invalid_phone';
    end if;
    if new.role = 'admin' or old.role = 'admin' then
      new.role := old.role;
    end if;
  end if;
  return new;
end;
$$;

-- Unanswered requests expire automatically every 15 minutes (pg_cron).
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    perform cron.schedule('expire-requests', '*/15 * * * *',
                          'select public.expire_stale_requests()');
  end if;
end $$;
