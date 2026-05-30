import { Router } from 'express';

import { asyncHandler } from '../../utils/asyncHandler.js';
import { getSettings, updateSettings } from './settings.service.js';

export const settingsRouter = Router();

settingsRouter.get(
  '/',
  asyncHandler(async (req, res) => {
    res.json({ settings: await getSettings(req.userProfile.id) });
  }),
);

settingsRouter.patch(
  '/',
  asyncHandler(async (req, res) => {
    res.json({ settings: await updateSettings(req.userProfile.id, req.body) });
  }),
);
