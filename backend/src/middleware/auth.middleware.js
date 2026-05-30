import { env } from '../config/env.js';
import { supabaseAuthClient } from '../config/supabase.js';
import { db, isUuid, maybeSingle, single } from '../modules/common/db.js';
import { profileForAppSession } from '../modules/auth/auth.service.js';
import { ApiError } from '../utils/ApiError.js';

function bearerToken(req) {
  const header = req.headers.authorization ?? '';
  const [scheme, token] = header.split(' ');
  return /^bearer$/i.test(scheme) ? token : null;
}

async function profileForAuthUser(authUser) {
  const existing = await maybeSingle(
    db().from('profiles').select('*').eq('auth_user_id', authUser.id),
  );
  if (existing) {
    return existing;
  }

  const name =
    authUser.user_metadata?.full_name ??
    authUser.user_metadata?.name ??
    authUser.email ??
    authUser.phone ??
    'Sajha User';
  const { data, error } = await db()
    .from('profiles')
    .insert({
      auth_user_id: authUser.id,
      full_name: name,
      phone: authUser.phone ?? null,
      avatar_url: authUser.user_metadata?.avatar_url ?? null,
      avatar_initials: name
        .split(/\s+/)
        .filter(Boolean)
        .slice(0, 2)
        .map((part) => part[0]?.toUpperCase())
        .join(''),
    })
    .select()
    .single();
  if (error) {
    throw new ApiError(500, error.message, error);
  }
  return data;
}

async function demoProfile(req) {
  const id = req.headers['x-demo-user-id']?.toString() || env.demoUserId;
  let query = db().from('profiles').select('*');
  query = isUuid(id) ? query.eq('id', id) : query.eq('legacy_user_id', id);
  return single(query, 'Demo user profile not found. Run the seed SQL first.');
}

async function resolveUser(req, required) {
  const token = bearerToken(req);
  if (token) {
    if (token.startsWith('sajha_')) {
      const profile = await profileForAppSession(token);
      if (!profile) {
        throw new ApiError(401, 'Invalid or expired app session.');
      }
      return profile;
    }
    const { data, error } = await supabaseAuthClient().auth.getUser(token);
    if (error || !data?.user) {
      throw new ApiError(401, 'Invalid or expired access token.');
    }
    return profileForAuthUser(data.user);
  }

  if (env.allowDemoAuth) {
    return demoProfile(req);
  }

  if (required) {
    throw new ApiError(401, 'Missing bearer token.');
  }
  return null;
}

export async function authenticateUser(req, _res, next) {
  try {
    req.userProfile = await resolveUser(req, true);
    next();
  } catch (error) {
    next(error);
  }
}

export async function optionalAuth(req, _res, next) {
  try {
    req.userProfile = await resolveUser(req, false);
    next();
  } catch (_error) {
    next();
  }
}
