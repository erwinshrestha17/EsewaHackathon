import { db, assertDb } from '../common/db.js';
import { activityDto } from '../common/mappers.js';

export async function listActivityLogs(userId, groupId) {
  let query = db()
    .from('activity_logs')
    .select('*, groups!left(*)')
    .eq('actor_id', userId)
    .order('created_at', { ascending: false })
    .limit(100);
  if (groupId) query = query.eq('group_id', groupId);
  const { data, error } = await query;
  assertDb(error);
  return data.map(activityDto);
}
