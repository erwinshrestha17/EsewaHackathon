import { db, findByIdOrLegacy, maybeSingle } from '../modules/common/db.js';
import { ApiError } from '../utils/ApiError.js';

async function resolveGroup(groupId) {
  const group = await findByIdOrLegacy('groups', groupId, 'legacy_group_id');
  if (!group || !group.is_active) {
    throw new ApiError(404, 'Group not found.');
  }
  return group;
}

export async function getGroupMembership(groupId, userId) {
  const group = await resolveGroup(groupId);
  const membership = await maybeSingle(
    db()
      .from('group_members')
      .select('*')
      .eq('group_id', group.id)
      .eq('user_id', userId)
      .eq('status', 'active'),
  );
  return { group, membership };
}

export function requireGroupMember(paramName = 'groupId') {
  return async (req, _res, next) => {
    try {
      const { group, membership } = await getGroupMembership(
        req.params[paramName],
        req.userProfile.id,
      );
      if (!membership) {
        throw new ApiError(403, 'You are not a member of this group.');
      }
      req.group = group;
      req.groupMembership = membership;
      next();
    } catch (error) {
      next(error);
    }
  };
}

export function requireGroupAdmin(paramName = 'groupId') {
  return async (req, _res, next) => {
    try {
      const { group, membership } = await getGroupMembership(
        req.params[paramName],
        req.userProfile.id,
      );
      if (!membership || membership.role !== 'admin') {
        throw new ApiError(403, 'Group admin access is required.');
      }
      req.group = group;
      req.groupMembership = membership;
      next();
    } catch (error) {
      next(error);
    }
  };
}

async function savingsGroupFor(id) {
  const savingsGroup = await findByIdOrLegacy(
    'community_savings_groups',
    id,
    'legacy_pool_id',
  );
  if (!savingsGroup || !savingsGroup.is_active) {
    throw new ApiError(404, 'Community savings group not found.');
  }
  return savingsGroup;
}

export function requireSavingsGroupMember(paramName = 'savingsGroupId') {
  return async (req, _res, next) => {
    try {
      const savingsGroup = await savingsGroupFor(req.params[paramName]);
      const { group, membership } = await getGroupMembership(
        savingsGroup.group_id,
        req.userProfile.id,
      );
      if (!membership) {
        throw new ApiError(403, 'You are not a member of this community savings group.');
      }
      req.group = group;
      req.groupMembership = membership;
      req.savingsGroup = savingsGroup;
      next();
    } catch (error) {
      next(error);
    }
  };
}

export function requireSavingsGroupAdmin(paramName = 'savingsGroupId') {
  return async (req, _res, next) => {
    try {
      const savingsGroup = await savingsGroupFor(req.params[paramName]);
      const { group, membership } = await getGroupMembership(
        savingsGroup.group_id,
        req.userProfile.id,
      );
      if (!membership || membership.role !== 'admin') {
        throw new ApiError(403, 'Community savings admin access is required.');
      }
      req.group = group;
      req.groupMembership = membership;
      req.savingsGroup = savingsGroup;
      next();
    } catch (error) {
      next(error);
    }
  };
}
