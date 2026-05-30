import { assertChoice, parseMoneyMinor, requireFields } from '../../middleware/validate.middleware.js';
import { ApiError } from '../../utils/ApiError.js';
import { logActivity } from '../common/audit.js';
import { db, assertDb, isUuid, single } from '../common/db.js';

const splitModes = ['equal', 'custom', 'item'];
const expenseStatuses = ['draft', 'active', 'voided'];

function expenseDto(row) {
  return {
    id: row.id,
    groupId: row.group_id,
    title: row.title,
    subtotalMinor: row.subtotal_minor,
    totalMinor: row.total_minor,
    payerId: row.payer_id,
    category: row.category,
    splitMode: row.split_mode,
    status: row.status,
    expenseDate: row.expense_date,
    note: row.note,
    receiptUrl: row.receipt_url,
    billTaxMinor: row.bill_tax_minor,
    billServiceChargeMinor: row.bill_service_charge_minor,
    billDiscountMinor: row.bill_discount_minor,
    createdBy: row.created_by,
    createdAt: row.created_at,
    payers: row.expense_payers ?? [],
    shares: row.expense_shares ?? [],
    items: row.expense_items ?? [],
  };
}

export async function listGroupExpenses(group, status) {
  assertChoice(status, expenseStatuses, 'status');
  let query = db()
    .from('expenses')
    .select('*, expense_payers(*), expense_shares(*), expense_items(*, expense_item_assignments(*))')
    .eq('group_id', group.id)
    .order('expense_date', { ascending: false });
  if (status) query = query.eq('status', status);
  const { data, error } = await query;
  assertDb(error);
  return data.map(expenseDto);
}

function equalShares(total, participantIds) {
  if (participantIds.length === 0) {
    throw new ApiError(400, 'At least one participant is required.');
  }
  const base = Math.floor(total / participantIds.length);
  let remainder = total - base * participantIds.length;
  return Object.fromEntries(
    participantIds.map((id) => {
      const amount = base + (remainder > 0 ? 1 : 0);
      remainder -= 1;
      return [id, amount];
    }),
  );
}

async function profileIdForLookup(value) {
  const id = value?.toString();
  if (!id) {
    throw new ApiError(400, 'User profile is required.');
  }
  const query = db().from('profiles').select('id');
  const profile = await single(
    isUuid(id) ? query.eq('id', id) : query.eq('legacy_user_id', id),
    'User profile not found.',
  );
  return profile.id;
}

async function profileIdMap(values) {
  const uniqueValues = [...new Set(values.filter(Boolean).map((value) => value.toString()))];
  const entries = await Promise.all(
    uniqueValues.map(async (value) => [value, await profileIdForLookup(value)]),
  );
  return new Map(entries);
}

export async function createExpense(group, userId, body) {
  requireFields(body, ['title', 'totalMinor', 'payerId']);
  assertChoice(body.splitMode ?? 'equal', splitModes, 'splitMode');
  const totalMinor = parseMoneyMinor(body.totalMinor, 'totalMinor');
  const splitMode = body.splitMode ?? 'equal';
  const participantIds = body.participantIds ?? [];
  const customAmounts = body.customAmounts ?? {};
  const payerRowsInput = body.payers ?? [{ userId: body.payerId, amountMinor: totalMinor }];
  const lookupValues = [
    body.payerId,
    ...participantIds,
    ...Object.keys(customAmounts),
    ...payerRowsInput.map((payer) => payer.userId),
    ...(body.items ?? []).flatMap((item) =>
      (item.assignments ?? []).map((assignment) => assignment.userId),
    ),
  ];
  const profileIds = await profileIdMap(lookupValues);
  const resolveProfileId = (value) => profileIds.get(value?.toString()) ?? value;
  const resolvedPayerId = resolveProfileId(body.payerId);
  const resolvedParticipantIds = participantIds.map(resolveProfileId);
  const resolvedCustomAmounts = Object.fromEntries(
    Object.entries(customAmounts).map(([id, amount]) => [resolveProfileId(id), amount]),
  );
  const shares =
    splitMode === 'equal'
      ? equalShares(totalMinor, resolvedParticipantIds)
      : Object.fromEntries(
          Object.entries(resolvedCustomAmounts).map(([id, amount]) => [id, Number(amount)]),
        );
  const shareTotal = Object.values(shares).reduce((sum, amount) => sum + amount, 0);
  if (shareTotal !== totalMinor) {
    throw new ApiError(400, 'Expense shares must add up to totalMinor.');
  }

  const { data: expense, error } = await db()
    .from('expenses')
    .insert({
      group_id: group.id,
      title: body.title.trim(),
      subtotal_minor: Number(body.subtotalMinor ?? totalMinor),
      total_minor: totalMinor,
      payer_id: resolvedPayerId,
      category: body.category ?? 'custom',
      split_mode: splitMode,
      status: body.status ?? 'active',
      expense_date: body.expenseDate ?? new Date().toISOString().slice(0, 10),
      note: body.note?.trim() || '',
      receipt_url: body.receiptUrl ?? null,
      bill_tax_minor: Number(body.billTaxMinor ?? 0),
      bill_service_charge_minor: Number(body.billServiceChargeMinor ?? 0),
      bill_discount_minor: Number(body.billDiscountMinor ?? 0),
      created_by: userId,
    })
    .select()
    .single();
  assertDb(error);

  const payerRows = payerRowsInput.map((payer) => ({
    expense_id: expense.id,
    user_id: resolveProfileId(payer.userId),
    amount_minor: Number(payer.amountMinor),
  }));
  const shareRows = Object.entries(shares).map(([shareUserId, amountMinor]) => ({
    expense_id: expense.id,
    user_id: shareUserId,
    amount_minor: amountMinor,
    source_type: splitMode,
  }));
  const { error: payerError } = await db().from('expense_payers').insert(payerRows);
  assertDb(payerError);
  const { error: shareError } = await db().from('expense_shares').insert(shareRows);
  assertDb(shareError);

  if (Array.isArray(body.items) && body.items.length > 0) {
    for (const [index, item] of body.items.entries()) {
      const { data: insertedItem, error: itemError } = await db()
        .from('expense_items')
        .insert({
          expense_id: expense.id,
          label: item.label,
          quantity: Number(item.quantity ?? 1),
          unit_amount_minor: Number(item.unitAmountMinor ?? item.totalAmountMinor),
          total_amount_minor: Number(item.totalAmountMinor),
          tax_minor: Number(item.taxMinor ?? 0),
          service_charge_minor: Number(item.serviceChargeMinor ?? 0),
          discount_minor: Number(item.discountMinor ?? 0),
          ocr_confidence: Number(item.ocrConfidence ?? 1),
          sort_order: index,
        })
        .select()
        .single();
      assertDb(itemError);
      if (Array.isArray(item.assignments) && item.assignments.length > 0) {
        const { error: assignmentError } = await db().from('expense_item_assignments').insert(
          item.assignments.map((assignment) => ({
            expense_item_id: insertedItem.id,
            user_id: resolveProfileId(assignment.userId),
            assigned_amount_minor: Number(assignment.assignedAmountMinor ?? 0),
            split_units: Number(assignment.splitUnits ?? 1),
          })),
        );
        assertDb(assignmentError);
      }
    }
  }

  await logActivity({
    groupId: group.id,
    actorId: userId,
    action: 'expense_created',
    entityType: 'expense',
    entityId: expense.id,
    title: 'Expense added',
    body: `${expense.title} was added to the group.`,
    metadata: { totalMinor },
  });
  return getExpense(expense.id);
}

export async function getExpense(expenseId) {
  const row = await single(
    db()
      .from('expenses')
      .select('*, expense_payers(*), expense_shares(*), expense_items(*, expense_item_assignments(*))')
      .eq('id', expenseId),
    'Expense not found.',
  );
  return expenseDto(row);
}

export async function voidExpense(group, userId, expenseId, reason) {
  const { data, error } = await db()
    .from('expenses')
    .update({
      status: 'voided',
      voided_at: new Date().toISOString(),
      voided_by: userId,
      void_reason: reason ?? null,
    })
    .eq('group_id', group.id)
    .eq('id', expenseId)
    .select()
    .single();
  assertDb(error);
  await logActivity({
    groupId: group.id,
    actorId: userId,
    action: 'expense_voided',
    entityType: 'expense',
    entityId: data.id,
    title: 'Expense voided',
    body: `${data.title} was voided.`,
  });
  return expenseDto(data);
}
