import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sajha_kharcha/shared/api/backend_api.dart';

void main() {
  test('realtimeWebSocketUri derives ws endpoint from backend base URL', () {
    final api = BackendApi(
      baseUrl: 'https://api.sajha.test/base/',
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    expect(
      api.realtimeWebSocketUri.toString(),
      'wss://api.sajha.test/base/api/app/ws',
    );
  });

  test('decodeRealtimeMessage parses websocket updates', () {
    final api = BackendApi(
      baseUrl: 'http://127.0.0.1:3000',
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    final event = api.decodeRealtimeMessage(
      utf8.encode(
        '{"type":"connection_changed","data":{"connectionId":"conn-1","status":"approved"}}',
      ),
    );

    expect(event.type, 'connection_changed');
    expect(event.data['connectionId'], 'conn-1');
    expect(event.data['status'], 'approved');
  });

  test('connection safety actions call backend endpoints', () async {
    final requests = <http.Request>[];
    final api = BackendApi(
      baseUrl: 'http://127.0.0.1:3000',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('{"ok":true}', 200);
      }),
    );

    await api.removeConnection(
      accessToken: 'access-token',
      connectionId: 'conn-1',
    );
    await api.blockConnection(
      accessToken: 'access-token',
      connectionId: 'conn-1',
      blockedUserId: 'u-utsav',
    );
    await api.unblockConnection(
      accessToken: 'access-token',
      connectionId: 'conn-1',
      blockedUserId: 'u-utsav',
    );
    await api.reportConnection(
      accessToken: 'access-token',
      connectionId: 'conn-1',
      reportedUserId: 'u-utsav',
      reasonCode: 'safety_review',
      note: 'Repeated messages',
    );

    expect(requests.map((request) => request.method), [
      'DELETE',
      'POST',
      'POST',
      'POST',
    ]);
    expect(requests.map((request) => request.url.path), [
      '/api/connections/conn-1',
      '/api/connections/conn-1/block',
      '/api/connections/conn-1/unblock',
      '/api/connections/conn-1/report',
    ]);
    expect(
      requests.every(
        (request) => request.headers['authorization'] == 'Bearer access-token',
      ),
      isTrue,
    );
    expect(jsonDecode(requests[1].body), {'blockedUserId': 'u-utsav'});
    expect(jsonDecode(requests[3].body), {
      'reportedUserId': 'u-utsav',
      'reasonCode': 'safety_review',
      'note': 'Repeated messages',
    });
  });

  test('connection profile search encodes query and auth header', () async {
    late http.Request captured;
    final api = BackendApi(
      baseUrl: 'http://127.0.0.1:3000',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          '{"users":[{"id":"u-maya","fullName":"Maya Gurung"}]}',
          200,
        );
      }),
    );

    final response = await api.searchConnectionProfiles(
      accessToken: 'access-token',
      query: 'Maya 980',
    );

    expect(captured.method, 'GET');
    expect(captured.url.path, '/api/connections/search');
    expect(captured.url.queryParameters['q'], 'Maya 980');
    expect(captured.headers['authorization'], 'Bearer access-token');
    expect(response['users'], isA<List<dynamic>>());
  });

  test(
    'group review recurring and invite actions call backend endpoints',
    () async {
      final requests = <http.Request>[];
      final api = BackendApi(
        baseUrl: 'http://127.0.0.1:3000',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{"ok":true,"invite":{"code":"SKG-123"}}', 200);
        }),
      );

      await api.createGroupInvite(
        accessToken: 'access-token',
        groupId: 'group-1',
      );
      await api.acceptGroupInvite(accessToken: 'access-token', code: 'SKG-123');
      await api.reviewExpense(
        accessToken: 'access-token',
        groupId: 'group-1',
        expenseId: 'expense-1',
        status: 'correction_requested',
        note: 'Wrong item',
      );
      await api.createRecurringExpense(
        accessToken: 'access-token',
        groupId: 'group-1',
        recurringExpense: {
          'title': 'Rent',
          'amountMinor': 3000000,
          'payerId': 'user-1',
        },
      );
      await api.postRecurringExpense(
        accessToken: 'access-token',
        groupId: 'group-1',
        recurringExpenseId: 'recurring-1',
      );
      await api.pauseRecurringExpense(
        accessToken: 'access-token',
        groupId: 'group-1',
        recurringExpenseId: 'recurring-1',
      );

      expect(requests.map((request) => request.method), [
        'POST',
        'POST',
        'POST',
        'POST',
        'POST',
        'POST',
      ]);
      expect(requests.map((request) => request.url.path), [
        '/api/groups/group-1/invites',
        '/api/groups/invites/accept',
        '/api/expenses/group/group-1/expense-1/reviews',
        '/api/expenses/group/group-1/recurring',
        '/api/expenses/group/group-1/recurring/recurring-1/post',
        '/api/expenses/group/group-1/recurring/recurring-1/pause',
      ]);
      expect(jsonDecode(requests[2].body), {
        'status': 'correction_requested',
        'note': 'Wrong item',
        'expenseItemId': null,
      });
      expect(jsonDecode(requests[4].body), <String, dynamic>{});
    },
  );
}
