import { parseMoneyMinor, requireFields } from '../../middleware/validate.middleware.js';
import { logActivity } from '../common/audit.js';
import { db, assertDb, findByIdOrLegacy, isUuid, single } from '../common/db.js';

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

async function profileIdForLookup(value) {
  const id = value?.toString();
  const query = db().from('profiles').select('id');
  const profile = await single(
    isUuid(id) ? query.eq('id', id) : query.eq('legacy_user_id', id),
    'User profile not found.',
  );
  return profile.id;
}

async function groupIdForLookup(value) {
  if (!value) return null;
  const group = await findByIdOrLegacy('groups', value.toString(), 'legacy_group_id');
  return group?.id ?? null;
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
  const recipientId = await profileIdForLookup(body.recipientId);
  const groupId = await groupIdForLookup(body.groupId);
  const { data, error } = await db()
    .from('gifts')
    .insert({
      sender_id: userId,
      recipient_id: recipientId,
      group_id: groupId,
      template: body.template,
      amount_minor: amountMinor,
      message: body.message ?? '',
      status: 'sent',
      idempotency_key: body.idempotencyKey ?? `${userId}:${recipientId}:${amountMinor}:${body.template}`,
      idempotency_scope: userId,
      operation_type: 'gift',
    })
    .select()
    .single();
  assertDb(error);
  await logActivity({
    actorId: userId,
    groupId,
    action: 'gift_sent',
    entityType: 'gift',
    entityId: data.id,
    title: 'Gift sent',
    body: 'A gift was marked sent in prototype mode.',
    metadata: { amountMinor },
  });
  return giftDto(data);
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
  const recipientId = await profileIdForLookup(body.recipientId);
  const { data, error } = await db()
    .from('gift_pools')
    .insert({
      group_id: group.id,
      created_by: userId,
      recipient_id: recipientId,
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
  return poolDto(data);
}

export async function contributeToGiftPool(userId, giftPoolId, body) {
  const amountMinor = parseMoneyMinor(body.amountMinor, 'amountMinor');
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
  return data;
}
