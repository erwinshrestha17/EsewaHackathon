import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryGreen,
      primary: AppColors.primaryGreen,
      onPrimary: Colors.white,
      primaryContainer: AppColors.lightGreen,
      onPrimaryContainer: AppColors.darkGreen,
      secondary: AppColors.darkGreen,
      tertiary: AppColors.info,
      error: AppColors.error,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      shadow: AppColors.shadow,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        showDragHandle: true,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.lightGreen,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppTextStyles.caption.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.darkGreen
                : AppColors.textSecondary,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          ),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.lightGreen,
        selectedIconTheme: IconThemeData(color: AppColors.darkGreen),
        unselectedIconTheme: IconThemeData(color: AppColors.textSecondary),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(
            color: AppColors.primaryGreen,
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: AppTextStyles.bodySecondary,
        helperStyle: AppTextStyles.caption,
        hintStyle: AppTextStyles.bodySecondary,
        prefixStyle: AppTextStyles.body,
        suffixStyle: AppTextStyles.body,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: AppTextStyles.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: AppTextStyles.button,
          foregroundColor: AppColors.darkGreen,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: AppTextStyles.button),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surfaceSoft,
        selectedColor: AppColors.lightGreen,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStateProperty.all(AppTextStyles.button),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.darkGreen
                : AppColors.textPrimary,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.lightGreen
                : AppColors.surface,
          ),
          side: WidgetStateProperty.all(
            const BorderSide(color: AppColors.border),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.surface
              : AppColors.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primaryGreen
              : AppColors.surfaceSoft,
        ),
      ),
      textTheme: base.textTheme.copyWith(
        headlineMedium: AppTextStyles.largeScreenTitle,
        headlineSmall: AppTextStyles.screenTitle,
        titleLarge: AppTextStyles.sectionTitle.copyWith(fontSize: 20),
        titleMedium: AppTextStyles.sectionTitle,
        titleSmall: AppTextStyles.cardTitle,
        bodyLarge: AppTextStyles.body.copyWith(fontSize: 15),
        bodyMedium: AppTextStyles.body,
        bodySmall: AppTextStyles.bodySecondary,
        labelLarge: AppTextStyles.caption.copyWith(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  static ThemeData get dark {
    const surface = Color(0xFF111817);
    const surfaceSoft = Color(0xFF18221F);
    const background = Color(0xFF0B1110);
    const outline = Color(0xFF2B3A35);
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryGreen,
      brightness: Brightness.dark,
      primary: const Color(0xFF42D77A),
      onPrimary: const Color(0xFF052E18),
      primaryContainer: const Color(0xFF0F3D23),
      onPrimaryContainer: const Color(0xFFC9F9D8),
      secondary: const Color(0xFF8FD9A8),
      tertiary: const Color(0xFF8AB4FF),
      error: const Color(0xFFFF8A8A),
      surface: surface,
      onSurface: const Color(0xFFE8F0EC),
      outline: outline,
      outlineVariant: outline,
      shadow: Colors.black,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: surface,
        foregroundColor: Color(0xFFE8F0EC),
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        showDragHandle: true,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
          side: BorderSide(color: outline),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: outline,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppTextStyles.caption.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSoft,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error),
        ),
        labelStyle: AppTextStyles.bodySecondary.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        helperStyle: AppTextStyles.caption.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        hintStyle: AppTextStyles.bodySecondary.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        prefixStyle: AppTextStyles.body.copyWith(color: scheme.onSurface),
        suffixStyle: AppTextStyles.body.copyWith(color: scheme.onSurface),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: AppTextStyles.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: AppTextStyles.button,
          foregroundColor: scheme.primary,
          side: const BorderSide(color: outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: AppTextStyles.button),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaceSoft,
        selectedColor: scheme.primaryContainer,
        side: const BorderSide(color: outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStateProperty.all(AppTextStyles.button),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurface,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.primaryContainer
                : surfaceSoft,
          ),
          side: WidgetStateProperty.all(const BorderSide(color: outline)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurfaceVariant,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : surfaceSoft,
        ),
      ),
      textTheme: base.textTheme.copyWith(
        headlineMedium: AppTextStyles.largeScreenTitle.copyWith(
          color: scheme.onSurface,
        ),
        headlineSmall: AppTextStyles.screenTitle.copyWith(
          color: scheme.onSurface,
        ),
        titleLarge: AppTextStyles.sectionTitle.copyWith(
          fontSize: 20,
          color: scheme.onSurface,
        ),
        titleMedium: AppTextStyles.sectionTitle.copyWith(
          color: scheme.onSurface,
        ),
        titleSmall: AppTextStyles.cardTitle.copyWith(color: scheme.onSurface),
        bodyLarge: AppTextStyles.body.copyWith(
          fontSize: 15,
          color: scheme.onSurface,
        ),
        bodyMedium: AppTextStyles.body.copyWith(color: scheme.onSurface),
        bodySmall: AppTextStyles.bodySecondary.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        labelLarge: AppTextStyles.caption.copyWith(
          fontSize: 13,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
