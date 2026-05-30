import { env } from '../../config/env.js';
import { ApiError } from '../../utils/ApiError.js';

let testPublisher;

export function setSmsPublisherForTests(publisher) {
  testPublisher = publisher;
}

function twilioMessageUrl() {
  const accountSid = encodeURIComponent(env.twilioAccountSid);
  return `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`;
}

function twilioAuthHeader() {
  const credentials = Buffer.from(`${env.twilioAccountSid}:${env.twilioAuthToken}`).toString(
    'base64',
  );
  return `Basic ${credentials}`;
}

async function twilioErrorDetails(response) {
  const fallback = { status: response.status };
  try {
    const payload = await response.json();
    return {
      status: response.status,
      code: payload?.code,
      message: payload?.message,
      moreInfo: payload?.more_info,
    };
  } catch (_error) {
    return fallback;
  }
}

export async function sendSignupOtpSms(phone, otp) {
  if (testPublisher) {
    await testPublisher({ phone, otp });
    return;
  }
  if (!env.hasTwilioSmsConfig) {
    throw new ApiError(503, 'OTP delivery is not configured.');
  }

  const body = new URLSearchParams({
    To: `+977${phone}`,
    Body: `Your Sajha Kharcha signup OTP is ${otp}. It expires in ${env.otpTtlMinutes} minutes.`,
  });

  if (env.twilioMessagingServiceSid) {
    body.set('MessagingServiceSid', env.twilioMessagingServiceSid);
  } else {
    body.set('From', env.twilioFromPhoneNumber);
  }

  try {
    const response = await fetch(twilioMessageUrl(), {
      method: 'POST',
      headers: {
        Authorization: twilioAuthHeader(),
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body,
    });

    if (!response.ok) {
      throw new ApiError(502, 'Unable to send OTP right now.', await twilioErrorDetails(response));
    }
  } catch (error) {
    if (error instanceof ApiError) {
      throw error;
    }
    throw new ApiError(502, 'Unable to send OTP right now.');
  }
}
