import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../src/finance.dart';
import '../../src/models.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

enum AppStatusTone { neutral, success, warning, info, danger }

Color appToneColorFor(BuildContext context, AppStatusTone tone) {
  final scheme = Theme.of(context).colorScheme;
  return switch (tone) {
    AppStatusTone.success => AppColors.success,
    AppStatusTone.warning => AppColors.warning,
    AppStatusTone.info => AppColors.info,
    AppStatusTone.danger => scheme.error,
    AppStatusTone.neutral => scheme.onSurfaceVariant,
  };
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final button = icon == null
        ? FilledButton(
            onPressed: loading ? null : onPressed,
            child: _ButtonContent(label: label, loading: loading),
          )
        : FilledButton.icon(
            onPressed: loading ? null : onPressed,
            icon: loading ? const SizedBox.shrink() : Icon(icon),
            label: _ButtonContent(label: label, loading: loading),
          );
    return SizedBox(width: double.infinity, child: button);
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final button = icon == null
        ? OutlinedButton(onPressed: onPressed, child: Text(label))
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          );
    return SizedBox(width: double.infinity, child: button);
  }
}

class DangerButton extends StatelessWidget {
  const DangerButton({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = FilledButton.styleFrom(
      backgroundColor: scheme.error,
      foregroundColor: scheme.onError,
    );
    return SizedBox(
      width: double.infinity,
      child: icon == null
          ? FilledButton(onPressed: onPressed, style: style, child: Text(label))
          : FilledButton.icon(
              onPressed: onPressed,
              style: style,
              icon: Icon(icon),
              label: Text(label),
            ),
    );
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({required this.label, required this.loading});

  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (!loading) {
      return Text(label);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(label),
      ],
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class AmountTextField extends StatelessWidget {
  const AmountTextField({
    required this.controller,
    this.label = 'Amount',
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      label: label,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      onChanged: onChanged,
      prefixIcon: Icons.payments_outlined,
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({
    required this.controller,
    required this.hint,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      label: 'Search',
      hint: hint,
      prefixIcon: Icons.search,
      onChanged: onChanged,
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.tone,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final AppStatusTone? tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final toneColor = tone == null ? null : appToneColorFor(context, tone!);
    final borderColor =
        toneColor?.withValues(alpha: 0.22) ?? scheme.outlineVariant;
    final background = toneColor?.withValues(alpha: 0.07) ?? scheme.surface;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: BorderSide(color: borderColor),
    );
    final content = Padding(padding: padding, child: child);

    if (onTap == null) {
      return Material(
        color: background,
        surfaceTintColor: Colors.transparent,
        shape: shape,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: content,
      );
    }

    return Material(
      color: background,
      surfaceTintColor: Colors.transparent,
      shape: shape,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.subtitle,
    this.action,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.sectionTitle),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle!, style: AppTextStyles.bodySecondary),
              ],
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: AppSpacing.md), action!],
      ],
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    required this.label,
    this.radius = 20,
    this.backgroundColor,
    super.key,
  });

  final String label;
  final double radius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      child: Text(
        label.isEmpty ? '?' : label.characters.first,
        style: TextStyle(fontSize: radius * 0.78, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class UserListTile extends StatelessWidget {
  const UserListTile({
    required this.user,
    this.subtitle,
    this.trailing,
    this.onTap,
    super.key,
  });

  final AppUser user;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: ProfileAvatar(label: user.avatar),
      title: Text(user.displayName, style: AppTextStyles.cardTitle),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing,
    );
  }
}

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    required this.title,
    required this.subtitle,
    required this.amountMinor,
    this.icon = Icons.receipt_long_outlined,
    this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final int amountMinor;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        child: Icon(icon),
      ),
      title: Text(title, style: AppTextStyles.cardTitle),
      subtitle: Text(subtitle),
      trailing: Text(
        money(amountMinor),
        style: AppTextStyles.cardTitle.copyWith(
          color: amountMinor < 0 ? scheme.error : AppColors.success,
        ),
      ),
    );
  }
}

class ActivityTile extends StatelessWidget {
  const ActivityTile({
    required this.title,
    required this.subtitle,
    this.icon = Icons.timeline_outlined,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: scheme.onSurfaceVariant,
        child: Icon(icon),
      ),
      title: Text(title, style: AppTextStyles.cardTitle),
      subtitle: Text(subtitle),
    );
  }
}

class BalanceCard extends StatelessWidget {
  const BalanceCard({
    required this.label,
    required this.amountMinor,
    required this.icon,
    required this.tone,
    super.key,
  });

  final String label;
  final int amountMinor;
  final IconData icon;
  final AppStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final color = appToneColorFor(context, tone);
    return AppCard(
      tone: tone,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            foregroundColor: color,
            child: Icon(icon),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  money(amountMinor),
                  style: AppTextStyles.amount.copyWith(color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
              child: Icon(icon, size: 28),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.cardTitle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary,
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({this.rows = 4, super.key});

  final int rows;

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final opacity = 0.38 + (_controller.value * 0.24);
        return Column(
          children: [
            for (var i = 0; i < widget.rows; i++) ...[
              Container(
                height: i == 0 ? 92 : 62,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
              if (i < widget.rows - 1) const SizedBox(height: AppSpacing.md),
            ],
          ],
        );
      },
    );
  }
}

class ConfirmationSheet extends StatelessWidget {
  const ConfirmationSheet({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.onConfirm,
    this.cancelLabel = 'Cancel',
    this.danger = false,
    super.key,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final VoidCallback onConfirm;
  final String cancelLabel;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSpacing.sm),
            Text(body, style: AppTextStyles.bodySecondary),
            const SizedBox(height: AppSpacing.lg),
            danger
                ? DangerButton(label: confirmLabel, onPressed: onConfirm)
                : PrimaryButton(label: confirmLabel, onPressed: onConfirm),
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              label: cancelLabel,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.label,
    required this.tone,
    this.icon,
    super.key,
  });

  final String label;
  final AppStatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = appToneColorFor(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    required this.title,
    this.subtitle,
    this.actions,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          if (subtitle != null) Text(subtitle!, style: AppTextStyles.caption),
        ],
      ),
      actions: actions,
    );
  }
}

class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: destinations,
      ),
    );
  }
}
