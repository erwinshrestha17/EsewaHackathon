import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/api/backend_api.dart';
import 'auth_state.dart';
import 'models/user_profile.dart';
import 'nepal_mobile.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    BackendApi? backendApi,
    FlutterSecureStorage? secureStorage,
    bool? useKeychainStorage,
  }) : _backendApi = backendApi ?? BackendApi(),
       _secureStorage =
           secureStorage ??
           const FlutterSecureStorage(
             mOptions: MacOsOptions(usesDataProtectionKeychain: false),
           ),
       _useKeychainStorage =
           useKeychainStorage ?? defaultTargetPlatform != TargetPlatform.macOS;

  static const _hasSeenIntroKey = 'auth.hasSeenIntro';
  static const _activeUserProfileKey = 'auth.activeUserProfile';
  static const _accessTokenKey = 'auth.accessToken';
  static const _refreshTokenKey = 'auth.refreshToken';
  static const _accessTokenExpiresAtKey = 'auth.accessTokenExpiresAt';
  static const _refreshTokenExpiresAtKey = 'auth.refreshTokenExpiresAt';

  final BackendApi _backendApi;
  final FlutterSecureStorage _secureStorage;
  final bool _useKeychainStorage;
  SharedPreferences? _preferences;
  AuthState _state = const AuthState.initial();
  _StoredBackendSession? _session;
  Future<String?>? _refreshInFlight;

  AuthState get state => _state;

  @visibleForTesting
  FlutterSecureStorage get debugSecureStorage => _secureStorage;

  @visibleForTesting
  bool get debugUsesKeychainStorage => _useKeychainStorage;

  Future<String?> backendAccessToken() async {
    if (!_backendApi.isConfigured) {
      return null;
    }
    final session = _session ??= await _readStoredSession();
    if (session != null && session.hasFreshAccessToken) {
      return session.accessToken;
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
    final rawProfile = await _readAuthValue(_activeUserProfileKey);
    if (rawProfile != null) {
      try {
        activeUser = UserProfile.fromJsonString(rawProfile);
      } on FormatException {
        activeUser = null;
      }
    }

    _session = activeUser == null ? null : await _readStoredSession();
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
    _assertBackendConfigured();
    final token = await backendAccessToken();
    if (token == null) {
      throw const AuthValidationException(
        'Sign in again to update your profile.',
      );
    }
    final Map<String, dynamic> data;
    try {
      data = await _backendApi.updateProfile(
        accessToken: token,
        profile: {
          'fullName': profile.displayName,
          'phone': profile.phone,
          'avatarUrl': profile.avatarUrl,
          'avatarInitials': profile.initials,
          'district': profile.district,
        },
      );
    } on BackendApiException catch (error) {
      throw AuthValidationException(error.message);
    }
    final updatedProfile = _profileFromBackendProfile(
      (data['profile'] as Map<String, dynamic>?) ?? data,
      fallback: profile,
    );
    await _writeAuthValue(_activeUserProfileKey, updatedProfile.toJsonString());
    _state = _state.copyWith(activeUser: updatedProfile);
    notifyListeners();
  }

  Future<void> logout() async {
    final session = _session ??= await _readStoredSession();
    final accessToken = session?.accessToken;
    final refreshToken = session?.refreshToken;
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
    _assertBackendConfigured();
    final token = await backendAccessToken();
    if (token == null) {
      throw const AuthValidationException(
        'Sign in again to delete your account.',
      );
    }
    try {
      await _backendApi.deleteAccount(accessToken: token);
    } on BackendApiException catch (error) {
      throw AuthValidationException(error.message);
    }
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
    await _writeAuthValue(_accessTokenKey, session.accessToken);
    await _writeAuthValue(_refreshTokenKey, session.refreshToken);
    await _writeAuthValue(
      _accessTokenExpiresAtKey,
      session.accessTokenExpiresAt,
    );
    await _writeAuthValue(
      _refreshTokenExpiresAtKey,
      session.refreshTokenExpiresAt,
    );
    await _writeAuthValue(_activeUserProfileKey, profile.toJsonString());
    _session = _StoredBackendSession.fromBackendSession(session);
    _state = AuthState(
      initialized: true,
      hasSeenIntro: true,
      isLoggedIn: true,
      activeUser: profile,
    );
    notifyListeners();
  }

  Future<String?> _refreshSession() async {
    final refreshToken = _session?.refreshToken;
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
    _session = null;
    await _deleteAuthValue(_activeUserProfileKey);
    await _deleteAuthValue(_accessTokenKey);
    await _deleteAuthValue(_refreshTokenKey);
    await _deleteAuthValue(_accessTokenExpiresAtKey);
    await _deleteAuthValue(_refreshTokenExpiresAtKey);
    if (notify) {
      _state = AuthState(
        initialized: true,
        hasSeenIntro: _state.hasSeenIntro,
        isLoggedIn: false,
      );
      notifyListeners();
    }
  }

  Future<_StoredBackendSession?> _readStoredSession() async {
    final accessToken = await _readAuthValue(_accessTokenKey);
    final refreshToken = await _readAuthValue(_refreshTokenKey);
    final accessTokenExpiresAt = DateTime.tryParse(
      await _readAuthValue(_accessTokenExpiresAtKey) ?? '',
    );
    final refreshTokenExpiresAt = DateTime.tryParse(
      await _readAuthValue(_refreshTokenExpiresAtKey) ?? '',
    );
    if (accessToken == null ||
        refreshToken == null ||
        accessTokenExpiresAt == null ||
        refreshTokenExpiresAt == null) {
      return null;
    }
    return _StoredBackendSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiresAt: accessTokenExpiresAt,
      refreshTokenExpiresAt: refreshTokenExpiresAt,
    );
  }

  Future<SharedPreferences> _prefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  Future<String?> _readAuthValue(String key) async {
    if (_useKeychainStorage) {
      return _secureStorage.read(key: key);
    }
    return (await _prefs()).getString(key);
  }

  Future<void> _writeAuthValue(String key, String value) async {
    if (_useKeychainStorage) {
      await _secureStorage.write(key: key, value: value);
      return;
    }
    await (await _prefs()).setString(key, value);
  }

  Future<void> _deleteAuthValue(String key) async {
    if (_useKeychainStorage) {
      await _secureStorage.delete(key: key);
      return;
    }
    await (await _prefs()).remove(key);
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

  UserProfile _profileFromBackendProfile(
    Map<String, dynamic> profile, {
    required UserProfile fallback,
  }) {
    return UserProfile(
      id: profile['id']?.toString() ?? fallback.id,
      displayName:
          profile['displayName']?.toString() ??
          profile['fullName']?.toString() ??
          fallback.displayName,
      phone: profile['phone']?.toString() ?? fallback.phone,
      esewaId:
          profile['esewaId']?.toString() ??
          profile['email']?.toString() ??
          fallback.esewaId,
      district: profile['district']?.toString() ?? fallback.district,
      avatarUrl: profile['avatarUrl']?.toString() ?? fallback.avatarUrl,
      dateOfBirth:
          DateTime.tryParse(profile['dateOfBirth']?.toString() ?? '') ??
          fallback.dateOfBirth,
      createdAt:
          DateTime.tryParse(profile['createdAt']?.toString() ?? '') ??
          fallback.createdAt,
    );
  }
}

class _StoredBackendSession {
  const _StoredBackendSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.refreshTokenExpiresAt,
  });

  factory _StoredBackendSession.fromBackendSession(BackendAuthSession session) {
    return _StoredBackendSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      accessTokenExpiresAt:
          DateTime.tryParse(session.accessTokenExpiresAt) ?? DateTime.now(),
      refreshTokenExpiresAt:
          DateTime.tryParse(session.refreshTokenExpiresAt) ?? DateTime.now(),
    );
  }

  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
  final DateTime refreshTokenExpiresAt;

  bool get hasFreshAccessToken {
    return accessTokenExpiresAt.isAfter(
      DateTime.now().add(const Duration(seconds: 45)),
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

  static AuthController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'No AuthScope found in context.');
    return scope!.notifier!;
  }
}
