import { createClient } from 'redis';

import { env } from './env.js';

let client;
let connectPromise;
let testClient;
const redisOperationTimeoutMs = 1500;

export function setRedisClientForTests(nextClient) {
  testClient = nextClient;
}

export async function redisClient() {
  if (testClient) {
    return testClient;
  }
  if (!env.redisUrl) {
    return null;
  }
  if (!client) {
    client = createClient({
      url: env.redisUrl,
      socket: {
        connectTimeout: redisOperationTimeoutMs,
        reconnectStrategy: false,
      },
    });
    client.on('error', (error) => {
      if (env.isProduction) {
        console.error('Redis error:', error.message);
      }
    });
  }
  if (!client.isOpen) {
    connectPromise ??= withRedisTimeout(client.connect())
      .catch(async (error) => {
        await closeRedisClient();
        throw error;
      })
      .finally(() => {
        connectPromise = null;
      });
    await connectPromise;
  }
  return client;
}

export async function redisGetJson(key) {
  const activeClient = await redisClient();
  if (!activeClient) {
    return null;
  }
  const value = await withRedisTimeout(activeClient.get(key));
  return value ? JSON.parse(value) : null;
}

export async function redisSetJson(key, value, ttlSeconds) {
  const activeClient = await redisClient();
  if (!activeClient) {
    return false;
  }
  await withRedisTimeout(activeClient.set(key, JSON.stringify(value), { EX: ttlSeconds }));
  return true;
}

export async function redisDelete(key) {
  const activeClient = await redisClient();
  if (!activeClient) {
    return false;
  }
  await withRedisTimeout(activeClient.del(key));
  return true;
}

async function closeRedisClient() {
  const closingClient = client;
  client = null;
  connectPromise = null;
  if (!closingClient) {
    return;
  }
  try {
    if (closingClient.isOpen) {
      await closingClient.quit();
      return;
    }
    await closingClient.destroy();
  } catch (_error) {
    // A failed Redis close should not mask the original cache failure.
  }
}

async function withRedisTimeout(operation) {
  let timeout;
  const timeoutPromise = new Promise((_, reject) => {
    timeout = setTimeout(() => {
      reject(new Error('Redis operation timed out.'));
    }, redisOperationTimeoutMs);
  });
  try {
    return await Promise.race([operation, timeoutPromise]);
  } finally {
    clearTimeout(timeout);
  }
}
