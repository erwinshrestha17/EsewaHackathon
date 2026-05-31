import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import test from 'node:test';
import WebSocket from 'ws';

import { app, isAllowedCorsOrigin } from '../src/app.js';
import { env } from '../src/config/env.js';
import { db } from '../src/modules/common/db.js';
import {
  clearRealtimeClientsForTesting,
  publishAppEvent,
  publishGroupEvent,
  setRealtimeGroupMemberResolverForTesting,
} from '../src/modules/realtime/realtime.service.js';
import {
  attachRealtimeWebSocketServer,
  setRealtimeWebSocketAuthenticatorForTesting,
} from '../src/modules/realtime/realtime.websocket.js';
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

async function withRealtimeServer(fn) {
  const server = createServer(app);
  const wss = attachRealtimeWebSocketServer(server);
  await new Promise((resolve, reject) => {
    server.once('listening', resolve);
    server.once('error', reject);
    server.listen(0, '127.0.0.1');
  });
  const { port } = server.address();
  try {
    await fn(`ws://127.0.0.1:${port}/api/app/ws`);
  } finally {
    for (const client of wss.clients) {
      client.terminate();
    }
    await new Promise((resolve) => wss.close(resolve));
    await new Promise((resolve) => server.close(resolve));
    clearRealtimeClientsForTesting();
  }
}

async function json(response) {
  const text = await response.text();
  return text ? JSON.parse(text) : {};
}

function waitForJson(ws, timeoutMs = 1000) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      cleanup();
      reject(new Error('Timed out waiting for websocket message.'));
    }, timeoutMs);
    function cleanup() {
      clearTimeout(timer);
      ws.off('message', onMessage);
      ws.off('error', onError);
    }
    function onMessage(raw) {
      cleanup();
      try {
        resolve(JSON.parse(raw.toString()));
      } catch (error) {
        reject(error);
      }
    }
    function onError(error) {
      cleanup();
      reject(error);
    }
    ws.once('message', onMessage);
    ws.once('error', onError);
  });
}

function waitForNoMessage(ws, timeoutMs = 100) {
  return new Promise((resolve) => {
    const timer = setTimeout(() => {
      ws.off('message', onMessage);
      resolve(true);
    }, timeoutMs);
    function onMessage() {
      clearTimeout(timer);
      resolve(false);
    }
    ws.once('message', onMessage);
  });
}

async function openAuthenticatedSocket(url, token = 'access-token') {
  const ws = new WebSocket(url);
  await new Promise((resolve, reject) => {
    ws.once('open', resolve);
    ws.once('error', reject);
  });
  ws.send(JSON.stringify({ type: 'auth', accessToken: token }));
  const connected = await waitForJson(ws);
  assert.equal(connected.type, 'connected');
  return ws;
}

function waitForClose(ws) {
  return new Promise((resolve) => {
    ws.once('close', (code, reason) => resolve({ code, reason: reason.toString() }));
  });
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

test('realtime websocket authenticates and delivers only to subscribed users', async () => {
  const restoreAuth = setRealtimeWebSocketAuthenticatorForTesting(async (token) => {
    if (token === 'recipient-token') return { id: 'u-recipient' };
    if (token === 'other-token') return { id: 'u-other' };
    throw new ApiError(401, 'Invalid token.');
  });
  try {
    await withRealtimeServer(async (url) => {
      const recipient = await openAuthenticatedSocket(url, 'recipient-token');
      const other = await openAuthenticatedSocket(url, 'other-token');

      publishAppEvent(['u-recipient'], {
        type: 'connection_changed',
        payload: { connectionId: 'conn-1', status: 'approved' },
      });

      const message = await waitForJson(recipient);
      assert.deepEqual(message, {
        type: 'connection_changed',
        data: { connectionId: 'conn-1', status: 'approved' },
      });
      assert.equal(await waitForNoMessage(other), true);

      recipient.close();
      other.close();
    });
  } finally {
    restoreAuth();
  }
});

test('realtime websocket closes invalid auth messages', async () => {
  const restoreAuth = setRealtimeWebSocketAuthenticatorForTesting(async () => {
    throw new ApiError(401, 'Invalid token.');
  });
  try {
    await withRealtimeServer(async (url) => {
      const ws = new WebSocket(url);
      await new Promise((resolve, reject) => {
        ws.once('open', resolve);
        ws.once('error', reject);
      });
      const closed = waitForClose(ws);
      ws.send(JSON.stringify({ type: 'auth', accessToken: 'bad-token' }));
      assert.equal((await closed).code, 4003);
    });
  } finally {
    restoreAuth();
  }
});

test('realtime group fanout is scheduled without blocking callers', async () => {
  const restoreAuth = setRealtimeWebSocketAuthenticatorForTesting(async () => ({ id: 'u-recipient' }));
  let resolverStarted = false;
  let releaseResolver;
  const resolverGate = new Promise((resolve) => {
    releaseResolver = resolve;
  });
  const restoreMembers = setRealtimeGroupMemberResolverForTesting(async (groupId) => {
    resolverStarted = true;
    assert.equal(groupId, 'group-1');
    await resolverGate;
    return ['u-recipient'];
  });

  try {
    await withRealtimeServer(async (url) => {
      const recipient = await openAuthenticatedSocket(url);
      const message = waitForJson(recipient);

      publishGroupEvent('group-1', {
        type: 'expense_changed',
        payload: { expenseId: 'expense-1' },
      });
      assert.equal(resolverStarted, false);

      await Promise.resolve();
      assert.equal(resolverStarted, true);
      releaseResolver();

      assert.deepEqual(await message, {
        type: 'expense_changed',
        data: { groupId: 'group-1', expenseId: 'expense-1' },
      });
      recipient.close();
    });
  } finally {
    restoreMembers();
    restoreAuth();
  }
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
