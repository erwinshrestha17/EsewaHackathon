insert into public.profiles (
  id, legacy_user_id, full_name, phone, avatar_initials, district, privacy_mode
) values
  ('10000000-0000-4000-8000-000000000001', 'u-sita', 'Sita Shrestha', '9800000001', 'SS', 'Kathmandu', 'everyone'),
  ('10000000-0000-4000-8000-000000000002', 'u-arjun', 'Arjun Karki', '9800000002', 'AK', 'Lalitpur', 'everyone'),
  ('10000000-0000-4000-8000-000000000003', 'u-maya', 'Maya Gurung', '9800000003', 'MG', 'Pokhara', 'everyone'),
  ('10000000-0000-4000-8000-000000000004', 'u-nabin', 'Nabin Rai', '9800000004', 'NR', 'Dharan', 'everyone'),
  ('10000000-0000-4000-8000-000000000005', 'u-laxmi', 'Laxmi Thapa', '9800000005', 'LT', 'Bhaktapur', 'everyone'),
  ('10000000-0000-4000-8000-000000000006', 'u-kabir', 'Kabir Lama', '9800000006', 'KL', 'Chitwan', 'qr_invite_only'),
  ('10000000-0000-4000-8000-000000000007', 'u-rina', 'Rina Basnet', '9800000007', 'RB', 'Butwal', 'everyone'),
  ('10000000-0000-4000-8000-000000000008', 'u-pasang', 'Pasang Sherpa', '9800000008', 'PS', 'Solukhumbu', 'everyone')
on conflict (id) do update set
  full_name = excluded.full_name,
  phone = excluded.phone,
  avatar_initials = excluded.avatar_initials,
  district = excluded.district,
  privacy_mode = excluded.privacy_mode;

insert into public.user_settings (user_id, theme_mode, language, confirm_before_payment)
select id, 'system', 'en', true from public.profiles
on conflict (user_id) do nothing;

insert into public.app_user_credentials (user_id, mpin_hash)
values (
  '10000000-0000-4000-8000-000000000001',
  'pbkdf2_sha256$120000$sajha-seed-sita$jlbmOKhKI45uyas4z0Mw_HqJ7-w4LKLvWrgm03Ww8-4'
)
on conflict (user_id) do update set
  mpin_hash = excluded.mpin_hash,
  failed_attempts = 0,
  locked_until = null;

insert into public.connections (
  id, requester_id, recipient_id, user_low_id, user_high_id, status, created_at, updated_at, expires_at
) values
  ('12000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002', 'approved', '2026-05-04T00:00:00Z', '2026-05-04T00:00:00Z', '2026-06-04T00:00:00Z'),
  ('12000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000003', 'approved', '2026-05-04T00:00:00Z', '2026-05-04T00:00:00Z', '2026-06-04T00:00:00Z'),
  ('12000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000004', '10000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000004', 'approved', '2026-05-04T00:00:00Z', '2026-05-04T00:00:00Z', '2026-06-04T00:00:00Z'),
  ('12000000-0000-4000-8000-000000000004', '10000000-0000-4000-8000-000000000006', '10000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000006', 'pending', '2026-05-27T00:00:00Z', '2026-05-27T00:00:00Z', '2026-06-10T00:00:00Z')
on conflict (id) do update set status = excluded.status, updated_at = excluded.updated_at;

insert into public.groups (
  id, legacy_group_id, name, description, category, template, kind, created_by, created_at
) values
  ('20000000-0000-4000-8000-000000000001', 'g-dashain', 'Dashain Khasi Split', 'Festival expense split for family and friends.', 'festival', 'Dashain Khasi Split', 'expense', '10000000-0000-4000-8000-000000000001', '2026-05-10T00:00:00Z'),
  ('20000000-0000-4000-8000-000000000002', 'g-trek', 'Mardi Trek Crew', 'Travel costs for the Mardi trek.', 'trek', 'New Year Trek', 'expense', '10000000-0000-4000-8000-000000000003', '2026-05-12T00:00:00Z'),
  ('20000000-0000-4000-8000-000000000003', 'g-apartment', 'Kupondole Apartment', 'Monthly utilities and household expenses.', 'apartment', 'Apartment Monthly', 'expense', '10000000-0000-4000-8000-000000000002', '2026-05-13T00:00:00Z'),
  ('20000000-0000-4000-8000-000000000004', 'g-shrestha-family', 'Shrestha Family', 'Community savings tracker for family contributions.', 'festival', 'Family Community Fund', 'dhukuti', '10000000-0000-4000-8000-000000000001', '2026-05-14T00:00:00Z'),
  ('20000000-0000-4000-8000-000000000005', 'g-college-friends', 'College Friends', 'Shared college friend expenses.', 'custom', 'Friends Circle', 'expense', '10000000-0000-4000-8000-000000000003', '2026-05-15T00:00:00Z'),
  ('20000000-0000-4000-8000-000000000006', 'g-office-circle', 'Office Savings Circle', 'Office community tracker.', 'custom', 'Work Circle', 'dhukuti', '10000000-0000-4000-8000-000000000002', '2026-05-16T00:00:00Z')
on conflict (id) do update set
  name = excluded.name,
  description = excluded.description,
  category = excluded.category,
  template = excluded.template,
  kind = excluded.kind,
  is_active = true;

insert into public.group_members (id, group_id, user_id, role, status, joined_at) values
  ('21000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'admin', 'active', '2026-05-10T00:00:00Z'),
  ('21000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002', 'member', 'active', '2026-05-10T00:00:00Z'),
  ('21000000-0000-4000-8000-000000000003', '20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000003', 'member', 'active', '2026-05-10T00:00:00Z'),
  ('21000000-0000-4000-8000-000000000004', '20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000004', 'member', 'active', '2026-05-10T00:00:00Z'),
  ('21000000-0000-4000-8000-000000000005', '20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000005', 'member', 'active', '2026-05-10T00:00:00Z'),
  ('21000000-0000-4000-8000-000000000006', '20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000007', 'member', 'active', '2026-05-10T00:00:00Z'),
  ('21000000-0000-4000-8000-000000000007', '20000000-0000-4000-8000-000000000004', '10000000-0000-4000-8000-000000000001', 'admin', 'active', '2026-05-14T00:00:00Z'),
  ('21000000-0000-4000-8000-000000000008', '20000000-0000-4000-8000-000000000004', '10000000-0000-4000-8000-000000000002', 'member', 'active', '2026-05-14T00:00:00Z'),
  ('21000000-0000-4000-8000-000000000009', '20000000-0000-4000-8000-000000000004', '10000000-0000-4000-8000-000000000003', 'member', 'active', '2026-05-14T00:00:00Z'),
  ('21000000-0000-4000-8000-000000000010', '20000000-0000-4000-8000-000000000004', '10000000-0000-4000-8000-000000000004', 'member', 'active', '2026-05-14T00:00:00Z')
on conflict (id) do update set role = excluded.role, status = excluded.status;

insert into public.expenses (
  id, group_id, title, subtotal_minor, total_minor, payer_id, category, split_mode, status, expense_date, note, created_by, created_at
) values
  ('30000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 'Khasi purchase', 600000, 600000, '10000000-0000-4000-8000-000000000001', 'festival', 'equal', 'active', '2026-05-18', 'Main Dashain khasi bill.', '10000000-0000-4000-8000-000000000001', '2026-05-18T10:00:00Z'),
  ('30000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000003', 'May utilities', 540000, 540000, '10000000-0000-4000-8000-000000000005', 'household', 'custom', 'active', '2026-05-20', '', '10000000-0000-4000-8000-000000000002', '2026-05-20T10:00:00Z')
on conflict (id) do update set title = excluded.title, total_minor = excluded.total_minor;

insert into public.expense_payers (expense_id, user_id, amount_minor) values
  ('30000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 600000),
  ('30000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000005', 540000)
on conflict (expense_id, user_id) do update set amount_minor = excluded.amount_minor;

insert into public.expense_shares (expense_id, user_id, amount_minor, source_type) values
  ('30000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 100000, 'equal'),
  ('30000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002', 100000, 'equal'),
  ('30000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000003', 100000, 'equal'),
  ('30000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000004', 100000, 'equal'),
  ('30000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000005', 100000, 'equal'),
  ('30000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000007', 100000, 'equal'),
  ('30000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000001', 162000, 'custom'),
  ('30000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002', 189000, 'custom'),
  ('30000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000005', 189000, 'custom')
on conflict (expense_id, user_id) do update set amount_minor = excluded.amount_minor;

insert into public.settlements (
  id, group_id, payer_id, payee_id, amount_minor, status, idempotency_key, idempotency_scope, operation_type, expires_at, balance_snapshot_hash, paid_at, created_at
) values (
  '32000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000001',
  100000,
  'paid',
  'seed-dashain-nabin-sita',
  '20000000-0000-4000-8000-000000000001',
  'external_settlement',
  '2026-06-01T00:00:00Z',
  'seed',
  '2026-05-21T10:00:00Z',
  '2026-05-21T09:00:00Z'
) on conflict (id) do update set status = excluded.status, paid_at = excluded.paid_at;

insert into public.gifts (
  id, sender_id, recipient_id, template, amount_minor, message, status, idempotency_key, idempotency_scope, operation_type, created_at
) values (
  '33000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000003',
  'Dashain',
  100000,
  'Happy Dashain, Maya!',
  'sent',
  'seed-gift-sita-maya',
  '10000000-0000-4000-8000-000000000001',
  'gift',
  '2026-05-22T10:00:00Z'
) on conflict (id) do update set status = excluded.status;

insert into public.gift_pools (
  id, group_id, created_by, recipient_id, title, template, target_amount_minor, contribution_rule, allow_over_target, min_contribution_amount_minor, max_contribution_amount_minor, message, status, created_at
) values (
  '34000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000005',
  'Tihar Gift Pool',
  'Tihar',
  500000,
  'threshold',
  false,
  25000,
  110000,
  'A group envelope for Laxmi.',
  'open',
  '2026-05-23T10:00:00Z'
) on conflict (id) do update set title = excluded.title, status = excluded.status;

insert into public.community_savings_groups (
  id, legacy_pool_id, group_id, name, monthly_contribution_amount, currency, current_month, created_by, is_active
) values (
  '11111111-1111-4111-8111-111111111111',
  'd-family-dashain',
  '20000000-0000-4000-8000-000000000004',
  'Family Dashain Community Fund',
  500000,
  'Rs.',
  '2026-05-01',
  '10000000-0000-4000-8000-000000000001',
  true
) on conflict (id) do update set
  legacy_pool_id = excluded.legacy_pool_id,
  group_id = excluded.group_id,
  name = excluded.name,
  monthly_contribution_amount = excluded.monthly_contribution_amount,
  currency = excluded.currency,
  current_month = excluded.current_month,
  created_by = excluded.created_by,
  is_active = true;

insert into public.contribution_records (
  id, savings_group_id, user_id, month, expected_amount, submitted_amount, received_amount, status, payment_method, submitted_note, admin_note, reference_number, submitted_at, confirmed_by, confirmed_at
) values
  ('31111111-1111-4111-8111-111111111111', '11111111-1111-4111-8111-111111111111', '10000000-0000-4000-8000-000000000001', '2026-05-01', 500000, 500000, 500000, 'confirmed', 'cash', 'Received during family meeting.', null, 'CASH-0505', '2026-05-05T08:00:00Z', '10000000-0000-4000-8000-000000000001', '2026-05-05T10:00:00Z'),
  ('31111111-1111-4111-8111-111111111112', '11111111-1111-4111-8111-111111111111', '10000000-0000-4000-8000-000000000002', '2026-05-01', 500000, 500000, 0, 'submitted', 'esewa', 'Paid outside the app, waiting for admin confirmation.', null, 'ESW-9812', '2026-05-08T09:30:00Z', null, null),
  ('31111111-1111-4111-8111-111111111113', '11111111-1111-4111-8111-111111111111', '10000000-0000-4000-8000-000000000003', '2026-05-01', 500000, 0, 0, 'waived', null, null, null, null, null, null, null),
  ('31111111-1111-4111-8111-111111111114', '11111111-1111-4111-8111-111111111111', '10000000-0000-4000-8000-000000000004', '2026-05-01', 500000, 0, 0, 'pending', null, null, null, null, null, null, null)
on conflict (id) do update set
  expected_amount = excluded.expected_amount,
  submitted_amount = excluded.submitted_amount,
  received_amount = excluded.received_amount,
  status = excluded.status,
  payment_method = excluded.payment_method,
  submitted_note = excluded.submitted_note,
  admin_note = excluded.admin_note,
  reference_number = excluded.reference_number,
  submitted_at = excluded.submitted_at,
  confirmed_by = excluded.confirmed_by,
  confirmed_at = excluded.confirmed_at;

insert into public.community_expenses (
  id, savings_group_id, title, amount, category, expense_date, description, recorded_by, receipt_reference
) values (
  '41111111-1111-4111-8111-111111111111',
  '11111111-1111-4111-8111-111111111111',
  'Meeting snacks',
  120000,
  'food',
  '2026-05-12',
  'Snacks for monthly community fund meeting.',
  '10000000-0000-4000-8000-000000000001',
  'SNK-204'
) on conflict (id) do update set
  title = excluded.title,
  amount = excluded.amount,
  category = excluded.category,
  expense_date = excluded.expense_date,
  description = excluded.description,
  recorded_by = excluded.recorded_by,
  receipt_reference = excluded.receipt_reference;

insert into public.notifications (id, user_id, title, body, type, metadata, is_read, created_at) values
  ('50000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'Prototype mode', 'Payments are tracked as mock/prototype records until real payment integration is added.', 'prototype_notice', '{}'::jsonb, false, '2026-05-24T10:00:00Z'),
  ('50000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002', 'Contribution submitted', 'Your Family Dashain Community Fund contribution is waiting for confirmation.', 'contribution_submitted', '{"savingsGroupId":"11111111-1111-4111-8111-111111111111"}'::jsonb, false, '2026-05-08T09:30:00Z')
on conflict (id) do update set title = excluded.title, body = excluded.body, is_read = excluded.is_read;

insert into public.activity_logs (
  id, group_id, actor_id, action, entity_type, entity_id, title, body, metadata, created_at
) values
  ('51000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'expense_created', 'expense', '30000000-0000-4000-8000-000000000001', 'Expense added', 'Khasi purchase was added to Dashain Khasi Split.', '{}'::jsonb, '2026-05-18T10:00:00Z'),
  ('51000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000004', '10000000-0000-4000-8000-000000000001', 'community_expense_recorded', 'community_expense', '41111111-1111-4111-8111-111111111111', 'Expense recorded', 'Meeting snacks was recorded for community savings.', '{}'::jsonb, '2026-05-12T10:00:00Z')
on conflict (id) do update set title = excluded.title, body = excluded.body;
