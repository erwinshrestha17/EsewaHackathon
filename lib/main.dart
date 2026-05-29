import 'package:flutter/material.dart';

import 'features/auth/auth_controller.dart';
import 'src/app.dart';
import 'src/app_state.dart';

void main() {
  runApp(
    AuthScope(
      notifier: AuthController(),
      child: StoreScope(notifier: AppStore(), child: const SangaiApp()),
    ),
  );
}
