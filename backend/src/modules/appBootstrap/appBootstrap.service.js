import { db, assertDb } from '../common/db.js';

function emptyResult() {
  return Promise.resolve({ data: [], error: null });
}

function fallbackLegacyId(row, prefix) {
  return row?.legacy_user_id ?? row?.legacy_group_id ?? row?.legacy_pool_id ?? `${prefix}-${row.id}`;
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

export async function appBootstrap(currentUserId) {
  const userMembershipsResult = await db()
    .from('group_members')
    .select('*')
    .eq('user_id', currentUserId)
    .eq('status', 'active');
  assertDb(userMembershipsResult.error);
  const userMemberships = userMembershipsResult.data ?? [];
  const visibleGroupIds = [...new Set(userMemberships.map((row) => row.group_id))];

  const [
    connectionsResult,
    groupsResult,
    groupMembersResult,
    expensesResult,
    settlementsResult,
    giftsResult,
    giftPoolsResult,
    communitySavingsGroupsResult,
    activityLogsResult,
    notificationsResult,
  ] = await Promise.all([
    db()
      .from('connections')
      .select('*')
      .or(`requester_id.eq.${currentUserId},recipient_id.eq.${currentUserId}`)
      .order('created_at', { ascending: true }),
    visibleGroupIds.length
      ? db()
          .from('groups')
          .select('*')
          .in('id', visibleGroupIds)
          .eq('is_active', true)
          .order('created_at', { ascending: true })
      : emptyResult(),
    visibleGroupIds.length
      ? db()
          .from('group_members')
          .select('*')
          .in('group_id', visibleGroupIds)
          .order('joined_at', { ascending: true })
      : emptyResult(),
    visibleGroupIds.length
      ? db()
          .from('expenses')
          .select('*')
          .in('group_id', visibleGroupIds)
          .order('created_at', { ascending: true })
      : emptyResult(),
    visibleGroupIds.length
      ? db()
          .from('settlements')
          .select('*')
          .in('group_id', visibleGroupIds)
          .order('created_at', { ascending: true })
      : emptyResult(),
    visibleGroupIds.length
      ? db()
          .from('gifts')
          .select('*')
          .or(
            `sender_id.eq.${currentUserId},recipient_id.eq.${currentUserId},group_id.in.(${visibleGroupIds.join(',')})`,
          )
          .order('created_at', { ascending: true })
      : db()
          .from('gifts')
          .select('*')
          .or(`sender_id.eq.${currentUserId},recipient_id.eq.${currentUserId}`)
          .order('created_at', { ascending: true }),
    visibleGroupIds.length
      ? db()
          .from('gift_pools')
          .select('*')
          .in('group_id', visibleGroupIds)
          .order('created_at', { ascending: true })
      : emptyResult(),
    visibleGroupIds.length
      ? db()
          .from('community_savings_groups')
          .select('*')
          .in('group_id', visibleGroupIds)
          .eq('is_active', true)
          .order('created_at', { ascending: true })
      : emptyResult(),
    visibleGroupIds.length
      ? db()
          .from('activity_logs')
          .select('*')
          .or(`actor_id.eq.${currentUserId},group_id.in.(${visibleGroupIds.join(',')})`)
          .order('created_at', { ascending: false })
          .limit(200)
      : db()
          .from('activity_logs')
          .select('*')
          .eq('actor_id', currentUserId)
          .order('created_at', { ascending: false })
          .limit(200),
    db()
      .from('notifications')
      .select('*')
      .eq('user_id', currentUserId)
      .order('created_at', { ascending: true }),
  ]);
  [
    connectionsResult,
    groupsResult,
    groupMembersResult,
    expensesResult,
    settlementsResult,
    giftsResult,
    giftPoolsResult,
    communitySavingsGroupsResult,
    activityLogsResult,
    notificationsResult,
  ].forEach((result) => assertDb(result.error));

  const connections = connectionsResult.data ?? [];
  const groups = groupsResult.data ?? [];
  const groupMembers = groupMembersResult.data ?? [];
  const expenses = expensesResult.data ?? [];
  const settlements = settlementsResult.data ?? [];
  const gifts = giftsResult.data ?? [];
  const giftPools = giftPoolsResult.data ?? [];
  const communitySavingsGroups = communitySavingsGroupsResult.data ?? [];
  const activityLogs = (activityLogsResult.data ?? []).reverse();
  const notifications = notificationsResult.data ?? [];

  const expenseIds = expenses.map((row) => row.id);
  const giftPoolIds = giftPools.map((row) => row.id);
  const savingsGroupIds = communitySavingsGroups.map((row) => row.id);

  const [
    expensePayersResult,
    expenseSharesResult,
    expenseItemsResult,
    giftPoolContributionsResult,
    contributionRecordsResult,
    communityExpensesResult,
  ] = await Promise.all([
    expenseIds.length ? db().from('expense_payers').select('*').in('expense_id', expenseIds) : emptyResult(),
    expenseIds.length ? db().from('expense_shares').select('*').in('expense_id', expenseIds) : emptyResult(),
    expenseIds.length
      ? db()
          .from('expense_items')
          .select('*')
          .in('expense_id', expenseIds)
          .order('sort_order', { ascending: true })
      : emptyResult(),
    giftPoolIds.length
      ? db()
          .from('gift_pool_contributions')
          .select('*')
          .in('gift_pool_id', giftPoolIds)
          .order('created_at', { ascending: true })
      : emptyResult(),
    savingsGroupIds.length
      ? db()
          .from('contribution_records')
          .select('*')
          .in('savings_group_id', savingsGroupIds)
          .order('month', { ascending: true })
      : emptyResult(),
    savingsGroupIds.length
      ? db()
          .from('community_expenses')
          .select('*')
          .in('savings_group_id', savingsGroupIds)
          .order('expense_date', { ascending: true })
      : emptyResult(),
  ]);
  [
    expensePayersResult,
    expenseSharesResult,
    expenseItemsResult,
    giftPoolContributionsResult,
    contributionRecordsResult,
    communityExpensesResult,
  ].forEach((result) => assertDb(result.error));

  const expensePayers = expensePayersResult.data ?? [];
  const expenseShares = expenseSharesResult.data ?? [];
  const expenseItems = expenseItemsResult.data ?? [];
  const giftPoolContributions = giftPoolContributionsResult.data ?? [];
  const contributionRecords = contributionRecordsResult.data ?? [];
  const communityExpenses = communityExpensesResult.data ?? [];
  const expenseItemIds = expenseItems.map((row) => row.id);

  const expenseItemAssignmentsResult = expenseItemIds.length
    ? await db().from('expense_item_assignments').select('*').in('expense_item_id', expenseItemIds)
    : await emptyResult();
  assertDb(expenseItemAssignmentsResult.error);
  const expenseItemAssignments = expenseItemAssignmentsResult.data ?? [];

  const paymentIds = [
    ...settlements.map((row) => row.payment_transaction_id),
    ...gifts.map((row) => row.payment_transaction_id),
    ...giftPoolContributions.map((row) => row.payment_transaction_id),
  ].filter(Boolean);
  const paymentsResult = paymentIds.length
    ? await db()
        .from('payment_transactions')
        .select('*')
        .in('id', [...new Set(paymentIds)])
        .order('created_at', { ascending: true })
    : await db()
        .from('payment_transactions')
        .select('*')
        .eq('actor_id', currentUserId)
        .order('created_at', { ascending: true });
  assertDb(paymentsResult.error);
  const payments = paymentsResult.data ?? [];

  const visibleProfileIds = new Set([
    currentUserId,
    ...connections.flatMap((row) => [row.requester_id, row.recipient_id]),
    ...groupMembers.map((row) => row.user_id),
    ...groups.map((row) => row.created_by),
    ...expenses.flatMap((row) => [row.payer_id, row.created_by, row.voided_by]),
    ...expensePayers.map((row) => row.user_id),
    ...expenseShares.map((row) => row.user_id),
    ...expenseItemAssignments.map((row) => row.user_id),
    ...settlements.flatMap((row) => [row.payer_id, row.payee_id]),
    ...gifts.flatMap((row) => [row.sender_id, row.recipient_id]),
    ...giftPools.flatMap((row) => [row.created_by, row.recipient_id]),
    ...giftPoolContributions.map((row) => row.contributor_id),
    ...communitySavingsGroups.map((row) => row.created_by),
    ...contributionRecords.flatMap((row) => [row.user_id, row.confirmed_by]),
    ...communityExpenses.map((row) => row.recorded_by),
    ...activityLogs.map((row) => row.actor_id),
    ...notifications.map((row) => row.user_id),
  ].filter(Boolean));

  const profilesResult = visibleProfileIds.size
    ? await db()
        .from('profiles')
        .select('*')
        .in('id', [...visibleProfileIds])
        .order('created_at', { ascending: true })
    : await emptyResult();
  assertDb(profilesResult.error);
  const profiles = profilesResult.data ?? [];

  const profileIds = new Map(profiles.map((row) => [row.id, fallbackLegacyId(row, 'user')]));
  const groupIds = new Map(groups.map((row) => [row.id, fallbackLegacyId(row, 'group')]));
  const poolIds = new Map(
    communitySavingsGroups.map((row) => [row.id, fallbackLegacyId(row, 'community-savings')]),
  );

  return {
    currentUserId: profileIds.get(currentUserId) ?? currentUserId,
    users: profiles.map(mapProfile),
    connections: connections.map((row) => mapConnection(row, profileIds)),
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
