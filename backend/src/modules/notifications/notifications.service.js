import { db, assertDb } from '../common/db.js';
import { notificationDto } from '../common/mappers.js';

export async function listNotifications(userId) {
  const { data, error } = await db()
    .from('notifications')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false });
  assertDb(error);
  return data.map(notificationDto);
}

export async function markRead(userId, notificationId) {
  const { data, error } = await db()
    .from('notifications')
    .update({ is_read: true })
    .eq('user_id', userId)
    .eq('id', notificationId)
    .select()
    .single();
  assertDb(error);
  return notificationDto(data);
}

export async function markAllRead(userId) {
  const { error } = await db()
    .from('notifications')
    .update({ is_read: true })
    .eq('user_id', userId)
    .eq('is_read', false);
  assertDb(error);
}
