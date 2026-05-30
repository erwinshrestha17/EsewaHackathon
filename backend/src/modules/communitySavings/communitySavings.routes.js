import { Router } from 'express';

import { getGroupMembership, requireSavingsGroupAdmin, requireSavingsGroupMember } from '../../middleware/role.middleware.js';
import { requireBody } from '../../middleware/validate.middleware.js';
import { asyncHandler } from '../../utils/asyncHandler.js';
import {
  confirmContribution,
  createSavingsGroup,
  getBalance,
  getContributions,
  getDashboard,
  getHistory,
  listSavingsGroupsForCurrentUser,
  recordExpense,
  submitContribution,
  updateSavingsGroup,
  waiveContribution,
} from './communitySavings.service.js';

export const communitySavingsRouter = Router();

communitySavingsRouter.get(
  '/',
  asyncHandler(async (req, res) => {
    res.json({ groups: await listSavingsGroupsForCurrentUser(req.userProfile.id) });
  }),
);

communitySavingsRouter.post(
  '/',
  requireBody(['groupId', 'name', 'monthlyContributionAmount']),
  asyncHandler(async (req, res) => {
    const { group, membership } = await getGroupMembership(req.body.groupId, req.userProfile.id);
    if (!membership || membership.role !== 'admin') {
      res.status(403).json({ error: 'Group admin access is required.' });
      return;
    }
    res.status(201).json({
      group: await createSavingsGroup(group, req.userProfile.id, req.body),
    });
  }),
);

communitySavingsRouter.get(
  '/:savingsGroupId/dashboard',
  requireSavingsGroupMember(),
  asyncHandler(async (req, res) => {
    res.json(await getDashboard(req.savingsGroup.id, req.query.month));
  }),
);

communitySavingsRouter.patch(
  '/:savingsGroupId',
  requireSavingsGroupAdmin(),
  asyncHandler(async (req, res) => {
    res.json({ group: await updateSavingsGroup(req.savingsGroup, req.body) });
  }),
);

communitySavingsRouter.get(
  '/:savingsGroupId/contributions',
  requireSavingsGroupMember(),
  asyncHandler(async (req, res) => {
    res.json(await getContributions(req.savingsGroup, req.query.month));
  }),
);

communitySavingsRouter.post(
  '/:savingsGroupId/contributions/submit',
  requireSavingsGroupMember(),
  requireBody(['amountPaid', 'paymentMethod']),
  asyncHandler(async (req, res) => {
    res.json({
      contribution: await submitContribution(req.savingsGroup, req.userProfile.id, req.body),
    });
  }),
);

communitySavingsRouter.post(
  '/contributions/:contributionId/confirm',
  requireBody(['savingsGroupId', 'amountReceived', 'paymentMethod']),
  asyncHandler(async (req, res, next) => {
    req.params.savingsGroupId = req.body.savingsGroupId;
    next();
  }),
  requireSavingsGroupAdmin(),
  asyncHandler(async (req, res) => {
    res.json({
      contribution: await confirmContribution(
        req.savingsGroup,
        req.userProfile.id,
        req.params.contributionId,
        req.body,
      ),
    });
  }),
);

communitySavingsRouter.post(
  '/contributions/:contributionId/waive',
  requireBody(['savingsGroupId']),
  asyncHandler(async (req, res, next) => {
    req.params.savingsGroupId = req.body.savingsGroupId;
    next();
  }),
  requireSavingsGroupAdmin(),
  asyncHandler(async (req, res) => {
    res.json({
      contribution: await waiveContribution(
        req.savingsGroup,
        req.userProfile.id,
        req.params.contributionId,
        req.body,
      ),
    });
  }),
);

communitySavingsRouter.post(
  '/:savingsGroupId/expenses',
  requireSavingsGroupAdmin(),
  requireBody(['title', 'amountSpent']),
  asyncHandler(async (req, res) => {
    res.status(201).json({
      expense: await recordExpense(req.savingsGroup, req.userProfile.id, req.body),
    });
  }),
);

communitySavingsRouter.get(
  '/:savingsGroupId/history',
  requireSavingsGroupMember(),
  asyncHandler(async (req, res) => {
    res.json(await getHistory(req.savingsGroup, req.query.filter ?? 'all'));
  }),
);

communitySavingsRouter.get(
  '/:savingsGroupId/balance',
  requireSavingsGroupMember(),
  asyncHandler(async (req, res) => {
    res.json(await getBalance(req.savingsGroup));
  }),
);

// Legacy paths used by the current Flutter CommunitySavingsApi.
communitySavingsRouter.get(
  '/groups',
  asyncHandler(async (req, res) => {
    res.json({ groups: await listSavingsGroupsForCurrentUser(req.userProfile.id) });
  }),
);

communitySavingsRouter.get(
  '/groups/:savingsGroupId/dashboard',
  requireSavingsGroupMember(),
  asyncHandler(async (req, res) => {
    res.json(await getDashboard(req.savingsGroup.id, req.query.month));
  }),
);

communitySavingsRouter.get(
  '/groups/:savingsGroupId/contributions',
  requireSavingsGroupMember(),
  asyncHandler(async (req, res) => {
    res.json(await getContributions(req.savingsGroup, req.query.month));
  }),
);

communitySavingsRouter.post(
  '/groups/:savingsGroupId/contributions/:contributionId/submit',
  requireSavingsGroupMember(),
  asyncHandler(async (req, res) => {
    res.json({
      contribution: await submitContribution(
        req.savingsGroup,
        req.userProfile.id,
        req.body,
        req.params.contributionId,
      ),
    });
  }),
);

communitySavingsRouter.post(
  '/groups/:savingsGroupId/contributions/:contributionId/confirm',
  requireSavingsGroupAdmin(),
  asyncHandler(async (req, res) => {
    res.json({
      contribution: await confirmContribution(
        req.savingsGroup,
        req.userProfile.id,
        req.params.contributionId,
        req.body,
      ),
    });
  }),
);

communitySavingsRouter.post(
  '/groups/:savingsGroupId/contributions/:contributionId/waive',
  requireSavingsGroupAdmin(),
  asyncHandler(async (req, res) => {
    res.json({
      contribution: await waiveContribution(
        req.savingsGroup,
        req.userProfile.id,
        req.params.contributionId,
        req.body,
      ),
    });
  }),
);

communitySavingsRouter.post(
  '/groups/:savingsGroupId/expenses',
  requireSavingsGroupAdmin(),
  asyncHandler(async (req, res) => {
    res.status(201).json({
      expense: await recordExpense(req.savingsGroup, req.userProfile.id, req.body),
    });
  }),
);

communitySavingsRouter.get(
  '/groups/:savingsGroupId/history',
  requireSavingsGroupMember(),
  asyncHandler(async (req, res) => {
    res.json(await getHistory(req.savingsGroup, req.query.filter ?? 'all'));
  }),
);
