import 'package:flutter/material.dart';

import '../../shared/localization/app_localizations.dart';
import 'settings_controller.dart';
import 'settings_models.dart';
import 'widgets/settings_section.dart';
import 'widgets/settings_switch_tile.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({required this.controller, super.key});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        return Scaffold(
          appBar: AppBar(title: Text(context.t('Notifications'))),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                context.t(
                  'Choose which Sajha Kharcha events appear in your notification center.',
                ),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              SettingsSection(
                title: context.t('Notification Types'),
                children: [
                  for (final preference in NotificationPreference.values)
                    SettingsSwitchTile(
                      icon: _iconFor(preference),
                      title: preference.label,
                      value: state.notifications[preference] ?? true,
                      onChanged: (value) =>
                          controller.setNotification(preference, value),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _iconFor(NotificationPreference preference) {
    return switch (preference) {
      NotificationPreference.connectionRequests => Icons.person_add_alt_1,
      NotificationPreference.groupInvitations => Icons.groups_outlined,
      NotificationPreference.expenseAdded => Icons.receipt_long,
      NotificationPreference.settlementReminders => Icons.payments_outlined,
      NotificationPreference.paymentStatusUpdates =>
        Icons.account_balance_wallet_outlined,
      NotificationPreference.giftReceived => Icons.card_giftcard_outlined,
      NotificationPreference.dhukutiContributionDue =>
        Icons.event_available_outlined,
      NotificationPreference.dhukutiCycleAtRisk => Icons.warning_amber_outlined,
    };
  }
}
