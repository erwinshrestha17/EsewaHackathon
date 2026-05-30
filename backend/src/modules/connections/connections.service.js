import { assertChoice, requireFields } from '../../middleware/validate.middleware.js';
import { ApiError } from '../../utils/ApiError.js';
import { createNotification, logActivity } from '../common/audit.js';
import { db, assertDb, isUuid, maybeSingle, single } from '../common/db.js';
import { profileDto } from '../common/mappers.js';

const statuses = ['pending', 'approved', 'declined', 'expired', 'removed'];
const connectionSelect =
  '*, requester:profiles!connections_requester_id_fkey(*), recipient:profiles!connections_recipient_id_fkey(*)';

function pair(a, b) {
  return a < b ? [a, b] : [b, a];
}

function connectionDto(row) {
  return {
    id: row.id,
    requesterId: row.requester_id,
    recipientId: row.recipient_id,
    status: row.status,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    expiresAt: row.expires_at,
    requester: profileDto(row.requester),
    recipient: profileDto(row.recipient),
  };
}

async function profileForLookup(value) {
  let query = db().from('profiles').select('*');
  if (value.includes('@')) query = query.eq('email', value);
  else if (value.startsWith('+') || /^\d+$/.test(value)) query = query.eq('phone', value);
  else query = isUuid(value) ? query.eq('id', value) : query.eq('legacy_user_id', value);
  return single(query, 'User profile not found.');
}

export async function listConnections(userId, status) {
  assertChoice(status, statuses, 'status');
  let query = db()
    .from('connections')
    .select(connectionSelect)
    .or(`requester_id.eq.${userId},recipient_id.eq.${userId}`)
    .order('updated_at', { ascending: false });
  if (status) query = query.eq('status', status);
  const { data, error } = await query;
  assertDb(error);
  return data.map(connectionDto);
}

export async function searchProfiles(currentUserId, query) {
  const term = query?.trim();
  if (!term) {
    return [];
  }
  const { data, error } = await db()
    .from('profiles')
    .select('*')
    .neq('id', currentUserId)
    .or(`full_name.ilike.%${term}%,phone.ilike.%${term}%,legacy_user_id.ilike.%${term}%`)
    .limit(20);
  assertDb(error);
  return data.map(profileDto);
}

export async function requestConnection(userId, body) {
  requireFields(body, ['targetUserId']);
  const target = await profileForLookup(body.targetUserId.toString());
  if (target.id === userId) {
    throw new ApiError(400, 'You cannot connect to yourself.');
  }
  const [low, high] = pair(userId, target.id);
  const existing = await maybeSingle(
    db().from('connections').select('*').eq('user_low_id', low).eq('user_high_id', high),
  );
  if (existing?.status === 'pending' || existing?.status === 'approved') {
    throw new ApiError(409, `Connection already ${existing.status}.`);
  }
  const payload = {
    requester_id: userId,
    recipient_id: target.id,
    user_low_id: low,
    user_high_id: high,
    status: 'pending',
    expires_at: body.expiresAt ?? new Date(Date.now() + 14 * 86400000).toISOString(),
  };
  const { data, error } = await db()
    .from('connections')
    .upsert(existing ? { ...payload, id: existing.id } : payload)
    .select(connectionSelect)
    .single();
  assertDb(error);
  await createNotification({
    userId: target.id,
    title: 'Connection request',
    body: `${data.requester.full_name} wants to connect with you.`,
    type: 'connection_requested',
    metadata: { connectionId: data.id },
  });
  await logActivity({
    actorId: userId,
    action: 'connection_requested',
    entityType: 'connection',
    entityId: data.id,
    title: 'Connection request sent',
    body: `Connection request sent to ${target.full_name}.`,
  });
  return connectionDto(data);
}

export async function updateConnection(userId, connectionId, status) {
  assertChoice(status, statuses, 'status');
  const current = await single(
    db()
      .from('connections')
      .select('*')
      .eq('id', connectionId)
      .or(`requester_id.eq.${userId},recipient_id.eq.${userId}`),
    'Connection not found.',
  );
  if (status === 'approved' || status === 'declined') {
    if (current.recipient_id !== userId) {
      throw new ApiError(
        403,
        `Only the request recipient can ${status.slice(0, -1)} this request.`,
      );
    }
    if (current.status !== 'pending') {
      throw new ApiError(409, 'Only pending connection requests can be updated.');
    }
  }
  const { data, error } = await db()
    .from('connections')
    .update({ status })
    .eq('id', current.id)
    .select(connectionSelect)
    .single();
  assertDb(error);
  await logActivity({
    actorId: userId,
    action: `connection_${status}`,
    entityType: 'connection',
    entityId: data.id,
    title: 'Connection updated',
    body: `Connection marked ${status}.`,
  });
  return connectionDto(data);
}
