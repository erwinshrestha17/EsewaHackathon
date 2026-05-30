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
    required this.expiresAt,
    required this.profile,
  });

  factory BackendAuthSession.fromJson(Map<String, dynamic> json) {
    return BackendAuthSession(
      accessToken: json['accessToken'].toString(),
      expiresAt: json['expiresAt'].toString(),
      profile: (json['profile'] as Map<String, dynamic>?) ?? {},
    );
  }

  final String accessToken;
  final String expiresAt;
  final Map<String, dynamic> profile;
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

  bool get isConfigured => _baseUrl.trim().isNotEmpty;

  Future<BackendAuthSession> loginWithMpin({
    required String phone,
    required String mPin,
  }) async {
    final data = await post('/api/auth/mpin/login', {
      'phone': phone,
      'mPin': mPin,
    });
    return BackendAuthSession.fromJson(data);
  }

  Future<BackendAuthSession> registerWithMpin({
    required String phone,
    required String mPin,
    required String fullName,
    String? district,
  }) async {
    final data = await post('/api/auth/mpin/register', {
      'phone': phone,
      'mPin': mPin,
      'fullName': fullName,
      'district': district,
    });
    return BackendAuthSession.fromJson(data);
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

  Future<Map<String, dynamic>> appBootstrap({required String accessToken}) {
    return get('/api/app/bootstrap', accessToken: accessToken);
  }

  Future<Map<String, dynamic>> createGroup({
    required String accessToken,
    required Map<String, Object?> body,
  }) {
    return post('/api/groups', body, accessToken: accessToken);
  }

  Future<Map<String, dynamic>> addGroupMember({
    required String accessToken,
    required String groupId,
    required Map<String, Object?> body,
  }) {
    return post('/api/groups/$groupId/members', body, accessToken: accessToken);
  }

  Future<Map<String, dynamic>> createExpense({
    required String accessToken,
    required String groupId,
    required Map<String, Object?> body,
  }) {
    return post('/api/expenses/group/$groupId', body, accessToken: accessToken);
  }

  Future<Map<String, dynamic>> createSettlement({
    required String accessToken,
    required String groupId,
    required Map<String, Object?> body,
  }) {
    return post(
      '/api/settlements/group/$groupId',
      body,
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> confirmSettlement({
    required String accessToken,
    required String groupId,
    required String settlementId,
  }) {
    return post(
      '/api/settlements/group/$groupId/$settlementId/confirm',
      const {},
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> sendGift({
    required String accessToken,
    required Map<String, Object?> body,
  }) {
    return post('/api/gifts', body, accessToken: accessToken);
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
    final response = await _client.get(
      _uri(path),
      headers: _headers(accessToken),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, Object?> body, {
    String? accessToken,
  }) async {
    final response = await _client.post(
      _uri(path),
      headers: _headers(accessToken),
      body: jsonEncode(body),
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

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        decoded['error']?.toString() ?? 'Backend request failed.',
      );
    }
    return decoded;
  }
}
