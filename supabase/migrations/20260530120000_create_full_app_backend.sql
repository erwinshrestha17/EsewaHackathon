create extension if not exists pgcrypto;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key default gen_random_uuid(),
  legacy_user_id text unique,
  auth_user_id uuid unique,
  full_name text not null check (length(trim(full_name)) > 0),
  phone text unique,
  email text unique,
  avatar_url text,
  avatar_initials text,
  district text,
  privacy_mode text not null default 'everyone' check (
    privacy_mode in ('everyone', 'contacts_only', 'qr_invite_only')
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_settings (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  theme_mode text not null default 'system' check (theme_mode in ('system', 'light', 'dark')),
  language text not null default 'en',
  push_preview_enabled boolean not null default true,
  confirm_before_payment boolean not null default true,
  biometric_enabled boolean not null default false,
  notification_preferences jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.connections (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  user_low_id uuid not null references public.profiles(id) on delete cascade,
  user_high_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (
    status in ('pending', 'approved', 'declined', 'expired', 'removed')
  ),
  expires_at timestamptz not null default (now() + interval '14 days'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_low_id, user_high_id),
  check (requester_id <> recipient_id)
);

create table if not exists public.connection_events (
  id uuid primary key default gen_random_uuid(),
  connection_id uuid not null references public.connections(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  event_type text not null,
  previous_status text,
  next_status text,
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  legacy_group_id text unique,
  name text not null check (length(trim(name)) > 0),
  description text,
  category text not null default 'custom',
  template text,
  kind text not null default 'expense' check (kind in ('expense', 'dhukuti')),
  created_by uuid not null references public.profiles(id),
  is_active boolean not null default true,
  latest_settlement_lock_at timestamptz,
  disbanded_at timestamptz,
  disbanded_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.group_members (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('admin', 'member', 'treasurer')),
  status text not null default 'active' check (status in ('active', 'invited', 'removed')),
  joined_at timestamptz not null default now(),
  removed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (group_id, user_id)
);

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  subtotal_minor integer not null check (subtotal_minor >= 0),
  total_minor integer not null check (total_minor > 0),
  payer_id uuid not null references public.profiles(id),
  category text not null default 'custom',
  split_mode text not null check (split_mode in ('equal', 'custom', 'item')),
  status text not null default 'active' check (status in ('draft', 'active', 'voided')),
  expense_date date not null default current_date,
  note text not null default '',
  receipt_url text,
  bill_tax_minor integer not null default 0,
  bill_service_charge_minor integer not null default 0,
  bill_discount_minor integer not null default 0,
  bill_tip_minor integer not null default 0,
  bill_rounding_adjustment_minor integer not null default 0,
  locked_at timestamptz,
  voided_at timestamptz,
  voided_by uuid references public.profiles(id),
  void_reason text,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.expense_payers (
  id uuid primary key default gen_random_uuid(),
  expense_id uuid not null references public.expenses(id) on delete cascade,
  user_id uuid not null references public.profiles(id),
  amount_minor integer not null check (amount_minor > 0),
  unique (expense_id, user_id)
);

create table if not exists public.expense_shares (
  id uuid primary key default gen_random_uuid(),
  expense_id uuid not null references public.expenses(id) on delete cascade,
  user_id uuid not null references public.profiles(id),
  amount_minor integer not null check (amount_minor >= 0),
  percentage numeric,
  share_units integer,
  source_type text not null default 'manual',
  source_id uuid,
  unique (expense_id, user_id)
);

create table if not exists public.expense_items (
  id uuid primary key default gen_random_uuid(),
  expense_id uuid not null references public.expenses(id) on delete cascade,
  label text not null,
  quantity numeric not null default 1,
  unit_amount_minor integer not null check (unit_amount_minor >= 0),
  total_amount_minor integer not null check (total_amount_minor >= 0),
  tax_minor integer not null default 0,
  service_charge_minor integer not null default 0,
  discount_minor integer not null default 0,
  ocr_confidence numeric not null default 1,
  sort_order integer not null default 0
);

create table if not exists public.expense_item_assignments (
  id uuid primary key default gen_random_uuid(),
  expense_item_id uuid not null references public.expense_items(id) on delete cascade,
  user_id uuid not null references public.profiles(id),
  assigned_amount_minor integer not null check (assigned_amount_minor >= 0),
  split_units integer not null default 1,
  unique (expense_item_id, user_id)
);

create table if not exists public.payment_transactions (
  id uuid primary key default gen_random_uuid(),
  payment_provider text not null default 'prototype',
  payment_reference text not null,
  operation_type text not null,
  entity_type text not null,
  entity_id uuid,
  actor_id uuid references public.profiles(id),
  amount_minor integer not null check (amount_minor > 0),
  status text not null check (
    status in ('pending', 'paid', 'failed', 'failed_review', 'expired', 'cancelled', 'refunded')
  ),
  raw_payload jsonb not null default '{}'::jsonb,
  confirmed_at timestamptz,
  failed_at timestamptz,
  expired_at timestamptz,
  cancelled_at timestamptz,
  refunded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (payment_provider, payment_reference)
);

create table if not exists public.settlements (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  payer_id uuid not null references public.profiles(id),
  payee_id uuid not null references public.profiles(id),
  amount_minor integer not null check (amount_minor > 0),
  status text not null default 'pending' check (
    status in ('pending', 'paid', 'failed', 'failed_review', 'expired', 'cancelled', 'refunded')
  ),
  payment_transaction_id uuid references public.payment_transactions(id),
  idempotency_key text not null unique,
  idempotency_scope text not null,
  operation_type text not null default 'external_settlement',
  failure_reason text,
  expires_at timestamptz not null,
  balance_snapshot_hash text not null,
  paid_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.gifts (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id),
  recipient_id uuid not null references public.profiles(id),
  group_id uuid references public.groups(id) on delete set null,
  template text not null,
  amount_minor integer not null check (amount_minor > 0),
  message text not null default '',
  status text not null default 'sent' check (
    status in ('pending', 'sent', 'opened', 'failed', 'failed_review', 'expired', 'cancelled', 'refunded')
  ),
  payment_transaction_id uuid references public.payment_transactions(id),
  idempotency_key text not null,
  idempotency_scope text not null,
  operation_type text not null default 'gift',
  opened_at timestamptz,
  refunded_at timestamptz,
  created_at timestamptz not null default now(),
  unique (idempotency_scope, idempotency_key)
);

create table if not exists public.gift_pools (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  created_by uuid not null references public.profiles(id),
  recipient_id uuid not null references public.profiles(id),
  title text not null,
  template text not null,
  target_amount_minor integer not null check (target_amount_minor > 0),
  contribution_rule text not null check (contribution_rule in ('equal', 'threshold')),
  allow_over_target boolean not null default false,
  equal_contribution_amount_minor integer,
  min_contribution_amount_minor integer,
  max_contribution_amount_minor integer,
  message text not null default '',
  status text not null default 'open' check (status in ('open', 'completed', 'cancelled', 'refunded')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.gift_pool_contributions (
  id uuid primary key default gen_random_uuid(),
  gift_pool_id uuid not null references public.gift_pools(id) on delete cascade,
  contributor_id uuid not null references public.profiles(id),
  amount_minor integer not null check (amount_minor > 0),
  status text not null default 'paid',
  payment_transaction_id uuid references public.payment_transactions(id),
  idempotency_key text not null,
  idempotency_scope text not null,
  operation_type text not null default 'gift_pool_contribution',
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  unique (idempotency_scope, idempotency_key)
);

create table if not exists public.community_savings_groups (
  id uuid primary key default gen_random_uuid(),
  legacy_pool_id text unique,
  group_id uuid references public.groups(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  monthly_contribution_amount integer not null check (monthly_contribution_amount > 0),
  currency text not null default 'Rs.',
  current_month date not null default date_trunc('month', now())::date,
  created_by uuid references public.profiles(id),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.community_savings_groups
  add column if not exists group_id uuid references public.groups(id) on delete cascade,
  add column if not exists created_by uuid references public.profiles(id),
  add column if not exists is_active boolean not null default true;

create table if not exists public.contribution_records (
  id uuid primary key default gen_random_uuid(),
  savings_group_id uuid not null references public.community_savings_groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  month date not null,
  expected_amount integer not null check (expected_amount >= 0),
  submitted_amount integer,
  received_amount integer,
  status text not null default 'pending' check (
    status in ('pending', 'submitted', 'confirmed', 'waived')
  ),
  payment_method text check (
    payment_method is null or payment_method in ('cash', 'bank_transfer', 'esewa', 'khalti', 'ime_pay', 'other')
  ),
  submitted_note text,
  admin_note text,
  reference_number text,
  submitted_at timestamptz,
  confirmed_by uuid references public.profiles(id),
  confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (savings_group_id, user_id, month),
  constraint submitted_contributions_do_not_affect_balance check (
    status <> 'submitted' or coalesce(received_amount, 0) = 0
  ),
  constraint waived_contributions_are_zero check (
    status <> 'waived' or (coalesce(submitted_amount, 0) = 0 and coalesce(received_amount, 0) = 0)
  ),
  constraint confirmed_contributions_have_received_amount check (
    status <> 'confirmed' or coalesce(received_amount, 0) > 0
  )
);

create table if not exists public.community_expenses (
  id uuid primary key default gen_random_uuid(),
  savings_group_id uuid not null references public.community_savings_groups(id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  amount integer not null check (amount > 0),
  category text not null check (
    category in ('food', 'event', 'emergency', 'maintenance', 'donation', 'travel', 'supplies', 'other')
  ),
  expense_date date not null default current_date,
  description text,
  recorded_by uuid references public.profiles(id),
  receipt_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.activity_logs (
  id uuid primary key default gen_random_uuid(),
  group_id uuid references public.groups(id) on delete set null,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  title text,
  body text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text not null,
  type text not null,
  metadata jsonb not null default '{}'::jsonb,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

do $$
declare
  t text;
begin
  foreach t in array array[
    'profiles', 'user_settings', 'connections', 'connection_events', 'groups',
    'group_members', 'expenses', 'expense_payers', 'expense_shares',
    'expense_items', 'expense_item_assignments', 'payment_transactions',
    'settlements', 'gifts', 'gift_pools', 'gift_pool_contributions',
    'community_savings_groups', 'contribution_records', 'community_expenses',
    'activity_logs', 'notifications'
  ] loop
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

do $$
declare
  t text;
begin
  foreach t in array array[
    'profiles', 'user_settings', 'connections', 'groups', 'group_members',
    'expenses', 'payment_transactions', 'gift_pools',
    'community_savings_groups', 'contribution_records', 'community_expenses'
  ] loop
    execute format('drop trigger if exists %I on public.%I', 'touch_' || t || '_updated_at', t);
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.touch_updated_at()',
      'touch_' || t || '_updated_at',
      t
    );
  end loop;
end $$;
