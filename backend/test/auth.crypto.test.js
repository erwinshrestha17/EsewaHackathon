import assert from 'node:assert/strict';
import test from 'node:test';

import { hashMpin, normalizeNepalMobile } from '../src/modules/auth/auth.service.js';

test('hashMpin stores M-PIN as PBKDF2 metadata, not plaintext', () => {
  const encoded = hashMpin('1234', 'test-salt');

  assert.match(encoded, /^pbkdf2_sha256\$120000\$test-salt\$/);
  assert.equal(encoded.includes('$1234'), false);
});

test('hashMpin changes when salt changes', () => {
  assert.notEqual(hashMpin('1234', 'salt-a'), hashMpin('1234', 'salt-b'));
});

test('normalizeNepalMobile treats +977 as display-only country code', () => {
  assert.equal(normalizeNepalMobile('9800000001'), '9800000001');
  assert.equal(normalizeNepalMobile('+977 9800000001'), '9800000001');
  assert.equal(normalizeNepalMobile('9779800000001'), '9800000001');
});
