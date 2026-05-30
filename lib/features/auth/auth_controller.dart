import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/api/backend_api.dart';
import 'auth_state.dart';
import 'models/user_profile.dart';
import 'nepal_mobile.dart';

class AuthController extends ChangeNotifier {
  AuthController({BackendApi? backendApi})
    : _backendApi = backendApi ?? BackendApi();

  static const _hasSeenIntroKey = 'auth.hasSeenIntro';
  static const _isLoggedInKey = 'auth.isLoggedIn';
  static const _activeUserProfileKey = 'auth.activeUserProfile';
  static const _mPinKey = 'auth.mPin';
  static const _biometricEnabledKey = 'auth.biometricEnabled';
  static const _localUsersKey = 'auth.localUsers';
  static const _backendAccessTokenKey = 'auth.backendAccessToken';
  static const _backendSessionExpiresAtKey = 'auth.backendSessionExpiresAt';
  static const demoOtp = '123456';
  static const demoMpin = '1234';

  final BackendApi _backendApi;
  SharedPreferences? _preferences;
  AuthState _state = const AuthState.initial();

  AuthState get state => _state;

  Future<String?> backendAccessToken() async {
    final preferences = await _prefs();
    return preferences.getString(_backendAccessTokenKey);
  }

  Future<void> initialize() async {
    if (_state.initialized) {
      return;
    }
    final preferences = _preferences ??= await SharedPreferences.getInstance();
    UserProfile? activeUser;
    final rawProfile = preferences.getString(_activeUserProfileKey);
    if (rawProfile != null) {
      try {
        activeUser = UserProfile.fromJsonString(rawProfile);
      } on FormatException {
        activeUser = null;
      }
    }

    final isLoggedIn = preferences.getBool(_isLoggedInKey) ?? false;
    _state = AuthState(
      initialized: true,
      hasSeenIntro: preferences.getBool(_hasSeenIntroKey) ?? false,
      isLoggedIn: isLoggedIn && activeUser != null,
      activeUser: activeUser,
    );
    notifyListeners();
  }

  Future<void> completeIntro() async {
    final preferences = await _prefs();
    await preferences.setBool(_hasSeenIntroKey, true);
    _state = _state.copyWith(hasSeenIntro: true);
    notifyListeners();
  }

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    final mobile = normalizeNepalMobile(identifier);
    if (mobile == null || password.isEmpty) {
      throw const AuthValidationException('Enter a valid Nepal mobile number.');
    }

    final existing = _state.activeUser;
    final profile =
        existing ??
        UserProfile.demo().copyWith(phone: mobile, esewaId: 'demo@esewa');
    await _saveLoggedInProfile(profile);
  }

  Future<void> loginWithMpin({
    required String phone,
    required String mPin,
  }) async {
    final mobile = normalizeNepalMobile(phone);
    if (mobile == null) {
      throw const AuthValidationException('Enter a valid Nepal mobile number.');
    }
    if (!_isValidMpin(mPin)) {
      throw const AuthValidationException('Enter your 4-digit M-PIN.');
    }
    if (_backendApi.isConfigured) {
      try {
        final session = await _backendApi.loginWithMpin(
          phone: mobile,
          mPin: mPin.trim(),
        );
        final profile = _profileFromBackendSession(
          session,
          fallbackPhone: mobile,
        );
        final preferences = await _prefs();
        await preferences.setString(
          _backendAccessTokenKey,
          session.accessToken,
        );
        await preferences.setString(
          _backendSessionExpiresAtKey,
          session.expiresAt,
        );
        await _saveLoggedInProfile(profile);
        return;
      } on BackendApiException catch (error) {
        throw AuthValidationException(error.message);
      }
    }
    final preferences = await _prefs();
    final localUsers = _localUsers(preferences);
    final localUser = localUsers[mobile];
    if (localUser != null) {
      if (mPin.trim() != localUser.mPin) {
        throw const AuthValidationException('M-PIN does not match.');
      }
      await _saveLoggedInProfile(localUser.profile.copyWith(phone: mobile));
      return;
    }

    if (localUsers.isNotEmpty || mPin.trim() != demoMpin) {
      throw const AuthValidationException('M-PIN does not match.');
    }
    await _saveLoggedInProfile(UserProfile.demo().copyWith(phone: mobile));
  }

  Future<void> loginWithBiometric({required String phone}) async {
    final mobile = normalizeNepalMobile(phone);
    if (mobile == null) {
      throw const AuthValidationException('Enter a valid Nepal mobile number.');
    }
    final preferences = await _prefs();
    final localUsers = _localUsers(preferences);
    final localUser = localUsers[mobile];
    if (localUser != null) {
      if (!localUser.biometricEnabled) {
        throw const AuthValidationException('Biometric login is not enabled.');
      }
      await _saveLoggedInProfile(localUser.profile.copyWith(phone: mobile));
      return;
    }

    if (localUsers.isNotEmpty ||
        !(preferences.getBool(_biometricEnabledKey) ?? true)) {
      throw const AuthValidationException('Biometric login is not enabled.');
    }
    await _saveLoggedInProfile(UserProfile.demo().copyWith(phone: mobile));
  }

  Future<void> register({
    required String mobileNumber,
    required DateTime dateOfBirth,
    required String mPin,
    required String otp,
    required bool biometricEnabled,
  }) async {
    final mobile = normalizeNepalMobile(mobileNumber);
    if (mobile == null || !_isValidMpin(mPin) || otp.trim().isEmpty) {
      throw const AuthValidationException('Complete all required fields.');
    }
    if (otp.trim() != demoOtp) {
      throw const AuthValidationException('Enter the 6-digit OTP.');
    }
    final now = DateTime.now();
    if (dateOfBirth.isAfter(DateTime(now.year, now.month, now.day))) {
      throw const AuthValidationException('Date of birth cannot be in future.');
    }

    if (_backendApi.isConfigured) {
      try {
        final session = await _backendApi.registerWithMpin(
          phone: mobile,
          mPin: mPin.trim(),
          fullName: 'Sajha Member',
        );
        final profile = _profileFromBackendSession(
          session,
          fallbackPhone: mobile,
        );
        final preferences = await _prefs();
        await preferences.setString(_mPinKey, mPin.trim());
        await preferences.setBool(_biometricEnabledKey, biometricEnabled);
        await preferences.setString(
          _backendAccessTokenKey,
          session.accessToken,
        );
        await preferences.setString(
          _backendSessionExpiresAtKey,
          session.expiresAt,
        );
        await _saveLoggedInProfile(profile);
        return;
      } on BackendApiException catch (error) {
        throw AuthValidationException(error.message);
      }
    }

    final profile = UserProfile(
      id: UserProfile.activeUserId,
      displayName: 'Sajha Member',
      phone: mobile,
      esewaId: '$mobile@esewa',
      district: '',
      dateOfBirth: dateOfBirth,
      createdAt: now,
    );
    final preferences = await _prefs();
    final localUsers = _localUsers(preferences);
    localUsers[mobile] = _LocalAuthUser(
      profile: profile,
      mPin: mPin.trim(),
      biometricEnabled: biometricEnabled,
    );
    await _saveLocalUsers(preferences, localUsers);
    await preferences.setString(_mPinKey, mPin.trim());
    await preferences.setBool(_biometricEnabledKey, biometricEnabled);
    await _saveLoggedInProfile(profile);
  }

  Future<void> continueAsDemoUser() async {
    await _saveLoggedInProfile(UserProfile.demo());
  }

  Future<void> updateProfile(UserProfile profile) async {
    final preferences = await _prefs();
    final localUsers = _localUsers(preferences);
    final previousPhone = _state.activeUser == null
        ? null
        : normalizeNepalMobile(_state.activeUser!.phone);
    final mobile = normalizeNepalMobile(profile.phone);
    if (mobile != null) {
      final previousUser = previousPhone == null
          ? null
          : localUsers.remove(previousPhone);
      final existing = localUsers[mobile] ?? previousUser;
      localUsers[mobile] = _LocalAuthUser(
        profile: profile.copyWith(phone: mobile),
        mPin:
            existing?.mPin ??
            preferences.getString(_mPinKey) ??
            AuthController.demoMpin,
        biometricEnabled:
            existing?.biometricEnabled ??
            preferences.getBool(_biometricEnabledKey) ??
            true,
      );
      await _saveLocalUsers(preferences, localUsers);
    }
    await preferences.setString(_activeUserProfileKey, profile.toJsonString());
    _state = _state.copyWith(activeUser: profile);
    notifyListeners();
  }

  Future<void> logout() async {
    final preferences = await _prefs();
    await preferences.setBool(_isLoggedInKey, false);
    await preferences.remove(_backendAccessTokenKey);
    await preferences.remove(_backendSessionExpiresAtKey);
    _state = _state.copyWith(isLoggedIn: false);
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    final preferences = await _prefs();
    final localUsers = _localUsers(preferences);
    final mobile = _state.activeUser == null
        ? null
        : normalizeNepalMobile(_state.activeUser!.phone);
    if (mobile != null) {
      localUsers.remove(mobile);
      await _saveLocalUsers(preferences, localUsers);
    }
    await preferences.setBool(_hasSeenIntroKey, true);
    await preferences.setBool(_isLoggedInKey, false);
    await preferences.remove(_activeUserProfileKey);
    await preferences.remove(_mPinKey);
    await preferences.remove(_biometricEnabledKey);
    await preferences.remove(_backendAccessTokenKey);
    await preferences.remove(_backendSessionExpiresAtKey);
    _state = const AuthState(
      initialized: true,
      hasSeenIntro: true,
      isLoggedIn: false,
    );
    notifyListeners();
  }

  Future<void> _saveLoggedInProfile(UserProfile profile) async {
    final preferences = await _prefs();
    await preferences.setBool(_hasSeenIntroKey, true);
    await preferences.setBool(_isLoggedInKey, true);
    await preferences.setString(_activeUserProfileKey, profile.toJsonString());
    _state = AuthState(
      initialized: true,
      hasSeenIntro: true,
      isLoggedIn: true,
      activeUser: profile,
    );
    notifyListeners();
  }

  Future<SharedPreferences> _prefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  bool _isValidMpin(String value) {
    return RegExp(r'^\d{4}$').hasMatch(value.trim());
  }

  Map<String, _LocalAuthUser> _localUsers(SharedPreferences preferences) {
    final users = <String, _LocalAuthUser>{};
    final rawUsers = preferences.getString(_localUsersKey);
    if (rawUsers != null) {
      try {
        final decoded = jsonDecode(rawUsers) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          final user = _LocalAuthUser.fromJson(entry.value);
          final phone =
              normalizeNepalMobile(user.profile.phone) ??
              normalizeNepalMobile(entry.key);
          if (phone != null) {
            users[phone] = user.copyWith(
              profile: user.profile.copyWith(phone: phone),
            );
          }
        }
      } on FormatException {
        users.clear();
      } on TypeError {
        users.clear();
      }
    }

    final legacyProfile = _storedOrDemoProfile(preferences);
    final legacyPhone = normalizeNepalMobile(legacyProfile.phone);
    if (legacyPhone != null && !users.containsKey(legacyPhone)) {
      users[legacyPhone] = _LocalAuthUser(
        profile: legacyProfile.copyWith(phone: legacyPhone),
        mPin: preferences.getString(_mPinKey) ?? demoMpin,
        biometricEnabled: preferences.getBool(_biometricEnabledKey) ?? true,
      );
    }
    return users;
  }

  Future<void> _saveLocalUsers(
    SharedPreferences preferences,
    Map<String, _LocalAuthUser> users,
  ) {
    final payload = users.map((phone, user) => MapEntry(phone, user.toJson()));
    return preferences.setString(_localUsersKey, jsonEncode(payload));
  }

  UserProfile _storedOrDemoProfile(SharedPreferences preferences) {
    final rawProfile = preferences.getString(_activeUserProfileKey);
    if (rawProfile != null) {
      try {
        return UserProfile.fromJsonString(rawProfile);
      } on FormatException {
        return UserProfile.demo();
      }
    }
    return UserProfile.demo();
  }

  UserProfile _profileFromBackendSession(
    BackendAuthSession session, {
    required String fallbackPhone,
  }) {
    final profile = session.profile;
    return UserProfile(
      id: profile['id']?.toString() ?? UserProfile.activeUserId,
      displayName: profile['displayName']?.toString() ?? 'Sajha Member',
      phone: profile['phone']?.toString() ?? fallbackPhone,
      esewaId:
          profile['esewaId']?.toString() ??
          '${profile['phone'] ?? fallbackPhone}@esewa',
      district: profile['district']?.toString() ?? '',
      avatarUrl: profile['avatarUrl']?.toString(),
      createdAt:
          DateTime.tryParse(profile['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class _LocalAuthUser {
  const _LocalAuthUser({
    required this.profile,
    required this.mPin,
    required this.biometricEnabled,
  });

  factory _LocalAuthUser.fromJson(Object? source) {
    final json = source as Map<String, dynamic>;
    return _LocalAuthUser(
      profile: UserProfile.fromJson(json['profile'] as Map<String, Object?>),
      mPin: json['mPin'] as String? ?? AuthController.demoMpin,
      biometricEnabled: json['biometricEnabled'] as bool? ?? true,
    );
  }

  final UserProfile profile;
  final String mPin;
  final bool biometricEnabled;

  Map<String, Object?> toJson() {
    return {
      'profile': profile.toJson(),
      'mPin': mPin,
      'biometricEnabled': biometricEnabled,
    };
  }

  _LocalAuthUser copyWith({UserProfile? profile}) {
    return _LocalAuthUser(
      profile: profile ?? this.profile,
      mPin: mPin,
      biometricEnabled: biometricEnabled,
    );
  }
}

class AuthValidationException implements Exception {
  const AuthValidationException(this.message);

  final String message;
}

class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({
    required AuthController super.notifier,
    required super.child,
    super.key,
  });

  static AuthController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'No AuthScope found in context.');
    return scope!.notifier!;
  }
}
