import crypto from 'node:crypto';

import { ApiError } from '../../utils/ApiError.js';
import { db, assertDb } from '../common/db.js';
import { profileDto } from '../common/mappers.js';

const mpinIterations = 120000;
const sessionDays = 30;

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

function parseDateOfBirth(value) {
  if (value === undefined || value === null || value === '') {
    return null;
  }
  const text = value.toString().trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(text)) {
    throw new ApiError(400, 'Date of birth must be in YYYY-MM-DD format.');
  }
  const parsed = new Date(`${text}T00:00:00Z`);
  if (Number.isNaN(parsed.getTime())) {
    throw new ApiError(400, 'Enter a valid date of birth.');
  }
  if (parsed.getTime() > Date.now()) {
    throw new ApiError(400, 'Date of birth cannot be in the future.');
  }
  return text;
}

export function hashMpin(mpin, salt = crypto.randomBytes(16).toString('base64url')) {
  const hash = crypto
    .pbkdf2Sync(mpin, salt, mpinIterations, 32, 'sha256')
    .toString('base64url');
  return `pbkdf2_sha256$${mpinIterations}$${salt}$${hash}`;
}

function verifyMpin(mpin, encoded) {
  const [algorithm, iterations, salt, expected] = encoded.split('$');
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

function sessionExpiry() {
  return new Date(Date.now() + sessionDays * 24 * 60 * 60 * 1000).toISOString();
}

function tokenHash(token) {
  return crypto.createHash('sha256').update(token).digest('base64url');
}

function authProfileDto(row) {
  return {
    id: row.legacy_user_id ?? row.id,
    profileId: row.id,
    displayName: row.full_name,
    phone: row.phone ?? '',
    esewaId: row.email ?? `${row.phone ?? row.id}@esewa`,
    district: row.district ?? '',
    avatarUrl: row.avatar_url,
    dateOfBirth: row.date_of_birth ?? null,
    createdAt: row.created_at,
  };
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
  return profileDto(data);
}

export async function loginWithMpin(body, req) {
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
  if (!data?.app_user_credentials) {
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
          failedAttempts >= 5
            ? new Date(Date.now() + 15 * 60 * 1000).toISOString()
            : null,
      })
      .eq('user_id', data.id);
    throw new ApiError(401, 'Phone number or M-PIN is incorrect.');
  }

  await db()
    .from('app_user_credentials')
    .update({ failed_attempts: 0, locked_until: null })
    .eq('user_id', data.id);

  const token = `sajha_${crypto.randomBytes(32).toString('base64url')}`;
  const { data: session, error: sessionError } = await db()
    .from('app_sessions')
    .insert({
      user_id: data.id,
      token_hash: tokenHash(token),
      user_agent: req.headers['user-agent'] ?? null,
      ip_address: req.ip ?? null,
      expires_at: sessionExpiry(),
    })
    .select()
    .single();
  assertDb(sessionError);

  return {
    accessToken: token,
    expiresAt: session.expires_at,
    profile: authProfileDto(data),
  };
}

export async function registerWithMpin(body, req) {
  const phone = normalizeNepalMobile(body.phone ?? body.mobileNumber);
  if (!phone) {
    throw new ApiError(400, 'Enter a valid Nepal mobile number.');
  }
  const mpin = assertMpin(body.mPin);
  const fullName = body.fullName?.trim();
  if (!fullName) {
    throw new ApiError(400, 'Enter your full name.');
  }
  const dateOfBirth = parseDateOfBirth(body.dateOfBirth);
  const { data: profile, error } = await db()
    .from('profiles')
    .upsert(
      {
        phone,
        full_name: fullName,
        avatar_initials: fullName
          .split(/\s+/)
          .filter(Boolean)
          .slice(0, 2)
          .map((part) => part[0]?.toUpperCase())
          .join(''),
        district: body.district?.trim() || null,
        date_of_birth: dateOfBirth,
      },
      { onConflict: 'phone' },
    )
    .select()
    .single();
  assertDb(error);

  const { error: credentialError } = await db()
    .from('app_user_credentials')
    .upsert(
      {
        user_id: profile.id,
        mpin_hash: hashMpin(mpin),
        failed_attempts: 0,
        locked_until: null,
      },
      { onConflict: 'user_id' },
    );
  assertDb(credentialError);

  return loginWithMpin({ phone, mPin: mpin }, req);
}

export async function logoutSession(token) {
  if (!token?.startsWith('sajha_')) {
    return;
  }
  const { error } = await db()
    .from('app_sessions')
    .update({ revoked_at: new Date().toISOString() })
    .eq('token_hash', tokenHash(token))
    .is('revoked_at', null);
  assertDb(error);
}

export async function profileForAppSession(token) {
  const { data, error } = await db()
    .from('app_sessions')
    .select('*, profiles(*)')
    .eq('token_hash', tokenHash(token))
    .is('revoked_at', null)
    .gt('expires_at', new Date().toISOString())
    .maybeSingle();
  assertDb(error);
  if (!data?.profiles) {
    return null;
  }
  await db()
    .from('app_sessions')
    .update({ last_seen_at: new Date().toISOString() })
    .eq('id', data.id);
  return data.profiles;
}
