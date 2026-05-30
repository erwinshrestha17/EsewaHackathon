import { db, assertDb } from './db.js';

export async function logActivity({
  groupId = null,
  actorId,
  action,
  entityType,
  entityId = null,
  title,
  body,
  metadata = {},
}) {
  const { error } = await db().from('activity_logs').insert({
    group_id: groupId,
    actor_id: actorId,
    action,
    entity_type: entityType,
    entity_id: entityId,
    title,
    body,
    metadata,
  });
  assertDb(error);
}

export async function createNotification({
  userId,
  title,
  body,
  type,
  metadata = {},
}) {
  const { error } = await db().from('notifications').insert({
    user_id: userId,
    title,
    body,
    type,
    metadata,
  });
  assertDb(error);
}
