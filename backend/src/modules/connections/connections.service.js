import { assertChoice, requireFields } from '../../middleware/validate.middleware.js';
import { ApiError } from '../../utils/ApiError.js';
import { createNotification, logActivity } from '../common/audit.js';
import { db, assertDb, isUuid, maybeSingle, single } from '../common/db.js';
import { profileDto } from '../common/mappers.js';
import { publishAppEvent } from '../realtime/realtime.service.js';

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

function connectionParticipants(connection) {
  return [connection.requester_id, connection.recipient_id];
}

function otherParticipant(connection, userId) {
  return connection.requester_id === userId ? connection.recipient_id : connection.requester_id;
}

async function touchConnection(connectionId) {
  const { error } = await db()
    .from('connections')
    .update({ updated_at: new Date().toISOString() })
    .eq('id', connectionId);
  assertDb(error);
}

async function profileForLookup(value) {
  let query = db().from('profiles').select('*');
  if (value.includes('@')) query = query.eq('email', value);
  else if (value.startsWith('+') || /^\d+$/.test(value)) query = query.eq('phone', value);
  else query = isUuid(value) ? query.eq('id', value) : query.eq('legacy_user_id', value);
  return single(query, 'User profile not found.');
}

async function connectionForUser(userId, connectionId) {
  return single(
    db()
      .from('connections')
      .select('*')
      .eq('id', connectionId)
      .or(`requester_id.eq.${userId},recipient_id.eq.${userId}`),
    'Connection not found.',
  );
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
  const safeTerm = term.replace(/[(),]/g, ' ').trim();
  const digits = term.replace(/\D/g, '');
  const filters = [
    `full_name.ilike.%${safeTerm}%`,
    `phone.ilike.%${safeTerm}%`,
    `legacy_user_id.ilike.%${safeTerm}%`,
  ];
  if (digits && digits !== safeTerm) {
    filters.push(`phone.ilike.%${digits}%`);
  }
  const { data, error } = await db()
    .from('profiles')
    .select('*')
    .neq('id', currentUserId)
    .or(filters.join(','))
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
  const event = await db()
    .from('connection_events')
    .insert({
      connection_id: data.id,
      actor_id: userId,
      event_type: 'requested',
      previous_status: existing?.status ?? null,
      next_status: data.status,
    });
  assertDb(event.error);
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
  publishAppEvent([userId, target.id], {
    type: 'connection_changed',
    payload: {
      connectionId: data.id,
      status: data.status,
      actorId: userId,
    },
  });
  return connectionDto(data);
}

export async function updateConnection(userId, connectionId, status) {
  assertChoice(status, statuses, 'status');
  const current = await connectionForUser(userId, connectionId);
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
  const event = await db()
    .from('connection_events')
    .insert({
      connection_id: data.id,
      actor_id: userId,
      event_type: status,
      previous_status: current.status,
      next_status: data.status,
    });
  assertDb(event.error);
  await logActivity({
    actorId: userId,
    action: `connection_${status}`,
    entityType: 'connection',
    entityId: data.id,
    title: 'Connection updated',
    body: `Connection marked ${status}.`,
  });
  if (status === 'approved' || status === 'declined') {
    await createNotification({
      userId: current.requester_id,
      title: status === 'approved' ? 'Connection approved' : 'Connection declined',
      body:
        status === 'approved'
          ? `${data.recipient.full_name} accepted your connection request.`
          : `${data.recipient.full_name} declined your connection request.`,
      type: `connection_${status}`,
      metadata: { connectionId: data.id },
    });
  }
  publishAppEvent([data.requester.id, data.recipient.id], {
    type: 'connection_changed',
    payload: {
      connectionId: data.id,
      status: data.status,
      actorId: userId,
    },
  });
  return connectionDto(data);
}

export async function blockConnection(userId, connectionId, body = {}) {
  const current = await connectionForUser(userId, connectionId);
  const blockedUserId = body.blockedUserId?.toString() || otherParticipant(current, userId);
  if (!connectionParticipants(current).includes(blockedUserId) || blockedUserId === userId) {
    throw new ApiError(400, 'This connection cannot be blocked.');
  }

  const existing = await maybeSingle(
    db()
      .from('connection_blocks')
      .select('*')
      .eq('connection_id', connectionId)
      .eq('blocker_id', userId)
      .eq('blocked_user_id', blockedUserId)
      .eq('active', true),
  );
  if (existing) {
    return existing;
  }

  const { data, error } = await db()
    .from('connection_blocks')
    .insert({
      connection_id: connectionId,
      blocker_id: userId,
      blocked_user_id: blockedUserId,
    })
    .select('*')
    .single();
  assertDb(error);
  const event = await db()
    .from('connection_events')
    .insert({
      connection_id: connectionId,
      actor_id: userId,
      event_type: 'blocked',
      previous_status: current.status,
      next_status: current.status,
    });
  assertDb(event.error);
  await logActivity({
    actorId: userId,
    action: 'connection_blocked',
    entityType: 'connection',
    entityId: connectionId,
    title: 'Connection blocked',
    body: 'Connection blocked.',
  });
  await touchConnection(connectionId);
  publishAppEvent(connectionParticipants(current), {
    type: 'connection_changed',
    payload: { connectionId, status: current.status, actorId: userId },
  });
  return data;
}

export async function unblockConnection(userId, connectionId, body = {}) {
  const current = await connectionForUser(userId, connectionId);
  const blockedUserId = body.blockedUserId?.toString() || otherParticipant(current, userId);
  if (!connectionParticipants(current).includes(blockedUserId) || blockedUserId === userId) {
    throw new ApiError(400, 'This connection cannot be unblocked.');
  }

  const { data, error } = await db()
    .from('connection_blocks')
    .update({ active: false, lifted_at: new Date().toISOString() })
    .eq('connection_id', connectionId)
    .eq('blocker_id', userId)
    .eq('blocked_user_id', blockedUserId)
    .eq('active', true)
    .select('*')
    .maybeSingle();
  assertDb(error);
  const event = await db()
    .from('connection_events')
    .insert({
      connection_id: connectionId,
      actor_id: userId,
      event_type: 'unblocked',
      previous_status: current.status,
      next_status: current.status,
    });
  assertDb(event.error);
  await touchConnection(connectionId);
  publishAppEvent(connectionParticipants(current), {
    type: 'connection_changed',
    payload: { connectionId, status: current.status, actorId: userId },
  });
  return data;
}

export async function reportConnection(userId, connectionId, body) {
  requireFields(body, ['reportedUserId', 'note']);
  const current = await connectionForUser(userId, connectionId);
  const reportedUser = await profileForLookup(body.reportedUserId.toString());
  const note = body.note?.toString().trim();
  if (!note) {
    throw new ApiError(400, 'Add a note before submitting a report.');
  }
  if (!connectionParticipants(current).includes(reportedUser.id) || reportedUser.id === userId) {
    throw new ApiError(400, 'This connection cannot be reported.');
  }
  const existing = await maybeSingle(
    db()
      .from('connection_reports')
      .select('*')
      .eq('connection_id', connectionId)
      .eq('reporter_id', userId)
      .eq('reported_user_id', reportedUser.id),
  );
  if (existing) {
    throw new ApiError(409, 'You have already reported this connection.');
  }

  const { data, error } = await db()
    .from('connection_reports')
    .insert({
      connection_id: connectionId,
      reporter_id: userId,
      reported_user_id: reportedUser.id,
      reason_code: body.reasonCode?.toString() || 'safety_review',
      details: note,
    })
    .select('*')
    .single();
  assertDb(error);
  const event = await db()
    .from('connection_events')
    .insert({
      connection_id: connectionId,
      actor_id: userId,
      event_type: 'reported',
      previous_status: current.status,
      next_status: current.status,
      note,
    });
  assertDb(event.error);
  await logActivity({
    actorId: userId,
    action: 'connection_reported',
    entityType: 'connection_report',
    entityId: data.id,
    title: 'Safety report opened',
    body: 'Connection safety report opened.',
  });
  await touchConnection(connectionId);
  publishAppEvent(connectionParticipants(current), {
    type: 'connection_changed',
    payload: { connectionId, status: current.status, actorId: userId },
  });
  return data;
}
