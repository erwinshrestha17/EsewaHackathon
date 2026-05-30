import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sajha_kharcha/shared/api/backend_api.dart';

void main() {
  test('appEvents parses server-sent connection updates', () async {
    final api = BackendApi(
      baseUrl: 'http://127.0.0.1:3000',
      client: MockClient((request) async {
        expect(request.url.path, '/api/app/events');
        expect(request.headers['authorization'], 'Bearer access-token');
        return http.Response.bytes(
          utf8.encode(
            'event: connected\n'
            'data: {"userId":"u-erwin"}\n\n'
            'event: connection_changed\n'
            'data: {"connectionId":"conn-1","status":"approved"}\n\n',
          ),
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      }),
    );

    final events = await api.appEvents(accessToken: 'access-token').toList();

    expect(events.map((event) => event.type), [
      'connected',
      'connection_changed',
    ]);
    expect(events.last.data['connectionId'], 'conn-1');
    expect(events.last.data['status'], 'approved');
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
}
