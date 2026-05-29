import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/app_state.dart';

void main() {
  runApp(StoreScope(notifier: AppStore(), child: const SangaiApp()));
}