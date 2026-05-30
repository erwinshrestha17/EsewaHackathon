alter table if exists public.profiles
  add column if not exists date_of_birth date,
  add column if not exists phone_verified_at timestamptz;

alter table if exists public.app_sessions
  add column if not exists refresh_token_hash text,
  add column if not exists previous_refresh_token_hash text,
  add column if not exists access_token_expires_at timestamptz,
  add column if not exists refresh_token_expires_at timestamptz,
  add column if not exists revocation_reason text,
  add column if not exists rotated_at timestamptz;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'app_sessions'
      and column_name = 'token_hash'
  ) then
    alter table public.app_sessions alter column token_hash drop not null;
  end if;
end $$;

update public.app_sessions
set
  refresh_token_hash = coalesce(refresh_token_hash, token_hash),
  refresh_token_expires_at = coalesce(refresh_token_expires_at, expires_at)
where refresh_token_hash is null
   or refresh_token_expires_at is null;

create unique index if not exists app_sessions_refresh_token_hash_idx
  on public.app_sessions(refresh_token_hash)
  where refresh_token_hash is not null and revoked_at is null;

create index if not exists app_sessions_refresh_valid_idx
  on public.app_sessions(user_id, refresh_token_expires_at)
  where revoked_at is null;

create index if not exists profiles_phone_verified_idx
  on public.profiles(phone, phone_verified_at)
  where phone is not null;

create or replace function public.register_app_user(
  p_phone text,
  p_full_name text,
  p_avatar_initials text,
  p_date_of_birth date,
  p_district text,
  p_mpin_hash text
)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  registered_profile public.profiles;
begin
  insert into public.profiles (
    phone,
    full_name,
    avatar_initials,
    district,
    date_of_birth,
    phone_verified_at
  ) values (
    p_phone,
    p_full_name,
    p_avatar_initials,
    nullif(trim(coalesce(p_district, '')), ''),
    p_date_of_birth,
    now()
  )
  returning * into registered_profile;

  insert into public.user_settings (user_id)
  values (registered_profile.id)
  on conflict (user_id) do nothing;

  insert into public.app_user_credentials (
    user_id,
    mpin_hash,
    failed_attempts,
    locked_until
  ) values (
    registered_profile.id,
    p_mpin_hash,
    0,
    null
  );

  return registered_profile;
end;
$$;

grant execute on function public.register_app_user(
  text,
  text,
  text,
  date,
  text,
  text
) to service_role;

notify pgrst, 'reload schema';
