import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import test from 'node:test';

import { app, isAllowedCorsOrigin } from '../src/app.js';
import { env } from '../src/config/env.js';
import { db } from '../src/modules/common/db.js';
import {
  publishAppEvent,
  subscribeAppEvents,
} from '../src/modules/realtime/realtime.service.js';
import { ApiError } from '../src/utils/ApiError.js';

const runRemoteTests = process.env.RUN_REMOTE_API_TESTS === 'true';
const remoteAuthPhone = process.env.REMOTE_AUTH_PHONE;
const remoteAuthMpin = process.env.REMOTE_AUTH_MPIN;
const remoteSavingsGroupId = process.env.REMOTE_SAVINGS_GROUP_ID;

async function withServer(fn) {
  const server = app.listen(0, '127.0.0.1');
  await new Promise((resolve, reject) => {
    server.once('listening', resolve);
    server.once('error', reject);
  });
  const { port } = server.address();
  try {
    await fn(`http://127.0.0.1:${port}`);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

async function json(response) {
  const text = await response.text();
  return text ? JSON.parse(text) : {};
}

test(
  'development CORS accepts Flutter web loopback origins on dynamic ports',
  { skip: env.isProduction },
  async () => {
    await withServer(async (baseUrl) => {
      const response = await fetch(`${baseUrl}/api/auth/login`, {
        method: 'OPTIONS',
        headers: {
          Origin: 'http://localhost:54732',
          'Access-Control-Request-Method': 'POST',
          'Access-Control-Request-Headers': 'content-type',
        },
      });

      assert.equal(response.status, 204);
      assert.equal(response.headers.get('access-control-allow-origin'), 'http://localhost:54732');
    });
  },
);

test(
  'development CORS accepts private network Flutter web origins',
  { skip: env.isProduction },
  () => {
    assert.equal(isAllowedCorsOrigin('http://0.0.0.0:51234'), true);
    assert.equal(isAllowedCorsOrigin('http://192.168.1.25:51234'), true);
    assert.equal(isAllowedCorsOrigin('http://10.0.2.15:51234'), true);
    assert.equal(isAllowedCorsOrigin('http://172.20.0.3:51234'), true);
    assert.equal(isAllowedCorsOrigin('http://linux-devbox:51234'), true);
    assert.equal(isAllowedCorsOrigin('https://linux-devbox:51234'), true);
    assert.equal(isAllowedCorsOrigin('ftp://linux-devbox:51234'), false);
  },
);

test('database config failure is reported as a setup error', () => {
  const previous = env.hasSupabaseConfig;
  env.hasSupabaseConfig = false;
  try {
    assert.throws(
      () => db(),
      (error) =>
        error instanceof ApiError &&
        error.status === 503 &&
        error.message.includes('Backend database is not configured'),
    );
  } finally {
    env.hasSupabaseConfig = previous;
  }
});

test('realtime app events deliver only to subscribed users', () => {
  const req = new EventEmitter();
  const chunks = [];
  const res = {
    set(headers) {
      this.headers = headers;
    },
    flushHeaders() {},
    write(chunk) {
      chunks.push(chunk);
    },
  };

  subscribeAppEvents('u-recipient', req, res);
  publishAppEvent(['u-other'], {
    type: 'connection_changed',
    payload: { connectionId: 'conn-1' },
  });
  assert.equal(chunks.some((chunk) => chunk.includes('conn-1')), false);

  publishAppEvent(['u-recipient'], {
    type: 'connection_changed',
    payload: { connectionId: 'conn-1' },
  });
  assert.equal(chunks.some((chunk) => chunk.includes('event: connection_changed')), true);
  assert.equal(chunks.some((chunk) => chunk.includes('"connectionId":"conn-1"')), true);

  req.emit('close');
  const afterClose = chunks.length;
  publishAppEvent(['u-recipient'], {
    type: 'connection_changed',
    payload: { connectionId: 'conn-2' },
  });
  assert.equal(chunks.length, afterClose);
});

test(
  'remote API smoke: login, profile, groups, community savings balance',
  {
    skip:
      !runRemoteTests ||
      !env.hasSupabaseConfig ||
      !remoteAuthPhone ||
      !remoteAuthMpin ||
      !remoteSavingsGroupId,
  },
  async () => {
    await withServer(async (baseUrl) => {
      const login = await fetch(`${baseUrl}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone: remoteAuthPhone, mPin: remoteAuthMpin }),
      });
      assert.equal(login.status, 200);
      const session = await json(login);
      assert.equal(typeof session.accessToken, 'string');
      assert.match(session.refreshToken, /^sr_/);

      const authHeaders = { Authorization: `Bearer ${session.accessToken}` };
      const me = await fetch(`${baseUrl}/api/me`, { headers: authHeaders });
      assert.equal(me.status, 200);
      assert.equal((await json(me)).profile.phone, remoteAuthPhone);

      const groups = await fetch(`${baseUrl}/api/groups`, { headers: authHeaders });
      assert.equal(groups.status, 200);
      assert.ok((await json(groups)).groups.length >= 1);

      const balance = await fetch(
        `${baseUrl}/api/community-savings/${remoteSavingsGroupId}/balance`,
        { headers: authHeaders },
      );
      assert.equal(balance.status, 200);
      assert.equal(typeof (await json(balance)).balance, 'number');
    });
  },
);

test(
  'remote API auth rejects incorrect M-PIN',
  { skip: !runRemoteTests || !env.hasSupabaseConfig || !remoteAuthPhone },
  async () => {
    await withServer(async (baseUrl) => {
      const response = await fetch(`${baseUrl}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone: remoteAuthPhone, mPin: '9999' }),
      });
      assert.equal(response.status, 401);
    });
  },
);

test(
  'remote API community savings admin flow: submit, confirm, waive, expense',
  {
    skip:
      !runRemoteTests ||
      !env.hasSupabaseConfig ||
      !remoteAuthPhone ||
      !remoteAuthMpin ||
      !remoteSavingsGroupId,
  },
  async () => {
    await withServer(async (baseUrl) => {
      const login = await fetch(`${baseUrl}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone: remoteAuthPhone, mPin: remoteAuthMpin }),
      });
      const session = await json(login);
      const authHeaders = {
        Authorization: `Bearer ${session.accessToken}`,
        'Content-Type': 'application/json',
      };
      const savingsGroupId = remoteSavingsGroupId;

      const submitted = await fetch(
        `${baseUrl}/api/community-savings/${savingsGroupId}/contributions/submit`,
        {
          method: 'POST',
          headers: authHeaders,
          body: JSON.stringify({
            month: '2099-12',
            amountPaid: 500000,
            paymentMethod: 'cash',
            note: 'Integration test submission.',
          }),
        },
      );
      assert.equal(submitted.status, 200);
      const contribution = (await json(submitted)).contribution;
      assert.equal(contribution.status, 'submitted');

      const confirmed = await fetch(
        `${baseUrl}/api/community-savings/contributions/${contribution.id}/confirm`,
        {
          method: 'POST',
          headers: authHeaders,
          body: JSON.stringify({
            savingsGroupId,
            amountReceived: 500000,
            paymentMethod: 'cash',
            note: 'Integration test confirmation.',
          }),
        },
      );
      assert.equal(confirmed.status, 200);
      assert.equal((await json(confirmed)).contribution.status, 'confirmed_received');

      const waived = await fetch(
        `${baseUrl}/api/community-savings/contributions/${contribution.id}/waive`,
        {
          method: 'POST',
          headers: authHeaders,
          body: JSON.stringify({
            savingsGroupId,
            note: 'Integration test cleanup.',
          }),
        },
      );
      assert.equal(waived.status, 200);
      assert.equal((await json(waived)).contribution.status, 'waived');

      const expense = await fetch(
        `${baseUrl}/api/community-savings/${savingsGroupId}/expenses`,
        {
          method: 'POST',
          headers: authHeaders,
          body: JSON.stringify({
            title: 'Integration test supplies',
            amountSpent: 100,
            category: 'supplies',
            expenseDate: '2099-12-31',
            description: 'Remote API smoke test.',
          }),
        },
      );
      assert.equal(expense.status, 201);
      assert.equal((await json(expense)).expense.amount, 100);
    });
  },
);
