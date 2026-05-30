import { Router } from 'express';

import { authenticateUser } from '../../middleware/auth.middleware.js';
import { asyncHandler } from '../../utils/asyncHandler.js';
import {
  currentProfile,
  loginWithMpin,
  logoutSession,
  registerWithMpin,
  updateCurrentProfile,
} from './auth.service.js';

export const authRouter = Router();

function bearerToken(req) {
  const header = req.headers.authorization ?? '';
  const [scheme, token] = header.split(' ');
  return /^bearer$/i.test(scheme) ? token : null;
}

authRouter.post(
  '/auth/mpin/login',
  asyncHandler(async (req, res) => {
    res.json(await loginWithMpin(req.body, req));
  }),
);

authRouter.post(
  '/auth/mpin/register',
  asyncHandler(async (req, res) => {
    res.status(201).json(await registerWithMpin(req.body, req));
  }),
);

authRouter.post(
  '/auth/logout',
  asyncHandler(async (req, res) => {
    await logoutSession(bearerToken(req));
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
