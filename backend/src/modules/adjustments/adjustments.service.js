import { parseMoneyMinor, requireFields } from '../../middleware/validate.middleware.js';
import { ApiError } from '../../utils/ApiError.js';
import { logActivity } from '../common/audit.js';
import { assertDb, db } from '../common/db.js';
import { publishGroupEvent } from '../realtime/realtime.service.js';

function adjustmentDto(row) {
  return {
    id: row.id,
    groupId: row.group_id,
    reason: row.reason,
    adjustmentType: row.adjustment_type,
    createdBy: row.created_by,
    createdAt: row.created_at,
    reversesSourceType: row.reverses_source_type,
    reversesSourceId: row.reverses_source_id,
    entries: row.adjustment_entries ?? [],
  };
}

export async function createAdjustment(group, userId, body) {
  requireFields(body, ['creditUserId', 'debitUserId', 'amountMinor', 'reason']);
  const amountMinor = parseMoneyMinor(body.amountMinor, 'amountMinor');
  if (body.creditUserId === body.debitUserId) {
    throw new ApiError(400, 'Adjustment must move money between two different members.');
  }

  const { data: adjustment, error } = await db()
    .from('adjustments')
    .insert({
      group_id: group.id,
      reason: body.reason.trim(),
      adjustment_type: body.adjustmentType ?? 'correction',
      created_by: userId,
      reverses_source_type: body.reversesSourceType ?? null,
      reverses_source_id: body.reversesSourceId ?? null,
    })
    .select()
    .single();
  assertDb(error);

  const { error: entryError } = await db().from('adjustment_entries').insert([
    {
      adjustment_id: adjustment.id,
      user_id: body.creditUserId,
      amount_minor: amountMinor,
      direction: 'credit',
    },
    {
      adjustment_id: adjustment.id,
      user_id: body.debitUserId,
      amount_minor: amountMinor,
      direction: 'debit',
    },
  ]);
  assertDb(entryError);
  await logActivity({
    groupId: group.id,
    actorId: userId,
    action: 'adjustment_created',
    entityType: 'adjustment',
    entityId: adjustment.id,
    title: 'Zero-sum adjustment',
    body: body.reason.trim(),
    metadata: { amountMinor },
  });
  await publishGroupEvent(group.id, {
    type: 'adjustment_changed',
    payload: { operation: 'created', adjustmentId: adjustment.id, actorId: userId },
  });
  return getAdjustment(adjustment.id);
}

export async function getAdjustment(adjustmentId) {
  const { data, error } = await db()
    .from('adjustments')
    .select('*, adjustment_entries(*)')
    .eq('id', adjustmentId)
    .single();
  assertDb(error);
  return adjustmentDto(data);
}
