import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'backend_api.dart';

typedef WebSocketConnector = WebSocketChannel Function(Uri uri);

class BackendRealtimeSyncService {
  BackendRealtimeSyncService({
    BackendApi? backendApi,
    WebSocketConnector? webSocketConnector,
  }) : _backendApi = backendApi ?? BackendApi(),
       _webSocketConnector = webSocketConnector ?? WebSocketChannel.connect;

  static const _events = <String>{
    'profile_changed',
    'settings_changed',
    'notification_changed',
    'connection_changed',
    'group_changed',
    'expense_changed',
    'expense_review_changed',
    'recurring_expense_changed',
    'adjustment_changed',
    'settlement_changed',
    'group_invite_changed',
    'group_ledger_changed',
    'gift_changed',
    'gift_pool_changed',
    'community_savings_changed',
  };
  static const _initialReconnectDelay = Duration(milliseconds: 500);
  static const _maxReconnectDelay = Duration(seconds: 8);

  final BackendApi _backendApi;
  final WebSocketConnector _webSocketConnector;
  final _controller = StreamController<BackendRealtimeEvent>.broadcast();
  StreamSubscription<dynamic>? _socketSubscription;
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Future<String?> Function()? _accessTokenProvider;
  var _stopped = true;
  var _connecting = false;
  var _reconnectAttempts = 0;

  Stream<BackendRealtimeEvent> get events => _controller.stream;

  Future<void> start({
    required Future<String?> Function() accessTokenProvider,
  }) async {
    _accessTokenProvider = accessTokenProvider;
    _stopped = false;
    if (_channel != null || _connecting) {
      return;
    }
    await _connect();
  }

  Future<void> stop() async {
    _stopped = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    await _closeSocket();
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }

  Future<void> _connect() async {
    if (_stopped || _connecting) {
      return;
    }
    _connecting = true;
    var shouldReconnect = false;
    try {
      final token = await _accessTokenProvider?.call();
      if (token == null || token.isEmpty) {
        await stop();
        return;
      }
      await _closeSocket();
      final channel = _webSocketConnector(_backendApi.realtimeWebSocketUri);
      _channel = channel;
      _socketSubscription = channel.stream.listen(
        _handleMessage,
        onError: (Object error) {
          debugPrint('Backend realtime websocket failed: $error');
          _scheduleReconnect();
        },
        onDone: _scheduleReconnect,
      );
      channel.sink.add(jsonEncode({'type': 'auth', 'accessToken': token}));
    } on Object catch (error) {
      debugPrint('Backend realtime websocket startup failed: $error');
      shouldReconnect = true;
    } finally {
      _connecting = false;
      if (shouldReconnect) {
        _scheduleReconnect();
      }
    }
  }

  Future<void> _closeSocket() async {
    final subscription = _socketSubscription;
    final channel = _channel;
    _socketSubscription = null;
    _channel = null;
    await subscription?.cancel();
    await channel?.sink.close();
  }

  void _scheduleReconnect() {
    if (_stopped || _connecting) {
      return;
    }
    unawaited(_closeSocket());
    if (_reconnectTimer?.isActive == true) {
      return;
    }
    final multiplier = 1 << math.min(_reconnectAttempts, 4);
    final delay = Duration(
      milliseconds: math.min(
        _initialReconnectDelay.inMilliseconds * multiplier,
        _maxReconnectDelay.inMilliseconds,
      ),
    );
    _reconnectAttempts += 1;
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      unawaited(_connect());
    });
  }

  void _handleMessage(Object? message) {
    BackendRealtimeEvent event;
    try {
      event = _backendApi.decodeRealtimeMessage(message ?? '');
    } on Object catch (error) {
      debugPrint('Backend realtime message ignored: $error');
      return;
    }
    if (!_events.contains(event.type) || _controller.isClosed) {
      return;
    }
    _reconnectAttempts = 0;
    _controller.add(event);
  }
}
