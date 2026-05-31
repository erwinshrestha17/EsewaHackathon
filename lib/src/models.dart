enum ConnectionStatus { pending, approved, declined, expired, removed }

enum PrivacyMode { everyone, contactsOnly, qrInviteOnly }

enum MemberRole { admin, member, treasurer }

enum MemberStatus { active, removed }

enum GroupKind { expense, dhukuti }

enum GroupLeaveDecisionType {
  canLeave,
  owesMoney,
  receivableActive,
  zeroBalance,
  needsNewAdmin,
  unavailable,
}

enum GroupCategory {
  festival,
  trek,
  bhoj,
  travel,
  event,
  household,
  apartment,
  custom,
}

enum SplitMode { equal, custom, item }

enum ExpenseStatus { draft, active, voided }

enum RecurringExpenseFrequency { weekly, monthly }

enum ExpenseReviewStatus {
  pending,
  accepted,
  correctionRequested,
  itemDisputed,
}

enum PaymentStatus {
  pending,
  paid,
  failed,
  failedReview,
  expired,
  cancelled,
  refunded,
}

enum GiftStatus {
  pending,
  sent,
  opened,
  failed,
  failedReview,
  expired,
  cancelled,
  refunded,
}

enum GiftPoolStatus { open, completed, cancelled, refunded }

enum GiftPoolContributionRule { equal, threshold }

enum ContributionStatus {
  due,
  pending,
  paid,
  late,
  missed,
  failed,
  failedReview,
  expired,
  cancelled,
}

enum DhukutiPoolStatus { draft, active, completed, cancelled }

enum DhukutiMemberStatus { invited, active, declined, exited }

enum DhukutiCycleStatus {
  upcoming,
  open,
  atRisk,
  readyForPayout,
  paidOut,
  closed,
  cancelled,
}

enum PayoutStatus { pending, paid, failed, failedReview, expired, cancelled }

enum AdjustmentType { correction, reversal, refund, manual }

enum DhukutiExitDecisionType {
  canLeaveBeforeStart,
  pendingContribution,
  receivedPayout,
  requiresApproval,
  unavailable,
}

class AppUser {
  AppUser({
    required this.id,
    required this.displayName,
    required this.phone,
    required this.avatar,
    required this.district,
    required this.createdAt,
    this.privacyMode = PrivacyMode.everyone,
  });

  final String id;
  final String displayName;
  final String phone;
  final String avatar;
  final String district;
  final DateTime createdAt;
  PrivacyMode privacyMode;
}

class ConnectionBlock {
  ConnectionBlock({
    required this.id,
    required this.connectionId,
    required this.blockerId,
    required this.blockedUserId,
    required this.createdAt,
    this.active = true,
    this.liftedAt,
  });

  final String id;
  final String connectionId;
  final String blockerId;
  final String blockedUserId;
  final DateTime createdAt;
  bool active;
  DateTime? liftedAt;
}

class ConnectionReport {
  ConnectionReport({
    required this.id,
    required this.connectionId,
    required this.reporterId,
    required this.reportedUserId,
    required this.reasonCode,
    required this.createdAt,
    this.details,
    this.status = 'open',
  });

  final String id;
  final String connectionId;
  final String reporterId;
  final String reportedUserId;
  final String reasonCode;
  final DateTime createdAt;
  final String? details;
  String status;
}

class ConnectionEvent {
  ConnectionEvent({
    required this.id,
    required this.connectionId,
    required this.actorId,
    required this.eventType,
    required this.createdAt,
    this.previousStatus,
    this.nextStatus,
    this.note,
  });

  final String id;
  final String connectionId;
  final String actorId;
  final String eventType;
  final DateTime createdAt;
  final ConnectionStatus? previousStatus;
  final ConnectionStatus? nextStatus;
  final String? note;
}

class Connection {
  Connection({
    required this.id,
    required this.requesterId,
    required this.recipientId,
    required this.userLowId,
    required this.userHighId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
    List<ConnectionEvent>? events,
    List<ConnectionBlock>? blocks,
    List<ConnectionReport>? reports,
  }) : events = events ?? <ConnectionEvent>[],
       blocks = blocks ?? <ConnectionBlock>[],
       reports = reports ?? <ConnectionReport>[];

  final String id;
  String requesterId;
  String recipientId;
  final String userLowId;
  final String userHighId;
  ConnectionStatus status;
  DateTime createdAt;
  DateTime updatedAt;
  DateTime expiresAt;
  final List<ConnectionEvent> events;
  final List<ConnectionBlock> blocks;
  final List<ConnectionReport> reports;

  bool hasUser(String userId) => requesterId == userId || recipientId == userId;

  String otherUserId(String userId) =>
      requesterId == userId ? recipientId : requesterId;

  bool isBlockedBetween(String a, String b) {
    return blocks.any(
      (block) =>
          block.active &&
          ((block.blockerId == a && block.blockedUserId == b) ||
              (block.blockerId == b && block.blockedUserId == a)),
    );
  }

  bool isBlockedBy(String blockerId, String blockedUserId) {
    return blocks.any(
      (block) =>
          block.active &&
          block.blockerId == blockerId &&
          block.blockedUserId == blockedUserId,
    );
  }

  bool hasReportFrom(String reporterId, String reportedUserId) {
    return reports.any(
      (report) =>
          report.reporterId == reporterId &&
          report.reportedUserId == reportedUserId,
    );
  }
}

class Group {
  Group({
    required this.id,
    required this.name,
    required this.category,
    required this.template,
    this.kind = GroupKind.expense,
    required this.createdBy,
    required this.createdAt,
    this.latestSettlementLockAt,
    this.disbandedAt,
    this.disbandedBy,
  });

  final String id;
  String name;
  GroupCategory category;
  String template;
  GroupKind kind;
  final String createdBy;
  final DateTime createdAt;
  DateTime? latestSettlementLockAt;
  DateTime? disbandedAt;
  String? disbandedBy;

  bool get isDisbanded => disbandedAt != null;
}

class GroupMember {
  GroupMember({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.role,
    required this.status,
    required this.joinedAt,
    this.removedAt,
  });

  final String id;
  final String groupId;
  final String userId;
  MemberRole role;
  MemberStatus status;
  final DateTime joinedAt;
  DateTime? removedAt;
}

class GroupLeaveDecision {
  const GroupLeaveDecision({
    required this.type,
    required this.title,
    required this.message,
    this.amountMinor = 0,
    this.primaryAction,
    this.secondaryAction,
  });

  final GroupLeaveDecisionType type;
  final String title;
  final String message;
  final int amountMinor;
  final String? primaryAction;
  final String? secondaryAction;

  bool get canLeaveNow =>
      type == GroupLeaveDecisionType.receivableActive ||
      type == GroupLeaveDecisionType.zeroBalance ||
      type == GroupLeaveDecisionType.canLeave;
}

class GroupTemplateSuggestion {
  const GroupTemplateSuggestion({
    required this.id,
    required this.name,
    required this.category,
    required this.template,
    required this.description,
    required this.memberLimit,
    this.recurringTitle,
    this.recurringAmountMinor = 0,
    this.recurringFrequency = RecurringExpenseFrequency.monthly,
  });

  final String id;
  final String name;
  final GroupCategory category;
  final String template;
  final String description;
  final int memberLimit;
  final String? recurringTitle;
  final int recurringAmountMinor;
  final RecurringExpenseFrequency recurringFrequency;

  bool get hasRecurringSeed =>
      recurringTitle != null && recurringAmountMinor > 0;
}

class DhukutiExitDecision {
  const DhukutiExitDecision({
    required this.type,
    required this.title,
    required this.message,
    this.amountMinor = 0,
    this.primaryAction,
    this.secondaryAction,
  });

  final DhukutiExitDecisionType type;
  final String title;
  final String message;
  final int amountMinor;
  final String? primaryAction;
  final String? secondaryAction;

  bool get canLeaveNow => type == DhukutiExitDecisionType.canLeaveBeforeStart;

  bool get canRequestApproval =>
      type == DhukutiExitDecisionType.requiresApproval ||
      type == DhukutiExitDecisionType.receivedPayout;
}

class ItemSplitInput {
  const ItemSplitInput({required this.userIds, this.shareUnits});

  final List<String> userIds;
  final Map<String, int>? shareUnits;
}

class ExpenseShare {
  ExpenseShare({
    required this.id,
    required this.expenseId,
    required this.userId,
    required this.amountMinor,
    this.percentage,
    this.shareUnits,
    this.sourceType = 'manual',
    this.sourceId,
  });

  final String id;
  final String expenseId;
  final String userId;
  int amountMinor;
  double? percentage;
  int? shareUnits;
  String sourceType;
  String? sourceId;
}

class ExpenseItemAssignment {
  ExpenseItemAssignment({
    required this.id,
    required this.expenseItemId,
    required this.userId,
    required this.assignedAmountMinor,
    this.splitUnits = 1,
  });

  final String id;
  final String expenseItemId;
  final String userId;
  int assignedAmountMinor;
  int splitUnits;
}

class ExpenseItem {
  ExpenseItem({
    required this.id,
    required this.expenseId,
    required this.label,
    required this.quantity,
    required this.unitAmountMinor,
    required this.totalAmountMinor,
    this.taxMinor = 0,
    this.serviceChargeMinor = 0,
    this.discountMinor = 0,
    this.ocrConfidence = 1,
    this.sortOrder = 0,
    List<ExpenseItemAssignment>? assignments,
  }) : assignments = assignments ?? <ExpenseItemAssignment>[];

  final String id;
  final String expenseId;
  String label;
  int quantity;
  int unitAmountMinor;
  int totalAmountMinor;
  int taxMinor;
  int serviceChargeMinor;
  int discountMinor;
  double ocrConfidence;
  int sortOrder;
  final List<ExpenseItemAssignment> assignments;
}

class ExpensePayer {
  ExpensePayer({
    required this.id,
    required this.expenseId,
    required this.userId,
    required this.amountMinor,
  });

  final String id;
  final String expenseId;
  final String userId;
  int amountMinor;
}

class Expense {
  Expense({
    required this.id,
    required this.groupId,
    required this.title,
    required this.subtotalMinor,
    required this.totalMinor,
    required this.payerId,
    required this.category,
    required this.splitMode,
    required this.status,
    required this.expenseDate,
    required this.createdBy,
    required this.createdAt,
    this.note = '',
    this.receiptUrl,
    this.billTaxMinor = 0,
    this.billServiceChargeMinor = 0,
    this.billDiscountMinor = 0,
    this.billTipMinor = 0,
    this.billRoundingAdjustmentMinor = 0,
    this.lockedAt,
    this.voidedAt,
    this.voidedBy,
    this.voidReason,
    List<ExpensePayer>? payers,
    List<ExpenseShare>? shares,
    List<ExpenseItem>? items,
  }) : payers = payers ?? <ExpensePayer>[],
       shares = shares ?? <ExpenseShare>[],
       items = items ?? <ExpenseItem>[];

  final String id;
  final String groupId;
  String title;
  int subtotalMinor;
  int totalMinor;
  String payerId;
  String category;
  SplitMode splitMode;
  ExpenseStatus status;
  DateTime expenseDate;
  String note;
  String? receiptUrl;
  int billTaxMinor;
  int billServiceChargeMinor;
  int billDiscountMinor;
  int billTipMinor;
  int billRoundingAdjustmentMinor;
  DateTime? lockedAt;
  DateTime? voidedAt;
  String? voidedBy;
  String? voidReason;
  final String createdBy;
  final DateTime createdAt;
  final List<ExpensePayer> payers;
  final List<ExpenseShare> shares;
  final List<ExpenseItem> items;
}

class ExpenseReview {
  ExpenseReview({
    required this.id,
    required this.expenseId,
    required this.userId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.note = '',
    this.expenseItemId,
  });

  final String id;
  final String expenseId;
  final String userId;
  ExpenseReviewStatus status;
  String note;
  String? expenseItemId;
  final DateTime createdAt;
  DateTime updatedAt;
}

class ExpenseReviewSummary {
  const ExpenseReviewSummary({
    required this.total,
    required this.accepted,
    required this.pending,
    required this.correctionRequested,
    required this.itemDisputed,
  });

  final int total;
  final int accepted;
  final int pending;
  final int correctionRequested;
  final int itemDisputed;

  bool get isFinal => total > 0 && accepted == total;
  bool get hasConcerns => correctionRequested > 0 || itemDisputed > 0;

  String get label {
    if (hasConcerns) {
      final concernCount = correctionRequested + itemDisputed;
      return '$concernCount issue${concernCount == 1 ? '' : 's'} raised';
    }
    if (isFinal) {
      return 'Accepted by all';
    }
    return '$accepted/$total accepted';
  }
}

class RecurringExpense {
  RecurringExpense({
    required this.id,
    required this.groupId,
    required this.title,
    required this.amountMinor,
    required this.payerId,
    required this.category,
    required this.splitMode,
    required this.frequency,
    required this.nextDueAt,
    required this.createdBy,
    required this.createdAt,
    List<String>? participantIds,
    this.note = '',
    this.active = true,
    this.lastPostedAt,
    this.sourceExpenseId,
    Map<String, int>? customAmounts,
  }) : participantIds = participantIds ?? <String>[],
       customAmounts = customAmounts ?? <String, int>{};

  final String id;
  final String groupId;
  String title;
  int amountMinor;
  String payerId;
  String category;
  SplitMode splitMode;
  RecurringExpenseFrequency frequency;
  DateTime nextDueAt;
  String note;
  bool active;
  DateTime? lastPostedAt;
  String? sourceExpenseId;
  final String createdBy;
  final DateTime createdAt;
  final List<String> participantIds;
  final Map<String, int> customAmounts;
}

class PaymentTransaction {
  PaymentTransaction({
    required this.id,
    required this.paymentProvider,
    required this.paymentReference,
    required this.operationType,
    required this.entityType,
    required this.entityId,
    required this.actorId,
    required this.amountMinor,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.confirmedAt,
    this.failedAt,
    this.expiredAt,
    this.cancelledAt,
    this.refundedAt,
    this.rawPayload = '',
  });

  final String id;
  final String paymentProvider;
  final String paymentReference;
  final String operationType;
  final String entityType;
  final String entityId;
  final String actorId;
  final int amountMinor;
  PaymentStatus status;
  final String rawPayload;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? confirmedAt;
  DateTime? failedAt;
  DateTime? expiredAt;
  DateTime? cancelledAt;
  DateTime? refundedAt;
}

class Settlement {
  Settlement({
    required this.id,
    required this.groupId,
    required this.payerId,
    required this.payeeId,
    required this.amountMinor,
    required this.status,
    required this.idempotencyKey,
    required this.idempotencyScope,
    required this.operationType,
    required this.expiresAt,
    required this.balanceSnapshotHash,
    required this.createdAt,
    this.paymentTransactionId,
    this.failureReason,
    this.paidAt,
  });

  final String id;
  final String groupId;
  final String payerId;
  final String payeeId;
  final int amountMinor;
  PaymentStatus status;
  String? paymentTransactionId;
  final String idempotencyKey;
  final String idempotencyScope;
  final String operationType;
  String? failureReason;
  final DateTime expiresAt;
  final String balanceSnapshotHash;
  final DateTime createdAt;
  DateTime? paidAt;

  bool get isExternal => operationType == 'external_settlement';
}

class AdjustmentEntry {
  AdjustmentEntry({
    required this.id,
    required this.adjustmentId,
    required this.userId,
    required this.amountMinor,
    required this.direction,
  });

  final String id;
  final String adjustmentId;
  final String userId;
  final int amountMinor;
  final String direction;
}

class Adjustment {
  Adjustment({
    required this.id,
    required this.groupId,
    required this.reason,
    required this.adjustmentType,
    required this.createdBy,
    required this.createdAt,
    List<AdjustmentEntry>? entries,
    this.reversesSourceType,
    this.reversesSourceId,
  }) : entries = entries ?? <AdjustmentEntry>[];

  final String id;
  final String groupId;
  final String reason;
  final AdjustmentType adjustmentType;
  final String createdBy;
  final DateTime createdAt;
  final String? reversesSourceType;
  final String? reversesSourceId;
  final List<AdjustmentEntry> entries;
}

class GiftCard {
  GiftCard({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.template,
    required this.amountMinor,
    required this.message,
    required this.status,
    required this.idempotencyKey,
    required this.idempotencyScope,
    required this.operationType,
    required this.createdAt,
    this.groupId,
    this.paymentTransactionId,
    this.openedAt,
    this.refundedAt,
  });

  final String id;
  final String senderId;
  final String recipientId;
  final String? groupId;
  final String template;
  final int amountMinor;
  final String message;
  GiftStatus status;
  String? paymentTransactionId;
  final String idempotencyKey;
  final String idempotencyScope;
  final String operationType;
  DateTime? openedAt;
  final DateTime createdAt;
  DateTime? refundedAt;
}

class GiftPool {
  GiftPool({
    required this.id,
    required this.groupId,
    required this.createdBy,
    required this.recipientId,
    required this.title,
    required this.template,
    required this.targetAmountMinor,
    required this.contributionRule,
    required this.allowOverTarget,
    required this.message,
    required this.status,
    required this.createdAt,
    this.equalContributionAmountMinor,
    this.minContributionAmountMinor,
    this.maxContributionAmountMinor,
  });

  final String id;
  final String groupId;
  final String createdBy;
  final String recipientId;
  String title;
  String template;
  int targetAmountMinor;
  GiftPoolContributionRule contributionRule;
  bool allowOverTarget;
  int? equalContributionAmountMinor;
  int? minContributionAmountMinor;
  int? maxContributionAmountMinor;
  String message;
  GiftPoolStatus status;
  final DateTime createdAt;
}

class GiftPoolContribution {
  GiftPoolContribution({
    required this.id,
    required this.giftPoolId,
    required this.contributorId,
    required this.amountMinor,
    required this.status,
    required this.idempotencyKey,
    required this.idempotencyScope,
    required this.operationType,
    required this.createdAt,
    this.paymentTransactionId,
    this.paidAt,
  });

  final String id;
  final String giftPoolId;
  final String contributorId;
  final int amountMinor;
  PaymentStatus status;
  String? paymentTransactionId;
  final String idempotencyKey;
  final String idempotencyScope;
  final String operationType;
  final DateTime createdAt;
  DateTime? paidAt;
}

class DhukutiPool {
  DhukutiPool({
    required this.id,
    required this.groupId,
    required this.name,
    required this.contributionAmountMinor,
    required this.frequency,
    required this.startDate,
    required this.createdBy,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String groupId;
  String name;
  int contributionAmountMinor;
  String frequency;
  DateTime startDate;
  String createdBy;
  DhukutiPoolStatus status;
  DateTime createdAt;
}

class DhukutiMember {
  DhukutiMember({
    required this.id,
    required this.poolId,
    required this.userId,
    required this.payoutOrder,
    required this.status,
  });

  final String id;
  final String poolId;
  final String userId;
  int payoutOrder;
  DhukutiMemberStatus status;
}

class DhukutiCycle {
  DhukutiCycle({
    required this.id,
    required this.poolId,
    required this.cycleNumber,
    required this.dueDate,
    required this.payoutRecipientId,
    required this.expectedContributionTotalMinor,
    required this.paidContributionTotalMinor,
    required this.status,
  });

  final String id;
  final String poolId;
  final int cycleNumber;
  DateTime dueDate;
  String payoutRecipientId;
  int expectedContributionTotalMinor;
  int paidContributionTotalMinor;
  DhukutiCycleStatus status;
}

class DhukutiContribution {
  DhukutiContribution({
    required this.id,
    required this.poolId,
    required this.cycleId,
    required this.userId,
    required this.cycleNumber,
    required this.dueDate,
    required this.amountMinor,
    required this.status,
    required this.idempotencyKey,
    required this.idempotencyScope,
    required this.operationType,
    this.paymentTransactionId,
    this.paidAt,
  });

  final String id;
  final String poolId;
  final String cycleId;
  final String userId;
  final int cycleNumber;
  DateTime dueDate;
  int amountMinor;
  ContributionStatus status;
  String? paymentTransactionId;
  final String idempotencyKey;
  final String idempotencyScope;
  final String operationType;
  DateTime? paidAt;
}

class DhukutiPayout {
  DhukutiPayout({
    required this.id,
    required this.poolId,
    required this.cycleId,
    required this.recipientId,
    required this.amountMinor,
    required this.status,
    required this.idempotencyKey,
    required this.idempotencyScope,
    required this.operationType,
    this.paymentTransactionId,
    this.failureReason,
    this.paidAt,
  });

  final String id;
  final String poolId;
  final String cycleId;
  final String recipientId;
  final int amountMinor;
  PayoutStatus status;
  String? paymentTransactionId;
  final String idempotencyKey;
  final String idempotencyScope;
  final String operationType;
  String? failureReason;
  DateTime? paidAt;
}

class EmergencyExitRequest {
  EmergencyExitRequest({
    required this.id,
    required this.poolId,
    required this.userId,
    required this.reason,
    required this.createdAt,
    this.status = 'requested',
  });

  final String id;
  final String poolId;
  final String userId;
  final String reason;
  final DateTime createdAt;
  String status;
}

class ActivityLog {
  ActivityLog({
    required this.id,
    required this.actorId,
    required this.actorType,
    required this.eventType,
    required this.entityType,
    required this.entityId,
    required this.title,
    required this.body,
    required this.createdAt,
    this.groupId,
  });

  final String id;
  final String? actorId;
  final String actorType;
  final String eventType;
  final String entityType;
  final String entityId;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? groupId;
}

class GroupLedgerEntry {
  const GroupLedgerEntry({
    required this.id,
    required this.groupId,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.createdAt,
    required this.amountMinor,
    required this.status,
    this.actorId,
    this.affectsBalance = true,
  });

  final String id;
  final String groupId;
  final String type;
  final String title;
  final String subtitle;
  final DateTime createdAt;
  final int amountMinor;
  final String status;
  final String? actorId;
  final bool affectsBalance;
}

class GroupInsight {
  const GroupInsight({
    required this.title,
    required this.body,
    required this.metric,
    this.tone = 'info',
  });

  final String title;
  final String body;
  final String metric;
  final String tone;
}

class NotificationItem {
  NotificationItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
  });

  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  bool read;
}

class SettlementSuggestion {
  SettlementSuggestion({
    required this.groupId,
    required this.payerId,
    required this.payeeId,
    required this.amountMinor,
    this.pendingSettlementId,
  });

  final String groupId;
  final String payerId;
  final String payeeId;
  final int amountMinor;
  final String? pendingSettlementId;

  bool get hasPending => pendingSettlementId != null;
}

class SmartSettlementPlan {
  const SmartSettlementPlan({
    required this.groupId,
    required this.suggestions,
    required this.blockedExpenseCount,
    required this.reviewIssueCount,
  });

  final String groupId;
  final List<SettlementSuggestion> suggestions;
  final int blockedExpenseCount;
  final int reviewIssueCount;

  int get routeCount => suggestions.length;

  int get totalAmountMinor => suggestions.fold<int>(
    0,
    (sum, suggestion) => sum + suggestion.amountMinor,
  );

  bool get hasRoutes => suggestions.isNotEmpty;

  bool get isReady =>
      hasRoutes && blockedExpenseCount == 0 && reviewIssueCount == 0;

  String get statusLabel {
    if (!hasRoutes) {
      return 'Settled';
    }
    if (reviewIssueCount > 0) {
      return 'Needs correction';
    }
    if (blockedExpenseCount > 0) {
      return 'Review pending';
    }
    return 'Ready';
  }
}

class ParsedReceiptItem {
  ParsedReceiptItem({
    required this.label,
    required this.amountMinor,
    this.quantity = 1,
    int? unitAmountMinor,
    this.confidence = 0.94,
  }) : unitAmountMinor = unitAmountMinor ?? amountMinor;

  final String label;
  final int amountMinor;
  final int quantity;
  final int unitAmountMinor;
  final double confidence;
}
