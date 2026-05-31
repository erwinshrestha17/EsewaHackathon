import { db, assertDb } from '../common/db.js';

function fallbackLegacyId(row, prefix) {
  return row?.id ?? `${prefix}-${row.id}`;
}

function mapProfile(row) {
  const id = fallbackLegacyId(row, 'user');
  return {
    id,
    displayName: row.full_name,
    phone: row.phone ?? '',
    avatar: row.avatar_initials ?? row.full_name?.slice(0, 1) ?? 'S',
    district: row.district ?? '',
    privacyMode: row.privacy_mode,
    createdAt: row.created_at,
  };
}

function mapGroup(row, profileIds) {
  return {
    id: fallbackLegacyId(row, 'group'),
    name: row.name,
    category: row.category,
    template: row.template ?? row.name,
    kind: row.kind,
    createdBy: profileIds.get(row.created_by) ?? row.created_by,
    createdAt: row.created_at,
    latestSettlementLockAt: row.latest_settlement_lock_at,
    disbandedAt: row.disbanded_at,
    disbandedBy: profileIds.get(row.disbanded_by) ?? row.disbanded_by,
  };
}

function mapGroupMember(row, profileIds, groupIds) {
  return {
    id: row.id,
    groupId: groupIds.get(row.group_id) ?? row.group_id,
    userId: profileIds.get(row.user_id) ?? row.user_id,
    role: row.role,
    status: row.status,
    joinedAt: row.joined_at,
    removedAt: row.removed_at,
  };
}

function mapConnection(row, profileIds) {
  return {
    id: row.id,
    requesterId: profileIds.get(row.requester_id) ?? row.requester_id,
    recipientId: profileIds.get(row.recipient_id) ?? row.recipient_id,
    userLowId: profileIds.get(row.user_low_id) ?? row.user_low_id,
    userHighId: profileIds.get(row.user_high_id) ?? row.user_high_id,
    status: row.status,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    expiresAt: row.expires_at,
  };
}

function mapConnectionEvent(row, profileIds) {
  return {
    id: row.id,
    connectionId: row.connection_id,
    actorId: profileIds.get(row.actor_id) ?? row.actor_id,
    eventType: row.event_type,
    previousStatus: row.previous_status,
    nextStatus: row.next_status,
    note: row.note,
    createdAt: row.created_at,
  };
}

function mapConnectionBlock(row, profileIds) {
  return {
    id: row.id,
    connectionId: row.connection_id,
    blockerId: profileIds.get(row.blocker_id) ?? row.blocker_id,
    blockedUserId: profileIds.get(row.blocked_user_id) ?? row.blocked_user_id,
    active: row.active,
    liftedAt: row.lifted_at,
    createdAt: row.created_at,
  };
}

function mapConnectionReport(row, profileIds) {
  return {
    id: row.id,
    connectionId: row.connection_id,
    reporterId: profileIds.get(row.reporter_id) ?? row.reporter_id,
    reportedUserId: profileIds.get(row.reported_user_id) ?? row.reported_user_id,
    reasonCode: row.reason_code,
    details: row.details,
    status: row.status,
    createdAt: row.created_at,
  };
}

function mapExpense(row, profileIds, groupIds) {
  return {
    id: row.id,
    groupId: groupIds.get(row.group_id) ?? row.group_id,
    title: row.title,
    subtotalMinor: row.subtotal_minor,
    totalMinor: row.total_minor,
    payerId: profileIds.get(row.payer_id) ?? row.payer_id,
    category: row.category,
    splitMode: row.split_mode,
    status: row.status,
    expenseDate: row.expense_date,
    createdBy: profileIds.get(row.created_by) ?? row.created_by,
    createdAt: row.created_at,
    note: row.note ?? '',
    receiptUrl: row.receipt_url,
    billTaxMinor: row.bill_tax_minor ?? 0,
    billServiceChargeMinor: row.bill_service_charge_minor ?? 0,
    billDiscountMinor: row.bill_discount_minor ?? 0,
    billTipMinor: row.bill_tip_minor ?? 0,
    billRoundingAdjustmentMinor: row.bill_rounding_adjustment_minor ?? 0,
    lockedAt: row.locked_at,
    voidedAt: row.voided_at,
    voidedBy: profileIds.get(row.voided_by) ?? row.voided_by,
    voidReason: row.void_reason,
  };
}

function mapPayment(row, profileIds) {
  return {
    id: row.id,
    paymentProvider: row.payment_provider,
    paymentReference: row.payment_reference,
    operationType: row.operation_type,
    entityType: row.entity_type,
    entityId: row.entity_id,
    actorId: profileIds.get(row.actor_id) ?? row.actor_id,
    amountMinor: row.amount_minor,
    status: row.status,
    rawPayload: JSON.stringify(row.raw_payload ?? {}),
    confirmedAt: row.confirmed_at,
    failedAt: row.failed_at,
    expiredAt: row.expired_at,
    cancelledAt: row.cancelled_at,
    refundedAt: row.refunded_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function unique(values) {
  return [...new Set(values.filter(Boolean))];
}

function mergeById(...lists) {
  const rows = new Map();
  for (const list of lists) {
    for (const row of list ?? []) {
      if (row?.id) rows.set(row.id, row);
    }
  }
  return [...rows.values()];
}

async function rows(query) {
  const { data, error } = await query;
  assertDb(error);
  return data ?? [];
}

async function rowsIn(table, column, values, select = '*') {
  const ids = unique(values);
  if (ids.length === 0) return [];
  return rows(db().from(table).select(select).in(column, ids));
}

export async function appBootstrap(currentUserId) {
  const [connections, currentMemberships] = await Promise.all([
    rows(
      db()
        .from('connections')
        .select('*')
        .or(`requester_id.eq.${currentUserId},recipient_id.eq.${currentUserId}`)
        .order('created_at', { ascending: true }),
    ),
    rows(
      db()
        .from('group_members')
        .select('*')
        .eq('user_id', currentUserId)
        .in('status', ['active', 'invited'])
        .order('joined_at', { ascending: true }),
    ),
  ]);
  const connectionIds = connections.map((row) => row.id);
  const membershipGroupIds = currentMemberships.map((row) => row.group_id);
  const groups = membershipGroupIds.length
    ? await rows(
        db()
          .from('groups')
          .select('*')
          .in('id', unique(membershipGroupIds))
          .eq('is_active', true)
          .order('created_at', { ascending: true }),
      )
    : [];
  const visibleGroupIds = groups.map((row) => row.id);
  const [
    groupMembers,
    expenses,
    settlements,
    adjustments,
    userGifts,
    groupGifts,
    giftPools,
    communitySavingsGroups,
    actorPayments,
    activityLogs,
    notifications,
    connectionEvents,
    connectionBlocks,
    connectionReports,
  ] = await Promise.all([
    visibleGroupIds.length
      ? rows(
          db()
            .from('group_members')
            .select('*')
            .in('group_id', visibleGroupIds)
            .order('joined_at', { ascending: true }),
        )
      : [],
    visibleGroupIds.length
      ? rows(
          db()
            .from('expenses')
            .select('*')
            .in('group_id', visibleGroupIds)
            .order('created_at', { ascending: true }),
        )
      : [],
    visibleGroupIds.length
      ? rows(
          db()
            .from('settlements')
            .select('*')
            .in('group_id', visibleGroupIds)
            .order('created_at', { ascending: true }),
        )
      : [],
    visibleGroupIds.length
      ? rows(
          db()
            .from('adjustments')
            .select('*')
            .in('group_id', visibleGroupIds)
            .order('created_at', { ascending: true }),
        )
      : [],
    rows(
      db()
        .from('gifts')
        .select('*')
        .or(`sender_id.eq.${currentUserId},recipient_id.eq.${currentUserId}`)
        .order('created_at', { ascending: true }),
    ),
    visibleGroupIds.length
      ? rows(
          db()
            .from('gifts')
            .select('*')
            .in('group_id', visibleGroupIds)
            .order('created_at', { ascending: true }),
        )
      : [],
    visibleGroupIds.length
      ? rows(
          db()
            .from('gift_pools')
            .select('*')
            .in('group_id', visibleGroupIds)
            .order('created_at', { ascending: true }),
        )
      : [],
    visibleGroupIds.length
      ? rows(
          db()
            .from('community_savings_groups')
            .select('*')
            .in('group_id', visibleGroupIds)
            .eq('is_active', true)
            .order('created_at', { ascending: true }),
        )
      : [],
    rows(
      db()
        .from('payment_transactions')
        .select('*')
        .eq('actor_id', currentUserId)
        .order('created_at', { ascending: true }),
    ),
    visibleGroupIds.length
      ? rows(
          db()
            .from('activity_logs')
            .select('*')
            .or(`actor_id.eq.${currentUserId},group_id.in.(${visibleGroupIds.join(',')})`)
            .order('created_at', { ascending: true }),
        )
      : rows(
          db()
            .from('activity_logs')
            .select('*')
            .eq('actor_id', currentUserId)
            .order('created_at', { ascending: true }),
        ),
    rows(
      db()
        .from('notifications')
        .select('*')
        .eq('user_id', currentUserId)
        .order('created_at', { ascending: true }),
    ),
    rowsIn('connection_events', 'connection_id', connectionIds),
    rowsIn('connection_blocks', 'connection_id', connectionIds),
    rowsIn('connection_reports', 'connection_id', connectionIds),
  ]);
  const expenseIds = expenses.map((row) => row.id);
  const [expensePayers, expenseShares, expenseItems] = await Promise.all([
    rowsIn('expense_payers', 'expense_id', expenseIds),
    rowsIn('expense_shares', 'expense_id', expenseIds),
    rowsIn('expense_items', 'expense_id', expenseIds),
  ]);
  expenseItems.sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0));
  const gifts = mergeById(userGifts, groupGifts);
  const savingsGroupIds = communitySavingsGroups.map((row) => row.id);
  const [
    expenseItemAssignments,
    adjustmentEntries,
    giftPoolContributions,
    contributionRecords,
    communityExpenses,
  ] = await Promise.all([
    rowsIn(
      'expense_item_assignments',
      'expense_item_id',
      expenseItems.map((row) => row.id),
    ),
    rowsIn(
      'adjustment_entries',
      'adjustment_id',
      adjustments.map((row) => row.id),
    ),
    rowsIn(
      'gift_pool_contributions',
      'gift_pool_id',
      giftPools.map((row) => row.id),
    ),
    rowsIn('contribution_records', 'savings_group_id', savingsGroupIds),
    rowsIn('community_expenses', 'savings_group_id', savingsGroupIds),
  ]);
  giftPoolContributions.sort((a, b) => new Date(a.created_at) - new Date(b.created_at));
  contributionRecords.sort((a, b) => new Date(a.month) - new Date(b.month));
  communityExpenses.sort((a, b) => new Date(a.expense_date) - new Date(b.expense_date));

  const visibleEntityIds = unique([
    ...settlements.map((row) => row.id),
    ...adjustments.map((row) => row.id),
    ...gifts.map((row) => row.id),
    ...giftPoolContributions.map((row) => row.id),
    ...contributionRecords.map((row) => row.id),
  ]);
  const entityPayments = await rowsIn('payment_transactions', 'entity_id', visibleEntityIds);
  const payments = mergeById(actorPayments, entityPayments).sort(
    (a, b) => new Date(a.created_at) - new Date(b.created_at),
  );

  const visibleProfileIds = unique([
    currentUserId,
    ...connections.flatMap((row) => [
      row.requester_id,
      row.recipient_id,
      row.user_low_id,
      row.user_high_id,
    ]),
    ...groups.flatMap((row) => [row.created_by, row.disbanded_by]),
    ...groupMembers.map((row) => row.user_id),
    ...connectionEvents.map((row) => row.actor_id),
    ...connectionBlocks.flatMap((row) => [row.blocker_id, row.blocked_user_id]),
    ...connectionReports.flatMap((row) => [row.reporter_id, row.reported_user_id]),
    ...expenses.flatMap((row) => [row.payer_id, row.created_by, row.voided_by]),
    ...expensePayers.map((row) => row.user_id),
    ...expenseShares.map((row) => row.user_id),
    ...expenseItemAssignments.map((row) => row.user_id),
    ...payments.map((row) => row.actor_id),
    ...settlements.flatMap((row) => [row.payer_id, row.payee_id]),
    ...adjustments.map((row) => row.created_by),
    ...adjustmentEntries.map((row) => row.user_id),
    ...gifts.flatMap((row) => [row.sender_id, row.recipient_id]),
    ...giftPools.flatMap((row) => [row.created_by, row.recipient_id]),
    ...giftPoolContributions.map((row) => row.contributor_id),
    ...communitySavingsGroups.map((row) => row.created_by),
    ...contributionRecords.flatMap((row) => [row.user_id, row.confirmed_by]),
    ...communityExpenses.map((row) => row.recorded_by),
    ...activityLogs.map((row) => row.actor_id),
    ...notifications.map((row) => row.user_id),
  ]);
  const profiles = visibleProfileIds.length
    ? await rows(
        db()
          .from('profiles')
          .select('*')
          .in('id', visibleProfileIds)
          .order('created_at', { ascending: true }),
      )
    : [];

  const profileIds = new Map(profiles.map((row) => [row.id, fallbackLegacyId(row, 'user')]));
  const groupIds = new Map(groups.map((row) => [row.id, fallbackLegacyId(row, 'group')]));
  const poolIds = new Map(
    communitySavingsGroups.map((row) => [row.id, fallbackLegacyId(row, 'community-savings')]),
  );

  return {
    currentUserId: profileIds.get(currentUserId) ?? currentUserId,
    users: profiles.map(mapProfile),
    connections: connections.map((row) => mapConnection(row, profileIds)),
    connectionEvents: connectionEvents.map((row) => mapConnectionEvent(row, profileIds)),
    connectionBlocks: connectionBlocks.map((row) => mapConnectionBlock(row, profileIds)),
    connectionReports: connectionReports.map((row) => mapConnectionReport(row, profileIds)),
    groups: groups.map((row) => mapGroup(row, profileIds)),
    groupMembers: groupMembers.map((row) => mapGroupMember(row, profileIds, groupIds)),
    expenses: expenses.map((row) => mapExpense(row, profileIds, groupIds)),
    expensePayers: expensePayers.map((row) => ({
      id: row.id,
      expenseId: row.expense_id,
      userId: profileIds.get(row.user_id) ?? row.user_id,
      amountMinor: row.amount_minor,
    })),
    expenseShares: expenseShares.map((row) => ({
      id: row.id,
      expenseId: row.expense_id,
      userId: profileIds.get(row.user_id) ?? row.user_id,
      amountMinor: row.amount_minor,
      percentage: row.percentage,
      shareUnits: row.share_units,
      sourceType: row.source_type,
      sourceId: row.source_id,
    })),
    expenseItems: expenseItems.map((row) => ({
      id: row.id,
      expenseId: row.expense_id,
      label: row.label,
      quantity: Number(row.quantity),
      unitAmountMinor: row.unit_amount_minor,
      totalAmountMinor: row.total_amount_minor,
      taxMinor: row.tax_minor,
      serviceChargeMinor: row.service_charge_minor,
      discountMinor: row.discount_minor,
      ocrConfidence: Number(row.ocr_confidence),
      sortOrder: row.sort_order,
    })),
    expenseItemAssignments: expenseItemAssignments.map((row) => ({
      id: row.id,
      expenseItemId: row.expense_item_id,
      userId: profileIds.get(row.user_id) ?? row.user_id,
      assignedAmountMinor: row.assigned_amount_minor,
      splitUnits: row.split_units,
    })),
    payments: payments.map((row) => mapPayment(row, profileIds)),
    settlements: settlements.map((row) => ({
      id: row.id,
      groupId: groupIds.get(row.group_id) ?? row.group_id,
      payerId: profileIds.get(row.payer_id) ?? row.payer_id,
      payeeId: profileIds.get(row.payee_id) ?? row.payee_id,
      amountMinor: row.amount_minor,
      status: row.status,
      paymentTransactionId: row.payment_transaction_id,
      idempotencyKey: row.idempotency_key,
      idempotencyScope: groupIds.get(row.idempotency_scope) ?? row.idempotency_scope,
      operationType: row.operation_type,
      failureReason: row.failure_reason,
      expiresAt: row.expires_at,
      balanceSnapshotHash: row.balance_snapshot_hash,
      paidAt: row.paid_at,
      createdAt: row.created_at,
    })),
    adjustments: adjustments.map((row) => ({
      id: row.id,
      groupId: groupIds.get(row.group_id) ?? row.group_id,
      reason: row.reason,
      adjustmentType: row.adjustment_type,
      createdBy: profileIds.get(row.created_by) ?? row.created_by,
      createdAt: row.created_at,
      reversesSourceType: row.reverses_source_type,
      reversesSourceId: row.reverses_source_id,
    })),
    adjustmentEntries: adjustmentEntries.map((row) => ({
      id: row.id,
      adjustmentId: row.adjustment_id,
      userId: profileIds.get(row.user_id) ?? row.user_id,
      amountMinor: row.amount_minor,
      direction: row.direction,
    })),
    gifts: gifts.map((row) => ({
      id: row.id,
      senderId: profileIds.get(row.sender_id) ?? row.sender_id,
      recipientId: profileIds.get(row.recipient_id) ?? row.recipient_id,
      groupId: groupIds.get(row.group_id) ?? row.group_id,
      template: row.template,
      amountMinor: row.amount_minor,
      message: row.message,
      status: row.status,
      paymentTransactionId: row.payment_transaction_id,
      idempotencyKey: row.idempotency_key,
      idempotencyScope: profileIds.get(row.idempotency_scope) ?? row.idempotency_scope,
      operationType: row.operation_type,
      openedAt: row.opened_at,
      refundedAt: row.refunded_at,
      createdAt: row.created_at,
    })),
    giftPools: giftPools.map((row) => ({
      id: row.id,
      groupId: groupIds.get(row.group_id) ?? row.group_id,
      createdBy: profileIds.get(row.created_by) ?? row.created_by,
      recipientId: profileIds.get(row.recipient_id) ?? row.recipient_id,
      title: row.title,
      template: row.template,
      targetAmountMinor: row.target_amount_minor,
      contributionRule: row.contribution_rule,
      allowOverTarget: row.allow_over_target,
      equalContributionAmountMinor: row.equal_contribution_amount_minor,
      minContributionAmountMinor: row.min_contribution_amount_minor,
      maxContributionAmountMinor: row.max_contribution_amount_minor,
      message: row.message,
      status: row.status,
      createdAt: row.created_at,
    })),
    giftPoolContributions: giftPoolContributions.map((row) => ({
      id: row.id,
      giftPoolId: row.gift_pool_id,
      contributorId: profileIds.get(row.contributor_id) ?? row.contributor_id,
      amountMinor: row.amount_minor,
      status: row.status,
      paymentTransactionId: row.payment_transaction_id,
      idempotencyKey: row.idempotency_key,
      idempotencyScope: row.idempotency_scope,
      operationType: row.operation_type,
      paidAt: row.paid_at,
      createdAt: row.created_at,
    })),
    communitySavingsGroups: communitySavingsGroups.map((row) => ({
      id: poolIds.get(row.id) ?? row.id,
      sourceId: row.id,
      groupId: groupIds.get(row.group_id) ?? row.group_id,
      name: row.name,
      monthlyContributionAmount: row.monthly_contribution_amount,
      currency: row.currency,
      currentMonth: row.current_month,
      createdBy: profileIds.get(row.created_by) ?? row.created_by,
      createdAt: row.created_at,
    })),
    contributionRecords: contributionRecords.map((row) => ({
      id: row.id,
      savingsGroupId: poolIds.get(row.savings_group_id) ?? row.savings_group_id,
      userId: profileIds.get(row.user_id) ?? row.user_id,
      month: row.month,
      expectedAmount: row.expected_amount,
      submittedAmount: row.submitted_amount ?? 0,
      receivedAmount: row.received_amount ?? 0,
      status: row.status,
      submittedAt: row.submitted_at,
      confirmedAt: row.confirmed_at,
    })),
    communityExpenses: communityExpenses.map((row) => ({
      id: row.id,
      savingsGroupId: poolIds.get(row.savings_group_id) ?? row.savings_group_id,
      title: row.title,
      amount: row.amount,
      category: row.category,
      expenseDate: row.expense_date,
      description: row.description,
      recordedBy: profileIds.get(row.recorded_by) ?? row.recorded_by,
      receiptReference: row.receipt_reference,
      createdAt: row.created_at,
    })),
    activity: activityLogs.map((row) => ({
      id: row.id,
      actorId: profileIds.get(row.actor_id) ?? row.actor_id,
      actorType: row.actor_id ? 'user' : 'system',
      eventType: row.action,
      entityType: row.entity_type,
      entityId: row.entity_id ?? '',
      title: row.title ?? '',
      body: row.body ?? '',
      createdAt: row.created_at,
      groupId: groupIds.get(row.group_id) ?? row.group_id,
    })),
    notifications: notifications.map((row) => ({
      id: row.id,
      userId: profileIds.get(row.user_id) ?? row.user_id,
      type: row.type,
      title: row.title,
      body: row.body,
      createdAt: row.created_at,
      read: row.is_read,
    })),
  };
}
