import assert from 'node:assert/strict';
import test from 'node:test';

import { env } from '../src/config/env.js';
import { sendSignupOtpSms, setSmsPublisherForTests } from '../src/modules/auth/twilio.service.js';

test('Twilio sender posts signup OTP as a form-encoded SMS request', async () => {
  const previousEnv = {
    twilioAccountSid: env.twilioAccountSid,
    twilioAuthToken: env.twilioAuthToken,
    twilioFromPhoneNumber: env.twilioFromPhoneNumber,
    twilioMessagingServiceSid: env.twilioMessagingServiceSid,
    hasTwilioSmsConfig: env.hasTwilioSmsConfig,
  };
  const previousFetch = globalThis.fetch;
  let request;

  env.twilioAccountSid = 'AC123';
  env.twilioAuthToken = 'secret';
  env.twilioFromPhoneNumber = '+15551234567';
  env.twilioMessagingServiceSid = undefined;
  env.hasTwilioSmsConfig = true;
  setSmsPublisherForTests(null);

  globalThis.fetch = async (url, options) => {
    request = { url, options };
    return { ok: true };
  };

  try {
    await sendSignupOtpSms('9800000001', '123456');

    assert.equal(
      request.url,
      'https://api.twilio.com/2010-04-01/Accounts/AC123/Messages.json',
    );
    assert.equal(request.options.method, 'POST');
    assert.equal(request.options.headers['Content-Type'], 'application/x-www-form-urlencoded');
    assert.equal(
      Buffer.from(request.options.headers.Authorization.replace('Basic ', ''), 'base64').toString(
        'utf8',
      ),
      'AC123:secret',
    );

    const params = new URLSearchParams(request.options.body);
    assert.equal(params.get('To'), '+9779800000001');
    assert.equal(params.get('From'), '+15551234567');
    assert.match(params.get('Body'), /123456/);
  } finally {
    Object.assign(env, previousEnv);
    globalThis.fetch = previousFetch;
  }
});
