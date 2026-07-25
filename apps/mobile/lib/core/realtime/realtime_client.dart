import 'dart:async';

import 'package:antrein/core/config/app_config.dart';
import 'package:antrein/core/realtime/realtime_event.dart';
import 'package:antrein/core/storage/token_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Single shared `/realtime` WebSocket connection (contract §101). Emits parsed
/// [RealtimeEvent]s; feature cubits filter the stream by `type` and recover
/// authoritative state over REST — WS informs, REST recovers (§112). Socket.IO
/// owns reconnection; every (re)connect fires [connections] so subscribers can
/// re-join their rooms and refetch.
///
/// ponytail: no Redis, no presence, no event-id dedup — one connection plus a
/// version-guarded REST refetch is enough for the MVP. The connect handshake
/// carries the token read at connect time; refreshing the token mid-connection
/// (for a reconnect after a >15-min idle) is deferred until it bites.
@lazySingleton
class RealtimeClient {
  RealtimeClient(this._config, this._tokens);

  final AppConfig _config;
  final TokenStorage _tokens;
  final Logger _log = Logger();

  io.Socket? _socket;
  final StreamController<RealtimeEvent> _events =
      StreamController<RealtimeEvent>.broadcast();
  final StreamController<void> _connections =
      StreamController<void>.broadcast();

  /// Parsed realtime events (all types — filter by `type` at the call site).
  Stream<RealtimeEvent> get events => _events.stream;

  /// Fires on every successful (re)connect so subscribers re-join + refetch.
  Stream<void> get connections => _connections.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Connect if not already connected. Idempotent; a no-op without a token.
  Future<void> connect() async {
    if (_socket != null) return;
    final token = await _tokens.readAccessToken();
    if (token == null) return;
    _socket =
        io.io(
            '${_origin()}/realtime',
            io.OptionBuilder()
                .setTransports(['websocket'])
                .disableAutoConnect()
                .enableReconnection()
                .setAuth({'accessToken': token})
                .build(),
          )
          ..onAny((_, data) {
            final parsed = RealtimeEvent.tryParse(data);
            if (parsed != null) _events.add(parsed);
          })
          ..onConnect((_) => _connections.add(null))
          ..onConnectError((e) => _log.w('realtime connect error: $e'))
          ..connect();
  }

  /// Ask the server to join the outlet-queue room (staff snapshot feed, §103).
  void subscribeOutletQueue(String outletId, String businessDate) {
    _socket?.emit('subscription.join.v1', {
      'channels': [
        {
          'type': 'outlet_queue',
          'resourceId': outletId,
          'businessDate': businessDate,
        },
      ],
    });
  }

  Future<void> disconnect() async {
    _socket?.dispose();
    _socket = null;
  }

  /// Origin of the API base URL with the `/api/v1` path stripped — the socket
  /// namespace lives at the server root, not under the REST prefix.
  String _origin() {
    final uri = Uri.parse(_config.apiBaseUrl);
    return '${uri.scheme}://${uri.host}:${uri.port}';
  }
}
