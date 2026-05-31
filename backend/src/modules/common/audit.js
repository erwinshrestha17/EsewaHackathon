import { db, assertDb } from './db.js';

function runAfterResponse(label, task) {
  queueMicrotask(() => {
    void task().catch((error) => {
      console.error(`${label} failed:`, error.message ?? error);
    });
  });
}

export function logActivity({
  groupId = null,
  actorId,
  action,
  entityType,
  entityId = null,
  title,
  body,
  metadata = {},
}) {
  runAfterResponse('Activity log write', async () => {
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
  });
}

export function createNotification({
  userId,
  title,
  body,
  type,
  metadata = {},
}) {
  runAfterResponse('Notification write', async () => {
    const { error } = await db().from('notifications').insert({
      user_id: userId,
      title,
      body,
      type,
      metadata,
    });
    assertDb(error);
  });
}
