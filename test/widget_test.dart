import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sajha_kharcha/features/auth/auth_controller.dart';
import 'package:sajha_kharcha/features/auth/models/user_profile.dart';
import 'package:sajha_kharcha/features/auth/screens/auth_screen.dart';
import 'package:sajha_kharcha/features/auth/screens/login_form.dart';
import 'package:sajha_kharcha/features/auth/screens/register_form.dart';
import 'package:sajha_kharcha/shared/api/backend_api.dart';
import 'package:sajha_kharcha/shared/api/realtime_sync_service.dart';
import 'package:sajha_kharcha/features/home/home_controller.dart';
import 'package:sajha_kharcha/features/settings/settings_controller.dart';
import 'package:sajha_kharcha/features/settings/settings_screen.dart';
import 'package:sajha_kharcha/shared/design_system/app_components.dart' as ds;
import 'package:sajha_kharcha/shared/design_system/app_colors.dart';
import 'package:sajha_kharcha/shared/design_system/app_theme.dart';
import 'package:sajha_kharcha/src/app.dart';
import 'package:sajha_kharcha/src/app_state.dart';
import 'package:sajha_kharcha/src/finance.dart';
import 'package:sajha_kharcha/src/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _testUserProfile = UserProfile(
  id: 'u-sita',
  displayName: 'Sita Shrestha',
  phone: '9800000001',
  esewaId: '9800000001@esewa',
  district: 'Kathmandu',
  createdAt: DateTime(2026, 5, 30),
  dateOfBirth: DateTime(2000, 1, 2),
);

class _FakeBackendApi extends BackendApi {
  _FakeBackendApi() : super(baseUrl: 'http://127.0.0.1:3000');

  @override
  Future<BackendOtpChallenge> requestSignupOtp({required String phone}) async {
    return const BackendOtpChallenge(
      message: 'OTP sent for verification.',
      expiresInSeconds: 300,
      resendAfterSeconds: 60,
    );
  }

  @override
  Future<BackendAuthSession> login({
    required String phone,
    required String mPin,
  }) async {
    if (mPin == '9999') {
      throw const BackendApiException('Phone number or M-PIN is incorrect.');
    }
    return _session(phone: phone);
  }

  @override
  Future<BackendAuthSession> signup({
    required String phone,
    required String otp,
    required String mPin,
    required String fullName,
    required String dateOfBirth,
    String? district,
  }) async {
    return _session(
      phone: phone,
      displayName: fullName,
      dateOfBirth: dateOfBirth,
    );
  }

  @override
  Future<BackendAuthSession> refresh({required String refreshToken}) async {
    return _session(phone: _testUserProfile.phone);
  }

  @override
  Future<void> logout({String? accessToken, String? refreshToken}) async {}

  @override
  Future<Map<String, dynamic>> appBootstrap({
    required String accessToken,
  }) async {
    return {
      'currentUserId': _testUserProfile.id,
      'users': [
        {
          'id': _testUserProfile.id,
          'displayName': _testUserProfile.displayName,
          'phone': _testUserProfile.phone,
          'avatar': 'S',
          'district': _testUserProfile.district,
          'createdAt': _testUserProfile.createdAt.toIso8601String(),
          'privacyMode': 'everyone',
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> settings({required String accessToken}) async {
    return {};
  }

  @override
  Future<Map<String, dynamic>> deleteAccount({
    required String accessToken,
  }) async {
    return {'profile': <String, dynamic>{}};
  }

  @override
  Future<Map<String, dynamic>> updateProfile({
    required String accessToken,
    required Map<String, Object?> profile,
  }) async {
    return {
      'profile': {
        'id': _testUserProfile.id,
        'fullName': profile['fullName'] ?? _testUserProfile.displayName,
        'phone': profile['phone'] ?? _testUserProfile.phone,
        'district': profile['district'] ?? _testUserProfile.district,
        'avatarUrl': profile['avatarUrl'],
        'createdAt': _testUserProfile.createdAt.toIso8601String(),
      },
    };
  }

  BackendAuthSession _session({
    required String phone,
    String displayName = 'Sita Shrestha',
    String dateOfBirth = '2000-01-02',
  }) {
    return BackendAuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      accessTokenExpiresAt: DateTime.now()
          .add(const Duration(minutes: 15))
          .toIso8601String(),
      refreshTokenExpiresAt: DateTime.now()
          .add(const Duration(days: 30))
          .toIso8601String(),
      profile: {
        'id': _testUserProfile.id,
        'displayName': displayName,
        'phone': phone,
        'esewaId': '$phone@esewa',
        'district': 'Kathmandu',
        'dateOfBirth': dateOfBirth,
        'createdAt': _testUserProfile.createdAt.toIso8601String(),
      },
    );
  }
}

class _FailingRealtimeSyncService extends BackendRealtimeSyncService {
  var starts = 0;

  @override
  Future<void> start({
    required Future<String?> Function() accessTokenProvider,
  }) async {
    starts += 1;
    throw const BackendApiException(
      'Backend realtime websocket is unavailable. Check that the API server is running.',
    );
  }
}

void _mockLoggedInStorage() {
  SharedPreferences.setMockInitialValues({'auth.hasSeenIntro': true});
  FlutterSecureStorage.setMockInitialValues({
    'auth.activeUserProfile': _testUserProfile.toJsonString(),
    'auth.accessToken': 'access-token',
    'auth.refreshToken': 'refresh-token',
    'auth.accessTokenExpiresAt': DateTime.now()
        .add(const Duration(hours: 1))
        .toIso8601String(),
    'auth.refreshTokenExpiresAt': DateTime.now()
        .add(const Duration(days: 30))
        .toIso8601String(),
  });
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('login accepts phone plus M-PIN and rejects invalid values', () async {
    final controller = AuthController(backendApi: _FakeBackendApi());

    expect(
      () => controller.loginWithMpin(phone: 'demo', mPin: '1234'),
      throwsA(isA<AuthValidationException>()),
    );
    expect(
      () => controller.loginWithMpin(phone: '9800000001', mPin: '12'),
      throwsA(isA<AuthValidationException>()),
    );
    expect(
      () => controller.loginWithMpin(phone: '9800000001', mPin: '9999'),
      throwsA(isA<AuthValidationException>()),
    );

    await controller.loginWithMpin(phone: '9800000001', mPin: '1234');

    expect(controller.state.isLoggedIn, isTrue);
    expect(controller.state.activeUser?.displayName, 'Sita Shrestha');
    expect(controller.state.activeUser?.phone, '9800000001');

    await controller.loginWithMpin(phone: '+977 9800000001', mPin: '1234');
    expect(controller.state.activeUser?.phone, '9800000001');
  });

  test('default auth storage uses the compatible macOS keychain', () {
    final controller = AuthController(backendApi: _FakeBackendApi());

    expect(
      controller.debugSecureStorage.mOptions
          .toMap()['usesDataProtectionKeychain'],
      'false',
    );
  });

  test('macOS auth storage avoids keychain prompts', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    final controller = AuthController(backendApi: _FakeBackendApi());

    expect(controller.debugUsesKeychainStorage, isFalse);

    await controller.loginWithMpin(phone: '9800000001', mPin: '1234');

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('auth.accessToken'), 'access-token');
    expect(
      await controller.debugSecureStorage.read(key: 'auth.accessToken'),
      isNull,
    );
  });

  test('delete account clears saved profile and login state', () async {
    SharedPreferences.setMockInitialValues({'auth.hasSeenIntro': true});
    FlutterSecureStorage.setMockInitialValues({
      'auth.activeUserProfile': _testUserProfile.toJsonString(),
      'auth.accessToken': 'access',
      'auth.refreshToken': 'refresh',
      'auth.accessTokenExpiresAt': DateTime.now()
          .add(const Duration(hours: 1))
          .toIso8601String(),
      'auth.refreshTokenExpiresAt': DateTime.now()
          .add(const Duration(days: 30))
          .toIso8601String(),
    });
    final controller = AuthController(backendApi: _FakeBackendApi());

    await controller.initialize();
    expect(controller.state.isLoggedIn, isTrue);

    await controller.deleteAccount();

    expect(controller.state.isLoggedIn, isFalse);
    expect(controller.state.activeUser, isNull);
  });

  testWidgets('login form requires phone number and M-PIN', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      AuthScope(
        notifier: AuthController(),
        child: const MaterialApp(home: Scaffold(body: LoginForm())),
      ),
    );

    expect(find.text('Nepal mobile number'), findsOneWidget);
    expect(find.text('M-PIN'), findsOneWidget);
    expect(find.text('Login with M-PIN'), findsOneWidget);
    expect(find.text('Login with biometric'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nepal mobile number'),
      '98000000011',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'M-PIN'),
      '12345',
    );
    await tester.pump();

    final phoneField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Nepal mobile number'),
    );
    final pinField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'M-PIN'),
    );
    expect(phoneField.controller?.text, '9800000001');
    expect(pinField.controller?.text, '1234');

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nepal mobile number'),
      '+977 9800000001',
    );
    await tester.pump();
    final pastedPhoneField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Nepal mobile number'),
    );
    expect(pastedPhoneField.controller?.text, '9800000001');
  });

  testWidgets('sign up requires mobile number dob M-PIN then verifies OTP', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = AuthController(backendApi: _FakeBackendApi());

    await tester.pumpWidget(
      AuthScope(
        notifier: controller,
        child: MaterialApp(
          home: const Scaffold(body: RegisterForm()),
          routes: {'/main': (_) => const Scaffold(body: Text('Main'))},
        ),
      ),
    );

    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Nepal mobile number'), findsOneWidget);
    expect(find.text('Date of birth'), findsOneWidget);
    expect(find.text('Create M-PIN'), findsOneWidget);
    expect(find.text('User name'), findsNothing);
    expect(find.text('Password'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name'),
      'Sita Shrestha',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nepal mobile number'),
      '9800000001',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Date of birth'),
      '2000-01-02',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Create M-PIN'),
      '2468',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Send OTP'));
    await tester.pumpAndSettle();

    expect(find.text('6-digit OTP'), findsOneWidget);
    expect(find.text('Verify OTP & Create Account'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, '6-digit OTP'),
      '123456',
    );
    await tester.tap(
      find.widgetWithText(FilledButton, 'Verify OTP & Create Account'),
    );
    await tester.pumpAndSettle();

    expect(controller.state.isLoggedIn, isTrue);
    expect(controller.state.activeUser?.displayName, 'Sita Shrestha');
    expect(controller.state.activeUser?.phone, '9800000001');
    expect(controller.state.activeUser?.dateOfBirth, DateTime(2000, 1, 2));
  });

  testWidgets('auth screen follows the active theme background', (
    tester,
  ) async {
    await tester.pumpWidget(
      AuthScope(
        notifier: AuthController(),
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: const AuthScreen(),
        ),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppTheme.dark.scaffoldBackgroundColor);

    final card = tester.widget<Card>(find.byType(Card));
    expect(card.color, AppTheme.dark.colorScheme.surface);
  });

  test('light theme keeps explicit readable text defaults', () {
    final textTheme = AppTheme.light.textTheme;
    final inputTheme = AppTheme.light.inputDecorationTheme;

    expect(textTheme.headlineSmall?.color, AppColors.textPrimary);
    expect(textTheme.titleMedium?.color, AppColors.textPrimary);
    expect(textTheme.titleSmall?.color, AppColors.textPrimary);
    expect(textTheme.bodyMedium?.color, AppColors.textPrimary);
    expect(textTheme.bodySmall?.color, AppColors.textSecondary);
    expect(inputTheme.labelStyle?.color, AppColors.textSecondary);
    expect(inputTheme.hintStyle?.color, AppColors.textSecondary);
  });

  Future<void> pumpGroupsForAddExpense(
    WidgetTester tester,
    AppStore store,
  ) async {
    store.selectedGroupId = 'g-dashain';
    tester.view.physicalSize = const Size(1000, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: const MaterialApp(home: GroupsScreen()),
      ),
    );
  }

  Future<void> openManualEntry(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Add expense'));
    await tester.pumpAndSettle();

    expect(find.text('Align the bill inside the frame'), findsOneWidget);
    expect(find.text('Manual Entry'), findsOneWidget);

    await tester.drag(find.text('Manual Entry'), const Offset(0, -1800));
    await tester.pumpAndSettle();
  }

  Future<void> chooseTheme(WidgetTester tester, String label) async {
    final settingsScroll = find.descendant(
      of: find.byType(SettingsScreen),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Theme'),
      260,
      scrollable: settingsScroll,
    );
    await tester.drag(settingsScroll, const Offset(0, -160));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('Sajha Kharcha shell renders seeded dashboard', (tester) async {
    _mockLoggedInStorage();

    await tester.pumpWidget(
      AuthScope(
        notifier: AuthController(backendApi: _FakeBackendApi()),
        child: StoreScope(
          notifier: AppStore.seeded(),
          child: const SajhaKharchaApp(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Sajha Kharcha'), findsOneWidget);
    expect(find.text('Namaste, Sita'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('Festival Mode'), findsNothing);
    expect(find.text('Scan Receipt'), findsNothing);
    expect(find.text('Settle Now'), findsNothing);
    expect(find.text('View Groups'), findsNothing);
    expect(find.text('Add Expense'), findsOneWidget);
    expect(find.text('Create Group'), findsOneWidget);
    expect(find.text('Send Gift'), findsWidgets);
    expect(find.text('Activity'), findsNothing);
  });

  testWidgets('theme choice applies across main and auth routes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue();
    });
    _mockLoggedInStorage();

    await tester.pumpWidget(
      AuthScope(
        notifier: AuthController(backendApi: _FakeBackendApi()),
        child: StoreScope(
          notifier: AppStore.seeded(),
          child: const SajhaKharchaApp(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
      Brightness.dark,
    );

    await chooseTheme(tester, 'Light');
    expect(
      Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
      Brightness.light,
    );

    Navigator.of(
      tester.element(find.byType(SettingsScreen)),
    ).pushNamed('/auth');
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(AuthScreen))).brightness,
      Brightness.light,
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      AppTheme.light.scaffoldBackgroundColor,
    );

    Navigator.of(tester.element(find.byType(AuthScreen))).pop();
    await tester.pumpAndSettle();

    await chooseTheme(tester, 'Dark');
    expect(
      Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
      Brightness.dark,
    );

    Navigator.of(
      tester.element(find.byType(SettingsScreen)),
    ).pushNamed('/auth');
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(AuthScreen))).brightness,
      Brightness.dark,
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      AppTheme.dark.scaffoldBackgroundColor,
    );
  });

  test('upcoming savings tracker card skips paid past months', () {
    final store = AppStore.seeded();
    final now = DateTime.now();
    final pool = DhukutiPool(
      id: 'd-test-upcoming',
      groupId: 'g-test',
      name: 'Future Office Community Fund',
      contributionAmountMinor: npr(1000),
      frequency: 'Monthly',
      startDate: now.add(const Duration(days: 12)),
      createdBy: store.currentUserId,
      status: DhukutiPoolStatus.active,
      createdAt: now,
    );
    final pastCycle = DhukutiCycle(
      id: 'cycle-past',
      poolId: pool.id,
      cycleNumber: 1,
      dueDate: now.subtract(const Duration(days: 10)),
      payoutRecipientId: store.currentUserId,
      expectedContributionTotalMinor: npr(1000),
      paidContributionTotalMinor: npr(1000),
      status: DhukutiCycleStatus.paidOut,
    );
    final futureCycle = DhukutiCycle(
      id: 'cycle-future',
      poolId: pool.id,
      cycleNumber: 2,
      dueDate: now.add(const Duration(days: 12)),
      payoutRecipientId: store.currentUserId,
      expectedContributionTotalMinor: npr(1000),
      paidContributionTotalMinor: 0,
      status: DhukutiCycleStatus.upcoming,
    );

    store.dhukutiPools
      ..clear()
      ..add(pool);
    store.dhukutiMembers
      ..clear()
      ..add(
        DhukutiMember(
          id: 'member-current',
          poolId: pool.id,
          userId: store.currentUserId,
          payoutOrder: 1,
          status: DhukutiMemberStatus.active,
        ),
      );
    store.dhukutiCycles
      ..clear()
      ..addAll([pastCycle, futureCycle]);
    store.dhukutiContributions
      ..clear()
      ..addAll([
        DhukutiContribution(
          id: 'contribution-paid',
          poolId: pool.id,
          cycleId: pastCycle.id,
          userId: store.currentUserId,
          cycleNumber: pastCycle.cycleNumber,
          dueDate: pastCycle.dueDate,
          amountMinor: npr(1000),
          status: ContributionStatus.paid,
          idempotencyKey: 'paid',
          idempotencyScope: pool.id,
          operationType: 'dhukuti_contribution',
          paidAt: pastCycle.dueDate,
        ),
        DhukutiContribution(
          id: 'contribution-upcoming',
          poolId: pool.id,
          cycleId: futureCycle.id,
          userId: store.currentUserId,
          cycleNumber: futureCycle.cycleNumber,
          dueDate: futureCycle.dueDate,
          amountMinor: npr(1000),
          status: ContributionStatus.pending,
          idempotencyKey: 'upcoming',
          idempotencyScope: pool.id,
          operationType: 'dhukuti_contribution',
        ),
      ]);

    final dues = HomeController(
      store: store,
    ).loadDashboard().upcomingDhukutiDues;

    expect(dues, hasLength(1));
    expect(dues.single.contributionId, 'contribution-upcoming');
    expect(dues.single.status, 'Upcoming');
    expect(dues.single.dueLabel, contains('left'));
    expect(dues.single.dueLabel, isNot(contains('late')));
    expect(dues.single.isPayable, isFalse);
  });

  testWidgets('shared cards use dark theme surfaces', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: const Scaffold(body: ds.AppCard(child: Text('Dark card'))),
      ),
    );

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(ds.AppCard),
        matching: find.byType(Material),
      ),
    );

    expect(material.color, AppTheme.dark.colorScheme.surface);
  });

  testWidgets('Main navigation includes Connections and excludes Scan tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    _mockLoggedInStorage();

    await tester.pumpWidget(
      AuthScope(
        notifier: AuthController(backendApi: _FakeBackendApi()),
        child: StoreScope(
          notifier: AppStore.seeded(),
          child: const SajhaKharchaApp(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Scan'), findsNothing);
    expect(find.text('Connections'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Connections'));
    await tester.pumpAndSettle();

    expect(find.text('Mobile Contacts'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('Delete Account'), findsOneWidget);

    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();

    expect(find.text('Settle balances first'), findsOneWidget);
    expect(
      find.text('You cannot delete your account while money is unsettled.'),
      findsOneWidget,
    );
    expect(find.text('• You still owe NPR 4020.'), findsOneWidget);
    expect(find.text('• You are still owed NPR 3400.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact connections and groups layouts render without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      _mockLoggedInStorage();

      await tester.pumpWidget(
        AuthScope(
          notifier: AuthController(backendApi: _FakeBackendApi()),
          child: StoreScope(
            notifier: AppStore.seeded(),
            child: const SajhaKharchaApp(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(NavigationDestination, 'Connections'),
      );
      await tester.pumpAndSettle();

      final searchField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Search name or phone',
      );
      await tester.enterText(searchField, 'Maya');
      await tester.pump();

      expect(find.text('Maya Gurung'), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.tap(find.widgetWithText(NavigationDestination, 'Groups'));
      await tester.pumpAndSettle();

      final savingsTrackerTab = find.text('Community Savings').first;
      await tester.ensureVisible(savingsTrackerTab);
      await tester.tapAt(tester.getCenter(savingsTrackerTab));
      await tester.pumpAndSettle();

      expect(find.text('Family Dashain Community Fund'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty home create group flow keeps a stable parent context', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    _mockLoggedInStorage();

    await tester.pumpWidget(
      AuthScope(
        notifier: AuthController(backendApi: _FakeBackendApi()),
        child: StoreScope(notifier: AppStore(), child: const SajhaKharchaApp()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final createGroup = find.widgetWithText(FilledButton, 'Create Group');
    await tester.ensureVisible(createGroup);
    await tester.tap(createGroup);
    await tester.pumpAndSettle();

    expect(find.text('Create Expense Group'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Create Expense Group'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Backend API is required for signed-in actions. Start the API server and set BACKEND_API_BASE_URL.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('incoming connection requests show a recipient banner', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    _mockLoggedInStorage();

    await tester.pumpWidget(
      AuthScope(
        notifier: AuthController(backendApi: _FakeBackendApi()),
        child: StoreScope(
          notifier: AppStore.seeded(),
          child: const SajhaKharchaApp(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Kabir Lama wants to connect with you.'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'View request'));
    await tester.pumpAndSettle();

    expect(find.text('Incoming Requests'), findsOneWidget);
    expect(find.text('Kabir Lama'), findsWidgets);
  });

  testWidgets('incoming connection banner dismisses manually and by timeout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    _mockLoggedInStorage();

    await tester.pumpWidget(
      AuthScope(
        notifier: AuthController(backendApi: _FakeBackendApi()),
        child: StoreScope(
          notifier: AppStore.seeded(),
          child: const SajhaKharchaApp(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Kabir Lama wants to connect with you.'), findsOneWidget);

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pump();

    expect(find.text('Kabir Lama wants to connect with you.'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await tester.pumpWidget(
      AuthScope(
        notifier: AuthController(backendApi: _FakeBackendApi()),
        child: StoreScope(
          notifier: AppStore.seeded(),
          child: const SajhaKharchaApp(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Kabir Lama wants to connect with you.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 8));
    await tester.pump();

    expect(find.text('Kabir Lama wants to connect with you.'), findsNothing);
  });

  testWidgets('incoming connection approve updates the request', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    _mockLoggedInStorage();
    final store = AppStore.seeded();

    await tester.pumpWidget(
      AuthScope(
        notifier: AuthController(backendApi: _FakeBackendApi()),
        child: StoreScope(notifier: store, child: const SajhaKharchaApp()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'View request'));
    await tester.pumpAndSettle();

    expect(find.text('Incoming Requests'), findsOneWidget);

    await tester.tap(find.byTooltip('Approve'));
    await tester.pumpAndSettle();

    expect(
      store.connectionBetween('u-sita', 'u-kabir')?.status,
      ConnectionStatus.approved,
    );
    expect(find.text('Incoming Requests'), findsNothing);
    expect(find.text('Kabir Lama is now connected.'), findsOneWidget);
  });

  testWidgets(
    'main route initializes auth before rendering store-backed home',
    (tester) async {
      _mockLoggedInStorage();
      final settings = SettingsController();
      addTearDown(settings.dispose);

      await tester.pumpWidget(
        AuthScope(
          notifier: AuthController(backendApi: _FakeBackendApi()),
          child: StoreScope(
            notifier: AppStore(),
            child: MaterialApp(
              routes: {
                '/auth': (_) => const AuthScreen(),
                '/intro': (_) => const Scaffold(body: Text('Intro')),
              },
              home: SajhaKharchaShell(settingsController: settings),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Namaste, Sita'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('missing realtime setup does not crash the signed-in shell', (
    tester,
  ) async {
    _mockLoggedInStorage();
    final settings = SettingsController();
    final backendApi = _FakeBackendApi();
    final realtimeService = _FailingRealtimeSyncService();
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      AuthScope(
        notifier: AuthController(backendApi: backendApi),
        child: StoreScope(
          notifier: AppStore(),
          child: MaterialApp(
            routes: {
              '/auth': (_) => const AuthScreen(),
              '/intro': (_) => const Scaffold(body: Text('Intro')),
            },
            home: SajhaKharchaShell(
              settingsController: settings,
              backendApi: backendApi,
              backendRealtimeService: realtimeService,
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(realtimeService.starts, greaterThanOrEqualTo(1));
    expect(find.text('Namaste, Sita'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('connection report dialog requires note and blocks duplicates', (
    tester,
  ) async {
    final store = AppStore.seeded();
    final connection = store.connectionBetween('u-sita', 'u-maya')!;
    final reportedUser = store.userById('u-maya');

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return FilledButton(
                  onPressed: () => showReportConnectionDialog(
                    context,
                    connection,
                    reportedUser,
                  ),
                  child: const Text('Open report'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Open report'));
    await tester.pumpAndSettle();

    expect(find.text('Report Maya Gurung'), findsOneWidget);
    expect(find.text('Report note'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Submit report'),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Report note'),
      'Repeated unwanted payment messages',
    );
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Submit report'),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Submit report'));
    await tester.pumpAndSettle();

    expect(connection.reports, hasLength(1));
    expect(
      connection.reports.single.details,
      'Repeated unwanted payment messages',
    );
    expect(find.text('Report submitted for Maya Gurung.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Open report'));
    await tester.pumpAndSettle();

    expect(find.text('Report Maya Gurung'), findsNothing);
    expect(find.text('You have already reported Maya Gurung.'), findsOneWidget);
    expect(connection.reports, hasLength(1));
  });

  testWidgets('gift pool dialog starts with empty amount inputs', (
    tester,
  ) async {
    final store = AppStore.seeded();

    String fieldValue(String label) {
      final field = tester.widget<TextField>(
        find.widgetWithText(TextField, label),
      );
      return field.controller?.text ?? '';
    }

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return FilledButton(
                  onPressed: () => showCreateGiftPoolDialog(context),
                  child: const Text('Open gift pool'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Open gift pool'));
    await tester.pumpAndSettle();

    expect(find.text('Contribution rule'), findsOneWidget);
    expect(find.text('Template'), findsNothing);
    expect(find.text('Equal amount'), findsOneWidget);
    expect(find.text('Equal amount per contributor'), findsOneWidget);
    expect(find.text('Allow contributions above goal'), findsOneWidget);
    expect(find.text('Target amount'), findsNothing);
    expect(fieldValue('Title'), isEmpty);
    expect(fieldValue('Equal amount per contributor'), isEmpty);
    expect(fieldValue('Message'), isEmpty);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Create'))
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('Min / max'));
    await tester.pumpAndSettle();

    expect(find.text('Target amount'), findsOneWidget);
    expect(find.text('Minimum contribution'), findsOneWidget);
    expect(find.text('Maximum contribution'), findsOneWidget);
    expect(find.text('Equal amount per contributor'), findsNothing);
    expect(fieldValue('Target amount'), isEmpty);
    expect(fieldValue('Minimum contribution'), isEmpty);
    expect(fieldValue('Maximum contribution'), isEmpty);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Create'))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Savings Tracker quick action opens Community Savings inside Groups tab',
    (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      _mockLoggedInStorage();

      await tester.pumpWidget(
        AuthScope(
          notifier: AuthController(backendApi: _FakeBackendApi()),
          child: StoreScope(
            notifier: AppStore.seeded(),
            child: const SajhaKharchaApp(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      final savingsTrackerAction = find.text('Savings Tracker').first;
      await tester.ensureVisible(savingsTrackerAction);
      await tester.tap(savingsTrackerAction);
      await tester.pumpAndSettle();

      expect(find.text('Community Savings'), findsOneWidget);
      expect(find.text('Community Savings Tracker'), findsWidgets);
      expect(
        find.textContaining('dependOnInheritedWidgetOfExactType'),
        findsNothing,
      );
      expect(
        find.textContaining('_DhukutiDetailScreenState.initState'),
        findsNothing,
      );
      expect(
        find.text('Expense groups stay separate from community fund tracking.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Groups screen tolerates a stale selected group', (tester) async {
    final store = AppStore.seeded()..selectedGroupId = 'missing-group';

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: const MaterialApp(home: GroupsScreen()),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Expense Groups'), findsWidgets);
    expect(find.text('Select a group'), findsNothing);
    expect(find.text('Groups overview'), findsOneWidget);
  });

  testWidgets('Groups screen does not open an expense group by default', (
    tester,
  ) async {
    final store = AppStore.seeded();

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: const MaterialApp(home: GroupsScreen()),
      ),
    );

    expect(store.selectedGroupId, isNull);
    expect(find.text('Groups overview'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add expense'), findsNothing);
  });

  testWidgets('group overview colors debit red and credit green', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Column(
            children: [
              BalancePill(amountMinor: -100),
              BalancePill(amountMinor: 100),
              StatTile(
                label: 'Debit',
                value: 'NPR 1',
                icon: Icons.call_made_outlined,
                tone: Tone.danger,
                tintValue: true,
              ),
              StatTile(
                label: 'Credit',
                value: 'NPR 2',
                icon: Icons.call_received_outlined,
                tone: Tone.success,
                tintValue: true,
              ),
            ],
          ),
        ),
      ),
    );

    final pills = tester.widgetList<StatusPill>(find.byType(StatusPill));
    expect(pills.elementAt(0).tone, Tone.danger);
    expect(pills.elementAt(1).tone, Tone.success);
    expect(
      tester.widget<Text>(find.text('NPR 1')).style?.color,
      AppColors.error,
    );
    expect(
      tester.widget<Text>(find.text('NPR 2')).style?.color,
      AppColors.success,
    );
  });

  testWidgets('create group dialog starts with members unselected', (
    tester,
  ) async {
    final store = AppStore.seeded();

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: FilledButton(
                  onPressed: () => showCreateGroupDialog(context),
                  child: const Text('Open create'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Open create'));
    await tester.pumpAndSettle();

    expect(find.text('Create Expense Group'), findsWidgets);
    expect(find.text('Community Savings Tracker Group'), findsNothing);
    final memberChips = tester.widgetList<FilterChip>(find.byType(FilterChip));
    expect(memberChips, isNotEmpty);
    expect(memberChips.every((chip) => !chip.selected), isTrue);
    expect(
      find.text(
        'You will be added automatically as admin. Select only the people you want to invite.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Community Savings create flow uses tracker-specific setup', (
    tester,
  ) async {
    final store = AppStore.seeded();

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: FilledButton(
                  onPressed: () => showCreateDhukutiGroupDialog(context),
                  child: const Text('Open tracker create'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Open tracker create'));
    await tester.pumpAndSettle();

    expect(find.text('Create Community Savings Tracker Group'), findsWidgets);
    expect(find.text('Contribution amount'), findsOneWidget);
    expect(find.text('Expected monthly total'), findsOneWidget);
    expect(find.text('Default split: Equal'), findsNothing);
    final memberCards = tester
        .widgetList<ParticipantSelectorCard>(
          find.byType(ParticipantSelectorCard),
        )
        .toList();
    expect(memberCards, isNotEmpty);
    expect(find.text(store.currentUser.displayName), findsOneWidget);
    expect(memberCards.where((card) => card.selected), hasLength(1));
    expect(memberCards.first.selected, isTrue);
    expect(memberCards.first.enabled, isFalse);
  });

  testWidgets('Groups screen separates expense and community savings groups', (
    tester,
  ) async {
    final store = AppStore.seeded();

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: const MaterialApp(home: GroupsScreen()),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Dashain Khasi Split'),
      320,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Dashain Khasi Split'), findsOneWidget);
    expect(find.text('Shrestha Family'), findsNothing);

    final savingsTrackerTab = find.text('Community Savings');
    await tester.ensureVisible(savingsTrackerTab);
    await tester.tapAt(tester.getCenter(savingsTrackerTab));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Family Dashain Community Fund'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Family Dashain Community Fund'), findsOneWidget);
    expect(find.text('Dashain Khasi Split'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inactive current member no longer sees group detail', (
    tester,
  ) async {
    final store = AppStore.seeded()
      ..switchUser('u-rina')
      ..removeGroupMember('g-dashain', 'u-rina')
      ..selectedGroupId = 'g-dashain';

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: const MaterialApp(home: GroupsScreen()),
      ),
    );

    expect(find.widgetWithText(FilledButton, 'Add expense'), findsNothing);
    expect(find.text('Dashain Khasi Split'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Groups screen uses general flow and table statement', (
    tester,
  ) async {
    final store = AppStore.seeded()..selectedGroupId = 'g-dashain';

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: const MaterialApp(home: GroupsScreen()),
      ),
    );

    expect(find.text('Festival Mode'), findsNothing);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Statement'));
    await tester.pumpAndSettle();

    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Paid By'), findsOneWidget);
    expect(find.text('Your Share'), findsOneWidget);
    expect(find.text('Group total'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('transaction history tags and filters paid and unpaid rows', (
    tester,
  ) async {
    final statement = GroupStatementData(
      rows: [
        GroupStatementRow(
          date: DateTime(2026, 5, 1),
          type: 'Payment',
          description: 'Paid settlement',
          paidBy: 'Erwin',
          participants: 'Maya',
          totalAmountMinor: npr(500),
          splitMode: 'Payment',
          yourShareMinor: 0,
          paidTag: TransactionPaidTag.paid,
          status: 'Paid',
        ),
        GroupStatementRow(
          date: DateTime(2026, 5, 2),
          type: 'Payment',
          description: 'Pending settlement',
          paidBy: 'Maya',
          participants: 'Erwin',
          totalAmountMinor: npr(700),
          splitMode: 'Payment',
          yourShareMinor: 0,
          paidTag: TransactionPaidTag.unpaid,
          status: 'Pending',
        ),
      ],
      totalGroupExpenses: 0,
      totalPaidByUser: 0,
      totalUserShare: 0,
      totalSettled: npr(500),
      remainingBalance: -npr(700),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 960,
            height: 560,
            child: GroupStatementTable(statement: statement),
          ),
        ),
      ),
    );

    expect(find.text('Transaction history'), findsOneWidget);
    expect(find.text('Paid Tag'), findsOneWidget);
    expect(find.text('Paid settlement'), findsOneWidget);
    expect(find.text('Pending settlement'), findsOneWidget);

    await tester.tap(find.text('Unpaid').first);
    await tester.pumpAndSettle();

    expect(find.text('Paid settlement'), findsNothing);
    expect(find.text('Pending settlement'), findsOneWidget);

    await tester.tap(find.text('Paid').first);
    await tester.pumpAndSettle();

    expect(find.text('Paid settlement'), findsOneWidget);
    expect(find.text('Pending settlement'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('active expense member sees rename action in group detail', (
    tester,
  ) async {
    final store = AppStore.seeded()..selectedGroupId = 'g-apartment';

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: const MaterialApp(home: GroupsScreen()),
      ),
    );

    expect(find.widgetWithText(OutlinedButton, 'Rename'), findsOneWidget);
  });

  testWidgets('admin rename action uses standard button sizing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store = AppStore.seeded();

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: const MaterialApp(home: GroupsScreen()),
      ),
    );

    final savingsTrackerTab = find.text('Community Savings');
    await tester.tapAt(tester.getCenter(savingsTrackerTab));
    await tester.pumpAndSettle();

    expect(find.text('Family Dashain Community Fund'), findsWidgets);
    final renameButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Rename'),
    );
    expect(
      renameButton.style?.minimumSize?.resolve(<WidgetState>{}),
      const Size(48, 48),
    );
  });

  testWidgets('settlement prompt supports eSewa and cash bank reconciliation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 7000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store = AppStore.seeded();
    final groupId = store.createGroup(
      name: 'Offline Lunch',
      category: GroupCategory.custom,
      memberIds: const ['u-arjun'],
    );
    store.addExpense(
      groupId: groupId,
      title: 'Cash momo',
      totalMinor: npr(200),
      payerId: 'u-sita',
      category: 'custom',
      splitMode: SplitMode.equal,
      participantIds: const ['u-sita', 'u-arjun'],
    );
    store.switchUser('u-arjun');

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: MaterialApp(
          home: Scaffold(body: GroupDetail(group: store.groupById(groupId))),
        ),
      ),
    );

    expect(find.widgetWithText(FilledButton, 'Settle Now'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Record cash/bank payment'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Settle Now'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm Settlement'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Pay with eSewa'), findsOneWidget);
    expect(store.settlements.where((item) => item.isExternal), isEmpty);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Record cash/bank payment'),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Record cash/bank payment'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.widgetWithText(FilledButton, 'Send Approval Request'),
    );
    await tester.pumpAndSettle();

    final request = store.settlements.singleWhere((item) => item.isExternal);
    expect(request.status, PaymentStatus.pending);
    expect(find.text('Approval pending'), findsOneWidget);

    store.switchUser('u-sita');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Approve'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await tester.pumpAndSettle();
    expect(find.text('Approve external settlement'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Approve Settlement'));
    await tester.pumpAndSettle();

    expect(request.status, PaymentStatus.paid);
    expect(store.balancesForGroup(groupId), isEmpty);
    expect(find.text('Nothing to settle'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add expense starts with participants and supports payer rows', (
    tester,
  ) async {
    final store = AppStore.seeded()..selectedGroupId = 'g-dashain';

    await pumpGroupsForAddExpense(tester, store);
    await openManualEntry(tester);

    final totalAmountField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Total amount',
    );
    await tester.enterText(totalAmountField, '1200');
    await tester.pump();

    // Select all participants after entering a real amount to make split ready.
    final participantCards = find.byType(ParticipantSelectorCard);
    final cardCount = participantCards.evaluate().length;
    for (var index = 0; index < cardCount; index++) {
      await tester.ensureVisible(participantCards.at(index));
      await tester.tap(participantCards.at(index));
      await tester.pumpAndSettle();
    }

    expect(find.text('Participants'), findsOneWidget);
    expect(find.text('Expense details'), findsOneWidget);
    expect(find.text('Who paid?'), findsWidgets);
    expect(find.text('Split preview'), findsOneWidget);
    expect(find.text('Calculated equal split'), findsOneWidget);
    expect(find.text('Net result'), findsOneWidget);
    expect(find.text('Status: Ready to save'), findsOneWidget);

    final addPayer = find.widgetWithText(OutlinedButton, 'Add another payer');
    await tester.ensureVisible(addPayer);
    expect(tester.widget<OutlinedButton>(addPayer).onPressed, isNull);

    final payerAmountField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Amount paid',
    );
    await tester.enterText(payerAmountField, '1300');
    await tester.pump();
    expect(tester.widget<OutlinedButton>(addPayer).onPressed, isNull);

    await tester.enterText(payerAmountField, '600');
    await tester.pump();
    expect(tester.widget<OutlinedButton>(addPayer).onPressed, isNotNull);

    tester.widget<OutlinedButton>(addPayer).onPressed!();
    await tester.pumpAndSettle();

    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save expense'),
    );
    expect(save.onPressed, isNull);
    expect(find.text('Enter a valid amount to continue.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Manual entry places split mode before item list', (
    tester,
  ) async {
    final store = AppStore.seeded()..selectedGroupId = 'g-dashain';

    await pumpGroupsForAddExpense(tester, store);
    await openManualEntry(tester);

    final whoPaidTop = tester.getTopLeft(find.text('Who paid?').first).dy;
    final splitModeTop = tester.getTopLeft(find.text('Split mode').first).dy;
    final itemListTop = tester.getTopLeft(find.text('Item list').first).dy;

    expect(whoPaidTop, lessThan(splitModeTop));
    expect(splitModeTop, lessThan(itemListTop));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Manual entry opens without hardcoded receipt data', (
    tester,
  ) async {
    final store = AppStore.seeded()..selectedGroupId = 'g-dashain';

    await pumpGroupsForAddExpense(tester, store);
    await openManualEntry(tester);

    expect(find.text('Chicken momo'), findsNothing);
    expect(find.text('Veg chowmein'), findsNothing);
    expect(find.text('Cold drinks'), findsNothing);
    expect(find.text('Office Bhoj'), findsNothing);

    final titleField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Title',
    );
    final totalAmountField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Total amount',
    );
    expect(tester.widget<TextField>(titleField).controller?.text, isEmpty);
    expect(
      tester.widget<TextField>(totalAmountField).controller?.text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Manual entry defaults who paid to current user and remains editable',
    (tester) async {
      final store = AppStore.seeded()
        ..switchUser('u-arjun')
        ..selectedGroupId = 'g-dashain';

      await pumpGroupsForAddExpense(tester, store);
      await openManualEntry(tester);

      final payerDropdown = find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String> &&
            widget.decoration.labelText == 'Who paid?',
      );
      expect(payerDropdown, findsOneWidget);
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(payerDropdown)
            .initialValue,
        'u-arjun',
      );

      await tester.tap(payerDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sita Shrestha').last);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<DropdownButtonFormField<String>>(payerDropdown)
            .initialValue,
        'u-sita',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Add expense participant cards toggle split preview', (
    tester,
  ) async {
    final store = AppStore.seeded()..selectedGroupId = 'g-dashain';

    await pumpGroupsForAddExpense(tester, store);
    await openManualEntry(tester);

    // Initially, no participants are selected
    expect(find.text('Select at least one participant.'), findsWidgets);

    final participantCards = find.byType(ParticipantSelectorCard);
    final cardCount = participantCards.evaluate().length;
    expect(cardCount, greaterThan(0));

    // Select all participants
    for (var index = 0; index < cardCount; index++) {
      await tester.ensureVisible(participantCards.at(index));
      await tester.tap(participantCards.at(index));
      await tester.pumpAndSettle();
    }

    // Now they are selected, error should disappear
    expect(find.text('Select at least one participant.'), findsNothing);

    // Deselect all participants
    for (var index = 0; index < cardCount; index++) {
      await tester.ensureVisible(participantCards.at(index));
      await tester.tap(participantCards.at(index));
      await tester.pumpAndSettle();
    }

    // Error should show again
    expect(find.text('Select at least one participant.'), findsWidgets);
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save expense'),
    );
    expect(save.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Group detail shows latest activity summary with full view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 9000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store = AppStore.seeded();

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: MaterialApp(
          home: GroupDetail(
            group: store.groupById('g-dashain'),
            activityTimelineLimit: 5,
          ),
        ),
      ),
    );

    expect(find.text('View all activity'), findsOneWidget);
    expect(find.byIcon(Icons.timeline).evaluate().length <= 5, isTrue);

    final viewAll = find.widgetWithText(OutlinedButton, 'View all activity');
    await tester.tap(viewAll);
    await tester.pumpAndSettle();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Expenses'), findsWidgets);
    expect(find.text('Settlements'), findsOneWidget);
    expect(find.text('Members'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Group activity resolves backend group member ids', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 9000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store = AppStore.seeded();
    final member = store.groupMembers.firstWhere(
      (item) => item.groupId == 'g-dashain' && item.userId == 'u-arjun',
    );
    store.activity.insert(
      0,
      ActivityLog(
        id: 'activity-backend-member',
        actorId: store.currentUserId,
        actorType: 'user',
        eventType: 'member_added',
        entityType: 'group_member',
        entityId: member.id,
        title: 'Member added',
        body: 'Arjun joined the group.',
        createdAt: DateTime(2099),
        groupId: 'g-dashain',
      ),
    );

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: MaterialApp(
          home: GroupDetail(
            group: store.groupById('g-dashain'),
            activityTimelineLimit: 5,
          ),
        ),
      ),
    );

    expect(find.text('Arjun Karki joined the group'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add expense item list row has only Name and Amount fields', (
    tester,
  ) async {
    final store = AppStore.seeded()..selectedGroupId = 'g-dashain';

    await pumpGroupsForAddExpense(tester, store);
    await openManualEntry(tester);

    final skipItemSplitSwitch = find.widgetWithText(
      SwitchListTile,
      'Skip item split and use total amount',
    );
    await tester.ensureVisible(skipItemSplitSwitch);
    await tester.tap(skipItemSplitSwitch);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, '+ Add item'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '+ Add item'));
    await tester.pumpAndSettle();

    final itemName = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Item name',
    );
    expect(itemName, findsWidgets);
    expect(tester.widget<TextField>(itemName.first).controller?.text, isEmpty);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Amount',
      ),
      findsWidgets,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Qty',
      ),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Unit price',
      ),
      findsNothing,
    );
    expect(find.text('Split this item by shares'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            (widget.decoration?.labelText ?? '').endsWith('shares'),
      ),
      findsNothing,
    );
    expect(find.text('Service charge, VAT, and discount'), findsOneWidget);
    expect(find.text('Service charge'), findsWidgets);
    expect(find.text('VAT'), findsOneWidget);
    expect(find.text('Discount'), findsOneWidget);
    expect(find.text('Line type'), findsNothing);
    expect(
      find.widgetWithText(OutlinedButton, 'Add VAT/adjustment'),
      findsNothing,
    );
    expect(find.byTooltip('Delete adjustment'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Manual entry includes service charge in bill total', (
    tester,
  ) async {
    final store = AppStore.seeded()..selectedGroupId = 'g-dashain';

    await pumpGroupsForAddExpense(tester, store);
    await openManualEntry(tester);

    final skipItemSplitSwitch = find.widgetWithText(
      SwitchListTile,
      'Skip item split and use total amount',
    );
    await tester.ensureVisible(skipItemSplitSwitch);
    await tester.tap(skipItemSplitSwitch);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, '+ Add item'));
    await tester.pumpAndSettle();

    final itemAmount = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Amount',
    );
    await tester.enterText(itemAmount.first, '100');
    await tester.pump();

    final serviceChargeAmount = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Service charge amount',
    );
    await tester.enterText(serviceChargeAmount, '50');
    await tester.pump();

    final totalAmountField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Total amount',
    );
    expect(
      tester.widget<TextField>(totalAmountField).controller?.text,
      '150.00',
    );
    expect(find.text('Service charge'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Add expense total amount and paid fields are editable in item split mode',
    (tester) async {
      final store = AppStore.seeded()..selectedGroupId = 'g-dashain';

      await pumpGroupsForAddExpense(tester, store);
      await openManualEntry(tester);

      // Toggle skip item split off to activate item split mode
      final skipItemSplitSwitch = find.widgetWithText(
        SwitchListTile,
        'Skip item split and use total amount',
      );
      await tester.ensureVisible(skipItemSplitSwitch);
      await tester.tap(skipItemSplitSwitch);
      await tester.pumpAndSettle();

      // Verify total amount field is editable in item split mode
      final totalAmountField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Total amount',
      );
      expect(totalAmountField, findsOneWidget);

      await tester.enterText(totalAmountField, '1500');
      await tester.pump();

      final totalTextField = tester.widget<TextField>(totalAmountField);
      expect(totalTextField.controller?.text, '1500');

      // Verify paid amount field is editable
      final payerAmountField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Amount paid',
      );
      expect(payerAmountField, findsOneWidget);

      await tester.enterText(payerAmountField, '1000');
      await tester.pump();

      final payerTextField = tester.widget<TextField>(payerAmountField);
      expect(payerTextField.controller?.text, '1000');

      expect(tester.takeException(), isNull);
    },
  );
}
