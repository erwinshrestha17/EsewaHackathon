import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class BackendApiException implements Exception {
  const BackendApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BackendAuthSession {
  const BackendAuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.refreshTokenExpiresAt,
    required this.profile,
  });

  factory BackendAuthSession.fromJson(Map<String, dynamic> json) {
    return BackendAuthSession(
      accessToken: json['accessToken'].toString(),
      refreshToken: json['refreshToken'].toString(),
      accessTokenExpiresAt: json['accessTokenExpiresAt'].toString(),
      refreshTokenExpiresAt: json['refreshTokenExpiresAt'].toString(),
      profile: (json['profile'] as Map<String, dynamic>?) ?? {},
    );
  }

  final String accessToken;
  final String refreshToken;
  final String accessTokenExpiresAt;
  final String refreshTokenExpiresAt;
  final Map<String, dynamic> profile;
}

class BackendOtpChallenge {
  const BackendOtpChallenge({
    required this.message,
    required this.expiresInSeconds,
    required this.resendAfterSeconds,
  });

  factory BackendOtpChallenge.fromJson(Map<String, dynamic> json) {
    return BackendOtpChallenge(
      message: json['message']?.toString() ?? 'OTP sent for verification.',
      expiresInSeconds:
          int.tryParse(json['expiresInSeconds']?.toString() ?? '') ?? 300,
      resendAfterSeconds:
          int.tryParse(json['resendAfterSeconds']?.toString() ?? '') ?? 60,
    );
  }

  final String message;
  final int expiresInSeconds;
  final int resendAfterSeconds;
}

class BackendRealtimeEvent {
  const BackendRealtimeEvent({required this.type, required this.data});

  final String type;
  final Map<String, dynamic> data;
}

class BackendApi {
  BackendApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'BACKEND_API_BASE_URL',
            defaultValue: '',
          );

  final http.Client _client;
  final String _baseUrl;
  static const _requestTimeout = Duration(seconds: 12);

  bool get isConfigured => _baseUrl.trim().isNotEmpty;

  Future<BackendOtpChallenge> requestSignupOtp({required String phone}) async {
    final data = await _post('/api/auth/signup/otp', {'phone': phone});
    return BackendOtpChallenge.fromJson(data);
  }

  Future<BackendAuthSession> signup({
    required String phone,
    required String otp,
    required String mPin,
    required String fullName,
    required String dateOfBirth,
    String? district,
  }) async {
    final data = await _post('/api/auth/signup', {
      'phone': phone,
      'otp': otp,
      'mPin': mPin,
      'fullName': fullName,
      'dateOfBirth': dateOfBirth,
      'district': district,
    });
    return BackendAuthSession.fromJson(data);
  }

  Future<BackendAuthSession> login({
    required String phone,
    required String mPin,
  }) async {
    final data = await _post('/api/auth/login', {'phone': phone, 'mPin': mPin});
    return BackendAuthSession.fromJson(data);
  }

  Future<BackendAuthSession> refresh({required String refreshToken}) async {
    final data = await _post('/api/auth/refresh', {
      'refreshToken': refreshToken,
    });
    return BackendAuthSession.fromJson(data);
  }

  Future<void> logout({String? accessToken, String? refreshToken}) async {
    await _post('/api/auth/logout', {
      'refreshToken': ?refreshToken,
    }, accessToken: accessToken);
  }

  Future<void> logoutAll({required String accessToken}) async {
    await _post('/api/auth/logout-all', {}, accessToken: accessToken);
  }

  Future<Map<String, dynamic>> currentProfile({required String accessToken}) {
    return get('/api/me', accessToken: accessToken);
  }

  Future<Map<String, dynamic>> groups({required String accessToken}) {
    return get('/api/groups', accessToken: accessToken);
  }

  Future<Map<String, dynamic>> group({
    required String accessToken,
    required String groupId,
  }) {
    return get('/api/groups/$groupId', accessToken: accessToken);
  }

  Future<Map<String, dynamic>> notifications({required String accessToken}) {
    return get('/api/notifications', accessToken: accessToken);
  }

  Future<Map<String, dynamic>> requestConnection({
    required String accessToken,
    required String targetUserId,
  }) {
    return _post('/api/connections', {
      'targetUserId': targetUserId,
    }, accessToken: accessToken);
  }

  Future<Map<String, dynamic>> approveConnection({
    required String accessToken,
    required String connectionId,
  }) {
    return _post(
      '/api/connections/$connectionId/approve',
      {},
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> declineConnection({
    required String accessToken,
    required String connectionId,
  }) {
    return _post(
      '/api/connections/$connectionId/decline',
      {},
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> appBootstrap({required String accessToken}) {
    return get('/api/app/bootstrap', accessToken: accessToken);
  }

  Stream<BackendRealtimeEvent> appEvents({required String accessToken}) async* {
    final request = http.Request('GET', _uri('/api/app/events'));
    request.headers.addAll({
      'Accept': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Authorization': 'Bearer $accessToken',
    });

    final response = await _sendStream(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      final decoded = _decodeBodyOrEmpty(body);
      throw BackendApiException(
        decoded['error']?.toString() ??
            'Backend stream failed (${response.statusCode}).',
      );
    }

    var eventType = 'message';
    final dataLines = <String>[];
    await for (final line
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.isEmpty) {
        if (dataLines.isNotEmpty) {
          final rawData = dataLines.join('\n');
          final decoded = jsonDecode(rawData);
          yield BackendRealtimeEvent(
            type: eventType,
            data: decoded is Map<String, dynamic>
                ? decoded
                : <String, dynamic>{'value': decoded},
          );
          eventType = 'message';
          dataLines.clear();
        }
        continue;
      }
      if (line.startsWith(':')) {
        continue;
      }
      if (line.startsWith('event:')) {
        eventType = line.substring(6).trim();
        continue;
      }
      if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      }
    }
  }

  Future<Map<String, dynamic>> communitySavingsDashboard({
    required String accessToken,
    required String savingsGroupId,
    String? month,
  }) {
    final query = month == null ? '' : '?month=$month';
    return get(
      '/api/community-savings/$savingsGroupId/dashboard$query',
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> communitySavingsBalance({
    required String accessToken,
    required String savingsGroupId,
  }) {
    return get(
      '/api/community-savings/$savingsGroupId/balance',
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> get(String path, {String? accessToken}) async {
    final response = await _send(
      () => _client.get(_uri(path), headers: _headers(accessToken)),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, Object?> body, {
    String? accessToken,
  }) async {
    final response = await _send(
      () => _client.post(
        _uri(path),
        headers: _headers(accessToken),
        body: jsonEncode(body),
      ),
    );
    return _decode(response);
  }

  Uri _uri(String path) =>
      Uri.parse('${_baseUrl.replaceAll(RegExp(r'/$'), '')}$path');

  Map<String, String> _headers(String? accessToken) {
    return {
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_requestTimeout);
    } on TimeoutException {
      throw const BackendApiException(
        'Backend is taking too long to respond. Check that the API server is running.',
      );
    } on BackendApiException {
      rethrow;
    } on Object {
      throw const BackendApiException(
        'Unable to reach backend. Check BACKEND_API_BASE_URL and the API server.',
      );
    }
  }

  Future<http.StreamedResponse> _sendStream(http.BaseRequest request) async {
    try {
      return await _client.send(request).timeout(_requestTimeout);
    } on TimeoutException {
      throw const BackendApiException(
        'Backend is taking too long to respond. Check that the API server is running.',
      );
    } on BackendApiException {
      rethrow;
    } on Object {
      throw const BackendApiException(
        'Unable to reach backend. Check BACKEND_API_BASE_URL and the API server.',
      );
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    final Map<String, dynamic> decoded;
    try {
      decoded = _decodeBodyOrEmpty(response.body);
    } on FormatException {
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw BackendApiException(
          'Backend request failed (${response.statusCode}).',
        );
      }
      throw const BackendApiException('Backend returned an invalid response.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        decoded['error']?.toString() ??
            'Backend request failed (${response.statusCode}).',
      );
    }
    return decoded;
  }

  Map<String, dynamic> _decodeBodyOrEmpty(String body) {
    final parsed = body.isEmpty ? <String, dynamic>{} : jsonDecode(body);
    return parsed is Map<String, dynamic> ? parsed : <String, dynamic>{};
  }
}
