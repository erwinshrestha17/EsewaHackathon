import { createClient } from 'redis';

import { env } from './env.js';

let client;
let connectPromise;
let testClient;

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
    client = createClient({ url: env.redisUrl });
    client.on('error', (error) => {
      if (env.isProduction) {
        console.error('Redis error:', error.message);
      }
    });
  }
  if (!client.isOpen) {
    connectPromise ??= client.connect().finally(() => {
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
  const value = await activeClient.get(key);
  return value ? JSON.parse(value) : null;
}

export async function redisSetJson(key, value, ttlSeconds) {
  const activeClient = await redisClient();
  if (!activeClient) {
    return false;
  }
  await activeClient.set(key, JSON.stringify(value), { EX: ttlSeconds });
  return true;
}

export async function redisDelete(key) {
  const activeClient = await redisClient();
  if (!activeClient) {
    return false;
  }
  await activeClient.del(key);
  return true;
}
