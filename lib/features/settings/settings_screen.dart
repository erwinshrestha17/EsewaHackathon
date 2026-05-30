import 'package:flutter/material.dart';

import '../../shared/design_system/app_spacing.dart';
import '../../shared/localization/app_localizations.dart';
import '../../src/app_state.dart';
import '../auth/auth_controller.dart';
import '../auth/models/user_profile.dart';
import 'edit_profile_screen.dart';
import 'notification_settings_screen.dart';
import 'settings_controller.dart';
import 'settings_models.dart';
import 'widgets/settings_choice_bottom_sheet.dart';
import 'widgets/settings_profile_card.dart';
import 'widgets/settings_section.dart';
import 'widgets/settings_switch_tile.dart';
import 'widgets/settings_tile.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.controller,
    required this.authController,
    required this.store,
    super.key,
  });

  final SettingsController controller;
  final AuthController authController;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, authController]),
      builder: (context, _) {
        final state = controller.state;
        final profile = authController.state.activeUser;
        if (profile == null) {
          return const Scaffold(
            body: Center(child: Text('Sign in again to view settings.')),
          );
        }
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
                title: context.t('Account'),
                children: [
                  SettingsTile(
                    icon: Icons.person_outline,
                    title: context.t('Edit Profile'),
                    onTap: () => _openEditProfile(context),
                  ),
                  SettingsTile(
                    icon: Icons.logout,
                    title: context.t('Logout'),
                    subtitle: context.t('Return to login on this device.'),
                    onTap: () => _confirmLogout(context),
                    danger: true,
                  ),
                  SettingsTile(
                    icon: Icons.delete_forever_outlined,
                    title: context.t('Delete Account'),
                    subtitle: context.t(
                      'Available only after every balance is settled.',
                    ),
                    onTap: () => _confirmDeleteAccount(context),
                    danger: true,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              SettingsSection(
                title: context.t('Privacy & Connections'),
                children: [
                  SettingsTile(
                    icon: Icons.shield_outlined,
                    title: context.t('Connection Requests'),
                    value: context.t(state.connectionRequestPreference.label),
                    onTap: () => _chooseConnectionRequestPreference(context),
                  ),
                  SettingsTile(
                    icon: Icons.block_outlined,
                    title: context.t('Blocked Users'),
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
                title: context.t('Groups & Expenses'),
                children: [
                  SettingsTile(
                    icon: Icons.call_split_outlined,
                    title: context.t('Default Split'),
                    value: context.t(state.defaultSplitMode.label),
                    onTap: () => _chooseDefaultSplitMode(context),
                  ),
                  SettingsTile(
                    icon: Icons.document_scanner_outlined,
                    title: context.t('OCR Review'),
                    value: context.t(state.ocrReviewPreference.label),
                    onTap: () => _chooseOcrReviewPreference(context),
                  ),
                  SettingsSwitchTile(
                    icon: Icons.calculate_outlined,
                    title: context.t('Show Rounding Note'),
                    subtitle:
                        'Shows a small note when split amounts are adjusted by rounding.',
                    value: state.showRoundingNote,
                    onChanged: controller.setShowRoundingNote,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              SettingsSection(
                title: context.t('Payments'),
                children: [
                  SettingsSwitchTile(
                    icon: Icons.verified_user_outlined,
                    title: context.t('Confirm Before Payment'),
                    value: state.confirmBeforePayment,
                    onChanged: controller.setConfirmBeforePayment,
                  ),
                  SettingsSwitchTile(
                    icon: Icons.notifications_active_outlined,
                    title: context.t('Settlement Nudges'),
                    value: state.settlementNudges,
                    onChanged: controller.setSettlementNudges,
                  ),
                  SettingsTile(
                    icon: Icons.alarm_outlined,
                    title: context.t('Default Reminder'),
                    value: context.t(state.reminderFrequency.label),
                    onTap: () => _chooseReminderFrequency(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              SettingsSection(
                title: context.t('Saving Circle'),
                children: [
                  SettingsSwitchTile(
                    icon: Icons.event_available_outlined,
                    title: context.t('Contribution Reminders'),
                    value: state.dhukutiContributionReminders,
                    onChanged: controller.setDhukutiContributionReminders,
                  ),
                  SettingsSwitchTile(
                    icon: Icons.warning_amber_outlined,
                    title: context.t('At-Risk Alerts'),
                    value: state.dhukutiAtRiskAlerts,
                    onChanged: controller.setDhukutiAtRiskAlerts,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              SettingsSection(
                title: context.t('Notifications'),
                children: [
                  SettingsTile(
                    icon: Icons.notifications_outlined,
                    title: context.t('Manage Notifications'),
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
                title: context.t('Appearance'),
                children: [
                  SettingsTile(
                    icon: Icons.palette_outlined,
                    title: context.t('Theme'),
                    value: context.t(state.themeMode.label),
                    onTap: () => _chooseTheme(context),
                  ),
                  SettingsTile(
                    icon: Icons.language_outlined,
                    title: context.t('Language'),
                    value: context.t(state.language.label),
                    onTap: () => _chooseLanguage(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              SettingsSection(
                title: context.t('Help & About'),
                children: [
                  SettingsTile(
                    icon: Icons.help_outline,
                    title: context.t('How Sajha Kharcha Works'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _InfoScreen(
                          title: 'How Sajha Kharcha Works',
                          icon: Icons.help_outline,
                          body:
                              'Sajha Kharcha brings shared spending into one clear flow: connect with trusted people, create a group, add an expense, choose who paid and who joined, then settle balances when everyone is ready. You can also send gifts, follow group activity, and keep Saving Circle contribution schedules visible for every member.',
                        ),
                      ),
                    ),
                  ),
                  SettingsTile(
                    icon: Icons.info_outline,
                    title: context.t('About Sajha Kharcha'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _InfoScreen(
                          title: 'About Sajha Kharcha',
                          icon: Icons.info_outline,
                          body:
                              'Sajha Kharcha is built for everyday shared costs in Nepal: meals, trips, apartments, festivals, gifts, and rotating Saving Circle commitments. The app focuses on clear member selection, transparent balances, spending insights, and fast settlement through familiar wallet flows.',
                        ),
                      ),
                    ),
                  ),
                  SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    title: context.t('Terms & Privacy'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _InfoScreen(
                          title: 'Terms & Privacy',
                          icon: Icons.privacy_tip_outlined,
                          body:
                              'Your group history should stay readable even when members leave, because expense records are shared financial context. Keep phone numbers current, invite only trusted contacts, and review group roles before adding or removing members.',
                        ),
                      ),
                    ),
                  ),
                  SettingsTile(
                    icon: Icons.info_outline,
                    title: context.t('Version 1.0'),
                    subtitle:
                        'Sajha Kharcha v1.0\nTeam Cache Flow · Challenge 10',
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
    final profile = authController.state.activeUser;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in again to edit your profile.')),
      );
      return;
    }
    final updated = await showModalBottomSheet<UserProfile>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => EditProfileSheet(profile: profile),
    );
    if (updated == null || !context.mounted) {
      return;
    }
    try {
      await authController.updateProfile(updated);
    } on AuthValidationException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Log out of Sajha Kharcha?'),
          content: const Text(
            'You will need to log in again to access your groups, gifts, and Saving Circle details on this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
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

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final blockers = store.accountDeletionBlockers;
    if (blockers.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(context.t('Settle balances first')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t(
                    'You cannot delete your account while money is unsettled.',
                  ),
                ),
                const SizedBox(height: 12),
                for (final blocker in blockers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $blocker'),
                  ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(context.t('OK')),
              ),
            ],
          );
        },
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.t('Delete account?')),
          content: Text(
            context.t(
              'This removes your saved profile and signs you out on this device.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.t('Cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(context.t('Delete')),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await authController.deleteAccount();
    } on AuthValidationException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil('/auth', (_) => false);
  }

  Future<void> _chooseConnectionRequestPreference(BuildContext context) async {
    final value =
        await showSettingsChoiceBottomSheet<ConnectionRequestPreference>(
          context: context,
          title: context.t('Connection Requests'),
          selectedValue: controller.state.connectionRequestPreference,
          options: [
            for (final preference in ConnectionRequestPreference.values)
              SettingsChoiceOption(
                value: preference,
                label: context.t(preference.label),
              ),
          ],
        );
    if (value != null) {
      controller.setConnectionRequestPreference(value);
    }
  }

  Future<void> _chooseTheme(BuildContext context) async {
    final value = await showSettingsChoiceBottomSheet<AppThemeMode>(
      context: context,
      title: context.t('Theme'),
      selectedValue: controller.state.themeMode,
      options: [
        for (final mode in AppThemeMode.values)
          SettingsChoiceOption(value: mode, label: context.t(mode.label)),
      ],
    );
    if (value != null) {
      controller.setThemeMode(value);
    }
  }

  Future<void> _chooseDefaultSplitMode(BuildContext context) async {
    final value = await showSettingsChoiceBottomSheet<DefaultSplitMode>(
      context: context,
      title: context.t('Default Split'),
      selectedValue: controller.state.defaultSplitMode,
      options: [
        for (final mode in DefaultSplitMode.values)
          SettingsChoiceOption(value: mode, label: context.t(mode.label)),
      ],
    );
    if (value != null) {
      controller.setDefaultSplitMode(value);
    }
  }

  Future<void> _chooseOcrReviewPreference(BuildContext context) async {
    final value = await showSettingsChoiceBottomSheet<OcrReviewPreference>(
      context: context,
      title: context.t('OCR Review'),
      selectedValue: controller.state.ocrReviewPreference,
      options: [
        for (final preference in OcrReviewPreference.values)
          SettingsChoiceOption(
            value: preference,
            label: context.t(preference.label),
          ),
      ],
    );
    if (value != null) {
      controller.setOcrReviewPreference(value);
    }
  }

  Future<void> _chooseReminderFrequency(BuildContext context) async {
    final value = await showSettingsChoiceBottomSheet<ReminderFrequency>(
      context: context,
      title: context.t('Default Reminder'),
      selectedValue: controller.state.reminderFrequency,
      options: [
        for (final frequency in ReminderFrequency.values)
          SettingsChoiceOption(
            value: frequency,
            label: context.t(frequency.label),
          ),
      ],
    );
    if (value != null) {
      controller.setReminderFrequency(value);
    }
  }

  Future<void> _chooseLanguage(BuildContext context) async {
    final value = await showSettingsChoiceBottomSheet<AppLanguage>(
      context: context,
      title: context.t('Language'),
      selectedValue: controller.state.language,
      options: [
        for (final language in AppLanguage.values)
          SettingsChoiceOption(
            value: language,
            label: context.t(language.label),
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
      appBar: AppBar(title: Text(context.t(title))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(radius: 28, child: Icon(icon)),
          const SizedBox(height: 16),
          Text(
            context.t(title),
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
