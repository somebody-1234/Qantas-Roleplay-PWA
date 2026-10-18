-- Qantas Roleplay only. Run this AFTER the boarding_passes and staff_profiles
-- tables exist and your own user is listed as role='admin'.
-- This migration removes direct pass-table access and exposes controlled RPCs.

alter table public.boarding_passes
  add column if not exists scan_token text;

update public.boarding_passes
set scan_token = replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '')
where scan_token is null;

alter table public.boarding_passes
  alter column scan_token set default replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
alter table public.boarding_passes
  alter column scan_token set not null;

create unique index if not exists boarding_passes_scan_token_uidx
  on public.boarding_passes(scan_token);

-- Do not allow browser clients to directly read or change pass rows.
revoke all on table public.boarding_passes from anon, authenticated;

-- The staff profile table remains readable only according to its existing RLS policy.
grant select on table public.staff_profiles to authenticated;

create or replace function public.create_roleplay_pass(
  p_passenger_name text,
  p_booking_reference text,
  p_flight_number text,
  p_origin text,
  p_destination text,
  p_departure_date date,
  p_departure_time text,
  p_seat text default null,
  p_boarding_group text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare r public.boarding_passes%rowtype;
begin
  if (select auth.uid()) is null or not exists (
    select 1 from public.staff_profiles sp
    where sp.user_id = (select auth.uid())
  ) then
    return jsonb_build_object('status', 'unauthorised');
  end if;

  insert into public.boarding_passes (
    booking_reference, passenger_name, flight_number, origin,
    destination, departure_date, departure_time, seat,
    boarding_group, created_by
  ) values (
    upper(trim(p_booking_reference)), trim(p_passenger_name),
    upper(trim(p_flight_number)), upper(trim(p_origin)),
    upper(trim(p_destination)), p_departure_date, p_departure_time,
    nullif(trim(coalesce(p_seat, '')), ''),
    nullif(trim(coalesce(p_boarding_group, '')), ''),
    (select auth.uid())
  ) returning * into r;

  return jsonb_build_object(
    'status', 'created',
    'booking_reference', r.booking_reference,
    'scan_token', r.scan_token
  );
exception when unique_violation then
  return jsonb_build_object('status', 'duplicate_booking_reference');
end;
$$;

create or replace function public.scan_roleplay_pass(p_scan_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare r public.boarding_passes%rowtype;
begin
  if (select auth.uid()) is null or not exists (
    select 1 from public.staff_profiles sp
    where sp.user_id = (select auth.uid())
  ) then
    return jsonb_build_object('status', 'unauthorised');
  end if;

  select * into r
  from public.boarding_passes bp
  where bp.scan_token = trim(p_scan_token)
  for update;

  if not found then
    return jsonb_build_object('status', 'invalid');
  end if;

  if r.used_at is not null then
    return jsonb_build_object('status', 'already_used', 'pass', jsonb_build_object(
      'passenger_name', r.passenger_name,
      'booking_reference', r.booking_reference,
      'flight_number', r.flight_number,
      'origin', r.origin, 'destination', r.destination,
      'departure_date', r.departure_date,
      'departure_time', r.departure_time,
      'seat', r.seat, 'boarding_group', r.boarding_group,
      'used_at', r.used_at
    ));
  end if;

  if r.departure_date < (now() at time zone 'Australia/Melbourne')::date then
    return jsonb_build_object('status', 'expired', 'pass', jsonb_build_object(
      'passenger_name', r.passenger_name,
      'booking_reference', r.booking_reference,
      'flight_number', r.flight_number,
      'origin', r.origin, 'destination', r.destination,
      'departure_date', r.departure_date,
      'departure_time', r.departure_time,
      'seat', r.seat, 'boarding_group', r.boarding_group,
      'used_at', r.used_at
    ));
  end if;

  update public.boarding_passes bp
  set used_at = now()
  where bp.id = r.id
  returning * into r;

  return jsonb_build_object('status', 'valid', 'pass', jsonb_build_object(
    'passenger_name', r.passenger_name,
    'booking_reference', r.booking_reference,
    'flight_number', r.flight_number,
    'origin', r.origin, 'destination', r.destination,
    'departure_date', r.departure_date,
    'departure_time', r.departure_time,
    'seat', r.seat, 'boarding_group', r.boarding_group,
    'used_at', r.used_at
  ));
end;
$$;

create or replace function public.list_roleplay_passes()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare result jsonb;
begin
  if (select auth.uid()) is null or not exists (
    select 1 from public.staff_profiles sp
    where sp.user_id = (select auth.uid())
  ) then
    return '[]'::jsonb;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'booking_reference', bp.booking_reference,
    'passenger_name', bp.passenger_name,
    'flight_number', bp.flight_number,
    'origin', bp.origin, 'destination', bp.destination,
    'departure_date', bp.departure_date,
    'departure_time', bp.departure_time,
    'seat', bp.seat, 'boarding_group', bp.boarding_group,
    'used_at', bp.used_at, 'scan_token', bp.scan_token,
    'created_at', bp.created_at
  ) order by bp.created_at desc), '[]'::jsonb)
  into result from public.boarding_passes bp;
  return result;
end;
$$;

revoke all on function public.create_roleplay_pass(text,text,text,text,text,date,text,text,text) from public, anon;
revoke all on function public.scan_roleplay_pass(text) from public, anon;
revoke all on function public.list_roleplay_passes() from public, anon;
grant execute on function public.create_roleplay_pass(text,text,text,text,text,date,text,text,text) to authenticated;
grant execute on function public.scan_roleplay_pass(text) to authenticated;
grant execute on function public.list_roleplay_passes() to authenticated;
