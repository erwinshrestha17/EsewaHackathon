import jwt from 'jsonwebtoken';

import { env } from '../../config/env.js';
import { ApiError } from '../../utils/ApiError.js';
import { assertDb, db } from '../common/db.js';

const clientsByUser = new Map();
let broadcastSender = sendSupabaseBroadcast;
let topicResolver = defaultAuthorizedRealtimeTopics;

export function userTopic(userId) {
  return `user:${userId}`;
}

export function groupTopic(groupId) {
  return `group:${groupId}`;
}

function writeEvent(res, type, data = {}) {
  res.write(`event: ${type}\n`);
  res.write(`data: ${JSON.stringify(data)}\n\n`);
}

export function subscribeAppEvents(userId, req, res) {
  res.set({
    'Cache-Control': 'no-cache, no-transform',
    Connection: 'keep-alive',
    'Content-Type': 'text/event-stream',
    'X-Accel-Buffering': 'no',
  });
  res.flushHeaders?.();

  const clients = clientsByUser.get(userId) ?? new Set();
  clients.add(res);
  clientsByUser.set(userId, clients);

  writeEvent(res, 'connected', { userId });
  const heartbeat = setInterval(() => {
    res.write(': keep-alive\n\n');
  }, 25000);

  req.on('close', () => {
    clearInterval(heartbeat);
    clients.delete(res);
    if (clients.size === 0) {
      clientsByUser.delete(userId);
    }
  });
}

export function publishAppEvent(userIds, { type, payload = {} }) {
  const delivered = new Set();
  for (const userId of userIds.filter(Boolean)) {
    const clients = clientsByUser.get(userId);
    if (!clients) {
      continue;
    }
    for (const res of clients) {
      if (delivered.has(res)) {
        continue;
      }
      delivered.add(res);
      writeEvent(res, type, payload);
    }
  }
  publishRealtimeTopics(
    userIds.filter(Boolean).map((userId) => userTopic(userId)),
    { type, payload },
  );
}

async function defaultAuthorizedRealtimeTopics(userId) {
  const { data, error } = await db()
    .from('group_members')
    .select('group_id')
    .eq('user_id', userId)
    .in('status', ['active', 'invited']);
  assertDb(error);
  return [
    userTopic(userId),
    ...new Set((data ?? []).map((row) => groupTopic(row.group_id))),
  ];
}

export function authorizedRealtimeTopics(userId) {
  return topicResolver(userId);
}

export async function realtimeAuth(userId) {
  if (!env.hasSupabaseRealtimeConfig) {
    throw new ApiError(
      503,
      'Supabase realtime is not configured. Set SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, and SUPABASE_JWT_SECRET.',
    );
  }
  const expiresInSeconds = env.realtimeTokenTtlMinutes * 60;
  const expiresAt = new Date(Date.now() + expiresInSeconds * 1000).toISOString();
  const accessToken = jwt.sign(
    {
      role: 'authenticated',
    },
    env.supabaseJwtSecret,
    {
      subject: userId,
      audience: 'authenticated',
      expiresIn: expiresInSeconds,
    },
  );
  return {
    supabaseUrl: env.supabaseUrl,
    supabasePublishableKey: env.supabasePublishableKey,
    accessToken,
    expiresAt,
    expiresInSeconds,
    topics: await topicResolver(userId),
  };
}

export async function publishGroupEvent(groupId, { type, payload = {} }, { extraUserIds = [] } = {}) {
  const { data, error } = await db()
    .from('group_members')
    .select('user_id')
    .eq('group_id', groupId)
    .in('status', ['active', 'invited']);
  assertDb(error);
  const userIds = [...new Set([...(data ?? []).map((row) => row.user_id), ...extraUserIds])];
  publishAppEvent(userIds, { type, payload: { groupId, ...payload } });
  publishRealtimeTopics([groupTopic(groupId)], { type, payload: { groupId, ...payload } });
}

export function publishUserEvent(userId, { type, payload = {} }) {
  publishAppEvent([userId], { type, payload });
}

export function publishRealtimeTopics(topics, { type, payload = {} }) {
  const messages = [...new Set(topics.filter(Boolean))].map((topic) => ({
    topic,
    event: type,
    payload: {
      ...payload,
      type,
      topic,
      emittedAt: new Date().toISOString(),
    },
  }));
  if (messages.length === 0) {
    return;
  }
  void broadcastSender(messages).catch((error) => {
    console.error('Supabase realtime broadcast failed:', error);
  });
}

export function setRealtimeBroadcastSenderForTesting(sender) {
  const previous = broadcastSender;
  broadcastSender = sender;
  return () => {
    broadcastSender = previous;
  };
}

export function setRealtimeTopicResolverForTesting(resolver) {
  const previous = topicResolver;
  topicResolver = resolver;
  return () => {
    topicResolver = previous;
  };
}

async function sendSupabaseBroadcast(messages) {
  if (!env.supabaseUrl || !env.supabaseSecretKey) {
    return;
  }
  const response = await fetch(
    `${env.supabaseUrl.replace(/\/$/, '')}/realtime/v1/api/broadcast`,
    {
      method: 'POST',
      headers: {
        apikey: env.supabaseSecretKey,
        Authorization: `Bearer ${env.supabaseSecretKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ messages }),
    },
  );
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Realtime broadcast failed (${response.status}): ${body}`);
  }
}
