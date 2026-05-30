export function profileDto(row) {
  if (!row) return null;
  return {
    id: row.id,
    legacyUserId: row.legacy_user_id,
    authUserId: row.auth_user_id,
    fullName: row.full_name,
    phone: row.phone,
    avatarUrl: row.avatar_url,
    avatarInitials: row.avatar_initials,
    district: row.district,
    dateOfBirth: row.date_of_birth,
    phoneVerifiedAt: row.phone_verified_at,
    privacyMode: row.privacy_mode,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function groupDto(row) {
  if (!row) return null;
  return {
    id: row.id,
    legacyGroupId: row.legacy_group_id,
    name: row.name,
    description: row.description,
    category: row.category,
    template: row.template,
    kind: row.kind,
    createdBy: row.created_by,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    isActive: row.is_active,
  };
}

export function memberDto(row) {
  if (!row) return null;
  return {
    id: row.id,
    groupId: row.group_id,
    userId: row.user_id,
    role: row.role,
    status: row.status,
    joinedAt: row.joined_at,
    profile: profileDto(row.profiles),
  };
}

export function activityDto(row) {
  if (!row) return null;
  return {
    id: row.id,
    groupId: row.group_id,
    actorId: row.actor_id,
    action: row.action,
    entityType: row.entity_type,
    entityId: row.entity_id,
    title: row.title,
    body: row.body,
    metadata: row.metadata ?? {},
    createdAt: row.created_at,
  };
}

export function notificationDto(row) {
  if (!row) return null;
  return {
    id: row.id,
    userId: row.user_id,
    title: row.title,
    body: row.body,
    type: row.type,
    metadata: row.metadata ?? {},
    isRead: row.is_read,
    createdAt: row.created_at,
  };
}
