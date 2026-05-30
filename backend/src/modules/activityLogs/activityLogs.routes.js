import { Router } from 'express';

import { asyncHandler } from '../../utils/asyncHandler.js';
import { listActivityLogs } from './activityLogs.service.js';

export const activityLogsRouter = Router();

activityLogsRouter.get(
  '/',
  asyncHandler(async (req, res) => {
    res.json({
      activityLogs: await listActivityLogs(req.userProfile.id, req.query.groupId),
    });
  }),
);
