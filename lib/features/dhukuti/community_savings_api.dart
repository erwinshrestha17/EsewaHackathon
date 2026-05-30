import 'dart:convert';

import 'package:http/http.dart' as http;

class CommunitySavingsApiException implements Exception {
  const CommunitySavingsApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CommunitySavingsApi {
  CommunitySavingsApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'BACKEND_API_BASE_URL',
            defaultValue: '',
          );

  final http.Client _client;
  final String _baseUrl;

  Future<Map<String, dynamic>> dashboard(
    String groupId, {
    required String accessToken,
    String? month,
  }) {
    final query = month == null ? '' : '?month=$month';
    return _get('/api/community-savings/$groupId/dashboard$query', accessToken);
  }

  Future<Map<String, dynamic>> submitContribution({
    required String groupId,
    required String contributionId,
    required int amountPaid,
    required String paymentMethod,
    String? note,
    String? referenceNumber,
    required String accessToken,
  }) {
    return _post(
      '/api/community-savings/groups/$groupId/contributions/$contributionId/submit',
      {
        'amountPaid': amountPaid,
        'paymentMethod': paymentMethod,
        'note': note,
        'referenceNumber': referenceNumber,
      },
      accessToken,
    );
  }

  Future<Map<String, dynamic>> confirmContribution({
    required String groupId,
    required String contributionId,
    required int amountReceived,
    required String paymentMethod,
    required String dateReceived,
    required String confirmedBy,
    String? note,
    String? referenceNumber,
    required String accessToken,
  }) {
    return _post(
      '/api/community-savings/groups/$groupId/contributions/$contributionId/confirm',
      {
        'amountReceived': amountReceived,
        'paymentMethod': paymentMethod,
        'dateReceived': dateReceived,
        'confirmedBy': confirmedBy,
        'note': note,
        'referenceNumber': referenceNumber,
      },
      accessToken,
    );
  }

  Future<Map<String, dynamic>> waiveContribution({
    required String groupId,
    required String contributionId,
    required String accessToken,
  }) {
    return _post(
      '/api/community-savings/groups/$groupId/contributions/$contributionId/waive',
      {},
      accessToken,
    );
  }

  Future<Map<String, dynamic>> recordExpense({
    required String groupId,
    required String title,
    required int amountSpent,
    required String expenseDate,
    required String category,
    required String recordedBy,
    String? description,
    String? receiptReference,
    required String accessToken,
  }) {
    return _post('/api/community-savings/$groupId/expenses', {
      'title': title,
      'amountSpent': amountSpent,
      'expenseDate': expenseDate,
      'category': category,
      'recordedBy': recordedBy,
      'description': description,
      'receiptReference': receiptReference,
    }, accessToken);
  }

  Future<Map<String, dynamic>> _get(String path, String accessToken) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl$path'),
      headers: _headers(accessToken),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, Object?> body,
    String accessToken,
  ) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl$path'),
      headers: _headers(accessToken),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Map<String, String> _headers(String accessToken) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CommunitySavingsApiException(
        decoded['error']?.toString() ?? 'Community savings API request failed.',
      );
    }
    return decoded;
  }
}
