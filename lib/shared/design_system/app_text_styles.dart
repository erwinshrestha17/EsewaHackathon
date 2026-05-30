import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  static const largeScreenTitle = TextStyle(
    fontSize: 30,
    height: 1.12,
    fontWeight: FontWeight.w900,
  );

  static const screenTitle = TextStyle(
    fontSize: 24,
    height: 1.16,
    fontWeight: FontWeight.w900,
  );

  static const sectionTitle = TextStyle(
    fontSize: 17,
    height: 1.25,
    fontWeight: FontWeight.w800,
  );

  static const cardTitle = TextStyle(
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w800,
  );

  static const body = TextStyle(
    fontSize: 14,
    height: 1.42,
    fontWeight: FontWeight.w500,
  );

  static const bodySecondary = TextStyle(
    fontSize: 13,
    height: 1.38,
    fontWeight: FontWeight.w500,
  );

  static const caption = TextStyle(
    fontSize: 12,
    height: 1.28,
    fontWeight: FontWeight.w600,
  );

  static const button = TextStyle(
    fontSize: 14,
    height: 1.2,
    fontWeight: FontWeight.w800,
  );

  static const amount = TextStyle(
    fontSize: 24,
    height: 1.05,
    fontWeight: FontWeight.w900,
  );

  static const error = TextStyle(
    fontSize: 13,
    height: 1.34,
    fontWeight: FontWeight.w700,
    color: AppColors.error,
  );
}
