import { randomBytes } from 'node:crypto';

import { requireFields, assertChoice } from '../../middleware/validate.middleware.js';
import { ApiError } from '../../utils/ApiError.js';
import { logActivity, createNotification } from '../common/audit.js';
import { db, assertDb, findByIdOrLegacy, isUuid, single } from '../common/db.js';
import { groupDto, memberDto } from '../common/mappers.js';
import { publishGroupEvent } from '../realtime/realtime.service.js';

const groupKinds = ['expense', 'dhukuti'];
const memberRoles = ['admin', 'member', 'treasurer'];
const memberStatuses = ['active', 'invited', 'removed'];

function inviteDto(row) {
  return {
    id: row.id,
    groupId: row.group_id,
    inviterId: row.inviter_id,
    code: row.code,
    expiresAt: row.expires_at,
    acceptedBy: row.accepted_by,
    acceptedAt: row.accepted_at,
    revokedAt: row.revoked_at,
    createdAt: row.created_at,
  };
}

function normalizeInviteCode(value) {
  return value?.toString().trim().toUpperCase() ?? '';
}

function inviteCode() {
  return `SKG-${randomBytes(6).toString('base64url').toUpperCase()}`;
}

export async function listGroups(userId) {
  const { data, error } = await db()
    .from('group_members')
    .select('*, groups(*)')
    .eq('user_id', userId)
    .eq('status', 'active')
    .order('joined_at', { ascending: false });
  assertDb(error);
  return data
    .map((row) => ({
      ...groupDto(row.groups),
      membership: memberDto(row),
    }))
    .filter((group) => group.isActive);
}

export async function createGroup(userId, body) {
  requireFields(body, ['name']);
  assertChoice(body.kind ?? 'expense', groupKinds, 'kind');
  const { data: group, error } = await db()
    .from('groups')
    .insert({
      legacy_group_id: body.legacyGroupId ?? null,
      name: body.name.trim(),
      description: body.description?.trim() || null,
      category: body.category ?? 'custom',
      template: body.template ?? body.name.trim(),
      kind: body.kind ?? 'expense',
      created_by: userId,
    })
    .select()
    .single();
  assertDb(error);

  const { error: memberError } = await db().from('group_members').insert({
    group_id: group.id,
    user_id: userId,
    role: 'admin',
    status: 'active',
  });
  assertDb(memberError);

  const memberIds = [
    ...new Set(
      (Array.isArray(body.memberIds) ? body.memberIds : [])
        .map((id) => id?.toString())
        .filter(Boolean)
        .filter((id) => id !== userId),
    ),
  ];
  if (memberIds.length > 0) {
    const { error: invitedError } = await db().from('group_members').upsert(
      memberIds.map((memberId) => ({
        group_id: group.id,
        user_id: memberId,
        role: 'member',
        status: 'active',
      })),
      { onConflict: 'group_id,user_id' },
    );
    assertDb(invitedError);
    await Promise.all(
      memberIds.map((memberId) =>
        createNotification({
          userId: memberId,
          title: 'Added to group',
          body: `You were added to ${group.name}.`,
          type: 'member_added',
          metadata: { groupId: group.id },
        }),
      ),
    );
  }

  await logActivity({
    groupId: group.id,
    actorId: userId,
    action: 'group_created',
    entityType: 'group',
    entityId: group.id,
    title: 'Group created',
    body: `${group.name} was created.`,
  });
  await publishGroupEvent(group.id, {
    type: 'group_changed',
    payload: { operation: 'created', actorId: userId },
  });
  return groupDto(group);
}

export async function getGroup(groupId) {
  const group = await findByIdOrLegacy('groups', groupId, 'legacy_group_id');
  if (!group || !group.is_active) {
    throw new ApiError(404, 'Group not found.');
  }
  const { data: members, error } = await db()
    .from('group_members')
    .select('*, profiles(*)')
    .eq('group_id', group.id)
    .order('joined_at', { ascending: true });
  assertDb(error);
  return { group: groupDto(group), members: members.map(memberDto) };
}

export async function updateGroup(group, userId, body) {
  const payload = {};
  if (body.name !== undefined) payload.name = body.name.trim();
  if (body.description !== undefined) payload.description = body.description?.trim() || null;
  if (body.category !== undefined) payload.category = body.category;
  if (body.template !== undefined) payload.template = body.template?.trim() || null;
  if (body.kind !== undefined) {
    assertChoice(body.kind, groupKinds, 'kind');
    payload.kind = body.kind;
  }
  const { data, error } = await db()
    .from('groups')
    .update(payload)
    .eq('id', group.id)
    .select()
    .single();
  assertDb(error);
  await logActivity({
    groupId: group.id,
    actorId: userId,
    action: 'group_updated',
    entityType: 'group',
    entityId: group.id,
    title: 'Group updated',
    body: `${data.name} settings were updated.`,
  });
  await publishGroupEvent(group.id, {
    type: 'group_changed',
    payload: { operation: 'updated', actorId: userId },
  });
  return groupDto(data);
}

export async function deactivateGroup(group, userId) {
  const { error } = await db()
    .from('groups')
    .update({ is_active: false, disbanded_at: new Date().toISOString(), disbanded_by: userId })
    .eq('id', group.id);
  assertDb(error);
  await logActivity({
    groupId: group.id,
    actorId: userId,
    action: 'group_deleted',
    entityType: 'group',
    entityId: group.id,
    title: 'Group archived',
    body: `${group.name} was archived.`,
  });
  await publishGroupEvent(group.id, {
    type: 'group_changed',
    payload: { operation: 'deleted', actorId: userId },
  });
}

export async function listMembers(group) {
  const { data, error } = await db()
    .from('group_members')
    .select('*, profiles(*)')
    .eq('group_id', group.id)
    .order('joined_at', { ascending: true });
  assertDb(error);
  return data.map(memberDto);
}

export async function addMember(group, actorId, body) {
  requireFields(body, ['userId']);
  assertChoice(body.role ?? 'member', memberRoles, 'role');
  const lookup = db().from('profiles').select('*');
  const user = await single(
    isUuid(body.userId) ? lookup.eq('id', body.userId) : lookup.eq('legacy_user_id', body.userId),
    'User profile not found.',
  );
  const { data, error } = await db()
    .from('group_members')
    .upsert(
      {
        group_id: group.id,
        user_id: user.id,
        role: body.role ?? 'member',
        status: body.status ?? 'active',
      },
      { onConflict: 'group_id,user_id' },
    )
    .select('*, profiles(*)')
    .single();
  assertDb(error);
  await createNotification({
    userId: user.id,
    title: 'Added to group',
    body: `You were added to ${group.name}.`,
    type: 'member_added',
    metadata: { groupId: group.id },
  });
  await logActivity({
    groupId: group.id,
    actorId,
    action: 'member_added',
    entityType: 'group_member',
    entityId: data.id,
    title: 'Member added',
    body: `${user.full_name} was added to ${group.name}.`,
  });
  await publishGroupEvent(group.id, {
    type: 'group_changed',
    payload: { operation: 'member_added', actorId, memberId: data.id },
  });
  return memberDto(data);
}

export async function createGroupInvite(group, actorId, body = {}) {
  const hours = Math.min(Math.max(Number(body.expiresInHours) || 168, 1), 168);
  const expiresAt = new Date(Date.now() + hours * 60 * 60 * 1000).toISOString();
  const { data, error } = await db()
    .from('group_invites')
    .insert({
      group_id: group.id,
      inviter_id: actorId,
      code: inviteCode(),
      expires_at: expiresAt,
    })
    .select()
    .single();
  assertDb(error);
  await logActivity({
    groupId: group.id,
    actorId,
    action: 'group_invite_created',
    entityType: 'group_invite',
    entityId: data.id,
    title: 'Group invite created',
    body: `An invite was created for ${group.name}.`,
    metadata: { expiresAt },
  });
  await publishGroupEvent(group.id, {
    type: 'group_invite_changed',
    payload: { operation: 'created', inviteId: data.id, actorId },
  });
  await publishGroupEvent(group.id, {
    type: 'group_ledger_changed',
    payload: { operation: 'group_invite_created', inviteId: data.id, actorId },
  });
  return inviteDto(data);
}

export async function acceptGroupInvite(userId, body) {
  requireFields(body, ['code']);
  const code = normalizeInviteCode(body.code);
  const invite = await single(
    db().from('group_invites').select('*').eq('code', code).is('revoked_at', null),
    'Group invite not found.',
  );
  if (new Date(invite.expires_at).getTime() <= Date.now()) {
    throw new ApiError(410, 'This group invite has expired.');
  }
  if (invite.accepted_by && invite.accepted_by !== userId) {
    throw new ApiError(409, 'This group invite has already been used.');
  }
  const group = await single(
    db().from('groups').select('*').eq('id', invite.group_id).eq('is_active', true),
    'Group not found.',
  );
  const { data: member, error: memberError } = await db()
    .from('group_members')
    .upsert(
      {
        group_id: group.id,
        user_id: userId,
        role: 'member',
        status: 'active',
        joined_at: new Date().toISOString(),
        removed_at: null,
      },
      { onConflict: 'group_id,user_id' },
    )
    .select('*, profiles(*)')
    .single();
  assertDb(memberError);
  const { data: updatedInvite, error: inviteError } = await db()
    .from('group_invites')
    .update({
      accepted_by: userId,
      accepted_at: invite.accepted_at ?? new Date().toISOString(),
    })
    .eq('id', invite.id)
    .select()
    .single();
  assertDb(inviteError);
  await createNotification({
    userId: invite.inviter_id,
    title: 'Invite accepted',
    body: `${member.profiles?.full_name ?? 'A member'} joined ${group.name}.`,
    type: 'group_invite_accepted',
    metadata: { groupId: group.id, inviteId: invite.id },
  });
  await logActivity({
    groupId: group.id,
    actorId: userId,
    action: 'group_invite_accepted',
    entityType: 'group_member',
    entityId: member.id,
    title: 'Invite accepted',
    body: `${member.profiles?.full_name ?? 'A member'} joined ${group.name}.`,
    metadata: { inviteId: invite.id },
  });
  await publishGroupEvent(
    group.id,
    {
      type: 'group_invite_changed',
      payload: { operation: 'accepted', inviteId: invite.id, actorId: userId },
    },
    { extraUserIds: [userId] },
  );
  await publishGroupEvent(
    group.id,
    {
      type: 'group_changed',
      payload: { operation: 'member_joined', memberId: member.id, actorId: userId },
    },
    { extraUserIds: [userId] },
  );
  await publishGroupEvent(
    group.id,
    {
      type: 'group_ledger_changed',
      payload: { operation: 'group_invite_accepted', inviteId: invite.id, actorId: userId },
    },
    { extraUserIds: [userId] },
  );
  return {
    group: groupDto(group),
    member: memberDto(member),
    invite: inviteDto(updatedInvite),
  };
}

export async function updateMember(group, actorId, memberId, body) {
  assertChoice(body.role, memberRoles, 'role');
  assertChoice(body.status, memberStatuses, 'status');
  const payload = {};
  if (body.role !== undefined) payload.role = body.role;
  if (body.status !== undefined) payload.status = body.status;
  if (body.status === 'removed') payload.removed_at = new Date().toISOString();
  const { data, error } = await db()
    .from('group_members')
    .update(payload)
    .eq('group_id', group.id)
    .eq('id', memberId)
    .select('*, profiles(*)')
    .single();
  assertDb(error);
  await logActivity({
    groupId: group.id,
    actorId,
    action: 'member_updated',
    entityType: 'group_member',
    entityId: data.id,
    title: 'Member updated',
    body: 'A group member record was updated.',
  });
  await publishGroupEvent(group.id, {
    type: 'group_changed',
    payload: { operation: 'member_updated', actorId, memberId: data.id },
  });
  return memberDto(data);
}

export async function leaveGroup(group, userId, body = {}) {
  const { data: activeMembers, error: activeError } = await db()
    .from('group_members')
    .select('*')
    .eq('group_id', group.id)
    .eq('status', 'active');
  assertDb(activeError);
  const current = activeMembers.find((member) => member.user_id === userId);
  if (!current) {
    throw new ApiError(404, 'Group membership not found.');
  }
  const otherAdmins = activeMembers.filter(
    (member) => member.user_id !== userId && member.role === 'admin',
  );
  if (current.role === 'admin' && otherAdmins.length === 0) {
    if (!body.transferAdminTo) {
      throw new ApiError(409, 'Choose another active member as admin before leaving.');
    }
    const transferMember = activeMembers.find(
      (member) => member.user_id === body.transferAdminTo || member.id === body.transferAdminTo,
    );
    if (!transferMember || transferMember.user_id === userId) {
      throw new ApiError(400, 'Admin transfer member is not active in this group.');
    }
    const { error: transferError } = await db()
      .from('group_members')
      .update({ role: 'admin' })
      .eq('group_id', group.id)
      .eq('id', transferMember.id);
    assertDb(transferError);
  }
  const { data, error } = await db()
    .from('group_members')
    .update({ status: 'removed', removed_at: new Date().toISOString() })
    .eq('group_id', group.id)
    .eq('id', current.id)
    .select('*, profiles(*)')
    .single();
  assertDb(error);
  await logActivity({
    groupId: group.id,
    actorId: userId,
    action: 'member_left',
    entityType: 'group_member',
    entityId: data.id,
    title: 'Member left',
    body: 'A member left the group.',
  });
  await publishGroupEvent(group.id, {
    type: 'group_changed',
    payload: { operation: 'member_left', actorId: userId, memberId: data.id },
  });
  return memberDto(data);
}
