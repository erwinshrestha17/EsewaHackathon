import 'package:flutter/foundation.dart';

import 'settings_models.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({SettingsState? initialState})
    : _state = initialState ?? SettingsState.seeded();

  SettingsState _state;

  SettingsState get state => _state;

  void setConnectionRequestPreference(ConnectionRequestPreference value) {
    _state = _state.copyWith(connectionRequestPreference: value);
    notifyListeners();
  }

  void setDefaultSplitMode(DefaultSplitMode value) {
    _state = _state.copyWith(defaultSplitMode: value);
    notifyListeners();
  }

  void setTaxAllocationMode(TaxAllocationMode value) {
    _state = _state.copyWith(taxAllocationMode: value);
    notifyListeners();
  }

  void setAmountFormatMode(AmountFormatMode value) {
    _state = _state.copyWith(amountFormatMode: value);
    notifyListeners();
  }

  void setDateFormatMode(DateFormatMode value) {
    _state = _state.copyWith(dateFormatMode: value);
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

  void setSavingsCircleContributionReminders(bool value) {
    _state = _state.copyWith(savingsCircleContributionReminders: value);
    notifyListeners();
  }

  void setSavingsCircleAtRiskAlerts(bool value) {
    _state = _state.copyWith(savingsCircleAtRiskAlerts: value);
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
