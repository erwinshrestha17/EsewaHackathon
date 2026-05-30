import { Router } from 'express';

import { asyncHandler } from '../../utils/asyncHandler.js';
import { appBootstrap } from './appBootstrap.service.js';
import { realtimeAuth, subscribeAppEvents } from '../realtime/realtime.service.js';

export const appBootstrapRouter = Router();

appBootstrapRouter.get(
  '/bootstrap',
  asyncHandler(async (req, res) => {
    res.json(await appBootstrap(req.userProfile.id));
  }),
);

appBootstrapRouter.get(
  '/realtime-token',
  asyncHandler(async (req, res) => {
    res.json(await realtimeAuth(req.userProfile.id));
  }),
);

appBootstrapRouter.get('/events', (req, res) => {
  subscribeAppEvents(req.userProfile.id, req, res);
});
