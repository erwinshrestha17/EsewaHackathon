enum ConnectionRequestPreference { everyone, contactsOnly, qrInviteOnly }

enum DefaultSplitMode { equal, exactAmount, percentage, shares }

enum ActivityTimelineLimit { latest5, latest10, latest20 }

enum AppThemeMode { system, light, dark }

enum AppLanguage { english, nepaliComingSoon }

enum NotificationPreference {
  connectionRequests,
  groupInvitations,
  expenseAdded,
  settlementReminders,
  paymentStatusUpdates,
  giftReceived,
  dhukutiContributionDue,
  dhukutiCycleAtRisk,
}

const dhukutiSafetyNoteText =
    'Digital Dhukuti in this prototype is a transparent contribution ledger '
    'and payment scheduler. It does not provide credit, interest, investment '
    'return, or guaranteed payout.';

class SettingsState {
  const SettingsState({
    required this.displayName,
    required this.phone,
    required this.esewaId,
    required this.district,
    required this.avatarInitials,
    required this.connectionRequestPreference,
    required this.defaultSplitMode,
    required this.activityTimelineLimit,
    required this.showRoundingNote,
    required this.confirmBeforePayment,
    required this.settlementNudges,
    required this.mockEsewaMode,
    required this.dhukutiContributionReminders,
    required this.dhukutiAtRiskAlerts,
    required this.themeMode,
    required this.language,
    required this.notifications,
  });

  factory SettingsState.seeded() {
    return SettingsState(
      displayName: 'Erwin Shrestha',
      phone: '98XXXXXXXX',
      esewaId: 'erwin@esewa',
      district: 'Bharatpur',
      avatarInitials: 'ES',
      connectionRequestPreference: ConnectionRequestPreference.everyone,
      defaultSplitMode: DefaultSplitMode.equal,
      activityTimelineLimit: ActivityTimelineLimit.latest5,
      showRoundingNote: true,
      confirmBeforePayment: true,
      settlementNudges: true,
      mockEsewaMode: true,
      dhukutiContributionReminders: true,
      dhukutiAtRiskAlerts: true,
      themeMode: AppThemeMode.system,
      language: AppLanguage.english,
      notifications: {
        for (final preference in NotificationPreference.values)
          preference: true,
      },
    );
  }

  final String displayName;
  final String phone;
  final String esewaId;
  final String district;
  final String avatarInitials;
  final ConnectionRequestPreference connectionRequestPreference;
  final DefaultSplitMode defaultSplitMode;
  final ActivityTimelineLimit activityTimelineLimit;
  final bool showRoundingNote;
  final bool confirmBeforePayment;
  final bool settlementNudges;
  final bool mockEsewaMode;
  final bool dhukutiContributionReminders;
  final bool dhukutiAtRiskAlerts;
  final AppThemeMode themeMode;
  final AppLanguage language;
  final Map<NotificationPreference, bool> notifications;

  SettingsState copyWith({
    String? displayName,
    String? phone,
    String? esewaId,
    String? district,
    String? avatarInitials,
    ConnectionRequestPreference? connectionRequestPreference,
    DefaultSplitMode? defaultSplitMode,
    ActivityTimelineLimit? activityTimelineLimit,
    bool? showRoundingNote,
    bool? confirmBeforePayment,
    bool? settlementNudges,
    bool? mockEsewaMode,
    bool? dhukutiContributionReminders,
    bool? dhukutiAtRiskAlerts,
    AppThemeMode? themeMode,
    AppLanguage? language,
    Map<NotificationPreference, bool>? notifications,
  }) {
    return SettingsState(
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      esewaId: esewaId ?? this.esewaId,
      district: district ?? this.district,
      avatarInitials: avatarInitials ?? this.avatarInitials,
      connectionRequestPreference:
          connectionRequestPreference ?? this.connectionRequestPreference,
      defaultSplitMode: defaultSplitMode ?? this.defaultSplitMode,
      activityTimelineLimit:
          activityTimelineLimit ?? this.activityTimelineLimit,
      showRoundingNote: showRoundingNote ?? this.showRoundingNote,
      confirmBeforePayment: confirmBeforePayment ?? this.confirmBeforePayment,
      settlementNudges: settlementNudges ?? this.settlementNudges,
      mockEsewaMode: mockEsewaMode ?? this.mockEsewaMode,
      dhukutiContributionReminders:
          dhukutiContributionReminders ?? this.dhukutiContributionReminders,
      dhukutiAtRiskAlerts: dhukutiAtRiskAlerts ?? this.dhukutiAtRiskAlerts,
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      notifications: notifications ?? this.notifications,
    );
  }
}

extension ConnectionRequestPreferenceLabel on ConnectionRequestPreference {
  String get label {
    return switch (this) {
      ConnectionRequestPreference.everyone => 'Everyone',
      ConnectionRequestPreference.contactsOnly => 'Contacts only',
      ConnectionRequestPreference.qrInviteOnly => 'QR invite only',
    };
  }
}

extension DefaultSplitModeLabel on DefaultSplitMode {
  String get label {
    return switch (this) {
      DefaultSplitMode.equal => 'Equal Split',
      DefaultSplitMode.exactAmount => 'Exact Amount',
      DefaultSplitMode.percentage => 'Percentage',
      DefaultSplitMode.shares => 'Shares',
    };
  }
}

extension ActivityTimelineLimitLabel on ActivityTimelineLimit {
  String get label {
    return switch (this) {
      ActivityTimelineLimit.latest5 => 'Latest 5',
      ActivityTimelineLimit.latest10 => 'Latest 10',
      ActivityTimelineLimit.latest20 => 'Latest 20',
    };
  }

  int get count {
    return switch (this) {
      ActivityTimelineLimit.latest5 => 5,
      ActivityTimelineLimit.latest10 => 10,
      ActivityTimelineLimit.latest20 => 20,
    };
  }
}

extension AppThemeModeLabel on AppThemeMode {
  String get label {
    return switch (this) {
      AppThemeMode.system => 'System',
      AppThemeMode.light => 'Light',
      AppThemeMode.dark => 'Dark',
    };
  }
}

extension AppLanguageLabel on AppLanguage {
  String get label {
    return switch (this) {
      AppLanguage.english => 'English',
      AppLanguage.nepaliComingSoon => 'Nepali',
    };
  }

  String? get helper {
    return switch (this) {
      AppLanguage.english => null,
      AppLanguage.nepaliComingSoon => 'Coming Soon',
    };
  }
}

extension NotificationPreferenceLabel on NotificationPreference {
  String get label {
    return switch (this) {
      NotificationPreference.connectionRequests => 'Connection requests',
      NotificationPreference.groupInvitations => 'Group invitations',
      NotificationPreference.expenseAdded => 'Expense added',
      NotificationPreference.settlementReminders => 'Settlement reminders',
      NotificationPreference.paymentStatusUpdates => 'Payment status updates',
      NotificationPreference.giftReceived => 'Gift received',
      NotificationPreference.dhukutiContributionDue =>
        'Dhukuti contribution due',
      NotificationPreference.dhukutiCycleAtRisk => 'Dhukuti cycle at risk',
    };
  }
}
