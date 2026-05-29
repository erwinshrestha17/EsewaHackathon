import 'package:flutter/material.dart';

class SettingsChoiceOption<T> {
  const SettingsChoiceOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.enabled = true,
  });

  final T value;
  final String label;
  final String? subtitle;
  final bool enabled;
}

Future<T?> showSettingsChoiceBottomSheet<T>({
  required BuildContext context,
  required String title,
  required T selectedValue,
  required List<SettingsChoiceOption<T>> options,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final selected = option.value == selectedValue;
                    return ListTile(
                      minTileHeight: 56,
                      enabled: option.enabled,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        option.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: option.subtitle == null
                          ? null
                          : Text(option.subtitle!),
                      trailing: selected
                          ? Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: option.enabled
                          ? () => Navigator.pop(context, option.value)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
