import 'package:flutter/foundation.dart';

import 'settings_models.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({SettingsState? initialState})
    : _state = initialState ?? SettingsState.defaults();

  SettingsState _state;

  SettingsState get state => _state;

  void applyBackendSettings(
    Map<String, dynamic> settings, {
    bool notify = true,
  }) {
    final preferences =
        settings['notificationPreferences'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    _state = _state.copyWith(
      connectionRequestPreference: _enumByName(
        ConnectionRequestPreference.values,
        preferences['connectionRequestPreference'],
        _state.connectionRequestPreference,
      ),
      defaultSplitMode: _enumByName(
        DefaultSplitMode.values,
        preferences['defaultSplitMode'],
        _state.defaultSplitMode,
      ),
      reminderFrequency: _enumByName(
        ReminderFrequency.values,
        preferences['reminderFrequency'],
        _state.reminderFrequency,
      ),
      ocrReviewPreference: _enumByName(
        OcrReviewPreference.values,
        preferences['ocrReviewPreference'],
        _state.ocrReviewPreference,
      ),
      activityTimelineLimit: _enumByName(
        ActivityTimelineLimit.values,
        preferences['activityTimelineLimit'],
        _state.activityTimelineLimit,
      ),
      showRoundingNote:
          preferences['showRoundingNote'] as bool? ?? _state.showRoundingNote,
      confirmBeforePayment:
          settings['confirmBeforePayment'] as bool? ??
          preferences['confirmBeforePayment'] as bool? ??
          _state.confirmBeforePayment,
      settlementNudges:
          preferences['settlementNudges'] as bool? ?? _state.settlementNudges,
      dhukutiContributionReminders:
          preferences['dhukutiContributionReminders'] as bool? ??
          _state.dhukutiContributionReminders,
      dhukutiAtRiskAlerts:
          preferences['dhukutiAtRiskAlerts'] as bool? ??
          _state.dhukutiAtRiskAlerts,
      themeMode: _themeMode(settings['themeMode'], _state.themeMode),
      language: _language(settings['language'], _state.language),
      notifications: {
        for (final preference in NotificationPreference.values)
          preference: preferences['notifications'] is Map<String, dynamic>
              ? ((preferences['notifications']
                            as Map<String, dynamic>)[preference.name]
                        as bool? ??
                    _state.notifications[preference] ??
                    true)
              : _state.notifications[preference] ?? true,
      },
    );
    if (notify) {
      notifyListeners();
    }
  }

  Map<String, Object?> toBackendPayload() {
    return {
      'themeMode': _state.themeMode.name,
      'language': switch (_state.language) {
        AppLanguage.english => 'en',
        AppLanguage.nepali => 'ne',
      },
      'confirmBeforePayment': _state.confirmBeforePayment,
      'notificationPreferences': {
        'connectionRequestPreference': _state.connectionRequestPreference.name,
        'defaultSplitMode': _state.defaultSplitMode.name,
        'reminderFrequency': _state.reminderFrequency.name,
        'ocrReviewPreference': _state.ocrReviewPreference.name,
        'activityTimelineLimit': _state.activityTimelineLimit.name,
        'showRoundingNote': _state.showRoundingNote,
        'confirmBeforePayment': _state.confirmBeforePayment,
        'settlementNudges': _state.settlementNudges,
        'dhukutiContributionReminders': _state.dhukutiContributionReminders,
        'dhukutiAtRiskAlerts': _state.dhukutiAtRiskAlerts,
        'notifications': {
          for (final preference in NotificationPreference.values)
            preference.name: _state.notifications[preference] ?? true,
        },
      },
    };
  }

  void setConnectionRequestPreference(ConnectionRequestPreference value) {
    _state = _state.copyWith(connectionRequestPreference: value);
    notifyListeners();
  }

  void setDefaultSplitMode(DefaultSplitMode value) {
    _state = _state.copyWith(defaultSplitMode: value);
    notifyListeners();
  }

  void setReminderFrequency(ReminderFrequency value) {
    _state = _state.copyWith(reminderFrequency: value);
    notifyListeners();
  }

  void setOcrReviewPreference(OcrReviewPreference value) {
    _state = _state.copyWith(ocrReviewPreference: value);
    notifyListeners();
  }

  void setActivityTimelineLimit(ActivityTimelineLimit value) {
    _state = _state.copyWith(activityTimelineLimit: value);
    notifyListeners();
  }

  void setShowRoundingNote(bool value) {
    _state = _state.copyWith(showRoundingNote: value);
    notifyListeners();
  }

  void setConfirmBeforePayment(bool value) {
    _state = _state.copyWith(confirmBeforePayment: value);
    notifyListeners();
  }

  void setSettlementNudges(bool value) {
    _state = _state.copyWith(settlementNudges: value);
    notifyListeners();
  }

  void setDhukutiContributionReminders(bool value) {
    _state = _state.copyWith(dhukutiContributionReminders: value);
    notifyListeners();
  }

  void setDhukutiAtRiskAlerts(bool value) {
    _state = _state.copyWith(dhukutiAtRiskAlerts: value);
    notifyListeners();
  }

  void setThemeMode(AppThemeMode value) {
    _state = _state.copyWith(themeMode: value);
    notifyListeners();
  }

  void setLanguage(AppLanguage value) {
    _state = _state.copyWith(language: value);
    notifyListeners();
  }

  void setNotification(NotificationPreference preference, bool enabled) {
    _state = _state.copyWith(
      notifications: {..._state.notifications, preference: enabled},
    );
    notifyListeners();
  }

  T _enumByName<T extends Enum>(List<T> values, Object? value, T fallback) {
    final name = value?.toString();
    if (name == null || name.isEmpty) {
      return fallback;
    }
    for (final item in values) {
      if (item.name == name) {
        return item;
      }
    }
    return fallback;
  }

  AppThemeMode _themeMode(Object? value, AppThemeMode fallback) {
    return _enumByName(AppThemeMode.values, value, fallback);
  }

  AppLanguage _language(Object? value, AppLanguage fallback) {
    return switch (value?.toString()) {
      'en' || 'english' => AppLanguage.english,
      'ne' || 'nepali' => AppLanguage.nepali,
      _ => fallback,
    };
  }
}
