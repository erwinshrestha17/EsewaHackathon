import { parseMoneyMinor, requireFields } from '../../middleware/validate.middleware.js';
import { logActivity } from '../common/audit.js';
import { db, assertDb, isUuid, single } from '../common/db.js';

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

async function profileIdForLookup(value) {
  const id = value?.toString();
  const query = db().from('profiles').select('id');
  const profile = await single(
    isUuid(id) ? query.eq('id', id) : query.eq('legacy_user_id', id),
    'User profile not found.',
  );
  return profile.id;
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
  const amountMinor = parseMoneyMinor(body.amountMinor, 'amountMinor');
  const payerId = await profileIdForLookup(body.payerId);
  const payeeId = await profileIdForLookup(body.payeeId);
  const { data, error } = await db()
    .from('settlements')
    .upsert(
      {
        group_id: group.id,
        payer_id: payerId,
        payee_id: payeeId,
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
  return settlementDto(data);
}

export async function confirmSettlement(group, userId, settlementId) {
  const { data, error } = await db()
    .from('settlements')
    .update({ status: 'paid', paid_at: new Date().toISOString() })
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
  return settlementDto(data);
}
