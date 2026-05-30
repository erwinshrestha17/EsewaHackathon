import 'package:flutter/material.dart';

import '../../shared/design_system/app_colors.dart';
import '../../shared/design_system/app_spacing.dart';
import '../auth/auth_controller.dart';
import '../auth/models/user_profile.dart';
import 'edit_profile_screen.dart';
import 'notification_settings_screen.dart';
import 'settings_controller.dart';
import 'settings_models.dart';
import 'widgets/savings_circle_safety_note_card.dart';
import 'widgets/settings_choice_bottom_sheet.dart';
import 'widgets/settings_profile_card.dart';
import 'widgets/settings_section.dart';
import 'widgets/settings_switch_tile.dart';
import 'widgets/settings_tile.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.controller,
    required this.authController,
    super.key,
  });

  final SettingsController controller;
  final AuthController authController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, authController]),
      builder: (context, _) {
        final state = controller.state;
        final profile = authController.state.activeUser ?? UserProfile.demo();
        return Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              SettingsProfileCard(
                profile: profile,
                onEdit: () => _openEditProfile(context),
              ),
              const SizedBox(height: AppSpacing.xl),
              SettingsSection(
                title: 'Account',
                children: [
                  SettingsTile(
                    icon: Icons.person_outline,
                    title: 'Edit Profile',
                    onTap: () => _openEditProfile(context),
                  ),
                  SettingsTile(
                    icon: Icons.logout,
                    title: 'Logout',
                    subtitle: 'Return to prototype login on this device.',
                    onTap: () => _confirmLogout(context),
                    danger: true,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              SettingsSection(
                title: 'Privacy & Connections',
                children: [
                  SettingsTile(
                    icon: Icons.shield_outlined,
                    title: 'Connection Requests',
                    value: state.connectionRequestPreference.label,
                    onTap: () => _chooseConnectionRequestPreference(context),
                  ),
                  SettingsTile(
                    icon: Icons.block_outlined,
                    title: 'Blocked Users',
                    onTap: () => _showUserList(
                      context,
                      title: 'Blocked Users',
                      emptyMessage: 'No blocked users.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              SettingsSection(
                title: 'Groups & Expenses',
                children: [
                  SettingsTile(
                    icon: Icons.call_split_outlined,
                    title: 'Default Split',
                    value: state.defaultSplitMode.label,
                    onTap: () => _chooseDefaultSplitMode(context),
                  ),
                  SettingsTile(
                    icon: Icons.receipt_long_outlined,
                    title: 'Tax Allocation',
                    subtitle: 'Used for VAT, service charge, and tips.',
                    value: state.taxAllocationMode.label,
                    onTap: () => _chooseTaxAllocationMode(context),
                  ),
                  SettingsTile(
                    icon: Icons.document_scanner_outlined,
                    title: 'OCR Review',
                    value: state.ocrReviewPreference.label,
                    onTap: () => _chooseOcrReviewPreference(context),
                  ),
                  SettingsSwitchTile(
                    icon: Icons.calculate_outlined,
                    title: 'Show Rounding Note',
                    subtitle:
                        'Shows a small note when split amounts are adjusted by rounding.',
                    value: state.showRoundingNote,
                    onChanged: controller.setShowRoundingNote,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              SettingsSection(
                title: 'Payments',
                children: [
                  SettingsSwitchTile(
                    icon: Icons.verified_user_outlined,
                    title: 'Confirm Before Payment',
                    value: state.confirmBeforePayment,
                    onChanged: controller.setConfirmBeforePayment,
                  ),
                  SettingsSwitchTile(
                    icon: Icons.notifications_active_outlined,
                    title: 'Settlement Nudges',
                    value: state.settlementNudges,
                    onChanged: controller.setSettlementNudges,
                  ),
                  SettingsTile(
                    icon: Icons.alarm_outlined,
                    title: 'Default Reminder',
                    value: state.reminderFrequency.label,
                    onTap: () => _chooseReminderFrequency(context),
                  ),
                  SettingsTile(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Mock eSewa Mode',
                    subtitle: 'Payments are simulated for this prototype.',
                    value: state.mockEsewaMode ? 'ON' : 'OFF',
                    enabled: false,
                    showChevron: false,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              SettingsSection(
                title: 'Savings Circle',
                footer: SavingsCircleSafetyNoteCard(
                  onTap: () => _showSavingsCircleSafetyNote(context),
                ),
                children: [
                  SettingsSwitchTile(
                    icon: Icons.event_available_outlined,
                    title: 'Contribution Reminders',
                    value: state.savingsCircleContributionReminders,
                    onChanged: controller.setSavingsCircleContributionReminders,
                  ),
                  SettingsSwitchTile(
                    icon: Icons.warning_amber_outlined,
                    title: 'At-Risk Alerts',
                    value: state.savingsCircleAtRiskAlerts,
                    onChanged: controller.setSavingsCircleAtRiskAlerts,
                  ),
                  SettingsTile(
                    icon: Icons.info_outline,
                    title: 'Safety Note',
                    value: 'Read',
                    onTap: () => _showSavingsCircleSafetyNote(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              SettingsSection(
                title: 'Notifications',
                children: [
                  SettingsTile(
                    icon: Icons.notifications_outlined,
                    title: 'Manage Notifications',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            NotificationSettingsScreen(controller: controller),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              SettingsSection(
                title: 'Appearance',
                children: [
                  SettingsTile(
                    icon: Icons.palette_outlined,
                    title: 'Theme',
                    value: state.themeMode.label,
                    onTap: () => _chooseTheme(context),
                  ),
                  SettingsTile(
                    icon: Icons.language_outlined,
                    title: 'Language',
                    value: state.language.label,
                    onTap: () => _chooseLanguage(context),
                  ),
                  SettingsTile(
                    icon: Icons.payments_outlined,
                    title: 'Amount Format',
                    value: state.amountFormatMode.label,
                    onTap: () => _chooseAmountFormat(context),
                  ),
                  SettingsTile(
                    icon: Icons.calendar_month_outlined,
                    title: 'Date Format',
                    value: state.dateFormatMode.label,
                    onTap: () => _chooseDateFormat(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              SettingsSection(
                title: 'Help & About',
                children: [
                  SettingsTile(
                    icon: Icons.help_outline,
                    title: 'How Sajha Kharcha Works',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _InfoScreen(
                          title: 'How Sajha Kharcha Works',
                          icon: Icons.help_outline,
                          body:
                              'Sajha Kharcha helps trusted people create groups, scan receipts, split expenses, settle dues, send gifts, and track transparent Savings Circle ledgers.',
                        ),
                      ),
                    ),
                  ),
                  SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Terms & Privacy',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _InfoScreen(
                          title: 'Terms & Privacy',
                          icon: Icons.privacy_tip_outlined,
                          body:
                              'Terms and privacy details are placeholders for the MVP demo. No real backend account, payment, or notification delivery is connected in this prototype.',
                        ),
                      ),
                    ),
                  ),
                  const SettingsTile(
                    icon: Icons.info_outline,
                    title: 'Version 1.0',
                    subtitle:
                        'Sajha Kharcha by eSewa v1.0\nTeam Cache Flow · Challenge 10',
                    showChevron: false,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openEditProfile(BuildContext context) async {
    final profile = authController.state.activeUser ?? UserProfile.demo();
    final updated = await showModalBottomSheet<UserProfile>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => EditProfileSheet(profile: profile),
    );
    if (updated == null || !context.mounted) {
      return;
    }
    await authController.updateProfile(updated);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated for this demo session.')),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Log out of Sajha Kharcha?'),
          content: const Text(
            'You will need to log in again to access your groups, gifts, and Savings Circle details on this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    await authController.logout();
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil('/auth', (_) => false);
  }

  Future<void> _chooseConnectionRequestPreference(BuildContext context) async {
    final value =
        await showSettingsChoiceBottomSheet<ConnectionRequestPreference>(
          context: context,
          title: 'Connection Requests',
          selectedValue: controller.state.connectionRequestPreference,
          options: [
            for (final preference in ConnectionRequestPreference.values)
              SettingsChoiceOption(value: preference, label: preference.label),
          ],
        );
    if (value != null) {
      controller.setConnectionRequestPreference(value);
    }
  }

  Future<void> _chooseTheme(BuildContext context) async {
    final value = await showSettingsChoiceBottomSheet<AppThemeMode>(
      context: context,
      title: 'Theme',
      selectedValue: controller.state.themeMode,
      options: [
        for (final mode in AppThemeMode.values)
          SettingsChoiceOption(value: mode, label: mode.label),
      ],
    );
    if (value != null) {
      controller.setThemeMode(value);
    }
  }

  Future<void> _chooseDefaultSplitMode(BuildContext context) async {
    final value = await showSettingsChoiceBottomSheet<DefaultSplitMode>(
      context: context,
      title: 'Default Split',
      selectedValue: controller.state.defaultSplitMode,
      options: [
        for (final mode in DefaultSplitMode.values)
          SettingsChoiceOption(value: mode, label: mode.label),
      ],
    );
    if (value != null) {
      controller.setDefaultSplitMode(value);
    }
  }

  Future<void> _chooseTaxAllocationMode(BuildContext context) async {
    final value = await showSettingsChoiceBottomSheet<TaxAllocationMode>(
      context: context,
      title: 'Tax Allocation',
      selectedValue: controller.state.taxAllocationMode,
      options: [
        for (final mode in TaxAllocationMode.values)
          SettingsChoiceOption(value: mode, label: mode.label),
      ],
    );
    if (value != null) {
      controller.setTaxAllocationMode(value);
    }
  }

  Future<void> _chooseOcrReviewPreference(BuildContext context) async {
    final value = await showSettingsChoiceBottomSheet<OcrReviewPreference>(
      context: context,
      title: 'OCR Review',
      selectedValue: controller.state.ocrReviewPreference,
      options: [
        for (final preference in OcrReviewPreference.values)
          SettingsChoiceOption(value: preference, label: preference.label),
      ],
    );
    if (value != null) {
      controller.setOcrReviewPreference(value);
    }
  }

  Future<void> _chooseReminderFrequency(BuildContext context) async {
    final value = await showSettingsChoiceBottomSheet<ReminderFrequency>(
      context: context,
      title: 'Default Reminder',
      selectedValue: controller.state.reminderFrequency,
      options: [
        for (final frequency in ReminderFrequency.values)
          SettingsChoiceOption(value: frequency, label: frequency.label),
      ],
    );
    if (value != null) {
      controller.setReminderFrequency(value);
    }
  }

  Future<void> _chooseAmountFormat(BuildContext context) async {
    final value = await showSettingsChoiceBottomSheet<AmountFormatMode>(
      context: context,
      title: 'Amount Format',
      selectedValue: controller.state.amountFormatMode,
      options: [
        for (final mode in AmountFormatMode.values)
          SettingsChoiceOption(value: mode, label: mode.label),
      ],
    );
    if (value != null) {
      controller.setAmountFormatMode(value);
    }
  }

  Future<void> _chooseDateFormat(BuildContext context) async {
    final value = await showSettingsChoiceBottomSheet<DateFormatMode>(
      context: context,
      title: 'Date Format',
      selectedValue: controller.state.dateFormatMode,
      options: [
        for (final mode in DateFormatMode.values)
          SettingsChoiceOption(value: mode, label: mode.label),
      ],
    );
    if (value != null) {
      controller.setDateFormatMode(value);
    }
  }

  Future<void> _chooseLanguage(BuildContext context) async {
    final value = await showSettingsChoiceBottomSheet<AppLanguage>(
      context: context,
      title: 'Language',
      selectedValue: controller.state.language,
      options: [
        SettingsChoiceOption(
          value: AppLanguage.english,
          label: AppLanguage.english.label,
        ),
        SettingsChoiceOption(
          value: AppLanguage.nepaliComingSoon,
          label: AppLanguage.nepaliComingSoon.label,
          subtitle: AppLanguage.nepaliComingSoon.helper,
          enabled: false,
        ),
      ],
    );
    if (value != null) {
      controller.setLanguage(value);
    }
  }

  Future<void> _showUserList(
    BuildContext context, {
    required String title,
    required String emptyMessage,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Icon(
                  Icons.people_outline,
                  size: 40,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(height: 8),
                Text(
                  emptyMessage,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text(
                  'You can review connection visibility here when history exists.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSavingsCircleSafetyNote(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      child: Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Savings Circle Safety Note',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(savingsCircleSafetyNoteText),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoScreen extends StatelessWidget {
  const _InfoScreen({
    required this.title,
    required this.icon,
    required this.body,
  });

  final String title;
  final IconData icon;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(radius: 28, child: Icon(icon)),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
