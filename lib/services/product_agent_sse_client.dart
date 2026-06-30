import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/agent_models.dart';
import '../services/chat_stream_handle.dart';

/// 工具箱智能体 SSE 流式回复。
class ProductAgentSseClient {
  ProductAgentSseClient._();

  static const Duration firstByteTimeout = Duration(seconds: 60);
  static const Duration totalTimeout = Duration(minutes: 5);

  static Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        if (ApiConfig.accessToken.isNotEmpty)
          'Authorization': 'Bearer ${ApiConfig.accessToken}',
      };

  static ChatStreamHandle sendMessage({
    required String agentCode,
    required int conversationId,
    required String content,
    required void Function(String delta) onDelta,
    required void Function(AgentStreamDone done) onDone,
    required void Function(String code, String message) onError,
  }) {
    final client = http.Client();
    final cancelled = StreamCancelFlag();
    final abortRegistration = StreamAbortRegistration();
    final done = _run(
      client: client,
      isCancelled: cancelled.isSet,
      abortRegistration: abortRegistration,
      agentCode: agentCode,
      conversationId: conversationId,
      content: content,
      onDelta: onDelta,
      onDone: onDone,
      onError: onError,
    );
    return ChatStreamHandle(client, done, cancelled, abortRegistration);
  }

  static Future<void> _run({
    required http.Client client,
    required bool Function() isCancelled,
    required StreamAbortRegistration abortRegistration,
    required String agentCode,
    required int conversationId,
    required String content,
    required void Function(String delta) onDelta,
    required void Function(AgentStreamDone done) onDone,
    required void Function(String code, String message) onError,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/v1/me/agents/$agentCode/conversations/$conversationId/messages',
    );
    final req = http.Request('POST', uri)
      ..headers.addAll(_headers())
      ..body = jsonEncode({'content': content, 'web_search': false});

    http.StreamedResponse streamed;
    try {
      streamed = await client.send(req).timeout(firstByteTimeout);
    } catch (e) {
      if (isCancelled()) return;
      onError('network', '$e');
      return;
    }

    if (streamed.statusCode == 501) {
      onError('not_implemented', '该智能体功能即将推出');
      return;
    }
    if (streamed.statusCode != 200) {
      onError('http_${streamed.statusCode}', '请求失败');
      return;
    }

    abortRegistration.bind(() => client.close());
    final deadline = DateTime.now().add(totalTimeout);
    var buffer = '';
    await for (final chunk in streamed.stream.transform(utf8.decoder)) {
      if (isCancelled()) return;
      if (DateTime.now().isAfter(deadline)) {
        onError('timeout', '响应超时');
        return;
      }
      buffer += chunk;
      while (true) {
        final sep = buffer.indexOf('\n\n');
        if (sep < 0) break;
        final block = buffer.substring(0, sep);
        buffer = buffer.substring(sep + 2);
        _parseBlock(block, onDelta, onDone, onError, isCancelled);
        if (isCancelled()) return;
      }
    }
  }

  static void _parseBlock(
    String block,
    void Function(String delta) onDelta,
    void Function(AgentStreamDone done) onDone,
    void Function(String code, String message) onError,
    bool Function() isCancelled,
  ) {
    String? event;
    final dataLines = <String>[];
    for (final line in block.split('\n')) {
      if (line.startsWith('event:')) {
        event = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trim());
      }
    }
    if (event == null || dataLines.isEmpty) return;
    final payload = jsonDecode(dataLines.join('\n'));
    if (payload is! Map<String, dynamic>) return;
    switch (event) {
      case 'delta':
        final text = payload['content'] as String? ?? '';
        if (text.isNotEmpty) onDelta(text);
      case 'done':
        onDone(AgentStreamDone.fromJson(payload));
      case 'error':
        onError(
          payload['code'] as String? ?? 'error',
          payload['message'] as String? ?? 'unknown error',
        );
    }
  }
}
