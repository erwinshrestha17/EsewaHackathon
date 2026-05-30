import { parseMoneyMinor, requireFields } from '../../middleware/validate.middleware.js';
import { ApiError } from '../../utils/ApiError.js';
import { logActivity } from '../common/audit.js';
import { db, assertDb, maybeSingle, single } from '../common/db.js';
import { publishGroupEvent, publishUserEvent } from '../realtime/realtime.service.js';

function giftDto(row) {
  return {
    id: row.id,
    senderId: row.sender_id,
    recipientId: row.recipient_id,
    groupId: row.group_id,
    template: row.template,
    amountMinor: row.amount_minor,
    message: row.message,
    status: row.status,
    openedAt: row.opened_at,
    createdAt: row.created_at,
  };
}

function poolDto(row) {
  return {
    id: row.id,
    groupId: row.group_id,
    createdBy: row.created_by,
    recipientId: row.recipient_id,
    title: row.title,
    template: row.template,
    targetAmountMinor: row.target_amount_minor,
    contributionRule: row.contribution_rule,
    allowOverTarget: row.allow_over_target,
    minContributionAmountMinor: row.min_contribution_amount_minor,
    maxContributionAmountMinor: row.max_contribution_amount_minor,
    message: row.message,
    status: row.status,
    createdAt: row.created_at,
    contributions: row.gift_pool_contributions ?? [],
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

async function createPaymentTransaction({
  body,
  operationType,
  entityType,
  entityId,
  actorId,
  amountMinor,
}) {
  if (!body.paymentReference && !body.paymentProvider) {
    return null;
  }
  const provider = body.paymentProvider ?? 'esewa';
  const reference = body.paymentReference ?? `${provider}:${entityId}:${Date.now()}`;
  const { data, error } = await db()
    .from('payment_transactions')
    .insert({
      payment_provider: provider,
      payment_reference: reference,
      operation_type: operationType,
      entity_type: entityType,
      entity_id: entityId,
      actor_id: actorId,
      amount_minor: amountMinor,
      status: 'paid',
      raw_payload: rawPayload(body.rawPayload),
      confirmed_at: new Date().toISOString(),
    })
    .select()
    .single();
  assertDb(error);
  return data;
}

export async function listGifts(userId) {
  const { data, error } = await db()
    .from('gifts')
    .select('*')
    .or(`sender_id.eq.${userId},recipient_id.eq.${userId}`)
    .order('created_at', { ascending: false });
  assertDb(error);
  return data.map(giftDto);
}

export async function sendGift(userId, body) {
  requireFields(body, ['recipientId', 'template', 'amountMinor']);
  const amountMinor = parseMoneyMinor(body.amountMinor, 'amountMinor');
  const { data, error } = await db()
    .from('gifts')
    .insert({
      sender_id: userId,
      recipient_id: body.recipientId,
      group_id: body.groupId ?? null,
      template: body.template,
      amount_minor: amountMinor,
      message: body.message ?? '',
      status: 'sent',
      idempotency_key: body.idempotencyKey ?? `${userId}:${body.recipientId}:${amountMinor}:${body.template}`,
      idempotency_scope: userId,
      operation_type: 'gift',
    })
    .select()
    .single();
  assertDb(error);
  const payment = await createPaymentTransaction({
    body,
    operationType: 'gift',
    entityType: 'gift',
    entityId: data.id,
    actorId: userId,
    amountMinor,
  });
  const gift = payment
    ? await single(
        db()
          .from('gifts')
          .update({ payment_transaction_id: payment.id })
          .eq('id', data.id)
          .select(),
      )
    : data;
  await logActivity({
    actorId: userId,
    groupId: body.groupId ?? null,
    action: 'gift_sent',
    entityType: 'gift',
    entityId: gift.id,
    title: 'Gift sent',
    body: 'A gift was marked sent in prototype mode.',
    metadata: { amountMinor },
  });
  publishUserEvent(body.recipientId, {
    type: 'gift_changed',
    payload: { operation: 'sent', giftId: gift.id, actorId: userId },
  });
  publishUserEvent(userId, {
    type: 'gift_changed',
    payload: { operation: 'sent', giftId: gift.id, actorId: userId },
  });
  if (body.groupId) {
    await publishGroupEvent(body.groupId, {
      type: 'gift_changed',
      payload: { operation: 'sent', giftId: gift.id, actorId: userId },
    });
  }
  return giftDto(gift);
}

export async function openGift(userId, giftId) {
  const { data, error } = await db()
    .from('gifts')
    .update({ status: 'opened', opened_at: new Date().toISOString() })
    .eq('id', giftId)
    .eq('recipient_id', userId)
    .select()
    .single();
  assertDb(error);
  publishUserEvent(data.sender_id, {
    type: 'gift_changed',
    payload: { operation: 'opened', giftId: data.id, actorId: userId },
  });
  publishUserEvent(userId, {
    type: 'gift_changed',
    payload: { operation: 'opened', giftId: data.id, actorId: userId },
  });
  return giftDto(data);
}

export async function listGiftPools(group) {
  const { data, error } = await db()
    .from('gift_pools')
    .select('*, gift_pool_contributions(*)')
    .eq('group_id', group.id)
    .order('created_at', { ascending: false });
  assertDb(error);
  return data.map(poolDto);
}

export async function createGiftPool(group, userId, body) {
  requireFields(body, ['recipientId', 'title', 'template', 'targetAmountMinor']);
  const { data, error } = await db()
    .from('gift_pools')
    .insert({
      group_id: group.id,
      created_by: userId,
      recipient_id: body.recipientId,
      title: body.title,
      template: body.template,
      target_amount_minor: parseMoneyMinor(body.targetAmountMinor, 'targetAmountMinor'),
      contribution_rule: body.contributionRule ?? 'threshold',
      allow_over_target: Boolean(body.allowOverTarget),
      equal_contribution_amount_minor: body.equalContributionAmountMinor ?? null,
      min_contribution_amount_minor: body.minContributionAmountMinor ?? null,
      max_contribution_amount_minor: body.maxContributionAmountMinor ?? null,
      message: body.message ?? '',
      status: 'open',
    })
    .select()
    .single();
  assertDb(error);
  await logActivity({
    groupId: group.id,
    actorId: userId,
    action: 'gift_pool_created',
    entityType: 'gift_pool',
    entityId: data.id,
    title: 'Gift pool created',
    body: `${data.title} was created.`,
  });
  await publishGroupEvent(group.id, {
    type: 'gift_pool_changed',
    payload: { operation: 'created', giftPoolId: data.id, actorId: userId },
  });
  return poolDto(data);
}

export async function contributeToGiftPool(userId, giftPoolId, body) {
  const amountMinor = parseMoneyMinor(body.amountMinor, 'amountMinor');
  const pool = await single(
    db().from('gift_pools').select('*').eq('id', giftPoolId),
    'Gift pool not found.',
  );
  const membership = await maybeSingle(
    db()
      .from('group_members')
      .select('id')
      .eq('group_id', pool.group_id)
      .eq('user_id', userId)
      .eq('status', 'active'),
  );
  if (!membership) {
    throw new ApiError(403, 'Only active group members can contribute to this gift pool.');
  }
  const { data, error } = await db()
    .from('gift_pool_contributions')
    .insert({
      gift_pool_id: giftPoolId,
      contributor_id: userId,
      amount_minor: amountMinor,
      status: 'paid',
      idempotency_key: body.idempotencyKey ?? `${giftPoolId}:${userId}:${amountMinor}`,
      idempotency_scope: giftPoolId,
      operation_type: 'gift_pool_contribution',
      paid_at: new Date().toISOString(),
    })
    .select()
    .single();
  assertDb(error);
  const payment = await createPaymentTransaction({
    body,
    operationType: 'gift_pool_contribution',
    entityType: 'gift_pool_contribution',
    entityId: data.id,
    actorId: userId,
    amountMinor,
  });
  const contribution = payment
    ? await single(
        db()
          .from('gift_pool_contributions')
          .update({ payment_transaction_id: payment.id })
          .eq('id', data.id)
          .select(),
      )
    : data;
  const contributionTotal = await db()
    .from('gift_pool_contributions')
    .select('amount_minor')
    .eq('gift_pool_id', giftPoolId)
    .eq('status', 'paid');
  assertDb(contributionTotal.error);
  const raised = (contributionTotal.data ?? []).reduce(
    (sum, item) => sum + Number(item.amount_minor ?? 0),
    0,
  );
  if (!pool.allow_over_target && raised >= pool.target_amount_minor) {
    const { error: poolError } = await db()
      .from('gift_pools')
      .update({ status: 'completed' })
      .eq('id', giftPoolId);
    assertDb(poolError);
  }
  await publishGroupEvent(pool.group_id, {
    type: 'gift_pool_changed',
    payload: {
      operation: 'contributed',
      giftPoolId,
      contributionId: contribution.id,
      actorId: userId,
    },
  });
  return contribution;
}

export async function cancelGiftPool(group, userId, giftPoolId) {
  const { data, error } = await db()
    .from('gift_pools')
    .update({ status: 'cancelled' })
    .eq('group_id', group.id)
    .eq('id', giftPoolId)
    .select()
    .single();
  assertDb(error);
  await logActivity({
    groupId: group.id,
    actorId: userId,
    action: 'gift_pool_cancelled',
    entityType: 'gift_pool',
    entityId: data.id,
    title: 'Gift pool cancelled',
    body: `${data.title} was cancelled.`,
  });
  await publishGroupEvent(group.id, {
    type: 'gift_pool_changed',
    payload: { operation: 'cancelled', giftPoolId: data.id, actorId: userId },
  });
  return poolDto(data);
}
