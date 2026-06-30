import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';
import '../models/chat_models.dart';
import '../state/dm_thread_store.dart';
import 'auth_api.dart';

/// 聊天收件箱 WebSocket：实时推送会话列表更新与聊天页消息。
class ChatInboxWs {
  ChatInboxWs._();

  static final ChatInboxWs instance = ChatInboxWs._();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _intentionalClose = false;

  final List<void Function(ChatMessage)> _messageListeners = [];

  void addMessageListener(void Function(ChatMessage) listener) {
    if (!_messageListeners.contains(listener)) {
      _messageListeners.add(listener);
    }
  }

  void removeMessageListener(void Function(ChatMessage) listener) {
    _messageListeners.remove(listener);
  }

  Uri _wsUri() {
    final base = Uri.parse(ApiConfig.baseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return base.replace(
      scheme: scheme,
      path: '/api/v1/chat/ws',
      queryParameters: {'token': ApiConfig.accessToken},
    );
  }

  /// 用当前 [ApiConfig.accessToken] 重建连接（先断开旧连接并取消待重连）。
  void reconnect() {
    if (!ApiConfig.isLoggedIn) {
      disconnect(reconnect: false);
      return;
    }
    connect();
  }

  void connect() {
    if (!ApiConfig.isLoggedIn) return;
    disconnect(reconnect: false);
    _intentionalClose = false;
    try {
      _channel = WebSocketChannel.connect(_wsUri());
      _sub = _channel!.stream.listen(_onData, onError: _onError, onDone: _onDone);
      _startPing();
      _reconnectAttempt = 0;
      if (kDebugMode) debugPrint('[ChatInboxWs] connected');
    } catch (e) {
      if (kDebugMode) debugPrint('[ChatInboxWs] connect failed: $e');
      unawaited(_handleConnectionFailure());
    }
  }

  void disconnect({bool reconnect = true}) {
    _intentionalClose = !reconnect;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
  }

  void subscribe(int conversationId) {
    if (conversationId <= 0) return;
    _send({'type': 'subscribe', 'conversation_id': conversationId});
  }

  void _send(Map<String, dynamic> frame) {
    final ch = _channel;
    if (ch == null) return;
    ch.sink.add(jsonEncode(frame));
  }

  void _onData(dynamic data) {
    try {
      final j = jsonDecode(data as String) as Map<String, dynamic>;
      switch (j['type'] as String? ?? '') {
        case 'conversation_update':
          final conv = j['conversation'];
          if (conv is Map<String, dynamic>) {
            try {
              DmThreadStore.instance.applyConversationUpdate(
                ChatConversationItem.fromJson(conv),
              );
            } catch (e) {
              if (kDebugMode) debugPrint('[ChatInboxWs] conversation_update parse failed: $e');
            }
          }
        case 'message':
          final msg = j['message'];
          if (msg is Map<String, dynamic>) {
            final m = ChatMessage.fromJson(msg);
            DmThreadStore.instance.applyIncomingMessage(m);
            for (final l in List<void Function(ChatMessage)>.of(_messageListeners)) {
              l(m);
            }
          }
        case 'pong':
          break;
        case 'error':
          if (kDebugMode) debugPrint('[ChatInboxWs] server error: ${j['error']}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ChatInboxWs] parse failed: $e');
    }
  }

  void _onError(Object error) {
    if (kDebugMode) debugPrint('[ChatInboxWs] stream error: $error');
    unawaited(_handleConnectionFailure());
  }

  void _onDone() {
    if (!_intentionalClose) unawaited(_handleConnectionFailure());
  }

  Future<void> _handleConnectionFailure() async {
    if (!ApiConfig.isLoggedIn || _intentionalClose) return;
    final res = await AuthApi.fetchSession();
    if (!res.ok) {
      disconnect(reconnect: false);
      return;
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!ApiConfig.isLoggedIn || _intentionalClose) return;
    _reconnectTimer?.cancel();
    _reconnectAttempt++;
    final secs = (_reconnectAttempt * 2).clamp(2, 30);
    _reconnectTimer = Timer(Duration(seconds: secs), () {
      if (ApiConfig.isLoggedIn && !_intentionalClose) connect();
    });
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _send({'type': 'ping'});
    });
  }
}
