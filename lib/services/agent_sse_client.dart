import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/agent_models.dart';
import '../models/chat_attachment.dart';
import 'chat_stream_handle.dart';
import 'sse_event_buffer.dart';

/// Agent 流式回复（SSE），独立于 [ApiClient] 的 12s 超时。
class AgentSseClient {
  AgentSseClient._();

  static const Duration firstByteTimeout = Duration(seconds: 60);
  static const Duration totalTimeout = Duration(minutes: 5);

  static Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        if (ApiConfig.accessToken.isNotEmpty) 'Authorization': 'Bearer ${ApiConfig.accessToken}',
      };

  /// 发送消息并消费 SSE 事件；返回 [ChatStreamHandle] 用于停止生成。
  static ChatStreamHandle sendMessage({
    required int conversationId,
    required String content,
    List<ChatAttachment> attachments = const [],
    bool webSearch = true,
    void Function(AgentToolEvent tool)? onTool,
    required void Function(String delta) onDelta,
    required void Function(AgentStreamDone done) onDone,
    required void Function(String code, String message) onError,
  }) {
    final client = http.Client();
    final cancelled = StreamCancelFlag();
    final abortRegistration = StreamAbortRegistration();
    final done = _runSendMessage(
      client: client,
      isCancelled: cancelled.isSet,
      abortRegistration: abortRegistration,
      conversationId: conversationId,
      content: content,
      attachments: attachments,
      webSearch: webSearch,
      onTool: onTool,
      onDelta: onDelta,
      onDone: onDone,
      onError: onError,
    );
    return ChatStreamHandle(client, done, cancelled, abortRegistration);
  }

  static Future<void> _runSendMessage({
    required http.Client client,
    required bool Function() isCancelled,
    required StreamAbortRegistration abortRegistration,
    required int conversationId,
    required String content,
    List<ChatAttachment> attachments = const [],
    bool webSearch = true,
    void Function(AgentToolEvent tool)? onTool,
    required void Function(String delta) onDelta,
    required void Function(AgentStreamDone done) onDone,
    required void Function(String code, String message) onError,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/agent/conversations/$conversationId/messages');
    final req = http.Request('POST', uri)
      ..headers.addAll(_headers())
      ..body = jsonEncode({
        'content': content,
        'web_search': webSearch,
        if (attachments.isNotEmpty) 'attachments': attachments.map((e) => e.toJson()).toList(),
      });

    http.StreamedResponse streamed;
    try {
      streamed = await client.send(req).timeout(firstByteTimeout);
    } catch (e) {
      if (isCancelled()) return;
      onError('stream_error', e.toString());
      return;
    }
    if (streamed.statusCode == 402) {
      final body = await streamed.stream.bytesToString();
      final (code, message) = _parseErrorBody(body);
      onError(code, message);
      return;
    }
    if (streamed.statusCode != 200) {
      final body = await streamed.stream.bytesToString();
      final (code, message) = _parseErrorBody(body);
      onError(code.isNotEmpty ? code : 'http_${streamed.statusCode}', message.isNotEmpty ? message : '请求失败');
      return;
    }

    var eventName = '';
    final buffer = SseEventBuffer();
    final completer = Completer<void>();
    StreamSubscription<List<int>>? sub;
    Timer? timer;

    void abortNow() {
      timer?.cancel();
      if (!completer.isCompleted) completer.complete();
      sub?.cancel();
    }

    abortRegistration.bind(abortNow);

    timer = Timer(totalTimeout, () {
      if (!completer.isCompleted) {
        abortNow();
        if (!isCancelled()) onError('timeout', '回复超时，请重试');
      }
    });

    sub = streamed.stream.timeout(
      const Duration(seconds: 120),
      onTimeout: (sink) {
        sink.close();
        if (!completer.isCompleted) {
          onError('timeout', '流中断，请重试');
          completer.complete();
        }
      },
    ).listen(
      (chunk) {
        buffer.add(utf8.decode(chunk, allowMalformed: true), (name, data) {
          eventName = name;
          if (name == 'delta') {
            final map = jsonDecode(data) as Map<String, dynamic>;
            final text = map['content'] as String? ?? '';
            if (text.isNotEmpty) onDelta(text);
          } else if (name == 'tool') {
            final map = jsonDecode(data) as Map<String, dynamic>;
            onTool?.call(AgentToolEvent.fromJson(map));
          } else if (name == 'done') {
            final map = jsonDecode(data) as Map<String, dynamic>;
            onDone(AgentStreamDone.fromJson(map));
            if (!completer.isCompleted) completer.complete();
          } else if (name == 'error') {
            final map = jsonDecode(data) as Map<String, dynamic>;
            onError(
              map['code'] as String? ?? 'error',
              map['message'] as String? ?? '生成失败',
            );
            if (!completer.isCompleted) completer.complete();
          }
        });
      },
      onDone: () {
        timer?.cancel();
        if (!completer.isCompleted) {
          if (!isCancelled() && eventName != 'done' && eventName != 'error') {
            onError('incomplete', '连接已关闭');
          }
          completer.complete();
        }
      },
      onError: (e) {
        timer?.cancel();
        if (!completer.isCompleted) {
          if (!isCancelled()) {
            onError('stream_error', e.toString());
          }
          completer.complete();
        }
      },
      cancelOnError: true,
    );

    try {
      await completer.future;
    } finally {
      timer?.cancel();
      await sub?.cancel();
    }
  }

  static (String, String) _parseErrorBody(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final code = decoded['code'];
      final message = decoded['message'] as String? ?? '';
      if (code is int) return ('$code', message);
      if (code is String) return (code, message);
      return ('', message);
    } catch (_) {
      return ('', body);
    }
  }
}
