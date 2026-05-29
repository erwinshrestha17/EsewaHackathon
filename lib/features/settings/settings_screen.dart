import 'package:flutter/material.dart';

import 'edit_profile_screen.dart';
import 'notification_settings_screen.dart';
import 'settings_controller.dart';
import 'settings_models.dart';
import 'widgets/dhukuti_safety_note_card.dart';
import 'widgets/settings_choice_bottom_sheet.dart';
import 'widgets/settings_profile_card.dart';
import 'widgets/settings_section.dart';
import 'widgets/settings_switch_tile.dart';
import 'widgets/settings_tile.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.controller, super.key});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Settings',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage your profile, privacy, payments, and Sangai preferences.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              SettingsProfileCard(
                state: state,
                onEdit: () => _openEditProfile(context),
              ),
              const SizedBox(height: 20),
              SettingsSection(
                title: 'Account',
                children: [
                  SettingsTile(
                    icon: Icons.person_outline,
                    title: 'Edit Profile',
                    onTap: () => _openEditProfile(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
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
                  SettingsTile(
                    icon: Icons.person_remove_outlined,
                    title: 'Removed Connections',
                    onTap: () => _showUserList(
                      context,
                      title: 'Removed Connections',
                      emptyMessage: 'No removed connections.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SettingsSection(
                title: 'Groups & Expenses',
                children: [
                  SettingsTile(
                    icon: Icons.receipt_long_outlined,
                    title: 'Default Split Mode',
                    value: state.defaultSplitMode.label,
                    onTap: () => _chooseDefaultSplitMode(context),
                  ),
                  SettingsTile(
                    icon: Icons.timeline_outlined,
                    title: 'Activity Timeline Limit',
                    value: state.activityTimelineLimit.label,
                    onTap: () => _chooseActivityTimelineLimit(context),
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
              const SizedBox(height: 20),
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
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Mock eSewa Mode',
                    subtitle: 'Payments are simulated for this prototype.',
                    value: state.mockEsewaMode ? 'ON' : 'OFF',
                    enabled: false,
                    showChevron: false,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SettingsSection(
                title: 'Digital Dhukuti',
                footer: DhukutiSafetyNoteCard(
                  onTap: () => _showDhukutiSafetyNote(context),
                ),
                children: [
                  SettingsSwitchTile(
                    icon: Icons.event_available_outlined,
                    title: 'Contribution Reminders',
                    value: state.dhukutiContributionReminders,
                    onChanged: controller.setDhukutiContributionReminders,
                  ),
                  SettingsSwitchTile(
                    icon: Icons.warning_amber_outlined,
                    title: 'At-Risk Alerts',
                    value: state.dhukutiAtRiskAlerts,
                    onChanged: controller.setDhukutiAtRiskAlerts,
                  ),
                  SettingsTile(
                    icon: Icons.info_outline,
                    title: 'Safety Note',
                    value: 'Read',
                    onTap: () => _showDhukutiSafetyNote(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
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
              const SizedBox(height: 20),
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
                ],
              ),
              const SizedBox(height: 20),
              SettingsSection(
                title: 'Help & About',
                children: [
                  SettingsTile(
                    icon: Icons.help_outline,
                    title: 'How Sangai Works',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _InfoScreen(
                          title: 'How Sangai Works',
                          icon: Icons.help_outline,
                          body:
                              'Sangai helps you connect with trusted people, create groups, split expenses, settle dues, send gifts, and track Digital Dhukuti ledgers.',
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
                    subtitle: 'Sangai v1.0\nTeam Cache Flow · Challenge 10',
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
    final draft = await showModalBottomSheet<ProfileDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => EditProfileSheet(state: controller.state),
    );
    if (draft == null || !context.mounted) {
      return;
    }
    controller.updateProfile(draft);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated for this demo session.')),
    );
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

  Future<void> _chooseDefaultSplitMode(BuildContext context) async {
    final value = await showSettingsChoiceBottomSheet<DefaultSplitMode>(
      context: context,
      title: 'Default Split Mode',
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

  Future<void> _chooseActivityTimelineLimit(BuildContext context) async {
    final value = await showSettingsChoiceBottomSheet<ActivityTimelineLimit>(
      context: context,
      title: 'Activity Timeline Limit',
      selectedValue: controller.state.activityTimelineLimit,
      options: [
        for (final limit in ActivityTimelineLimit.values)
          SettingsChoiceOption(value: limit, label: limit.label),
      ],
    );
    if (value != null) {
      controller.setActivityTimelineLimit(value);
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

  Future<void> _showDhukutiSafetyNote(BuildContext context) {
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
                      'Digital Dhukuti Safety Note',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(dhukutiSafetyNoteText),
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
