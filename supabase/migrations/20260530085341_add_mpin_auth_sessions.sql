do $$
begin
  if to_regclass('public.profiles') is not null then
    create table if not exists public.app_user_credentials (
      user_id uuid primary key references public.profiles(id) on delete cascade,
      mpin_hash text not null,
      failed_attempts integer not null default 0 check (failed_attempts >= 0),
      locked_until timestamptz,
      created_at timestamptz not null default now(),
      updated_at timestamptz not null default now()
    );

    create table if not exists public.app_sessions (
      id uuid primary key default gen_random_uuid(),
      user_id uuid not null references public.profiles(id) on delete cascade,
      token_hash text not null unique,
      user_agent text,
      ip_address inet,
      expires_at timestamptz not null,
      revoked_at timestamptz,
      created_at timestamptz not null default now(),
      last_seen_at timestamptz not null default now()
    );

    alter table public.app_user_credentials enable row level security;
    alter table public.app_sessions enable row level security;

    drop policy if exists "Server role manages app_user_credentials"
      on public.app_user_credentials;
    create policy "Server role manages app_user_credentials"
    on public.app_user_credentials
    for all
    to service_role
    using (true)
    with check (true);

    drop policy if exists "Server role manages app_sessions"
      on public.app_sessions;
    create policy "Server role manages app_sessions"
    on public.app_sessions
    for all
    to service_role
    using (true)
    with check (true);

    grant select, insert, update, delete on table
      public.app_user_credentials,
      public.app_sessions
    to service_role;

    drop trigger if exists touch_app_user_credentials_updated_at
      on public.app_user_credentials;
    create trigger touch_app_user_credentials_updated_at
    before update on public.app_user_credentials
    for each row execute function public.touch_updated_at();

    create index if not exists app_sessions_user_id_idx
      on public.app_sessions(user_id);

    create index if not exists app_sessions_valid_idx
      on public.app_sessions(user_id, expires_at)
      where revoked_at is null;
  end if;
end $$;
