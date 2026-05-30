import { Router } from 'express';

import { requireGroupMember } from '../../middleware/role.middleware.js';
import { requireBody } from '../../middleware/validate.middleware.js';
import { asyncHandler } from '../../utils/asyncHandler.js';
import {
  contributeToGiftPool,
  createGiftPool,
  listGiftPools,
  listGifts,
  openGift,
  sendGift,
} from './gifts.service.js';

export const giftsRouter = Router();

giftsRouter.get(
  '/',
  asyncHandler(async (req, res) => {
    res.json({ gifts: await listGifts(req.userProfile.id) });
  }),
);

giftsRouter.post(
  '/',
  requireBody(['recipientId', 'template', 'amountMinor']),
  asyncHandler(async (req, res) => {
    res.status(201).json({ gift: await sendGift(req.userProfile.id, req.body) });
  }),
);

giftsRouter.post(
  '/:giftId/open',
  asyncHandler(async (req, res) => {
    res.json({ gift: await openGift(req.userProfile.id, req.params.giftId) });
  }),
);

giftsRouter.get(
  '/pools/group/:groupId',
  requireGroupMember(),
  asyncHandler(async (req, res) => {
    res.json({ giftPools: await listGiftPools(req.group) });
  }),
);

giftsRouter.post(
  '/pools/group/:groupId',
  requireGroupMember(),
  requireBody(['recipientId', 'title', 'template', 'targetAmountMinor']),
  asyncHandler(async (req, res) => {
    res.status(201).json({
      giftPool: await createGiftPool(req.group, req.userProfile.id, req.body),
    });
  }),
);

giftsRouter.post(
  '/pools/:giftPoolId/contributions',
  requireBody(['amountMinor']),
  asyncHandler(async (req, res) => {
    res.status(201).json({
      contribution: await contributeToGiftPool(
        req.userProfile.id,
        req.params.giftPoolId,
        req.body,
      ),
    });
  }),
);
