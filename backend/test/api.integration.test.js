import assert from 'node:assert/strict';
import test from 'node:test';

import { app } from '../src/app.js';
import { env } from '../src/config/env.js';

const runRemoteTests = process.env.RUN_REMOTE_API_TESTS === 'true';

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
  'remote API smoke: login, profile, groups, community savings balance',
  { skip: !runRemoteTests || !env.hasSupabaseConfig },
  async () => {
    await withServer(async (baseUrl) => {
      const login = await fetch(`${baseUrl}/api/auth/mpin/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone: '9800000001', mPin: '1234' }),
      });
      assert.equal(login.status, 200);
      const session = await json(login);
      assert.match(session.accessToken, /^sajha_/);

      const authHeaders = { Authorization: `Bearer ${session.accessToken}` };
      const me = await fetch(`${baseUrl}/api/me`, { headers: authHeaders });
      assert.equal(me.status, 200);
      assert.equal((await json(me)).profile.phone, '9800000001');

      const groups = await fetch(`${baseUrl}/api/groups`, { headers: authHeaders });
      assert.equal(groups.status, 200);
      assert.ok((await json(groups)).groups.length >= 1);

      const balance = await fetch(
        `${baseUrl}/api/community-savings/d-family-dashain/balance`,
        { headers: authHeaders },
      );
      assert.equal(balance.status, 200);
      assert.equal((await json(balance)).balance, 380000);
    });
  },
);

test(
  'remote API auth rejects incorrect M-PIN',
  { skip: !runRemoteTests || !env.hasSupabaseConfig },
  async () => {
    await withServer(async (baseUrl) => {
      const response = await fetch(`${baseUrl}/api/auth/mpin/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone: '9800000001', mPin: '9999' }),
      });
      assert.equal(response.status, 401);
    });
  },
);

test(
  'remote API community savings admin flow: submit, confirm, waive, expense',
  { skip: !runRemoteTests || !env.hasSupabaseConfig },
  async () => {
    await withServer(async (baseUrl) => {
      const login = await fetch(`${baseUrl}/api/auth/mpin/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone: '9800000001', mPin: '1234' }),
      });
      const session = await json(login);
      const authHeaders = {
        Authorization: `Bearer ${session.accessToken}`,
        'Content-Type': 'application/json',
      };
      const savingsGroupId = 'd-family-dashain';

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
