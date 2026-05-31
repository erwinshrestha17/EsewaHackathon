import { Router } from 'express';

import { requireGroupMember } from '../../middleware/role.middleware.js';
import { requireBody } from '../../middleware/validate.middleware.js';
import { asyncHandler } from '../../utils/asyncHandler.js';
import {
  createRecurringExpense,
  createExpense,
  getExpense,
  listExpenseReviews,
  listGroupExpenses,
  listRecurringExpenses,
  pauseRecurringExpense,
  postRecurringExpense,
  setExpenseReview,
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
  '/group/:groupId/recurring',
  requireGroupMember(),
  asyncHandler(async (req, res) => {
    res.json({ recurringExpenses: await listRecurringExpenses(req.group) });
  }),
);

expensesRouter.post(
  '/group/:groupId/recurring',
  requireGroupMember(),
  requireBody(['title', 'amountMinor', 'payerId']),
  asyncHandler(async (req, res) => {
    res.status(201).json({
      recurringExpense: await createRecurringExpense(
        req.group,
        req.userProfile.id,
        req.body,
      ),
    });
  }),
);

expensesRouter.post(
  '/group/:groupId/recurring/:recurringExpenseId/post',
  requireGroupMember(),
  asyncHandler(async (req, res) => {
    res.json(
      await postRecurringExpense(
        req.group,
        req.userProfile.id,
        req.params.recurringExpenseId,
      ),
    );
  }),
);

expensesRouter.post(
  '/group/:groupId/recurring/:recurringExpenseId/pause',
  requireGroupMember(),
  asyncHandler(async (req, res) => {
    res.json({
      recurringExpense: await pauseRecurringExpense(
        req.group,
        req.userProfile.id,
        req.params.recurringExpenseId,
      ),
    });
  }),
);

expensesRouter.get(
  '/:expenseId',
  asyncHandler(async (req, res) => {
    res.json({ expense: await getExpense(req.params.expenseId) });
  }),
);

expensesRouter.get(
  '/group/:groupId/:expenseId/reviews',
  requireGroupMember(),
  asyncHandler(async (req, res) => {
    res.json({ reviews: await listExpenseReviews(req.group, req.params.expenseId) });
  }),
);

expensesRouter.post(
  '/group/:groupId/:expenseId/reviews',
  requireGroupMember(),
  requireBody(['status']),
  asyncHandler(async (req, res) => {
    res.json({
      review: await setExpenseReview(
        req.group,
        req.userProfile.id,
        req.params.expenseId,
        req.body,
      ),
    });
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
