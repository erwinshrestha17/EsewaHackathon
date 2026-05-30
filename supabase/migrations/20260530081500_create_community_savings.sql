create extension if not exists pgcrypto;

create table if not exists public.community_savings_groups (
  id uuid primary key default gen_random_uuid(),
  legacy_pool_id text unique,
  name text not null check (length(trim(name)) > 0),
  monthly_contribution_amount integer not null check (monthly_contribution_amount > 0),
  currency text not null default 'Rs.',
  current_month date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.community_savings_members (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.community_savings_groups(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  role text not null default 'member' check (role in ('admin', 'member')),
  avatar_initials text not null check (length(trim(avatar_initials)) between 1 and 4),
  created_at timestamptz not null default now(),
  unique (group_id, name)
);

create table if not exists public.community_savings_contributions (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.community_savings_groups(id) on delete cascade,
  member_id uuid not null references public.community_savings_members(id) on delete cascade,
  member_name text not null check (length(trim(member_name)) > 0),
  month date not null,
  expected_amount integer not null check (expected_amount >= 0),
  submitted_amount integer not null default 0 check (submitted_amount >= 0),
  received_amount integer not null default 0 check (received_amount >= 0),
  status text not null default 'pending' check (
    status in ('pending', 'submitted', 'confirmed_received', 'waived')
  ),
  payment_method text check (
    payment_method is null or payment_method in (
      'Cash',
      'Bank Transfer',
      'eSewa',
      'Khalti',
      'IME Pay',
      'Other'
    )
  ),
  submitted_at timestamptz,
  confirmed_at timestamptz,
  confirmed_by text,
  note text,
  reference_number text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (group_id, member_id, month),
  constraint submitted_requires_no_balance check (
    status <> 'submitted' or received_amount = 0
  ),
  constraint waived_requires_zero_amount check (
    status <> 'waived' or (submitted_amount = 0 and received_amount = 0)
  ),
  constraint confirmed_requires_received_amount check (
    status <> 'confirmed_received' or received_amount > 0
  )
);

create table if not exists public.community_savings_expenses (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.community_savings_groups(id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  amount integer not null check (amount > 0),
  expense_date date not null,
  category text not null check (
    category in (
      'Food',
      'Event',
      'Emergency',
      'Maintenance',
      'Donation',
      'Travel',
      'Supplies',
      'Other'
    )
  ),
  recorded_by text not null check (length(trim(recorded_by)) > 0),
  description text,
  receipt_reference text,
  created_at timestamptz not null default now()
);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists touch_community_savings_groups_updated_at
  on public.community_savings_groups;
create trigger touch_community_savings_groups_updated_at
before update on public.community_savings_groups
for each row execute function public.touch_updated_at();

drop trigger if exists touch_community_savings_contributions_updated_at
  on public.community_savings_contributions;
create trigger touch_community_savings_contributions_updated_at
before update on public.community_savings_contributions
for each row execute function public.touch_updated_at();

alter table public.community_savings_groups enable row level security;
alter table public.community_savings_members enable row level security;
alter table public.community_savings_contributions enable row level security;
alter table public.community_savings_expenses enable row level security;

drop policy if exists "Server role manages community savings groups"
  on public.community_savings_groups;
create policy "Server role manages community savings groups"
on public.community_savings_groups
for all
to service_role
using (true)
with check (true);

drop policy if exists "Server role manages community savings members"
  on public.community_savings_members;
create policy "Server role manages community savings members"
on public.community_savings_members
for all
to service_role
using (true)
with check (true);

drop policy if exists "Server role manages community savings contributions"
  on public.community_savings_contributions;
create policy "Server role manages community savings contributions"
on public.community_savings_contributions
for all
to service_role
using (true)
with check (true);

drop policy if exists "Server role manages community savings expenses"
  on public.community_savings_expenses;
create policy "Server role manages community savings expenses"
on public.community_savings_expenses
for all
to service_role
using (true)
with check (true);

grant select, insert, update, delete on table
  public.community_savings_groups,
  public.community_savings_members,
  public.community_savings_contributions,
  public.community_savings_expenses
to service_role;
