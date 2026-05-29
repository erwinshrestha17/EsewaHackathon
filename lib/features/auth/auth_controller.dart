import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_state.dart';
import 'models/user_profile.dart';

class AuthController extends ChangeNotifier {
  AuthController();

  static const _hasSeenIntroKey = 'auth.hasSeenIntro';
  static const _isLoggedInKey = 'auth.isLoggedIn';
  static const _activeUserProfileKey = 'auth.activeUserProfile';

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

  String? _normalizeNepalMobile(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    final mobile = digits.length == 13 && digits.startsWith('977')
        ? digits.substring(3)
        : digits;
    return RegExp(r'^9[678]\d{8}$').hasMatch(mobile) ? mobile : null;
  }

  Future<void> register({
    required String fullName,
    required String phone,
    required String esewaId,
    required String district,
    required String password,
  }) async {
    if (fullName.trim().isEmpty ||
        phone.trim().isEmpty ||
        esewaId.trim().isEmpty ||
        district.trim().isEmpty ||
        password.isEmpty) {
      throw const AuthValidationException('Complete all required fields.');
    }

    final profile = UserProfile(
      id: UserProfile.activeUserId,
      displayName: fullName.trim(),
      phone: phone.trim(),
      esewaId: esewaId.trim(),
      district: district.trim(),
      createdAt: DateTime.now(),
    );
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
