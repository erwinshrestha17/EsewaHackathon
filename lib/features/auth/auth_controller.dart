import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_state.dart';
import 'models/user_profile.dart';

class AuthController extends ChangeNotifier {
  AuthController();

  static const _hasSeenIntroKey = 'auth.hasSeenIntro';
  static const _isLoggedInKey = 'auth.isLoggedIn';
  static const _activeUserProfileKey = 'auth.activeUserProfile';
  static const _mPinKey = 'auth.mPin';
  static const _biometricEnabledKey = 'auth.biometricEnabled';
  static const demoOtp = '123456';
  static const demoMpin = '1234';

  SharedPreferences? _preferences;
  AuthState _state = const AuthState.initial();

  AuthState get state => _state;

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
    final mobile = _normalizeNepalMobile(identifier);
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
    final mobile = _normalizeNepalMobile(phone);
    if (mobile == null) {
      throw const AuthValidationException('Enter a valid Nepal mobile number.');
    }
    if (!_isValidMpin(mPin)) {
      throw const AuthValidationException('Enter your 4-digit M-PIN.');
    }
    final preferences = await _prefs();
    final savedMpin = preferences.getString(_mPinKey) ?? demoMpin;
    if (mPin.trim() != savedMpin) {
      throw const AuthValidationException('M-PIN does not match.');
    }
    final profile = _storedOrDemoProfile(preferences);
    final savedMobile = _normalizeNepalMobile(profile.phone);
    if (savedMobile != null && savedMobile != mobile) {
      throw const AuthValidationException('Phone number does not match.');
    }
    await _saveLoggedInProfile(profile.copyWith(phone: mobile));
  }

  Future<void> loginWithBiometric({required String phone}) async {
    final mobile = _normalizeNepalMobile(phone);
    if (mobile == null) {
      throw const AuthValidationException('Enter a valid Nepal mobile number.');
    }
    final preferences = await _prefs();
    final biometricEnabled = preferences.getBool(_biometricEnabledKey) ?? true;
    if (!biometricEnabled) {
      throw const AuthValidationException('Biometric login is not enabled.');
    }
    final profile = _storedOrDemoProfile(preferences);
    final savedMobile = _normalizeNepalMobile(profile.phone);
    if (savedMobile != null && savedMobile != mobile) {
      throw const AuthValidationException('Phone number does not match.');
    }
    await _saveLoggedInProfile(profile.copyWith(phone: mobile));
  }

  String? _normalizeNepalMobile(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return RegExp(r'^9[678]\d{8}$').hasMatch(digits) ? digits : null;
  }

  Future<void> register({
    required String mobileNumber,
    required DateTime dateOfBirth,
    required String mPin,
    required String otp,
    required bool biometricEnabled,
  }) async {
    final mobile = _normalizeNepalMobile(mobileNumber);
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
    await preferences.setString(_mPinKey, mPin.trim());
    await preferences.setBool(_biometricEnabledKey, biometricEnabled);
    await _saveLoggedInProfile(profile);
  }

  Future<void> continueAsDemoUser() async {
    await _saveLoggedInProfile(UserProfile.demo());
  }

  Future<void> updateProfile(UserProfile profile) async {
    final preferences = await _prefs();
    await preferences.setString(_activeUserProfileKey, profile.toJsonString());
    _state = _state.copyWith(activeUser: profile);
    notifyListeners();
  }

  Future<void> logout() async {
    final preferences = await _prefs();
    await preferences.setBool(_isLoggedInKey, false);
    _state = _state.copyWith(isLoggedIn: false);
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    final preferences = await _prefs();
    await preferences.setBool(_hasSeenIntroKey, true);
    await preferences.setBool(_isLoggedInKey, false);
    await preferences.remove(_activeUserProfileKey);
    await preferences.remove(_mPinKey);
    await preferences.remove(_biometricEnabledKey);
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
