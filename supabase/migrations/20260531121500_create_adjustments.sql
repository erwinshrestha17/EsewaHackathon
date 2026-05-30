create table if not exists public.adjustments (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  reason text not null check (length(trim(reason)) > 0),
  adjustment_type text not null default 'correction' check (
    adjustment_type in ('correction', 'reversal', 'manual')
  ),
  created_by uuid not null references public.profiles(id),
  reverses_source_type text,
  reverses_source_id uuid,
  created_at timestamptz not null default now()
);

create table if not exists public.adjustment_entries (
  id uuid primary key default gen_random_uuid(),
  adjustment_id uuid not null references public.adjustments(id) on delete cascade,
  user_id uuid not null references public.profiles(id),
  amount_minor integer not null check (amount_minor > 0),
  direction text not null check (direction in ('credit', 'debit'))
);

alter table public.adjustments enable row level security;
alter table public.adjustment_entries enable row level security;

drop policy if exists "Server role manages adjustments" on public.adjustments;
create policy "Server role manages adjustments"
on public.adjustments
for all
to service_role
using (true)
with check (true);

drop policy if exists "Server role manages adjustment_entries" on public.adjustment_entries;
create policy "Server role manages adjustment_entries"
on public.adjustment_entries
for all
to service_role
using (true)
with check (true);

grant select, insert, update, delete on table
  public.adjustments,
  public.adjustment_entries
to service_role;
