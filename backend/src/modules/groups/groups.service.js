import { requireFields, assertChoice } from '../../middleware/validate.middleware.js';
import { ApiError } from '../../utils/ApiError.js';
import { logActivity, createNotification } from '../common/audit.js';
import { db, assertDb, findByIdOrLegacy, isUuid, single } from '../common/db.js';
import { groupDto, memberDto } from '../common/mappers.js';

const groupKinds = ['expense', 'dhukuti'];
const memberRoles = ['admin', 'member', 'treasurer'];
const memberStatuses = ['active', 'invited', 'removed'];

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

  await logActivity({
    groupId: group.id,
    actorId: userId,
    action: 'group_created',
    entityType: 'group',
    entityId: group.id,
    title: 'Group created',
    body: `${group.name} was created.`,
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
  return memberDto(data);
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
  return memberDto(data);
}
