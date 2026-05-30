import { Router } from 'express';

import { asyncHandler } from '../../utils/asyncHandler.js';
import { appBootstrap } from './appBootstrap.service.js';

export const appBootstrapRouter = Router();

appBootstrapRouter.get(
  '/bootstrap',
  asyncHandler(async (req, res) => {
    res.json(await appBootstrap(req.userProfile.id));
  }),
);
