import { Router } from 'express';

import { requireBody } from '../../middleware/validate.middleware.js';
import { asyncHandler } from '../../utils/asyncHandler.js';
import {
  listConnections,
  requestConnection,
  searchProfiles,
  updateConnection,
} from './connections.service.js';

export const connectionsRouter = Router();

connectionsRouter.get(
  '/',
  asyncHandler(async (req, res) => {
    res.json({
      connections: await listConnections(req.userProfile.id, req.query.status),
    });
  }),
);

connectionsRouter.get(
  '/search',
  asyncHandler(async (req, res) => {
    res.json({ users: await searchProfiles(req.userProfile.id, req.query.q) });
  }),
);

connectionsRouter.post(
  '/',
  requireBody(['targetUserId']),
  asyncHandler(async (req, res) => {
    res.status(201).json({
      connection: await requestConnection(req.userProfile.id, req.body),
    });
  }),
);

connectionsRouter.post(
  '/:connectionId/approve',
  asyncHandler(async (req, res) => {
    res.json({
      connection: await updateConnection(req.userProfile.id, req.params.connectionId, 'approved'),
    });
  }),
);

connectionsRouter.post(
  '/:connectionId/decline',
  asyncHandler(async (req, res) => {
    res.json({
      connection: await updateConnection(req.userProfile.id, req.params.connectionId, 'declined'),
    });
  }),
);

connectionsRouter.delete(
  '/:connectionId',
  asyncHandler(async (req, res) => {
    res.json({
      connection: await updateConnection(req.userProfile.id, req.params.connectionId, 'removed'),
    });
  }),
);
