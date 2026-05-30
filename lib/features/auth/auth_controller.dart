import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/api/backend_api.dart';
import 'auth_state.dart';
import 'models/user_profile.dart';
import 'nepal_mobile.dart';

class AuthController extends ChangeNotifier {
  AuthController({BackendApi? backendApi, FlutterSecureStorage? secureStorage})
    : _backendApi = backendApi ?? BackendApi(),
      _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _hasSeenIntroKey = 'auth.hasSeenIntro';
  static const _activeUserProfileKey = 'auth.activeUserProfile';
  static const _accessTokenKey = 'auth.accessToken';
  static const _refreshTokenKey = 'auth.refreshToken';
  static const _accessTokenExpiresAtKey = 'auth.accessTokenExpiresAt';
  static const _refreshTokenExpiresAtKey = 'auth.refreshTokenExpiresAt';

  final BackendApi _backendApi;
  final FlutterSecureStorage _secureStorage;
  SharedPreferences? _preferences;
  AuthState _state = const AuthState.initial();
  Future<String?>? _refreshInFlight;

  AuthState get state => _state;

  Future<String?> backendAccessToken() async {
    if (!_backendApi.isConfigured) {
      return null;
    }
    final accessToken = await _secureStorage.read(key: _accessTokenKey);
    final expiresAt = DateTime.tryParse(
      await _secureStorage.read(key: _accessTokenExpiresAtKey) ?? '',
    );
    if (accessToken != null &&
        expiresAt != null &&
        expiresAt.isAfter(DateTime.now().add(const Duration(seconds: 45)))) {
      return accessToken;
    }
    return _refreshInFlight ??= _refreshSession().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<void> initialize() async {
    if (_state.initialized) {
      return;
    }
    final preferences = _preferences ??= await SharedPreferences.getInstance();
    await _clearLegacySharedPreferenceSecrets(preferences);

    UserProfile? activeUser;
    final rawProfile = await _secureStorage.read(key: _activeUserProfileKey);
    if (rawProfile != null) {
      try {
        activeUser = UserProfile.fromJsonString(rawProfile);
      } on FormatException {
        activeUser = null;
      }
    }

    final token = activeUser == null ? null : await backendAccessToken();
    if (activeUser != null && token == null) {
      await _clearSession(notify: false);
      activeUser = null;
    }

    _state = AuthState(
      initialized: true,
      hasSeenIntro: preferences.getBool(_hasSeenIntroKey) ?? false,
      isLoggedIn: activeUser != null && token != null,
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

  Future<BackendOtpChallenge> requestSignupOtp({required String phone}) async {
    final mobile = normalizeNepalMobile(phone);
    if (mobile == null) {
      throw const AuthValidationException('Enter a valid Nepal mobile number.');
    }
    _assertBackendConfigured();
    try {
      return await _backendApi.requestSignupOtp(phone: mobile);
    } on BackendApiException catch (error) {
      throw AuthValidationException(error.message);
    }
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
    _assertBackendConfigured();
    try {
      final session = await _backendApi.login(phone: mobile, mPin: mPin.trim());
      await _saveSession(session, fallbackPhone: mobile);
    } on BackendApiException catch (error) {
      throw AuthValidationException(error.message);
    }
  }

  Future<void> register({
    required String fullName,
    required String mobileNumber,
    required DateTime dateOfBirth,
    required String mPin,
    required String otp,
    String? district,
  }) async {
    final mobile = normalizeNepalMobile(mobileNumber);
    if (mobile == null || !_isValidMpin(mPin) || otp.trim().isEmpty) {
      throw const AuthValidationException('Complete all required fields.');
    }
    if (fullName.trim().length < 2) {
      throw const AuthValidationException('Enter your full name.');
    }
    final now = DateTime.now();
    if (dateOfBirth.isAfter(DateTime(now.year, now.month, now.day))) {
      throw const AuthValidationException('Date of birth cannot be in future.');
    }
    _assertBackendConfigured();

    try {
      final normalizedDistrict = district?.trim();
      final session = await _backendApi.signup(
        phone: mobile,
        otp: otp.trim(),
        mPin: mPin.trim(),
        fullName: fullName.trim(),
        dateOfBirth: _dateInput(dateOfBirth),
        district: normalizedDistrict == null || normalizedDistrict.isEmpty
            ? null
            : normalizedDistrict,
      );
      await _saveSession(session, fallbackPhone: mobile);
    } on BackendApiException catch (error) {
      throw AuthValidationException(error.message);
    }
  }

  Future<void> updateProfile(UserProfile profile) async {
    await _secureStorage.write(
      key: _activeUserProfileKey,
      value: profile.toJsonString(),
    );
    _state = _state.copyWith(activeUser: profile);
    notifyListeners();
  }

  Future<void> logout() async {
    final accessToken = await _secureStorage.read(key: _accessTokenKey);
    final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
    if (_backendApi.isConfigured &&
        (accessToken != null || refreshToken != null)) {
      try {
        await _backendApi.logout(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
      } on BackendApiException {
        // Local cleanup still wins; logout is idempotent server-side.
      }
    }
    await _clearSession();
  }

  Future<void> deleteAccount() async {
    final preferences = await _prefs();
    await preferences.setBool(_hasSeenIntroKey, true);
    await _clearSession(notify: false);
    _state = const AuthState(
      initialized: true,
      hasSeenIntro: true,
      isLoggedIn: false,
    );
    notifyListeners();
  }

  Future<void> _saveSession(
    BackendAuthSession session, {
    required String fallbackPhone,
  }) async {
    final profile = _profileFromBackendSession(
      session,
      fallbackPhone: fallbackPhone,
    );
    final preferences = await _prefs();
    await preferences.setBool(_hasSeenIntroKey, true);
    await _secureStorage.write(
      key: _accessTokenKey,
      value: session.accessToken,
    );
    await _secureStorage.write(
      key: _refreshTokenKey,
      value: session.refreshToken,
    );
    await _secureStorage.write(
      key: _accessTokenExpiresAtKey,
      value: session.accessTokenExpiresAt,
    );
    await _secureStorage.write(
      key: _refreshTokenExpiresAtKey,
      value: session.refreshTokenExpiresAt,
    );
    await _secureStorage.write(
      key: _activeUserProfileKey,
      value: profile.toJsonString(),
    );
    _state = AuthState(
      initialized: true,
      hasSeenIntro: true,
      isLoggedIn: true,
      activeUser: profile,
    );
    notifyListeners();
  }

  Future<String?> _refreshSession() async {
    final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
    if (refreshToken == null) {
      return null;
    }
    try {
      final session = await _backendApi.refresh(refreshToken: refreshToken);
      await _saveSession(
        session,
        fallbackPhone: _state.activeUser?.phone ?? '',
      );
      return session.accessToken;
    } on BackendApiException {
      await _clearSession();
      return null;
    }
  }

  Future<void> _clearSession({bool notify = true}) async {
    await _secureStorage.delete(key: _activeUserProfileKey);
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _accessTokenExpiresAtKey);
    await _secureStorage.delete(key: _refreshTokenExpiresAtKey);
    if (notify) {
      _state = AuthState(
        initialized: true,
        hasSeenIntro: _state.hasSeenIntro,
        isLoggedIn: false,
      );
      notifyListeners();
    }
  }

  Future<SharedPreferences> _prefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  Future<void> _clearLegacySharedPreferenceSecrets(
    SharedPreferences preferences,
  ) async {
    await preferences.remove('auth.isLoggedIn');
    await preferences.remove('auth.activeUserProfile');
    await preferences.remove('auth.mPin');
    await preferences.remove('auth.biometricEnabled');
    await preferences.remove('auth.backendAccessToken');
    await preferences.remove('auth.backendSessionExpiresAt');
  }

  void _assertBackendConfigured() {
    if (!_backendApi.isConfigured) {
      throw const AuthValidationException(
        'Start the app with BACKEND_API_BASE_URL to sign in.',
      );
    }
  }

  bool _isValidMpin(String value) {
    return RegExp(r'^\d{4}$').hasMatch(value.trim());
  }

  String _dateInput(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  UserProfile _profileFromBackendSession(
    BackendAuthSession session, {
    required String fallbackPhone,
  }) {
    final profile = session.profile;
    return UserProfile(
      id: profile['id']?.toString() ?? profile['profileId']?.toString() ?? '',
      displayName: profile['displayName']?.toString() ?? 'Sajha Member',
      phone: profile['phone']?.toString() ?? fallbackPhone,
      esewaId:
          profile['esewaId']?.toString() ??
          '${profile['phone'] ?? fallbackPhone}@esewa',
      district: profile['district']?.toString() ?? '',
      avatarUrl: profile['avatarUrl']?.toString(),
      dateOfBirth: DateTime.tryParse(profile['dateOfBirth']?.toString() ?? ''),
      createdAt:
          DateTime.tryParse(profile['createdAt']?.toString() ?? '') ??
          DateTime.now(),
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
