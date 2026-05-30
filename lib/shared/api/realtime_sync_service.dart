import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_api.dart';

class BackendRealtimeSyncService {
  BackendRealtimeSyncService({BackendApi? backendApi})
    : _backendApi = backendApi ?? BackendApi();

  static const _events = <String>[
    'profile_changed',
    'settings_changed',
    'notification_changed',
    'connection_changed',
    'group_changed',
    'expense_changed',
    'adjustment_changed',
    'settlement_changed',
    'gift_changed',
    'gift_pool_changed',
    'community_savings_changed',
  ];

  final BackendApi _backendApi;
  final _controller = StreamController<BackendRealtimeEvent>.broadcast();
  final List<RealtimeChannel> _channels = <RealtimeChannel>[];
  SupabaseClient? _client;
  Timer? _refreshTimer;
  Future<String?> Function()? _accessTokenProvider;
  String? _lastSupabaseUrl;
  String? _lastPublishableKey;

  Stream<BackendRealtimeEvent> get events => _controller.stream;

  Future<void> start({
    required Future<String?> Function() accessTokenProvider,
  }) async {
    _accessTokenProvider = accessTokenProvider;
    final backendAccessToken = await accessTokenProvider();
    if (backendAccessToken == null || backendAccessToken.isEmpty) {
      await stop();
      return;
    }
    final config = await _backendApi.realtimeToken(
      accessToken: backendAccessToken,
    );
    await _applyConfig(config);
  }

  Future<void> stop() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    final client = _client;
    for (final channel in List<RealtimeChannel>.from(_channels)) {
      await client?.removeChannel(channel);
    }
    _channels.clear();
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }

  Future<void> _applyConfig(BackendRealtimeConfig config) async {
    if (config.supabaseUrl.isEmpty ||
        config.supabasePublishableKey.isEmpty ||
        config.accessToken.isEmpty) {
      return;
    }
    if (_client == null ||
        _lastSupabaseUrl != config.supabaseUrl ||
        _lastPublishableKey != config.supabasePublishableKey) {
      await stop();
      _client = SupabaseClient(
        config.supabaseUrl,
        config.supabasePublishableKey,
      );
      _lastSupabaseUrl = config.supabaseUrl;
      _lastPublishableKey = config.supabasePublishableKey;
    } else {
      for (final channel in List<RealtimeChannel>.from(_channels)) {
        await _client?.removeChannel(channel);
      }
      _channels.clear();
    }

    await _client!.realtime.setAuth(config.accessToken);
    for (final topic in config.topics) {
      final channel = _client!.channel(
        topic,
        opts: const RealtimeChannelConfig(private: true),
      );
      for (final event in _events) {
        channel.onBroadcast(
          event: event,
          callback: (payload) => _emit(event, payload),
        );
      }
      channel.subscribe((status, error) {
        if (error != null) {
          debugPrint('Realtime subscription failed for $topic: $error');
        }
      });
      _channels.add(channel);
    }
    _scheduleRefresh(config.expiresAt);
  }

  void _scheduleRefresh(DateTime expiresAt) {
    _refreshTimer?.cancel();
    final refreshAt = expiresAt.subtract(const Duration(minutes: 1));
    final delay = refreshAt.difference(DateTime.now());
    _refreshTimer = Timer(delay.isNegative ? Duration.zero : delay, () async {
      final provider = _accessTokenProvider;
      if (provider == null) {
        return;
      }
      try {
        await start(accessTokenProvider: provider);
      } on Object catch (error) {
        debugPrint('Realtime token refresh failed: $error');
      }
    });
  }

  void _emit(String event, Map<String, dynamic> payload) {
    final rawData = payload['payload'];
    final data = rawData is Map<String, dynamic>
        ? rawData
        : Map<String, dynamic>.from(payload);
    _controller.add(BackendRealtimeEvent(type: event, data: data));
  }
}
