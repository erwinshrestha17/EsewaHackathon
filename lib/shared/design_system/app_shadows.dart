import 'package:flutter/material.dart';

abstract final class AppShadows {
  static const soft = [
    BoxShadow(color: Color(0x120F172A), blurRadius: 18, offset: Offset(0, 8)),
  ];

  static const medium = [
    BoxShadow(color: Color(0x1A0F172A), blurRadius: 24, offset: Offset(0, 12)),
  ];

  static List<BoxShadow> tinted(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.18),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];

  static const none = <BoxShadow>[];
}
