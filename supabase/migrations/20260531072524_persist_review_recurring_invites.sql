create table if not exists public.expense_reviews (
  id uuid primary key default gen_random_uuid(),
  expense_id uuid not null references public.expenses(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (
    status in ('pending', 'accepted', 'correction_requested', 'item_disputed')
  ),
  note text not null default '',
  expense_item_id uuid references public.expense_items(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (expense_id, user_id)
);

create table if not exists public.recurring_expenses (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  amount_minor integer not null check (amount_minor > 0),
  payer_id uuid not null references public.profiles(id),
  category text not null default 'custom',
  split_mode text not null default 'equal' check (split_mode in ('equal', 'custom')),
  frequency text not null default 'monthly' check (frequency in ('weekly', 'monthly')),
  next_due_at timestamptz not null,
  note text not null default '',
  active boolean not null default true,
  last_posted_at timestamptz,
  source_expense_id uuid references public.expenses(id) on delete set null,
  created_by uuid not null references public.profiles(id),
  participant_ids uuid[] not null default '{}'::uuid[],
  custom_amounts jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.group_invites (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  inviter_id uuid not null references public.profiles(id),
  code text not null unique,
  expires_at timestamptz not null,
  accepted_by uuid references public.profiles(id),
  accepted_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists expense_reviews_expense_id_idx
on public.expense_reviews(expense_id);

create index if not exists recurring_expenses_group_due_idx
on public.recurring_expenses(group_id, active, next_due_at);

create index if not exists group_invites_code_idx
on public.group_invites(code);

alter table public.expense_reviews enable row level security;
alter table public.recurring_expenses enable row level security;
alter table public.group_invites enable row level security;

drop policy if exists "Server role manages expense_reviews" on public.expense_reviews;
create policy "Server role manages expense_reviews"
on public.expense_reviews
for all
to service_role
using (true)
with check (true);

drop policy if exists "Server role manages recurring_expenses" on public.recurring_expenses;
create policy "Server role manages recurring_expenses"
on public.recurring_expenses
for all
to service_role
using (true)
with check (true);

drop policy if exists "Server role manages group_invites" on public.group_invites;
create policy "Server role manages group_invites"
on public.group_invites
for all
to service_role
using (true)
with check (true);

grant select, insert, update, delete on table
  public.expense_reviews,
  public.recurring_expenses,
  public.group_invites
to service_role;

drop trigger if exists touch_expense_reviews_updated_at on public.expense_reviews;
create trigger touch_expense_reviews_updated_at
before update on public.expense_reviews
for each row execute function public.touch_updated_at();

drop trigger if exists touch_recurring_expenses_updated_at on public.recurring_expenses;
create trigger touch_recurring_expenses_updated_at
before update on public.recurring_expenses
for each row execute function public.touch_updated_at();
