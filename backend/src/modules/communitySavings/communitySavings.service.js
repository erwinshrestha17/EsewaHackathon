import { assertChoice, parseMoneyMinor, requireFields } from '../../middleware/validate.middleware.js';
import { ApiError } from '../../utils/ApiError.js';
import { createNotification, logActivity } from '../common/audit.js';
import { db, assertDb, findByIdOrLegacy } from '../common/db.js';
import { groupDto } from '../common/mappers.js';

const paymentMethods = ['cash', 'bank_transfer', 'esewa', 'khalti', 'ime_pay', 'other'];
const expenseCategories = ['food', 'event', 'emergency', 'maintenance', 'donation', 'travel', 'supplies', 'other'];
const contributionStatuses = ['pending', 'submitted', 'confirmed', 'waived'];

function normalizeMonth(value) {
  const now = new Date();
  const input = value ?? `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}`;
  if (/^\d{4}-\d{2}$/.test(input)) return `${input}-01`;
  if (/^\d{4}-\d{2}-\d{2}$/.test(input)) return `${input.slice(0, 7)}-01`;
  throw new ApiError(400, 'Month must use YYYY-MM or YYYY-MM-DD format.');
}

function nextMonth(monthDate) {
  const date = new Date(`${monthDate}T00:00:00.000Z`);
  date.setUTCMonth(date.getUTCMonth() + 1);
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}-01`;
}

function displayPaymentMethod(value) {
  return {
    cash: 'Cash',
    bank_transfer: 'Bank Transfer',
    esewa: 'eSewa',
    khalti: 'Khalti',
    ime_pay: 'IME Pay',
    other: 'Other',
  }[value] ?? value;
}

function normalizePaymentMethod(value) {
  const normalized = value?.toString().trim().toLowerCase().replace(/\s+/g, '_');
  const mapped = normalized === 'bank_transfer' ? normalized : normalized?.replace('e_sewa', 'esewa');
  assertChoice(mapped, paymentMethods, 'paymentMethod');
  return mapped;
}

function groupMap(row, summary) {
  return {
    id: row.id,
    legacyPoolId: row.legacy_pool_id,
    groupId: row.group_id,
    name: row.name,
    monthlyContributionAmount: row.monthly_contribution_amount,
    currency: row.currency,
    currentMonth: row.current_month,
    createdAt: row.created_at,
    summary,
  };
}

function contributionMap(row) {
  return {
    id: row.id,
    groupId: row.savings_group_id,
    memberId: row.user_id,
    memberName: row.profiles?.full_name ?? row.member_name,
    month: row.month,
    expectedAmount: row.expected_amount,
    submittedAmount: row.submitted_amount ?? 0,
    receivedAmount: row.received_amount ?? 0,
    status: row.status === 'confirmed' ? 'confirmed_received' : row.status,
    paymentMethod: displayPaymentMethod(row.payment_method),
    submittedAt: row.submitted_at,
    confirmedAt: row.confirmed_at,
    confirmedBy: row.confirmed_by,
    note: row.submitted_note ?? row.admin_note ?? '',
    referenceNumber: row.reference_number ?? '',
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function expenseMap(row) {
  return {
    id: row.id,
    groupId: row.savings_group_id,
    title: row.title,
    amount: row.amount,
    category: row.category ? row.category[0].toUpperCase() + row.category.slice(1) : 'Other',
    expenseDate: row.expense_date,
    description: row.description ?? '',
    recordedBy: row.profiles?.full_name ?? row.recorded_by,
    receiptReference: row.receipt_reference ?? '',
    createdAt: row.created_at,
  };
}

export async function resolveSavingsGroup(id) {
  const row = await findByIdOrLegacy('community_savings_groups', id, 'legacy_pool_id');
  if (!row || !row.is_active) {
    throw new ApiError(404, 'Community savings group not found.');
  }
  return row;
}

async function listMembers(savingsGroup) {
  const { data, error } = await db()
    .from('group_members')
    .select('*, profiles(*)')
    .eq('group_id', savingsGroup.group_id)
    .eq('status', 'active')
    .order('joined_at', { ascending: true });
  assertDb(error);
  return data.map((row) => ({
    id: row.user_id,
    userId: row.user_id,
    name: row.profiles?.full_name ?? 'Member',
    role: row.role,
    avatarInitials: row.profiles?.avatar_initials ?? '?',
    createdAt: row.joined_at,
  }));
}

async function listContributions(savingsGroupId, month) {
  let query = db()
    .from('contribution_records')
    .select('*, profiles:user_id(*)')
    .eq('savings_group_id', savingsGroupId)
    .order('created_at', { ascending: true });
  if (month) query = query.eq('month', month);
  const { data, error } = await query;
  assertDb(error);
  return data.map(contributionMap);
}

async function listExpenses(savingsGroupId, month) {
  let query = db()
    .from('community_expenses')
    .select('*, profiles:recorded_by(*)')
    .eq('savings_group_id', savingsGroupId)
    .order('expense_date', { ascending: false });
  if (month) query = query.gte('expense_date', month).lt('expense_date', nextMonth(month));
  const { data, error } = await query;
  assertDb(error);
  return data.map(expenseMap);
}

function summary(allContributions, monthContributions, monthExpenses, allExpenses) {
  const confirmed = allContributions.filter((item) => item.status === 'confirmed_received');
  const totalConfirmedContributions = confirmed.reduce((sum, item) => sum + item.receivedAmount, 0);
  const totalRecordedExpenses = allExpenses.reduce((sum, item) => sum + item.amount, 0);
  return {
    fundBalance: totalConfirmedContributions - totalRecordedExpenses,
    receivedThisMonth: monthContributions
      .filter((item) => item.status === 'confirmed_received')
      .reduce((sum, item) => sum + item.receivedAmount, 0),
    pendingContributions: monthContributions.filter((item) =>
      ['pending', 'submitted'].includes(item.status),
    ).length,
    expensesThisMonth: monthExpenses.reduce((sum, item) => sum + item.amount, 0),
    totalExpectedThisMonth: monthContributions.reduce((sum, item) => sum + item.expectedAmount, 0),
  };
}

export async function createSavingsGroup(group, userId, body) {
  requireFields(body, ['name', 'monthlyContributionAmount']);
  const { data, error } = await db()
    .from('community_savings_groups')
    .insert({
      group_id: group.id,
      legacy_pool_id: body.legacyPoolId ?? null,
      name: body.name.trim(),
      monthly_contribution_amount: parseMoneyMinor(
        body.monthlyContributionAmount,
        'monthlyContributionAmount',
      ),
      currency: body.currency ?? 'Rs.',
      current_month: normalizeMonth(body.currentMonth),
      created_by: userId,
    })
    .select()
    .single();
  assertDb(error);
  await logActivity({
    groupId: group.id,
    actorId: userId,
    action: 'community_savings_created',
    entityType: 'community_savings_group',
    entityId: data.id,
    title: 'Community savings tracker created',
    body: `${data.name} was created.`,
  });
  return groupMap(data);
}

export async function getDashboard(savingsGroupId, rawMonth) {
  const savingsGroup = await resolveSavingsGroup(savingsGroupId);
  const month = normalizeMonth(rawMonth ?? savingsGroup.current_month);
  const [members, monthContributions, monthExpenses, allContributions, allExpenses] =
    await Promise.all([
      listMembers(savingsGroup),
      listContributions(savingsGroup.id, month),
      listExpenses(savingsGroup.id, month),
      listContributions(savingsGroup.id),
      listExpenses(savingsGroup.id),
    ]);
  return {
    group: groupMap(savingsGroup),
    month,
    members,
    contributions: monthContributions,
    expenses: monthExpenses,
    summary: summary(allContributions, monthContributions, monthExpenses, allExpenses),
    notice:
      'Payments are made outside the app. The fund balance updates only after an admin confirms money was received.',
  };
}

export async function updateSavingsGroup(savingsGroup, body) {
  const payload = {};
  if (body.name !== undefined) payload.name = body.name.trim();
  if (body.monthlyContributionAmount !== undefined) {
    payload.monthly_contribution_amount = parseMoneyMinor(
      body.monthlyContributionAmount,
      'monthlyContributionAmount',
    );
  }
  if (body.currentMonth !== undefined) payload.current_month = normalizeMonth(body.currentMonth);
  const { data, error } = await db()
    .from('community_savings_groups')
    .update(payload)
    .eq('id', savingsGroup.id)
    .select()
    .single();
  assertDb(error);
  return groupMap(data);
}

export async function getContributions(savingsGroup, rawMonth) {
  const month = normalizeMonth(rawMonth ?? savingsGroup.current_month);
  return {
    group: groupMap(savingsGroup),
    month,
    contributions: await listContributions(savingsGroup.id, month),
  };
}

export async function submitContribution(savingsGroup, userId, body, contributionId = null) {
  const month = normalizeMonth(body.month ?? savingsGroup.current_month);
  const amountPaid = parseMoneyMinor(body.amountPaid ?? body.submittedAmount, 'amountPaid');
  const paymentMethod = normalizePaymentMethod(body.paymentMethod);
  const payload = {
    savings_group_id: savingsGroup.id,
    user_id: body.userId ?? userId,
    month,
    expected_amount: savingsGroup.monthly_contribution_amount,
    submitted_amount: amountPaid,
    received_amount: null,
    status: 'submitted',
    payment_method: paymentMethod,
    submitted_note: body.note?.trim() || null,
    reference_number: body.referenceNumber?.trim() || null,
    submitted_at: new Date().toISOString(),
  };
  const query = contributionId
    ? db()
        .from('contribution_records')
        .update(payload)
        .eq('savings_group_id', savingsGroup.id)
        .eq('id', contributionId)
    : db()
        .from('contribution_records')
        .upsert(payload, { onConflict: 'savings_group_id,user_id,month' });
  const { data, error } = await query.select('*, profiles:user_id(*)').single();
  assertDb(error);
  await logActivity({
    groupId: savingsGroup.group_id,
    actorId: userId,
    action: 'contribution_submitted',
    entityType: 'contribution_record',
    entityId: data.id,
    title: 'Contribution submitted',
    body: 'A contribution note was submitted for admin confirmation.',
  });
  return contributionMap(data);
}

export async function confirmContribution(savingsGroup, actorId, contributionId, body) {
  const amount = parseMoneyMinor(body.amountReceived ?? body.receivedAmount, 'amountReceived');
  const payload = {
    received_amount: amount,
    submitted_amount: body.submittedAmount ?? amount,
    status: 'confirmed',
    payment_method: normalizePaymentMethod(body.paymentMethod),
    admin_note: body.note?.trim() || null,
    reference_number: body.referenceNumber?.trim() || null,
    confirmed_by: actorId,
    confirmed_at: body.dateReceived ?? new Date().toISOString(),
  };
  const { data, error } = await db()
    .from('contribution_records')
    .update(payload)
    .eq('savings_group_id', savingsGroup.id)
    .eq('id', contributionId)
    .select('*, profiles:user_id(*)')
    .single();
  assertDb(error);
  await createNotification({
    userId: data.user_id,
    title: 'Contribution confirmed',
    body: 'Your community savings contribution was confirmed.',
    type: 'contribution_confirmed',
    metadata: { contributionId: data.id, savingsGroupId: savingsGroup.id },
  });
  await logActivity({
    groupId: savingsGroup.group_id,
    actorId,
    action: 'contribution_confirmed',
    entityType: 'contribution_record',
    entityId: data.id,
    title: 'Contribution confirmed',
    body: 'A community savings contribution was confirmed.',
  });
  return contributionMap(data);
}

export async function waiveContribution(savingsGroup, actorId, contributionId, body = {}) {
  const { data, error } = await db()
    .from('contribution_records')
    .update({
      status: 'waived',
      submitted_amount: 0,
      received_amount: 0,
      admin_note: body.note?.trim() || null,
      confirmed_by: actorId,
      confirmed_at: null,
    })
    .eq('savings_group_id', savingsGroup.id)
    .eq('id', contributionId)
    .select('*, profiles:user_id(*)')
    .single();
  assertDb(error);
  await logActivity({
    groupId: savingsGroup.group_id,
    actorId,
    action: 'contribution_waived',
    entityType: 'contribution_record',
    entityId: data.id,
    title: 'Contribution waived',
    body: 'A community savings contribution was waived.',
  });
  return contributionMap(data);
}

export async function recordExpense(savingsGroup, actorId, body) {
  requireFields(body, ['title', 'amountSpent']);
  const category = body.category?.toString().trim().toLowerCase() ?? 'other';
  assertChoice(category, expenseCategories, 'category');
  const { data, error } = await db()
    .from('community_expenses')
    .insert({
      savings_group_id: savingsGroup.id,
      title: body.title.trim(),
      amount: parseMoneyMinor(body.amountSpent, 'amountSpent'),
      category,
      expense_date: body.expenseDate ?? new Date().toISOString().slice(0, 10),
      description: body.description?.trim() || null,
      recorded_by: actorId,
      receipt_reference: body.receiptReference?.trim() || null,
    })
    .select('*, profiles:recorded_by(*)')
    .single();
  assertDb(error);
  await logActivity({
    groupId: savingsGroup.group_id,
    actorId,
    action: 'community_expense_recorded',
    entityType: 'community_expense',
    entityId: data.id,
    title: 'Expense recorded',
    body: `${data.title} was recorded for community savings.`,
  });
  return expenseMap(data);
}

export async function getHistory(savingsGroup, filter = 'all') {
  const [contributions, expenses] = await Promise.all([
    listContributions(savingsGroup.id),
    listExpenses(savingsGroup.id),
  ]);
  const contributionItems = contributions
    .filter((item) => item.status === 'confirmed_received')
    .map((item) => ({
      id: item.id,
      type: 'contribution',
      title: item.memberName,
      amount: item.receivedAmount,
      paymentMethod: item.paymentMethod,
      month: item.month,
      confirmedAt: item.confirmedAt,
      confirmedBy: item.confirmedBy,
      createdAt: item.confirmedAt,
    }));
  const expenseItems = expenses.map((item) => ({
    id: item.id,
    type: 'expense',
    title: item.title,
    amount: item.amount,
    category: item.category,
    expenseDate: item.expenseDate,
    recordedBy: item.recordedBy,
    createdAt: item.expenseDate,
  }));
  const items = [
    ...(filter === 'expenses' ? [] : contributionItems),
    ...(filter === 'contributions' ? [] : expenseItems),
  ].sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
  return { group: groupMap(savingsGroup), filter, items };
}

export async function getBalance(savingsGroup) {
  const [contributions, expenses] = await Promise.all([
    listContributions(savingsGroup.id),
    listExpenses(savingsGroup.id),
  ]);
  return {
    group: groupMap(savingsGroup),
    balance: summary(contributions, [], [], expenses).fundBalance,
  };
}

export async function listSavingsGroupsForCurrentUser(userId) {
  const { data, error } = await db()
    .from('group_members')
    .select('groups!inner(*, community_savings_groups(*))')
    .eq('user_id', userId)
    .eq('status', 'active');
  assertDb(error);
  return data.flatMap((row) =>
    (row.groups.community_savings_groups ?? []).map((item) => ({
      ...groupMap(item),
      group: groupDto(row.groups),
    })),
  );
}
