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

class BackendRealtimeConfig {
  const BackendRealtimeConfig({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.accessToken,
    required this.expiresAt,
    required this.topics,
  });

  factory BackendRealtimeConfig.fromJson(Map<String, dynamic> json) {
    return BackendRealtimeConfig(
      supabaseUrl: json['supabaseUrl']?.toString() ?? '',
      supabasePublishableKey: json['supabasePublishableKey']?.toString() ?? '',
      accessToken: json['accessToken']?.toString() ?? '',
      expiresAt:
          DateTime.tryParse(json['expiresAt']?.toString() ?? '') ??
          DateTime.now(),
      topics: [
        for (final topic in (json['topics'] as List<dynamic>? ?? const []))
          topic.toString(),
      ],
    );
  }

  final String supabaseUrl;
  final String supabasePublishableKey;
  final String accessToken;
  final DateTime expiresAt;
  final List<String> topics;
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

  Future<Map<String, dynamic>> updateProfile({
    required String accessToken,
    required Map<String, Object?> profile,
  }) {
    return _patch('/api/me', profile, accessToken: accessToken);
  }

  Future<Map<String, dynamic>> deleteAccount({required String accessToken}) {
    return _delete('/api/me', accessToken: accessToken);
  }

  Future<Map<String, dynamic>> settings({required String accessToken}) async {
    final data = await get('/api/settings', accessToken: accessToken);
    return (data['settings'] as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> updateSettings({
    required String accessToken,
    required Map<String, Object?> settings,
  }) async {
    final data = await _patch(
      '/api/settings',
      settings,
      accessToken: accessToken,
    );
    return (data['settings'] as Map<String, dynamic>?) ?? {};
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

  Future<Map<String, dynamic>> createGroup({
    required String accessToken,
    required Map<String, Object?> group,
  }) {
    return _post('/api/groups', group, accessToken: accessToken);
  }

  Future<Map<String, dynamic>> updateGroup({
    required String accessToken,
    required String groupId,
    required Map<String, Object?> group,
  }) {
    return _patch('/api/groups/$groupId', group, accessToken: accessToken);
  }

  Future<void> deleteGroup({
    required String accessToken,
    required String groupId,
  }) async {
    await _delete('/api/groups/$groupId', accessToken: accessToken);
  }

  Future<Map<String, dynamic>> leaveGroup({
    required String accessToken,
    required String groupId,
    String? transferAdminTo,
  }) {
    return _post('/api/groups/$groupId/leave', {
      'transferAdminTo': transferAdminTo,
    }, accessToken: accessToken);
  }

  Future<Map<String, dynamic>> addGroupMember({
    required String accessToken,
    required String groupId,
    required String userId,
    required String role,
  }) {
    return _post('/api/groups/$groupId/members', {
      'userId': userId,
      'role': role,
    }, accessToken: accessToken);
  }

  Future<Map<String, dynamic>> updateGroupMember({
    required String accessToken,
    required String groupId,
    required String memberId,
    String? role,
    String? status,
  }) {
    return _patch('/api/groups/$groupId/members/$memberId', {
      'role': role,
      'status': status,
    }, accessToken: accessToken);
  }

  Future<Map<String, dynamic>> removeGroupMember({
    required String accessToken,
    required String groupId,
    required String memberId,
  }) {
    return _delete(
      '/api/groups/$groupId/members/$memberId',
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> notifications({required String accessToken}) {
    return get('/api/notifications', accessToken: accessToken);
  }

  Future<void> markAllNotificationsRead({required String accessToken}) async {
    await _patch('/api/notifications/read-all', {}, accessToken: accessToken);
  }

  Future<Map<String, dynamic>> markNotificationRead({
    required String accessToken,
    required String notificationId,
  }) {
    return _patch(
      '/api/notifications/$notificationId/read',
      {},
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> requestConnection({
    required String accessToken,
    required String targetUserId,
  }) {
    return _post('/api/connections', {
      'targetUserId': targetUserId,
    }, accessToken: accessToken);
  }

  Future<Map<String, dynamic>> searchConnectionProfiles({
    required String accessToken,
    required String query,
  }) {
    final encoded = Uri(queryParameters: {'q': query}).query;
    return get('/api/connections/search?$encoded', accessToken: accessToken);
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

  Future<Map<String, dynamic>> removeConnection({
    required String accessToken,
    required String connectionId,
  }) {
    return _delete('/api/connections/$connectionId', accessToken: accessToken);
  }

  Future<Map<String, dynamic>> blockConnection({
    required String accessToken,
    required String connectionId,
    required String blockedUserId,
  }) {
    return _post('/api/connections/$connectionId/block', {
      'blockedUserId': blockedUserId,
    }, accessToken: accessToken);
  }

  Future<Map<String, dynamic>> unblockConnection({
    required String accessToken,
    required String connectionId,
    required String blockedUserId,
  }) {
    return _post('/api/connections/$connectionId/unblock', {
      'blockedUserId': blockedUserId,
    }, accessToken: accessToken);
  }

  Future<Map<String, dynamic>> reportConnection({
    required String accessToken,
    required String connectionId,
    required String reportedUserId,
    required String reasonCode,
    required String note,
  }) {
    return _post('/api/connections/$connectionId/report', {
      'reportedUserId': reportedUserId,
      'reasonCode': reasonCode,
      'note': note,
    }, accessToken: accessToken);
  }

  Future<Map<String, dynamic>> appBootstrap({required String accessToken}) {
    return get('/api/app/bootstrap', accessToken: accessToken);
  }

  Future<BackendRealtimeConfig> realtimeToken({
    required String accessToken,
  }) async {
    final data = await get('/api/app/realtime-token', accessToken: accessToken);
    return BackendRealtimeConfig.fromJson(data);
  }

  Future<Map<String, dynamic>> createExpense({
    required String accessToken,
    required String groupId,
    required Map<String, Object?> expense,
  }) {
    return _post(
      '/api/expenses/group/$groupId',
      expense,
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> updateExpense({
    required String accessToken,
    required String groupId,
    required String expenseId,
    required Map<String, Object?> expense,
  }) {
    return _patch(
      '/api/expenses/group/$groupId/$expenseId',
      expense,
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> voidExpense({
    required String accessToken,
    required String groupId,
    required String expenseId,
    required String reason,
  }) {
    return _post('/api/expenses/group/$groupId/$expenseId/void', {
      'reason': reason,
    }, accessToken: accessToken);
  }

  Future<Map<String, dynamic>> createAdjustment({
    required String accessToken,
    required String groupId,
    required Map<String, Object?> adjustment,
  }) {
    return _post(
      '/api/adjustments/group/$groupId',
      adjustment,
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> createSettlement({
    required String accessToken,
    required String groupId,
    required Map<String, Object?> settlement,
  }) {
    return _post(
      '/api/settlements/group/$groupId',
      settlement,
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> confirmSettlement({
    required String accessToken,
    required String groupId,
    required String settlementId,
    required Map<String, Object?> payment,
  }) {
    return _post(
      '/api/settlements/group/$groupId/$settlementId/confirm',
      payment,
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> cancelSettlement({
    required String accessToken,
    required String groupId,
    required String settlementId,
  }) {
    return _post(
      '/api/settlements/group/$groupId/$settlementId/cancel',
      {},
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> sendGift({
    required String accessToken,
    required Map<String, Object?> gift,
  }) {
    return _post('/api/gifts', gift, accessToken: accessToken);
  }

  Future<Map<String, dynamic>> openGift({
    required String accessToken,
    required String giftId,
  }) {
    return _post('/api/gifts/$giftId/open', {}, accessToken: accessToken);
  }

  Future<Map<String, dynamic>> createGiftPool({
    required String accessToken,
    required String groupId,
    required Map<String, Object?> giftPool,
  }) {
    return _post(
      '/api/gifts/pools/group/$groupId',
      giftPool,
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> contributeToGiftPool({
    required String accessToken,
    required String giftPoolId,
    required int amountMinor,
    required String idempotencyKey,
    String? paymentProvider,
    String? paymentReference,
    Map<String, Object?>? rawPayload,
  }) {
    return _post('/api/gifts/pools/$giftPoolId/contributions', {
      'amountMinor': amountMinor,
      'idempotencyKey': idempotencyKey,
      'paymentProvider': paymentProvider,
      'paymentReference': paymentReference,
      'rawPayload': rawPayload,
    }, accessToken: accessToken);
  }

  Future<Map<String, dynamic>> cancelGiftPool({
    required String accessToken,
    required String groupId,
    required String giftPoolId,
  }) {
    return _post(
      '/api/gifts/pools/group/$groupId/$giftPoolId/cancel',
      {},
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> createCommunitySavingsGroup({
    required String accessToken,
    required Map<String, Object?> group,
  }) {
    return _post('/api/community-savings', group, accessToken: accessToken);
  }

  Future<Map<String, dynamic>> updateCommunitySavingsGroup({
    required String accessToken,
    required String savingsGroupId,
    required Map<String, Object?> group,
  }) {
    return _patch(
      '/api/community-savings/$savingsGroupId',
      group,
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> submitCommunitySavingsContribution({
    required String accessToken,
    required String savingsGroupId,
    required String contributionId,
    required Map<String, Object?> contribution,
  }) {
    return _post(
      '/api/community-savings/groups/$savingsGroupId/contributions/$contributionId/submit',
      contribution,
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> confirmCommunitySavingsContribution({
    required String accessToken,
    required String savingsGroupId,
    required String contributionId,
    required Map<String, Object?> contribution,
  }) {
    return _post(
      '/api/community-savings/groups/$savingsGroupId/contributions/$contributionId/confirm',
      contribution,
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> waiveCommunitySavingsContribution({
    required String accessToken,
    required String savingsGroupId,
    required String contributionId,
    required Map<String, Object?> contribution,
  }) {
    return _post(
      '/api/community-savings/groups/$savingsGroupId/contributions/$contributionId/waive',
      contribution,
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> recordCommunitySavingsExpense({
    required String accessToken,
    required String savingsGroupId,
    required Map<String, Object?> expense,
  }) {
    return _post(
      '/api/community-savings/groups/$savingsGroupId/expenses',
      expense,
      accessToken: accessToken,
    );
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
      final Map<String, dynamic> decoded;
      try {
        decoded = _decodeBodyOrEmpty(body);
      } on FormatException {
        throw BackendApiException(
          'Backend stream failed (${response.statusCode}).',
        );
      }
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

  Future<Map<String, dynamic>> _delete(
    String path, {
    String? accessToken,
  }) async {
    final response = await _send(
      () => _client.delete(_uri(path), headers: _headers(accessToken)),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _patch(
    String path,
    Map<String, Object?> body, {
    String? accessToken,
  }) async {
    final response = await _send(
      () => _client.patch(
        _uri(path),
        headers: _headers(accessToken),
        body: jsonEncode(body),
      ),
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
