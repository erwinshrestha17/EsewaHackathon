import { Router } from 'express';

import { requireGroupMember } from '../../middleware/role.middleware.js';
import { requireBody } from '../../middleware/validate.middleware.js';
import { asyncHandler } from '../../utils/asyncHandler.js';
import {
  confirmSettlement,
  createSettlement,
  listSettlements,
} from './settlements.service.js';

export const settlementsRouter = Router();

settlementsRouter.get(
  '/',
  asyncHandler(async (req, res) => {
    res.json({ settlements: await listSettlements(req.userProfile.id) });
  }),
);

settlementsRouter.get(
  '/group/:groupId',
  requireGroupMember(),
  asyncHandler(async (req, res) => {
    res.json({ settlements: await listSettlements(req.userProfile.id, req.group) });
  }),
);

settlementsRouter.post(
  '/group/:groupId',
  requireGroupMember(),
  requireBody(['payerId', 'payeeId', 'amountMinor']),
  asyncHandler(async (req, res) => {
    res.status(201).json({
      settlement: await createSettlement(req.group, req.userProfile.id, req.body),
    });
  }),
);

settlementsRouter.post(
  '/group/:groupId/:settlementId/confirm',
  requireGroupMember(),
  asyncHandler(async (req, res) => {
    res.json({
      settlement: await confirmSettlement(
        req.group,
        req.userProfile.id,
        req.params.settlementId,
      ),
    });
  }),
);
