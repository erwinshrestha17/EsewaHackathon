alter table public.profiles
  add column if not exists date_of_birth date,
  add column if not exists phone_verified_at timestamptz;

alter table public.app_sessions
  add column if not exists refresh_token_hash text,
  add column if not exists previous_refresh_token_hash text,
  add column if not exists access_token_expires_at timestamptz,
  add column if not exists refresh_token_expires_at timestamptz,
  add column if not exists revocation_reason text,
  add column if not exists rotated_at timestamptz;

alter table public.app_sessions
  alter column token_hash drop not null;

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

do $$
declare
  seed_users uuid[] := array[
    '10000000-0000-4000-8000-000000000001'::uuid,
    '10000000-0000-4000-8000-000000000002'::uuid,
    '10000000-0000-4000-8000-000000000003'::uuid,
    '10000000-0000-4000-8000-000000000004'::uuid,
    '10000000-0000-4000-8000-000000000005'::uuid,
    '10000000-0000-4000-8000-000000000006'::uuid,
    '10000000-0000-4000-8000-000000000007'::uuid,
    '10000000-0000-4000-8000-000000000008'::uuid
  ];
  seed_groups uuid[] := array[
    '20000000-0000-4000-8000-000000000001'::uuid,
    '20000000-0000-4000-8000-000000000002'::uuid,
    '20000000-0000-4000-8000-000000000003'::uuid,
    '20000000-0000-4000-8000-000000000004'::uuid,
    '20000000-0000-4000-8000-000000000005'::uuid,
    '20000000-0000-4000-8000-000000000006'::uuid
  ];
  seed_savings uuid[] := array[
    '11111111-1111-4111-8111-111111111111'::uuid
  ];
begin
  delete from public.notifications where user_id = any(seed_users);
  delete from public.activity_logs
  where actor_id = any(seed_users)
     or group_id = any(seed_groups)
     or entity_id = any(seed_groups)
     or entity_id = any(seed_savings);

  delete from public.community_expenses
  where savings_group_id = any(seed_savings)
     or recorded_by = any(seed_users);
  delete from public.contribution_records
  where savings_group_id = any(seed_savings)
     or user_id = any(seed_users)
     or confirmed_by = any(seed_users);
  delete from public.community_savings_expenses where group_id = any(seed_savings);
  delete from public.community_savings_contributions where group_id = any(seed_savings);
  delete from public.community_savings_members where group_id = any(seed_savings);
  delete from public.community_savings_groups
  where id = any(seed_savings)
     or group_id = any(seed_groups)
     or created_by = any(seed_users)
     or legacy_pool_id in ('d-family-dashain', 'd-office-circle');

  delete from public.gift_pool_contributions
  where contributor_id = any(seed_users)
     or gift_pool_id in (
       select id from public.gift_pools
       where group_id = any(seed_groups)
          or created_by = any(seed_users)
          or recipient_id = any(seed_users)
     );
  delete from public.gift_pools
  where group_id = any(seed_groups)
     or created_by = any(seed_users)
     or recipient_id = any(seed_users);
  delete from public.gifts
  where sender_id = any(seed_users)
     or recipient_id = any(seed_users);

  delete from public.settlements
  where group_id = any(seed_groups)
     or payer_id = any(seed_users)
     or payee_id = any(seed_users);
  delete from public.payment_transactions where actor_id = any(seed_users);

  delete from public.expense_item_assignments
  where user_id = any(seed_users)
     or expense_item_id in (
       select expense_items.id
       from public.expense_items
       join public.expenses on expenses.id = expense_items.expense_id
       where expenses.group_id = any(seed_groups)
          or expenses.created_by = any(seed_users)
          or expenses.payer_id = any(seed_users)
     );
  delete from public.expense_items
  where expense_id in (
    select id from public.expenses
    where group_id = any(seed_groups)
       or created_by = any(seed_users)
       or payer_id = any(seed_users)
  );
  delete from public.expense_shares
  where user_id = any(seed_users)
     or expense_id in (
       select id from public.expenses
       where group_id = any(seed_groups)
          or created_by = any(seed_users)
          or payer_id = any(seed_users)
     );
  delete from public.expense_payers
  where user_id = any(seed_users)
     or expense_id in (
       select id from public.expenses
       where group_id = any(seed_groups)
          or created_by = any(seed_users)
          or payer_id = any(seed_users)
     );
  delete from public.expenses
  where group_id = any(seed_groups)
     or created_by = any(seed_users)
     or payer_id = any(seed_users);

  delete from public.group_members
  where group_id = any(seed_groups)
     or user_id = any(seed_users);
  delete from public.groups
  where id = any(seed_groups)
     or created_by = any(seed_users)
     or legacy_group_id in (
       'g-dashain',
       'g-trek',
       'g-apartment',
       'g-shrestha-family',
       'g-college-friends',
       'g-office-circle'
     );

  delete from public.connection_events
  where actor_id = any(seed_users)
     or connection_id in (
       select id from public.connections
       where requester_id = any(seed_users)
          or recipient_id = any(seed_users)
          or user_low_id = any(seed_users)
          or user_high_id = any(seed_users)
     );
  delete from public.connections
  where requester_id = any(seed_users)
     or recipient_id = any(seed_users)
     or user_low_id = any(seed_users)
     or user_high_id = any(seed_users);

  delete from public.app_sessions where user_id = any(seed_users);
  delete from public.app_user_credentials where user_id = any(seed_users);
  delete from public.user_settings where user_id = any(seed_users);
  delete from public.profiles
  where id = any(seed_users)
     or legacy_user_id in (
       'u-sita',
       'u-arjun',
       'u-maya',
       'u-nabin',
       'u-laxmi',
       'u-kabir',
       'u-rina',
       'u-pasang'
     )
     or phone in (
       '9800000001',
       '9800000002',
       '9800000003',
       '9800000004',
       '9800000005',
       '9800000006',
       '9800000007',
       '9800000008'
     );
end $$;
