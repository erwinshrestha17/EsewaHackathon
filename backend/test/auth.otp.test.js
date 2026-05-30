import assert from 'node:assert/strict';
import test from 'node:test';

import { env } from '../src/config/env.js';
import { setRedisClientForTests } from '../src/config/redis.js';
import { sendSignupOtp, verifySignupOtp } from '../src/modules/auth/otp.service.js';
import { setSnsPublisherForTests } from '../src/modules/auth/sns.service.js';

class FakeRedis {
  constructor() {
    this.values = new Map();
  }

  async get(key) {
    const item = this.values.get(key);
    if (!item) return null;
    if (item.expiresAt <= Date.now()) {
      this.values.delete(key);
      return null;
    }
    return item.value;
  }

  async set(key, value, options = {}) {
    this.values.set(key, {
      value,
      expiresAt: Date.now() + Number(options.EX ?? 60) * 1000,
    });
  }

  async del(key) {
    this.values.delete(key);
  }
}

test('signup OTP is hashed in Redis and can be verified once', async () => {
  const redis = new FakeRedis();
  let deliveredOtp;
  setRedisClientForTests(redis);
  setSnsPublisherForTests(async ({ otp }) => {
    deliveredOtp = otp;
  });

  await sendSignupOtp('9800000001');

  const stored = JSON.parse(await redis.get('auth:otp:signup:9800000001'));
  assert.equal(stored.phone, '9800000001');
  assert.notEqual(stored.otpHash, deliveredOtp);
  assert.match(deliveredOtp, /^\d{6}$/);

  await verifySignupOtp('9800000001', deliveredOtp);
  assert.equal(await redis.get('auth:otp:signup:9800000001'), null);

  setRedisClientForTests(null);
  setSnsPublisherForTests(null);
});

test('signup OTP fails closed when AWS SNS is not configured', async () => {
  const redis = new FakeRedis();
  const previous = env.hasAwsSnsConfig;
  env.hasAwsSnsConfig = false;
  setRedisClientForTests(redis);
  setSnsPublisherForTests(null);

  await assert.rejects(
    () => sendSignupOtp('9800000001'),
    /OTP delivery is not configured/,
  );
  assert.equal(await redis.get('auth:otp:signup:9800000001'), null);

  env.hasAwsSnsConfig = previous;
  setRedisClientForTests(null);
});
