import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/chat_attachment.dart';
import '../models/kb_chat_models.dart';
import 'chat_stream_handle.dart';

/// 知识库问答 SSE（delta / sources / empty / done / error）。
class KbSseClient {
  KbSseClient._();

  static const Duration _firstByteTimeout = Duration(seconds: 60);
  static const Duration _totalTimeout = Duration(minutes: 5);

  /// 发起流式问答；返回 [ChatStreamHandle] 用于停止生成。
  static ChatStreamHandle chatStream({
    required String question,
    required List<int> kbIds,
    List<ChatAttachment> attachments = const [],
    String scopeType = 'personal',
    int conversationId = 0,
    required void Function(String delta) onDelta,
    void Function(List<KbMessageSource> sources)? onSources,
    void Function(String message)? onEmpty,
    required void Function() onDone,
    void Function(int conversationId)? onConversationId,
    required void Function(String message) onError,
  }) {
    final client = http.Client();
    final cancelled = StreamCancelFlag();
    final abortRegistration = StreamAbortRegistration();
    final done = _runChatStream(
      client: client,
      isCancelled: cancelled.isSet,
      abortRegistration: abortRegistration,
      question: question,
      kbIds: kbIds,
      attachments: attachments,
      scopeType: scopeType,
      conversationId: conversationId,
      onDelta: onDelta,
      onSources: onSources,
      onEmpty: onEmpty,
      onDone: onDone,
      onConversationId: onConversationId,
      onError: onError,
    );
    return ChatStreamHandle(client, done, cancelled, abortRegistration);
  }

  static Future<void> _runChatStream({
    required http.Client client,
    required bool Function() isCancelled,
    required StreamAbortRegistration abortRegistration,
    required String question,
    required List<int> kbIds,
    List<ChatAttachment> attachments = const [],
    String scopeType = 'personal',
    int conversationId = 0,
    required void Function(String delta) onDelta,
    void Function(List<KbMessageSource> sources)? onSources,
    void Function(String message)? onEmpty,
    required void Function() onDone,
    void Function(int conversationId)? onConversationId,
    required void Function(String message) onError,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/kb/chat/stream');
    final req = http.Request('POST', uri)
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        if (ApiConfig.accessToken.isNotEmpty) 'Authorization': 'Bearer ${ApiConfig.accessToken}',
      })
      ..body = jsonEncode({
        'question': question,
        'kb_ids': kbIds,
        'scope_type': scopeType,
        if (conversationId > 0) 'conversation_id': conversationId,
        if (attachments.isNotEmpty) 'attachments': attachments.map((e) => e.toJson()).toList(),
      });

    http.StreamedResponse streamed;
    try {
      streamed = await client.send(req).timeout(_firstByteTimeout);
    } catch (e) {
      if (isCancelled()) return;
      onError(e.toString());
      return;
    }
    if (streamed.statusCode != 200) {
      final body = await streamed.stream.bytesToString();
      onError(body.isNotEmpty ? body : 'HTTP ${streamed.statusCode}');
      return;
    }

    var buf = '';
    StreamSubscription<String>? sub;
    final done = Completer<void>();

    void abortNow() {
      if (!done.isCompleted) done.complete();
      sub?.cancel();
    }

    abortRegistration.bind(abortNow);

    sub = streamed.stream.timeout(_totalTimeout).transform(utf8.decoder).listen(
      (chunk) {
        buf += chunk;
        while (true) {
          final idx = buf.indexOf('\n\n');
          if (idx < 0) break;
          final block = buf.substring(0, idx);
          buf = buf.substring(idx + 2);
          _handleBlock(block, onDelta, onSources, onEmpty, onDone, onConversationId, onError);
        }
      },
      onError: (e) {
        if (!done.isCompleted) {
          if (!isCancelled()) onError(e.toString());
          done.complete();
        }
      },
      onDone: () {
        if (buf.trim().isNotEmpty) {
          _handleBlock(buf, onDelta, onSources, onEmpty, onDone, onConversationId, onError);
        }
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );
    try {
      await done.future;
    } finally {
      await sub.cancel();
    }
  }

  static void _handleBlock(
    String block,
    void Function(String) onDelta,
    void Function(List<KbMessageSource> sources)? onSources,
    void Function(String message)? onEmpty,
    void Function() onDone,
    void Function(int conversationId)? onConversationId,
    void Function(String) onError,
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
    final dataStr = dataLines.join('\n');
    if (event == 'delta') {
      try {
        final m = jsonDecode(dataStr) as Map<String, dynamic>;
        final c = m['content'] as String? ?? '';
        if (c.isNotEmpty) onDelta(c);
      } catch (_) {
        if (dataStr.isNotEmpty) onDelta(dataStr);
      }
    } else if (event == 'sources') {
      try {
        final m = jsonDecode(dataStr) as Map<String, dynamic>;
        final raw = m['items'] as List<dynamic>? ?? [];
        final items = raw.map((e) => KbMessageSource.fromJson(e as Map<String, dynamic>)).toList();
        onSources?.call(items);
      } catch (_) {}
    } else if (event == 'empty') {
      try {
        final m = jsonDecode(dataStr) as Map<String, dynamic>;
        final msg = m['message'] as String? ?? '';
        if (msg.isNotEmpty) onEmpty?.call(msg);
      } catch (_) {
        if (dataStr.isNotEmpty) onEmpty?.call(dataStr);
      }
    } else if (event == 'done') {
      try {
        final m = jsonDecode(dataStr) as Map<String, dynamic>;
        final id = (m['conversation_id'] as num?)?.toInt() ?? 0;
        if (id > 0) onConversationId?.call(id);
      } catch (_) {}
      onDone();
    } else if (event == 'error') {
      try {
        final m = jsonDecode(dataStr) as Map<String, dynamic>;
        final code = m['code'] as String? ?? '';
        final msg = m['message'] as String? ?? dataStr;
        if (code == 'use_kb_import') {
          onError('请先在知识库中导入 PDF/Word 文档后再提问');
        } else {
          onError(msg);
        }
      } catch (_) {
        onError(dataStr);
      }
    }
  }
}
