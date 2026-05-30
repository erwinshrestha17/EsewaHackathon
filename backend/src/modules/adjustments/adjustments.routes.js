import { Router } from 'express';

import { requireGroupMember } from '../../middleware/role.middleware.js';
import { requireBody } from '../../middleware/validate.middleware.js';
import { asyncHandler } from '../../utils/asyncHandler.js';
import { createAdjustment } from './adjustments.service.js';

export const adjustmentsRouter = Router();

adjustmentsRouter.post(
  '/group/:groupId',
  requireGroupMember(),
  requireBody(['creditUserId', 'debitUserId', 'amountMinor', 'reason']),
  asyncHandler(async (req, res) => {
    res.status(201).json({
      adjustment: await createAdjustment(req.group, req.userProfile.id, req.body),
    });
  }),
);
