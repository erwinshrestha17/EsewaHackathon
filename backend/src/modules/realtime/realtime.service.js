import { assertDb, db } from '../common/db.js';

const clientsByUser = new Map();

let groupMemberResolver = defaultGroupMemberIds;
let logger = console;

function isOpen(client) {
  return client.readyState === undefined || client.readyState === 1;
}

function sendJson(client, message) {
  if (!isOpen(client)) {
    return;
  }
  try {
    client.send(JSON.stringify(message));
  } catch (error) {
    logger.error?.('Realtime websocket send failed:', error);
  }
}

function removeClient(userId, client) {
  const clients = clientsByUser.get(userId);
  if (!clients) {
    return;
  }
  clients.delete(client);
  if (clients.size === 0) {
    clientsByUser.delete(userId);
  }
}

export function registerRealtimeClient(userId, client) {
  const clients = clientsByUser.get(userId) ?? new Set();
  clients.add(client);
  clientsByUser.set(userId, clients);

  const cleanup = () => removeClient(userId, client);
  client.once?.('close', cleanup);
  client.once?.('error', cleanup);
  return cleanup;
}

export function publishAppEvent(userIds, { type, payload = {} }) {
  const delivered = new Set();
  for (const userId of userIds.filter(Boolean)) {
    const clients = clientsByUser.get(userId);
    if (!clients) {
      continue;
    }
    for (const client of clients) {
      if (delivered.has(client)) {
        continue;
      }
      delivered.add(client);
      sendJson(client, { type, data: payload });
    }
  }
}

async function defaultGroupMemberIds(groupId) {
  const { data, error } = await db()
    .from('group_members')
    .select('user_id')
    .eq('group_id', groupId)
    .in('status', ['active', 'invited']);
  assertDb(error);
  return (data ?? []).map((row) => row.user_id);
}

async function emitGroupEvent(groupId, { type, payload = {} }, { extraUserIds = [] } = {}) {
  const memberIds = await groupMemberResolver(groupId);
  const userIds = [...new Set([...(memberIds ?? []), ...extraUserIds].filter(Boolean))];
  publishAppEvent(userIds, { type, payload: { groupId, ...payload } });
}

export function publishGroupEvent(groupId, event, options = {}) {
  queueMicrotask(() => {
    void emitGroupEvent(groupId, event, options).catch((error) => {
      logger.error?.('Realtime group fanout failed:', error);
    });
  });
}

export function publishUserEvent(userId, { type, payload = {} }) {
  publishAppEvent([userId], { type, payload });
}

export function setRealtimeGroupMemberResolverForTesting(resolver) {
  const previous = groupMemberResolver;
  groupMemberResolver = resolver;
  return () => {
    groupMemberResolver = previous;
  };
}

export function setRealtimeLoggerForTesting(nextLogger) {
  const previous = logger;
  logger = nextLogger;
  return () => {
    logger = previous;
  };
}

export function clearRealtimeClientsForTesting() {
  clientsByUser.clear();
}
