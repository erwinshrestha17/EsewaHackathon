import { assertChoice, parseMoneyMinor, requireFields } from '../../middleware/validate.middleware.js';
import { ApiError } from '../../utils/ApiError.js';
import { logActivity } from '../common/audit.js';
import { db, assertDb, single } from '../common/db.js';
import { publishGroupEvent } from '../realtime/realtime.service.js';

const splitModes = ['equal', 'custom', 'item'];
const expenseStatuses = ['draft', 'active', 'voided'];
const reviewStatuses = ['pending', 'accepted', 'correction_requested', 'item_disputed'];
const recurringFrequencies = ['weekly', 'monthly'];
const recurringSplitModes = ['equal', 'custom'];

async function rows(query) {
  const { data, error } = await query;
  assertDb(error);
  return data ?? [];
}

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

function expenseReviewDto(row) {
  return {
    id: row.id,
    expenseId: row.expense_id,
    userId: row.user_id,
    status: row.status,
    note: row.note ?? '',
    expenseItemId: row.expense_item_id,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function recurringExpenseDto(row) {
  return {
    id: row.id,
    groupId: row.group_id,
    title: row.title,
    amountMinor: row.amount_minor,
    payerId: row.payer_id,
    category: row.category,
    splitMode: row.split_mode,
    frequency: row.frequency,
    nextDueAt: row.next_due_at,
    note: row.note ?? '',
    active: row.active,
    lastPostedAt: row.last_posted_at,
    sourceExpenseId: row.source_expense_id,
    createdBy: row.created_by,
    createdAt: row.created_at,
    participantIds: row.participant_ids ?? [],
    customAmounts: row.custom_amounts ?? {},
  };
}

function normalizeEnum(value) {
  return value?.toString().trim().toLowerCase().replace(/[^a-z0-9]/g, '') ?? '';
}

function normalizeReviewStatus(value) {
  const normalized = normalizeEnum(value);
  if (normalized === 'correctionrequested') return 'correction_requested';
  if (normalized === 'itemdisputed') return 'item_disputed';
  return reviewStatuses.find((status) => normalizeEnum(status) === normalized);
}

function normalizeSplitMode(value) {
  const normalized = normalizeEnum(value ?? 'equal');
  if (normalized === 'custom') return 'custom';
  return 'equal';
}

function normalizeFrequency(value) {
  const normalized = normalizeEnum(value ?? 'monthly');
  return recurringFrequencies.find((frequency) => normalizeEnum(frequency) === normalized);
}

function parseDueDate(value, field = 'nextDueAt') {
  const date = new Date(value ?? Date.now());
  if (Number.isNaN(date.getTime())) {
    throw new ApiError(400, `${field} must be a valid date.`);
  }
  return date;
}

function nextRecurringDueDate(from, frequency) {
  const date = new Date(from);
  if (frequency === 'weekly') {
    date.setUTCDate(date.getUTCDate() + 7);
    return date;
  }
  const target = new Date(date);
  const day = target.getUTCDate();
  target.setUTCDate(1);
  target.setUTCMonth(target.getUTCMonth() + 1);
  const daysInTargetMonth = new Date(
    Date.UTC(target.getUTCFullYear(), target.getUTCMonth() + 1, 0),
  ).getUTCDate();
  target.setUTCDate(Math.min(day, daysInTargetMonth));
  return target;
}

async function assertActiveGroupUsers(groupId, userIds) {
  const ids = [...new Set(userIds.filter(Boolean))];
  if (ids.length === 0) {
    throw new ApiError(400, 'At least one participant is required.');
  }
  const members = await rows(
    db()
      .from('group_members')
      .select('user_id')
      .eq('group_id', groupId)
      .eq('status', 'active')
      .in('user_id', ids),
  );
  const found = new Set(members.map((member) => member.user_id));
  const missing = ids.filter((id) => !found.has(id));
  if (missing.length > 0) {
    throw new ApiError(400, 'All payers and participants must be active group members.');
  }
}

async function expenseReviewContext(group, expenseId) {
  const expense = await single(
    db().from('expenses').select('*').eq('group_id', group.id).eq('id', expenseId),
    'Expense not found.',
  );
  if (expense.status !== 'active') {
    throw new ApiError(409, 'Only active expenses can be reviewed.');
  }
  if (expense.locked_at) {
    throw new ApiError(409, 'This expense is locked by a settlement.');
  }
  const [payers, shares] = await Promise.all([
    rows(db().from('expense_payers').select('user_id').eq('expense_id', expense.id)),
    rows(db().from('expense_shares').select('user_id').eq('expense_id', expense.id)),
  ]);
  return {
    expense,
    affectedUserIds: new Set([
      expense.payer_id,
      ...payers.map((row) => row.user_id),
      ...shares.map((row) => row.user_id),
    ].filter(Boolean)),
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

export async function createExpense(group, userId, body) {
  requireFields(body, ['title', 'totalMinor', 'payerId']);
  assertChoice(body.splitMode ?? 'equal', splitModes, 'splitMode');
  const totalMinor = parseMoneyMinor(body.totalMinor, 'totalMinor');
  const splitMode = body.splitMode ?? 'equal';
  const participantIds = body.participantIds ?? [];
  const shares =
    splitMode === 'equal' && body.equalAmounts
      ? Object.fromEntries(participantIds.map((id) => [id, Number(body.equalAmounts[id] ?? 0)]))
      : splitMode === 'equal'
        ? equalShares(totalMinor, participantIds)
        : Object.fromEntries(Object.entries(body.customAmounts ?? {}).map(([id, amount]) => [id, Number(amount)]));
  const shareTotal = Object.values(shares).reduce((sum, amount) => sum + amount, 0);
  if (shareTotal !== totalMinor) {
    throw new ApiError(400, 'Expense shares must add up to totalMinor.');
  }
  const payerTotal = (body.payers ?? [{ userId: body.payerId, amountMinor: totalMinor }]).reduce(
    (sum, payer) => sum + Number(payer.amountMinor ?? 0),
    0,
  );
  if (payerTotal !== totalMinor) {
    throw new ApiError(400, 'Expense payer amounts must add up to totalMinor.');
  }

  const { data: expense, error } = await db()
    .from('expenses')
    .insert({
      group_id: group.id,
      title: body.title.trim(),
      subtotal_minor: Number(body.subtotalMinor ?? totalMinor),
      total_minor: totalMinor,
      payer_id: body.payerId,
      category: body.category ?? 'custom',
      split_mode: splitMode,
      status: body.status ?? 'active',
      expense_date: body.expenseDate ?? new Date().toISOString().slice(0, 10),
      note: body.note?.trim() || '',
      receipt_url: body.receiptUrl ?? null,
      bill_tax_minor: Number(body.billTaxMinor ?? 0),
      bill_service_charge_minor: Number(body.billServiceChargeMinor ?? 0),
      bill_discount_minor: Number(body.billDiscountMinor ?? 0),
      bill_tip_minor: Number(body.billTipMinor ?? 0),
      bill_rounding_adjustment_minor: Number(body.billRoundingAdjustmentMinor ?? 0),
      created_by: userId,
    })
    .select()
    .single();
  assertDb(error);

  const payerRows = (body.payers ?? [{ userId: body.payerId, amountMinor: totalMinor }]).map(
    (payer) => ({
      expense_id: expense.id,
      user_id: payer.userId,
      amount_minor: Number(payer.amountMinor),
    }),
  );
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
    const { data: insertedItems, error: itemError } = await db().from('expense_items').insert(
      body.items.map((item, index) => ({
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
      })),
    ).select();
    assertDb(itemError);
    const assignmentRows = [];
    for (let index = 0; index < (insertedItems ?? []).length; index += 1) {
      const sourceItem = body.items[index];
      for (const assignment of sourceItem.assignments ?? []) {
        assignmentRows.push({
          expense_item_id: insertedItems[index].id,
          user_id: assignment.userId,
          assigned_amount_minor: Number(assignment.assignedAmountMinor),
          split_units: Number(assignment.splitUnits ?? 1),
        });
      }
    }
    if (assignmentRows.length > 0) {
      const { error: assignmentError } = await db()
        .from('expense_item_assignments')
        .insert(assignmentRows);
      assertDb(assignmentError);
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
  await publishGroupEvent(group.id, {
    type: 'expense_changed',
    payload: { operation: 'created', expenseId: expense.id, actorId: userId },
  });
  await publishGroupEvent(group.id, {
    type: 'group_ledger_changed',
    payload: { operation: 'expense_created', expenseId: expense.id, actorId: userId },
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
  await publishGroupEvent(group.id, {
    type: 'expense_changed',
    payload: { operation: 'voided', expenseId: data.id, actorId: userId },
  });
  await publishGroupEvent(group.id, {
    type: 'group_ledger_changed',
    payload: { operation: 'expense_voided', expenseId: data.id, actorId: userId },
  });
  return expenseDto(data);
}

export async function updateExpense(group, userId, expenseId, body) {
  const payload = {};
  if (body.title !== undefined) payload.title = body.title.trim();
  if (body.note !== undefined) payload.note = body.note?.trim() ?? '';
  if (Object.keys(payload).length === 0) {
    return getExpense(expenseId);
  }
  const { data, error } = await db()
    .from('expenses')
    .update(payload)
    .eq('group_id', group.id)
    .eq('id', expenseId)
    .is('locked_at', null)
    .select()
    .single();
  assertDb(error);
  await logActivity({
    groupId: group.id,
    actorId: userId,
    action: 'expense_updated',
    entityType: 'expense',
    entityId: data.id,
    title: 'Expense updated',
    body: `${data.title} was updated.`,
  });
  await publishGroupEvent(group.id, {
    type: 'expense_changed',
    payload: { operation: 'updated', expenseId: data.id, actorId: userId },
  });
  await publishGroupEvent(group.id, {
    type: 'group_ledger_changed',
    payload: { operation: 'expense_updated', expenseId: data.id, actorId: userId },
  });
  return getExpense(data.id);
}

export async function listExpenseReviews(group, expenseId) {
  await expenseReviewContext(group, expenseId);
  const reviews = await rows(
    db()
      .from('expense_reviews')
      .select('*')
      .eq('expense_id', expenseId)
      .order('updated_at', { ascending: true }),
  );
  return reviews.map(expenseReviewDto);
}

export async function setExpenseReview(group, userId, expenseId, body) {
  const status = normalizeReviewStatus(body.status);
  if (!status) {
    throw new ApiError(400, `status must be one of: ${reviewStatuses.join(', ')}.`);
  }
  const { expense, affectedUserIds } = await expenseReviewContext(group, expenseId);
  if (!affectedUserIds.has(userId)) {
    throw new ApiError(403, 'Only affected group members can review this expense.');
  }

  const note = body.note?.toString().trim() ?? '';
  const expenseItemId = body.expenseItemId?.toString().trim() || null;
  if ((status === 'correction_requested' || status === 'item_disputed') && note.length < 4) {
    throw new ApiError(400, 'Add a short reason for the review request.');
  }
  if (status === 'item_disputed') {
    if (!expenseItemId) {
      throw new ApiError(400, 'expenseItemId is required when disputing an item.');
    }
    await single(
      db().from('expense_items').select('id').eq('expense_id', expense.id).eq('id', expenseItemId),
      'Expense item not found.',
    );
  }

  const { data, error } = await db()
    .from('expense_reviews')
    .upsert(
      {
        expense_id: expense.id,
        user_id: userId,
        status,
        note: status === 'accepted' ? '' : note,
        expense_item_id: status === 'item_disputed' ? expenseItemId : null,
      },
      { onConflict: 'expense_id,user_id' },
    )
    .select()
    .single();
  assertDb(error);

  const action = {
    accepted: 'expense_split_accepted',
    pending: 'expense_review_pending',
    correction_requested: 'expense_correction_requested',
    item_disputed: 'expense_item_disputed',
  }[status];
  await logActivity({
    groupId: group.id,
    actorId: userId,
    action,
    entityType: 'expense',
    entityId: expense.id,
    title: status === 'accepted' ? 'Split accepted' : 'Expense review updated',
    body: status === 'accepted' ? `${expense.title} was accepted.` : note,
    metadata: { status, expenseItemId },
  });
  await publishGroupEvent(group.id, {
    type: 'expense_review_changed',
    payload: { operation: status, expenseId: expense.id, reviewId: data.id, actorId: userId },
  });
  await publishGroupEvent(group.id, {
    type: 'group_ledger_changed',
    payload: { operation: 'expense_reviewed', expenseId: expense.id, actorId: userId },
  });
  return expenseReviewDto(data);
}

export async function listRecurringExpenses(group) {
  const schedules = await rows(
    db()
      .from('recurring_expenses')
      .select('*')
      .eq('group_id', group.id)
      .order('next_due_at', { ascending: true }),
  );
  return schedules.map(recurringExpenseDto);
}

export async function createRecurringExpense(group, userId, body) {
  requireFields(body, ['title', 'amountMinor', 'payerId']);
  const amountMinor = parseMoneyMinor(body.amountMinor, 'amountMinor');
  const frequency = normalizeFrequency(body.frequency);
  if (!frequency) {
    throw new ApiError(400, `frequency must be one of: ${recurringFrequencies.join(', ')}.`);
  }
  const splitMode = normalizeSplitMode(body.splitMode);
  assertChoice(splitMode, recurringSplitModes, 'splitMode');
  const participantIds = [
    ...new Set((body.participantIds ?? body.participants ?? [body.payerId]).filter(Boolean)),
  ];
  const customAmounts = Object.fromEntries(
    Object.entries(body.customAmounts ?? {}).map(([id, amount]) => [id, Number(amount)]),
  );
  if (splitMode === 'custom') {
    const shareTotal = Object.values(customAmounts).reduce((sum, amount) => sum + amount, 0);
    if (shareTotal !== amountMinor) {
      throw new ApiError(400, 'Recurring custom shares must add up to amountMinor.');
    }
  }
  await assertActiveGroupUsers(group.id, [
    body.payerId,
    ...participantIds,
    ...Object.keys(customAmounts),
  ]);
  const nextDueAt = parseDueDate(body.nextDueAt);
  const { data, error } = await db()
    .from('recurring_expenses')
    .insert({
      group_id: group.id,
      title: body.title.trim(),
      amount_minor: amountMinor,
      payer_id: body.payerId,
      category: body.category ?? 'custom',
      split_mode: splitMode,
      frequency,
      next_due_at: nextDueAt.toISOString(),
      note: body.note?.toString().trim() ?? '',
      source_expense_id: body.sourceExpenseId ?? null,
      created_by: userId,
      participant_ids: participantIds,
      custom_amounts: splitMode === 'custom' ? customAmounts : {},
    })
    .select()
    .single();
  assertDb(error);
  await logActivity({
    groupId: group.id,
    actorId: userId,
    action: 'recurring_expense_created',
    entityType: 'recurring_expense',
    entityId: data.id,
    title: 'Recurring expense scheduled',
    body: `${data.title} will repeat ${data.frequency}.`,
    metadata: { amountMinor, nextDueAt: data.next_due_at },
  });
  await publishGroupEvent(group.id, {
    type: 'recurring_expense_changed',
    payload: { operation: 'created', recurringExpenseId: data.id, actorId: userId },
  });
  await publishGroupEvent(group.id, {
    type: 'group_ledger_changed',
    payload: { operation: 'recurring_created', recurringExpenseId: data.id, actorId: userId },
  });
  return recurringExpenseDto(data);
}

export async function postRecurringExpense(group, userId, recurringExpenseId) {
  const schedule = await single(
    db()
      .from('recurring_expenses')
      .select('*')
      .eq('group_id', group.id)
      .eq('id', recurringExpenseId),
    'Recurring expense not found.',
  );
  if (!schedule.active) {
    throw new ApiError(409, 'This recurring expense is paused.');
  }
  const dueAt = new Date(schedule.next_due_at);
  if (dueAt.getTime() > Date.now()) {
    throw new ApiError(409, `${schedule.title} is not due yet.`);
  }

  const expense = await createExpense(group, userId, {
    title: schedule.title,
    subtotalMinor: schedule.amount_minor,
    totalMinor: schedule.amount_minor,
    payerId: schedule.payer_id,
    category: schedule.category,
    splitMode: schedule.split_mode,
    participantIds: schedule.participant_ids,
    customAmounts: schedule.split_mode === 'custom' ? schedule.custom_amounts : {},
    note: schedule.note || 'Posted from recurring schedule.',
  });
  const nextDueAt = nextRecurringDueDate(dueAt, schedule.frequency);
  const { data, error } = await db()
    .from('recurring_expenses')
    .update({
      last_posted_at: new Date().toISOString(),
      next_due_at: nextDueAt.toISOString(),
    })
    .eq('group_id', group.id)
    .eq('id', schedule.id)
    .select()
    .single();
  assertDb(error);
  await logActivity({
    groupId: group.id,
    actorId: userId,
    action: 'recurring_expense_posted',
    entityType: 'expense',
    entityId: expense.id,
    title: 'Recurring expense posted',
    body: `${schedule.title} was posted to the group ledger.`,
    metadata: { recurringExpenseId: schedule.id, nextDueAt: data.next_due_at },
  });
  await publishGroupEvent(group.id, {
    type: 'recurring_expense_changed',
    payload: { operation: 'posted', recurringExpenseId: schedule.id, expenseId: expense.id, actorId: userId },
  });
  await publishGroupEvent(group.id, {
    type: 'group_ledger_changed',
    payload: { operation: 'recurring_posted', recurringExpenseId: schedule.id, expenseId: expense.id, actorId: userId },
  });
  return { recurringExpense: recurringExpenseDto(data), expense };
}

export async function pauseRecurringExpense(group, userId, recurringExpenseId) {
  const { data, error } = await db()
    .from('recurring_expenses')
    .update({ active: false })
    .eq('group_id', group.id)
    .eq('id', recurringExpenseId)
    .select()
    .single();
  assertDb(error);
  await logActivity({
    groupId: group.id,
    actorId: userId,
    action: 'recurring_expense_paused',
    entityType: 'recurring_expense',
    entityId: data.id,
    title: 'Recurring expense paused',
    body: `${data.title} will not post automatically.`,
  });
  await publishGroupEvent(group.id, {
    type: 'recurring_expense_changed',
    payload: { operation: 'paused', recurringExpenseId: data.id, actorId: userId },
  });
  await publishGroupEvent(group.id, {
    type: 'group_ledger_changed',
    payload: { operation: 'recurring_paused', recurringExpenseId: data.id, actorId: userId },
  });
  return recurringExpenseDto(data);
}
