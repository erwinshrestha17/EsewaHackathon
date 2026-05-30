import { Router } from 'express';

import { asyncHandler } from '../../utils/asyncHandler.js';
import { listNotifications, markAllRead, markRead } from './notifications.service.js';

export const notificationsRouter = Router();

notificationsRouter.get(
  '/',
  asyncHandler(async (req, res) => {
    res.json({ notifications: await listNotifications(req.userProfile.id) });
  }),
);

notificationsRouter.patch(
  '/:notificationId/read',
  asyncHandler(async (req, res) => {
    res.json({
      notification: await markRead(req.userProfile.id, req.params.notificationId),
    });
  }),
);

notificationsRouter.patch(
  '/read-all',
  asyncHandler(async (req, res) => {
    await markAllRead(req.userProfile.id);
    res.status(204).end();
  }),
);
