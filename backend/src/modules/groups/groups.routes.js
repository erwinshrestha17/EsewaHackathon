import { Router } from 'express';

import { requireGroupAdmin, requireGroupMember } from '../../middleware/role.middleware.js';
import { requireBody } from '../../middleware/validate.middleware.js';
import { asyncHandler } from '../../utils/asyncHandler.js';
import {
  addMember,
  createGroup,
  deactivateGroup,
  getGroup,
  listGroups,
  listMembers,
  leaveGroup,
  updateGroup,
  updateMember,
} from './groups.service.js';

export const groupsRouter = Router();

groupsRouter.get(
  '/',
  asyncHandler(async (req, res) => {
    res.json({ groups: await listGroups(req.userProfile.id) });
  }),
);

groupsRouter.post(
  '/',
  requireBody(['name']),
  asyncHandler(async (req, res) => {
    res.status(201).json({ group: await createGroup(req.userProfile.id, req.body) });
  }),
);

groupsRouter.get(
  '/:groupId',
  requireGroupMember(),
  asyncHandler(async (req, res) => {
    res.json(await getGroup(req.group.id));
  }),
);

groupsRouter.patch(
  '/:groupId',
  requireGroupAdmin(),
  asyncHandler(async (req, res) => {
    res.json({ group: await updateGroup(req.group, req.userProfile.id, req.body) });
  }),
);

groupsRouter.delete(
  '/:groupId',
  requireGroupAdmin(),
  asyncHandler(async (req, res) => {
    await deactivateGroup(req.group, req.userProfile.id);
    res.status(204).end();
  }),
);

groupsRouter.post(
  '/:groupId/leave',
  requireGroupMember(),
  asyncHandler(async (req, res) => {
    res.json({
      member: await leaveGroup(req.group, req.userProfile.id, req.body),
    });
  }),
);

groupsRouter.get(
  '/:groupId/members',
  requireGroupMember(),
  asyncHandler(async (req, res) => {
    res.json({ members: await listMembers(req.group) });
  }),
);

groupsRouter.post(
  '/:groupId/members',
  requireGroupAdmin(),
  requireBody(['userId']),
  asyncHandler(async (req, res) => {
    res.status(201).json({
      member: await addMember(req.group, req.userProfile.id, req.body),
    });
  }),
);

groupsRouter.patch(
  '/:groupId/members/:memberId',
  requireGroupAdmin(),
  asyncHandler(async (req, res) => {
    res.json({
      member: await updateMember(
        req.group,
        req.userProfile.id,
        req.params.memberId,
        req.body,
      ),
    });
  }),
);

groupsRouter.delete(
  '/:groupId/members/:memberId',
  requireGroupAdmin(),
  asyncHandler(async (req, res) => {
    res.json({
      member: await updateMember(req.group, req.userProfile.id, req.params.memberId, {
        status: 'removed',
      }),
    });
  }),
);
