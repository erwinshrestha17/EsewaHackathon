import crypto from 'node:crypto';

import jwt from 'jsonwebtoken';

import { env } from '../../config/env.js';
import { redisDelete, redisGetJson, redisSetJson } from '../../config/redis.js';
import { ApiError } from '../../utils/ApiError.js';
import { assertDb, db, maybeSingle } from '../common/db.js';
import { profileDto } from '../common/mappers.js';
import { publishUserEvent } from '../realtime/realtime.service.js';
import { sendSignupOtp, verifySignupOtp } from './otp.service.js';

const mpinIterations = 120000;
const issuer = 'sajha-kharcha-api';
const audience = 'sajha-kharcha-app';

export function normalizeNepalMobile(value) {
  let digits = value?.toString().replace(/\D/g, '') ?? '';
  if (digits.startsWith('977') && digits.length > 10) {
    digits = digits.slice(3);
  }
  return /^9[678]\d{8}$/.test(digits) ? digits : null;
}

function assertMpin(value) {
  const pin = value?.toString().trim() ?? '';
  if (!/^\d{4}$/.test(pin)) {
    throw new ApiError(400, 'Enter a valid 4-digit M-PIN.');
  }
  return pin;
}

function assertOtp(value) {
  const otp = value?.toString().trim() ?? '';
  if (!/^\d{6}$/.test(otp)) {
    throw new ApiError(400, 'Enter the 6-digit OTP.');
  }
  return otp;
}

function assertFullName(value) {
  const name = value?.toString().trim() ?? '';
  if (name.length < 2 || name.length > 120) {
    throw new ApiError(400, 'Enter your full name.');
  }
  return name;
}

function assertDateOfBirth(value) {
  const text = value?.toString().trim() ?? '';
  const parsed = /^\d{4}-\d{2}-\d{2}$/.test(text) ? new Date(`${text}T00:00:00Z`) : null;
  if (!parsed || Number.isNaN(parsed.getTime())) {
    throw new ApiError(400, 'Enter date of birth as YYYY-MM-DD.');
  }
  const today = new Date();
  const todayUtc = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate()));
  if (parsed > todayUtc) {
    throw new ApiError(400, 'Date of birth cannot be in future.');
  }
  return text;
}

export function hashMpin(mpin, salt = crypto.randomBytes(16).toString('base64url')) {
  const hash = crypto
    .pbkdf2Sync(mpin, salt, mpinIterations, 32, 'sha256')
    .toString('base64url');
  return `pbkdf2_sha256$${mpinIterations}$${salt}$${hash}`;
}

export function verifyMpin(mpin, encoded) {
  const [algorithm, iterations, salt, expected] = encoded?.split('$') ?? [];
  if (algorithm !== 'pbkdf2_sha256' || !iterations || !salt || !expected) {
    return false;
  }
  const actual = crypto
    .pbkdf2Sync(mpin, salt, Number(iterations), 32, 'sha256')
    .toString('base64url');
  if (actual.length !== expected.length) {
    return false;
  }
  return crypto.timingSafeEqual(Buffer.from(actual), Buffer.from(expected));
}

export function tokenHash(token) {
  return crypto.createHash('sha256').update(token).digest('base64url');
}

function secondsUntil(date) {
  return Math.max(1, Math.floor((new Date(date).getTime() - Date.now()) / 1000));
}

function futureIso({ minutes = 0, days = 0 } = {}) {
  return new Date(Date.now() + minutes * 60 * 1000 + days * 24 * 60 * 60 * 1000).toISOString();
}

function sessionKey(sessionId) {
  return `auth:session:${sessionId}`;
}

function authProfileDto(row) {
  return {
    id: row.id,
    profileId: row.id,
    displayName: row.full_name,
    phone: row.phone ?? '',
    esewaId: row.email ?? `${row.phone ?? row.id}@esewa`,
    district: row.district ?? '',
    avatarUrl: row.avatar_url,
    dateOfBirth: row.date_of_birth,
    phoneVerifiedAt: row.phone_verified_at,
    createdAt: row.created_at,
  };
}

function avatarInitials(fullName) {
  return fullName
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join('');
}

async function cacheSession(session) {
  try {
    await redisSetJson(
      sessionKey(session.id),
      {
        id: session.id,
        userId: session.user_id,
        refreshTokenExpiresAt: session.refresh_token_expires_at ?? session.expires_at,
        revokedAt: session.revoked_at,
      },
      secondsUntil(session.refresh_token_expires_at ?? session.expires_at),
    );
  } catch (_error) {
    // Postgres remains the source of truth; Redis failures should not make active sessions unusable.
  }
}

async function invalidateSessionCache(sessionId) {
  await redisDelete(sessionKey(sessionId)).catch(() => {});
}

function signAccessToken(profile, session) {
  const accessTokenExpiresAt = futureIso({ minutes: env.authAccessTokenTtlMinutes });
  const accessToken = jwt.sign(
    {
      typ: 'access',
      sid: session.id,
      phone: profile.phone,
    },
    env.authAccessTokenSecret,
    {
      subject: profile.id,
      issuer,
      audience,
      jwtid: crypto.randomBytes(16).toString('base64url'),
      expiresIn: `${env.authAccessTokenTtlMinutes}m`,
      header: { kid: 'access-v1' },
    },
  );
  return { accessToken, accessTokenExpiresAt };
}

function verifyAccessToken(accessToken) {
  try {
    const payload = jwt.verify(accessToken, env.authAccessTokenSecret, {
      issuer,
      audience,
    });
    if (payload?.typ !== 'access' || !payload.sub || !payload.sid) {
      throw new ApiError(401, 'Invalid or expired access token.');
    }
    return payload;
  } catch (error) {
    if (error instanceof ApiError) {
      throw error;
    }
    throw new ApiError(401, 'Invalid or expired access token.');
  }
}

function refreshToken() {
  return `sr_${crypto.randomBytes(48).toString('base64url')}`;
}

async function profileById(profileId) {
  const profile = await maybeSingle(db().from('profiles').select('*').eq('id', profileId));
  if (!profile) {
    throw new ApiError(401, 'Invalid or expired access token.');
  }
  return profile;
}

async function activeSessionById(sessionId, userId) {
  let cached;
  try {
    cached = await redisGetJson(sessionKey(sessionId));
  } catch (_error) {
    cached = null;
  }
  if (cached) {
    if (
      cached.userId !== userId ||
      cached.revokedAt ||
      new Date(cached.refreshTokenExpiresAt) <= new Date()
    ) {
      throw new ApiError(401, 'Invalid or expired access token.');
    }
    return cached;
  }

  const session = await maybeSingle(
    db()
      .from('app_sessions')
      .select('*')
      .eq('id', sessionId)
      .eq('user_id', userId)
      .is('revoked_at', null)
      .gt('expires_at', new Date().toISOString()),
  );
  if (!session) {
    throw new ApiError(401, 'Invalid or expired access token.');
  }
  await cacheSession(session);
  return session;
}

async function createTokenPair(profile, req) {
  const newRefreshToken = refreshToken();
  const refreshTokenHash = tokenHash(newRefreshToken);
  const refreshTokenExpiresAt = futureIso({ days: env.authRefreshTokenTtlDays });
  const accessTokenExpiresAt = futureIso({ minutes: env.authAccessTokenTtlMinutes });

  const { data: session, error } = await db()
    .from('app_sessions')
    .insert({
      user_id: profile.id,
      token_hash: refreshTokenHash,
      refresh_token_hash: refreshTokenHash,
      user_agent: req.headers['user-agent'] ?? null,
      ip_address: req.ip ?? null,
      expires_at: refreshTokenExpiresAt,
      access_token_expires_at: accessTokenExpiresAt,
      refresh_token_expires_at: refreshTokenExpiresAt,
    })
    .select()
    .single();
  assertDb(error);

  const access = signAccessToken(profile, session);
  await db()
    .from('app_sessions')
    .update({ access_token_expires_at: access.accessTokenExpiresAt })
    .eq('id', session.id);
  await cacheSession({ ...session, access_token_expires_at: access.accessTokenExpiresAt });

  return {
    ...access,
    refreshToken: newRefreshToken,
    refreshTokenExpiresAt,
    profile: authProfileDto(profile),
  };
}

async function revokeSession(sessionId, reason = 'logout') {
  const { error } = await db()
    .from('app_sessions')
    .update({
      revoked_at: new Date().toISOString(),
      revocation_reason: reason,
    })
    .eq('id', sessionId)
    .is('revoked_at', null);
  assertDb(error);
  await invalidateSessionCache(sessionId);
}

export function currentProfile(req) {
  return profileDto(req.userProfile);
}

export async function updateCurrentProfile(userId, body) {
  const payload = {};
  if (body.fullName !== undefined) payload.full_name = body.fullName?.trim();
  if (body.phone !== undefined) payload.phone = body.phone?.trim() || null;
  if (body.avatarUrl !== undefined) payload.avatar_url = body.avatarUrl?.trim() || null;
  if (body.avatarInitials !== undefined) {
    payload.avatar_initials = body.avatarInitials?.trim() || null;
  }
  if (body.district !== undefined) payload.district = body.district?.trim() || null;
  if (body.privacyMode !== undefined) payload.privacy_mode = body.privacyMode;

  const { data, error } = await db()
    .from('profiles')
    .update(payload)
    .eq('id', userId)
    .select()
    .single();
  assertDb(error);
  publishUserEvent(userId, {
    type: 'profile_changed',
    payload: { operation: 'updated' },
  });
  return profileDto(data);
}

export async function deleteCurrentProfile(userId) {
  const pending = await maybeSingle(
    db()
      .from('settlements')
      .select('id')
      .or(`payer_id.eq.${userId},payee_id.eq.${userId}`)
      .eq('status', 'pending')
      .limit(1),
  );
  if (pending) {
    throw new ApiError(409, 'Settle pending balances before deleting your account.');
  }

  await logoutAllSessions(userId);
  const { error: credentialError } = await db()
    .from('app_user_credentials')
    .delete()
    .eq('user_id', userId);
  assertDb(credentialError);
  const { data, error } = await db()
    .from('profiles')
    .update({
      full_name: 'Deleted Member',
      phone: null,
      email: null,
      avatar_url: null,
      avatar_initials: 'DM',
      district: null,
      privacy_mode: 'qr_invite_only',
    })
    .eq('id', userId)
    .select()
    .single();
  assertDb(error);
  publishUserEvent(userId, {
    type: 'profile_changed',
    payload: { operation: 'deleted' },
  });
  return profileDto(data);
}

export async function requestSignupOtp(body) {
  const phone = normalizeNepalMobile(body.phone);
  if (!phone) {
    throw new ApiError(400, 'Enter a valid Nepal mobile number.');
  }
  const existing = await maybeSingle(db().from('profiles').select('id').eq('phone', phone));
  if (existing) {
    throw new ApiError(409, 'Phone number is already registered. Please log in.');
  }
  await sendSignupOtp(phone);
  return {
    message: 'OTP sent for verification.',
    expiresInSeconds: env.otpTtlMinutes * 60,
    resendAfterSeconds: env.otpResendCooldownSeconds,
  };
}

export async function signup(body, req) {
  const phone = normalizeNepalMobile(body.phone);
  if (!phone) {
    throw new ApiError(400, 'Enter a valid Nepal mobile number.');
  }
  const otp = assertOtp(body.otp);
  const mpin = assertMpin(body.mPin);
  const fullName = assertFullName(body.fullName);
  const dateOfBirth = assertDateOfBirth(body.dateOfBirth);
  const district = body.district?.toString().trim() || null;

  await verifySignupOtp(phone, otp);

  const { data: profile, error } = await db()
    .rpc('register_app_user', {
      p_phone: phone,
      p_full_name: fullName,
      p_avatar_initials: avatarInitials(fullName),
      p_date_of_birth: dateOfBirth,
      p_district: district,
      p_mpin_hash: hashMpin(mpin),
    })
    .single();
  if (error?.code === '23505') {
    throw new ApiError(409, 'Phone number is already registered. Please log in.');
  }
  assertDb(error);

  return createTokenPair(profile, req);
}

export async function login(body, req) {
  const phone = normalizeNepalMobile(body.phone);
  if (!phone) {
    throw new ApiError(400, 'Enter a valid Nepal mobile number.');
  }
  const mpin = assertMpin(body.mPin);
  const { data, error } = await db()
    .from('profiles')
    .select('*, app_user_credentials(*)')
    .eq('phone', phone)
    .maybeSingle();
  assertDb(error);
  if (!data?.phone_verified_at || !data?.app_user_credentials) {
    throw new ApiError(401, 'Phone number or M-PIN is incorrect.');
  }

  const credentials = Array.isArray(data.app_user_credentials)
    ? data.app_user_credentials[0]
    : data.app_user_credentials;
  if (credentials.locked_until && new Date(credentials.locked_until) > new Date()) {
    throw new ApiError(423, 'M-PIN is temporarily locked. Try again later.');
  }
  if (!verifyMpin(mpin, credentials.mpin_hash)) {
    const failedAttempts = (credentials.failed_attempts ?? 0) + 1;
    await db()
      .from('app_user_credentials')
      .update({
        failed_attempts: failedAttempts,
        locked_until:
          failedAttempts >= 5 ? new Date(Date.now() + 15 * 60 * 1000).toISOString() : null,
      })
      .eq('user_id', data.id);
    throw new ApiError(401, 'Phone number or M-PIN is incorrect.');
  }

  await db()
    .from('app_user_credentials')
    .update({ failed_attempts: 0, locked_until: null })
    .eq('user_id', data.id);

  return createTokenPair(data, req);
}

export async function refreshSession(body, req) {
  const currentRefreshToken = body.refreshToken?.toString().trim();
  if (!currentRefreshToken?.startsWith('sr_')) {
    throw new ApiError(401, 'Invalid or expired refresh token.');
  }
  const currentHash = tokenHash(currentRefreshToken);
  const now = new Date().toISOString();

  const session = await maybeSingle(
    db()
      .from('app_sessions')
      .select('*, profiles(*)')
      .eq('refresh_token_hash', currentHash)
      .is('revoked_at', null)
      .gt('expires_at', now),
  );

  if (!session) {
    const reused = await maybeSingle(
      db()
        .from('app_sessions')
        .select('id')
        .eq('previous_refresh_token_hash', currentHash)
        .is('revoked_at', null)
    ).catch(() => null);
    if (reused?.id) {
      await revokeSession(reused.id, 'refresh_reuse_detected');
    }
    throw new ApiError(401, 'Invalid or expired refresh token.');
  }

  const profile = session.profiles;
  if (!profile) {
    await revokeSession(session.id, 'missing_profile');
    throw new ApiError(401, 'Invalid or expired refresh token.');
  }

  const nextRefreshToken = refreshToken();
  const nextRefreshHash = tokenHash(nextRefreshToken);
  const refreshTokenExpiresAt = session.refresh_token_expires_at ?? session.expires_at;
  const access = signAccessToken(profile, session);

  const { data: updatedSession, error } = await db()
    .from('app_sessions')
    .update({
      token_hash: nextRefreshHash,
      refresh_token_hash: nextRefreshHash,
      previous_refresh_token_hash: currentHash,
      access_token_expires_at: access.accessTokenExpiresAt,
      rotated_at: new Date().toISOString(),
      last_seen_at: new Date().toISOString(),
      user_agent: req.headers['user-agent'] ?? session.user_agent,
      ip_address: req.ip ?? session.ip_address,
    })
    .eq('id', session.id)
    .eq('refresh_token_hash', currentHash)
    .is('revoked_at', null)
    .select()
    .single();
  assertDb(error);
  await cacheSession(updatedSession);

  return {
    ...access,
    refreshToken: nextRefreshToken,
    refreshTokenExpiresAt,
    profile: authProfileDto(profile),
  };
}

export async function logoutSession({ accessToken, refreshToken: bodyRefreshToken }) {
  if (bodyRefreshToken?.startsWith('sr_')) {
    const session = await maybeSingle(
      db()
        .from('app_sessions')
        .select('id')
        .eq('refresh_token_hash', tokenHash(bodyRefreshToken))
        .is('revoked_at', null),
    );
    if (session) {
      await revokeSession(session.id, 'logout');
      return;
    }
  }

  if (accessToken) {
    try {
      const payload = verifyAccessToken(accessToken);
      await revokeSession(payload.sid, 'logout');
    } catch (_error) {
      // Logout is idempotent.
    }
  }
}

export async function logoutAllSessions(userId) {
  const { data: sessions, error } = await db()
    .from('app_sessions')
    .update({
      revoked_at: new Date().toISOString(),
      revocation_reason: 'logout_all',
    })
    .eq('user_id', userId)
    .is('revoked_at', null)
    .select('id');
  assertDb(error);
  await Promise.all((sessions ?? []).map((session) => invalidateSessionCache(session.id)));
}

export async function profileForAccessToken(accessToken) {
  const payload = verifyAccessToken(accessToken);
  await activeSessionById(payload.sid, payload.sub);
  const profile = await profileById(payload.sub);
  await db()
    .from('app_sessions')
    .update({ last_seen_at: new Date().toISOString() })
    .eq('id', payload.sid)
    .is('revoked_at', null);
  return profile;
}
