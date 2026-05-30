create table if not exists public.connection_blocks (
  id uuid primary key default gen_random_uuid(),
  connection_id uuid not null references public.connections(id) on delete cascade,
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_user_id uuid not null references public.profiles(id) on delete cascade,
  active boolean not null default true,
  lifted_at timestamptz,
  created_at timestamptz not null default now(),
  check (blocker_id <> blocked_user_id)
);

create unique index if not exists connection_blocks_one_active_pair
  on public.connection_blocks (connection_id, blocker_id, blocked_user_id)
  where active;

create table if not exists public.connection_reports (
  id uuid primary key default gen_random_uuid(),
  connection_id uuid not null references public.connections(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reported_user_id uuid not null references public.profiles(id) on delete cascade,
  reason_code text not null default 'safety_review',
  details text,
  status text not null default 'open' check (status in ('open', 'reviewing', 'closed')),
  created_at timestamptz not null default now(),
  check (reporter_id <> reported_user_id),
  unique (connection_id, reporter_id, reported_user_id)
);

do $$
declare
  t text;
begin
  foreach t in array array['connection_blocks', 'connection_reports'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "Server role manages %s" on public.%I', t, t);
    execute format(
      'create policy "Server role manages %s" on public.%I for all to service_role using (true) with check (true)',
      t,
      t
    );
    execute format('grant select, insert, update, delete on table public.%I to service_role', t);
  end loop;
end $$;
