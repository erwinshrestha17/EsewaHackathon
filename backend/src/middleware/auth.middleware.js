import { profileForAccessToken } from '../modules/auth/auth.service.js';
import { ApiError } from '../utils/ApiError.js';

export function bearerToken(req) {
  const header = req.headers.authorization ?? '';
  const [scheme, token] = header.split(' ');
  return /^bearer$/i.test(scheme) ? token : null;
}

async function resolveUser(req, required) {
  const token = bearerToken(req);
  if (!token) {
    if (required) {
      throw new ApiError(401, 'Missing bearer token.');
    }
    return null;
  }
  return profileForAccessToken(token);
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
