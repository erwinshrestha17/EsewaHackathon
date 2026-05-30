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
}
