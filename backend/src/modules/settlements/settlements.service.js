import { parseMoneyMinor, requireFields } from '../../middleware/validate.middleware.js';
import { ApiError } from '../../utils/ApiError.js';
import { logActivity } from '../common/audit.js';
import { db, assertDb, single } from '../common/db.js';
import { publishGroupEvent } from '../realtime/realtime.service.js';

function settlementDto(row) {
  return {
    id: row.id,
    groupId: row.group_id,
    payerId: row.payer_id,
    payeeId: row.payee_id,
    amountMinor: row.amount_minor,
    status: row.status,
    idempotencyKey: row.idempotency_key,
    operationType: row.operation_type,
    expiresAt: row.expires_at,
    paidAt: row.paid_at,
    createdAt: row.created_at,
  };
}

function rawPayload(value) {
  if (typeof value !== 'string') {
    return value ?? {};
  }
  try {
    return JSON.parse(value || '{}');
  } catch (_error) {
    return { raw: value };
  }
}

async function rows(query) {
  const { data, error } = await query;
  assertDb(error);
  return data ?? [];
}

async function assertGroupExpensesFinal(groupId) {
  const expenses = await rows(
    db()
      .from('expenses')
      .select('id, title, payer_id, created_by')
      .eq('group_id', groupId)
      .eq('status', 'active')
      .is('locked_at', null),
  );
  const expenseIds = expenses.map((expense) => expense.id);
  if (expenseIds.length === 0) {
    return;
  }
  const [payers, shares, reviews] = await Promise.all([
    rows(db().from('expense_payers').select('expense_id, user_id').in('expense_id', expenseIds)),
    rows(db().from('expense_shares').select('expense_id, user_id').in('expense_id', expenseIds)),
    rows(db().from('expense_reviews').select('*').in('expense_id', expenseIds)),
  ]);
  const reviewsByExpenseAndUser = new Map(
    reviews.map((review) => [`${review.expense_id}:${review.user_id}`, review]),
  );
  for (const expense of expenses) {
    const affectedUsers = new Set([
      expense.payer_id,
      ...payers
        .filter((row) => row.expense_id === expense.id)
        .map((row) => row.user_id),
      ...shares
        .filter((row) => row.expense_id === expense.id)
        .map((row) => row.user_id),
    ].filter(Boolean));
    for (const userId of affectedUsers) {
      const review = reviewsByExpenseAndUser.get(`${expense.id}:${userId}`);
      const status = review?.status ?? (userId === expense.created_by ? 'accepted' : 'pending');
      if (status !== 'accepted') {
        throw new ApiError(409, 'Resolve expense reviews before settling this group.');
      }
    }
  }
}

export async function listSettlements(userId, group) {
  let query = db()
    .from('settlements')
    .select('*')
    .or(`payer_id.eq.${userId},payee_id.eq.${userId}`)
    .order('created_at', { ascending: false });
  if (group) query = query.eq('group_id', group.id);
  const { data, error } = await query;
  assertDb(error);
  return data.map(settlementDto);
}

export async function createSettlement(group, userId, body) {
  requireFields(body, ['payerId', 'payeeId', 'amountMinor']);
  await assertGroupExpensesFinal(group.id);
  const amountMinor = parseMoneyMinor(body.amountMinor, 'amountMinor');
  const { data, error } = await db()
    .from('settlements')
    .upsert(
      {
        group_id: group.id,
        payer_id: body.payerId,
        payee_id: body.payeeId,
        amount_minor: amountMinor,
        status: body.status ?? 'pending',
        idempotency_key:
          body.idempotencyKey ?? `${group.id}:${body.payerId}:${body.payeeId}:${amountMinor}`,
        idempotency_scope: group.id,
        operation_type: body.operationType ?? 'external_settlement',
        expires_at: body.expiresAt ?? new Date(Date.now() + 86400000).toISOString(),
        balance_snapshot_hash: body.balanceSnapshotHash ?? 'manual',
      },
      { onConflict: 'idempotency_key' },
    )
    .select()
    .single();
  assertDb(error);
  await logActivity({
    groupId: group.id,
    actorId: userId,
    action: 'settlement_created',
    entityType: 'settlement',
    entityId: data.id,
    title: 'Settlement created',
    body: 'A settlement was prepared for the group.',
    metadata: { amountMinor },
  });
  await publishGroupEvent(group.id, {
    type: 'settlement_changed',
    payload: { operation: 'created', settlementId: data.id, actorId: userId },
  });
  await publishGroupEvent(group.id, {
    type: 'group_ledger_changed',
    payload: { operation: 'settlement_created', settlementId: data.id, actorId: userId },
  });
  return settlementDto(data);
}

async function createSettlementPayment(settlement, actorId, body = {}) {
  const provider = body.paymentProvider ?? (settlement.operation_type === 'external_settlement' ? 'external' : 'esewa');
  const reference = body.paymentReference ?? `${provider}:${settlement.id}:${Date.now()}`;
  const { data, error } = await db()
    .from('payment_transactions')
    .insert({
      payment_provider: provider,
      payment_reference: reference,
      operation_type: settlement.operation_type,
      entity_type: 'settlement',
      entity_id: settlement.id,
      actor_id: actorId,
      amount_minor: settlement.amount_minor,
      status: 'paid',
      raw_payload: rawPayload(body.rawPayload),
      confirmed_at: new Date().toISOString(),
    })
    .select()
    .single();
  assertDb(error);
  return data;
}

export async function confirmSettlement(group, userId, settlementId, body = {}) {
  const current = await single(
    db().from('settlements').select('*').eq('group_id', group.id).eq('id', settlementId),
    'Settlement not found.',
  );
  if (current.status !== 'pending') {
    throw new ApiError(409, 'Only pending settlements can be confirmed.');
  }
  if (current.operation_type === 'external_settlement' && current.payee_id !== userId) {
    throw new ApiError(403, 'Only the recipient can approve an external settlement.');
  }
  if (current.operation_type !== 'external_settlement' && current.payer_id !== userId) {
    throw new ApiError(403, 'Only the payer can confirm this settlement.');
  }
  await assertGroupExpensesFinal(group.id);
  const payment = await createSettlementPayment(current, userId, body);
  const { data, error } = await db()
    .from('settlements')
    .update({
      status: 'paid',
      paid_at: new Date().toISOString(),
      payment_transaction_id: payment.id,
    })
    .eq('group_id', group.id)
    .eq('id', settlementId)
    .select()
    .single();
  assertDb(error);
  await logActivity({
    groupId: group.id,
    actorId: userId,
    action: 'settlement_confirmed',
    entityType: 'settlement',
    entityId: data.id,
    title: 'Settlement confirmed',
    body: 'A settlement was marked paid outside the app.',
  });
  await db()
    .from('groups')
    .update({ latest_settlement_lock_at: data.paid_at })
    .eq('id', group.id);
  await db()
    .from('expenses')
    .update({ locked_at: data.paid_at })
    .eq('group_id', group.id)
    .eq('status', 'active')
    .is('locked_at', null)
    .lte('created_at', data.paid_at);
  await publishGroupEvent(group.id, {
    type: 'settlement_changed',
    payload: { operation: 'confirmed', settlementId: data.id, actorId: userId },
  });
  await publishGroupEvent(group.id, {
    type: 'group_ledger_changed',
    payload: { operation: 'settlement_confirmed', settlementId: data.id, actorId: userId },
  });
  return settlementDto(data);
}

export async function cancelSettlement(group, userId, settlementId) {
  const current = await single(
    db().from('settlements').select('*').eq('group_id', group.id).eq('id', settlementId),
    'Settlement not found.',
  );
  if (![current.payer_id, current.payee_id].includes(userId)) {
    throw new ApiError(403, 'Only settlement participants can cancel this request.');
  }
  if (current.status !== 'pending') {
    throw new ApiError(409, 'Only pending settlements can be cancelled.');
  }
  const { data, error } = await db()
    .from('settlements')
    .update({ status: 'cancelled' })
    .eq('group_id', group.id)
    .eq('id', settlementId)
    .select()
    .single();
  assertDb(error);
  await logActivity({
    groupId: group.id,
    actorId: userId,
    action: 'settlement_cancelled',
    entityType: 'settlement',
    entityId: data.id,
    title: 'Settlement cancelled',
    body: 'A pending settlement was cancelled.',
  });
  await publishGroupEvent(group.id, {
    type: 'settlement_changed',
    payload: { operation: 'cancelled', settlementId: data.id, actorId: userId },
  });
  await publishGroupEvent(group.id, {
    type: 'group_ledger_changed',
    payload: { operation: 'settlement_cancelled', settlementId: data.id, actorId: userId },
  });
  return settlementDto(data);
}
