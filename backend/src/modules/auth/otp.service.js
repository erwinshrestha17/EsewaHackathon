import crypto from 'node:crypto';

import { env } from '../../config/env.js';
import { redisDelete, redisGetJson, redisSetJson } from '../../config/redis.js';
import { ApiError } from '../../utils/ApiError.js';
import { sendSignupOtpSms } from './twilio.service.js';

const maxOtpAttempts = 5;

function otpKey(phone) {
  return `auth:otp:signup:${phone}`;
}

function otpHash(phone, otp) {
  return crypto
    .createHmac('sha256', env.authAccessTokenSecret)
    .update(`${phone}:${otp}`)
    .digest('base64url');
}

function equalHash(a, b) {
  if (!a || !b || a.length !== b.length) {
    return false;
  }
  return crypto.timingSafeEqual(Buffer.from(a), Buffer.from(b));
}

export function generateOtp() {
  return crypto.randomInt(100000, 1000000).toString();
}

export async function sendSignupOtp(phone) {
  let existing;
  try {
    existing = await redisGetJson(otpKey(phone));
  } catch (_error) {
    throw new ApiError(503, 'OTP cache is unavailable.');
  }

  const now = Date.now();
  if (existing?.resendAllowedAt && existing.resendAllowedAt > now) {
    throw new ApiError(429, 'Please wait before requesting another OTP.');
  }

  const otp = generateOtp();
  const payload = {
    phone,
    otpHash: otpHash(phone, otp),
    attempts: 0,
    createdAt: now,
    resendAllowedAt: now + env.otpResendCooldownSeconds * 1000,
  };

  try {
    await redisSetJson(otpKey(phone), payload, env.otpTtlMinutes * 60);
  } catch (_error) {
    throw new ApiError(503, 'OTP cache is unavailable.');
  }

  try {
    await sendSignupOtpSms(phone, otp);
  } catch (error) {
    await redisDelete(otpKey(phone)).catch(() => {});
    throw error;
  }
}

export async function verifySignupOtp(phone, otp) {
  let challenge;
  try {
    challenge = await redisGetJson(otpKey(phone));
  } catch (_error) {
    throw new ApiError(503, 'OTP cache is unavailable.');
  }

  if (!challenge) {
    throw new ApiError(401, 'OTP is invalid or expired.');
  }
  if (challenge.attempts >= maxOtpAttempts) {
    await redisDelete(otpKey(phone)).catch(() => {});
    throw new ApiError(401, 'OTP is invalid or expired.');
  }

  if (!equalHash(challenge.otpHash, otpHash(phone, otp))) {
    challenge.attempts += 1;
    const elapsedSeconds = Math.max(1, Math.floor((Date.now() - challenge.createdAt) / 1000));
    const ttlSeconds = Math.max(1, env.otpTtlMinutes * 60 - elapsedSeconds);
    await redisSetJson(otpKey(phone), challenge, ttlSeconds).catch(() => {});
    throw new ApiError(401, 'OTP is invalid or expired.');
  }

  await redisDelete(otpKey(phone)).catch(() => {});
}
