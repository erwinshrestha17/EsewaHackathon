import rateLimit from 'express-rate-limit';
import { Router } from 'express';
import { z } from 'zod';

import { bearerToken, authenticateUser } from '../../middleware/auth.middleware.js';
import { asyncHandler } from '../../utils/asyncHandler.js';
import { ApiError } from '../../utils/ApiError.js';
import {
  currentProfile,
  deleteCurrentProfile,
  login,
  logoutAllSessions,
  logoutSession,
  refreshSession,
  requestSignupOtp,
  signup,
  updateCurrentProfile,
} from './auth.service.js';

export const authRouter = Router();

const phone = z.string().min(1, 'phone is required.');
const mpin = z.string().regex(/^\d{4}$/, 'mPin must be a 4-digit PIN.');
const otp = z.string().regex(/^\d{6}$/, 'otp must be a 6-digit code.');
const refreshToken = z.string().min(1, 'refreshToken is required.');

const otpLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many OTP requests. Try again later.' },
});

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 30,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many auth attempts. Try again later.' },
});

function validateBody(schema) {
  return (req, _res, next) => {
    const result = schema.safeParse(req.body ?? {});
    if (!result.success) {
      next(new ApiError(400, result.error.issues[0]?.message ?? 'Invalid request body.'));
      return;
    }
    req.body = result.data;
    next();
  };
}

authRouter.post(
  '/auth/signup/otp',
  otpLimiter,
  validateBody(z.object({ phone })),
  asyncHandler(async (req, res) => {
    res.status(202).json(await requestSignupOtp(req.body));
  }),
);

authRouter.post(
  '/auth/signup',
  authLimiter,
  validateBody(
    z.object({
      phone,
      otp,
      mPin: mpin,
      fullName: z.string().min(2, 'fullName is required.').max(120),
      dateOfBirth: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'dateOfBirth must be YYYY-MM-DD.'),
      district: z.string().max(80).optional().nullable(),
    }),
  ),
  asyncHandler(async (req, res) => {
    res.status(201).json(await signup(req.body, req));
  }),
);

authRouter.post(
  '/auth/login',
  authLimiter,
  validateBody(z.object({ phone, mPin: mpin })),
  asyncHandler(async (req, res) => {
    res.json(await login(req.body, req));
  }),
);

authRouter.post(
  '/auth/refresh',
  authLimiter,
  validateBody(z.object({ refreshToken })),
  asyncHandler(async (req, res) => {
    res.json(await refreshSession(req.body, req));
  }),
);

authRouter.post(
  '/auth/logout',
  asyncHandler(async (req, res) => {
    await logoutSession({
      accessToken: bearerToken(req),
      refreshToken: req.body?.refreshToken?.toString(),
    });
    res.status(204).end();
  }),
);

authRouter.post(
  '/auth/logout-all',
  authenticateUser,
  asyncHandler(async (req, res) => {
    await logoutAllSessions(req.userProfile.id);
    res.status(204).end();
  }),
);

authRouter.get(
  '/me',
  authenticateUser,
  asyncHandler(async (req, res) => {
    res.json({ profile: currentProfile(req) });
  }),
);

authRouter.patch(
  '/me',
  authenticateUser,
  asyncHandler(async (req, res) => {
    res.json({ profile: await updateCurrentProfile(req.userProfile.id, req.body) });
  }),
);

authRouter.delete(
  '/me',
  authenticateUser,
  asyncHandler(async (req, res) => {
    res.json({ profile: await deleteCurrentProfile(req.userProfile.id) });
  }),
);
