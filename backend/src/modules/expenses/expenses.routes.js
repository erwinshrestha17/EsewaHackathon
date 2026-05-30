import { Router } from 'express';

import { requireGroupMember } from '../../middleware/role.middleware.js';
import { requireBody } from '../../middleware/validate.middleware.js';
import { asyncHandler } from '../../utils/asyncHandler.js';
import {
  createExpense,
  getExpense,
  listGroupExpenses,
  updateExpense,
  voidExpense,
} from './expenses.service.js';

export const expensesRouter = Router();

expensesRouter.get(
  '/group/:groupId',
  requireGroupMember(),
  asyncHandler(async (req, res) => {
    res.json({ expenses: await listGroupExpenses(req.group, req.query.status) });
  }),
);

expensesRouter.post(
  '/group/:groupId',
  requireGroupMember(),
  requireBody(['title', 'totalMinor', 'payerId']),
  asyncHandler(async (req, res) => {
    res.status(201).json({
      expense: await createExpense(req.group, req.userProfile.id, req.body),
    });
  }),
);

expensesRouter.get(
  '/:expenseId',
  asyncHandler(async (req, res) => {
    res.json({ expense: await getExpense(req.params.expenseId) });
  }),
);

expensesRouter.patch(
  '/group/:groupId/:expenseId',
  requireGroupMember(),
  asyncHandler(async (req, res) => {
    res.json({
      expense: await updateExpense(
        req.group,
        req.userProfile.id,
        req.params.expenseId,
        req.body,
      ),
    });
  }),
);

expensesRouter.post(
  '/group/:groupId/:expenseId/void',
  requireGroupMember(),
  asyncHandler(async (req, res) => {
    res.json({
      expense: await voidExpense(
        req.group,
        req.userProfile.id,
        req.params.expenseId,
        req.body.reason,
      ),
    });
  }),
);
