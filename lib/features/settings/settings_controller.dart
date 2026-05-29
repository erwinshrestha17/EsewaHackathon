import 'package:flutter/foundation.dart';

import 'settings_models.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({SettingsState? initialState})
    : _state = initialState ?? SettingsState.seeded();

  SettingsState _state;

  SettingsState get state => _state;

  void updateProfile(ProfileDraft draft) {
    _state = _state.copyWith(
      displayName: draft.displayName,
      phone: draft.phone,
      esewaId: draft.esewaId,
      district: draft.district,
      avatarInitials: draft.avatarInitials,
    );
    notifyListeners();
  }

  void setConnectionRequestPreference(ConnectionRequestPreference value) {
    _state = _state.copyWith(connectionRequestPreference: value);
    notifyListeners();
  }

  void setDefaultSplitMode(DefaultSplitMode value) {
    _state = _state.copyWith(defaultSplitMode: value);
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
    if (value == AppLanguage.nepaliComingSoon) {
      return;
    }
    _state = _state.copyWith(language: value);
    notifyListeners();
  }

  void setNotification(NotificationPreference preference, bool enabled) {
    _state = _state.copyWith(
      notifications: {..._state.notifications, preference: enabled},
    );
    notifyListeners();
  }
}
