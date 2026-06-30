import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/kb_models.dart';

/// 知识库文档解析状态 SSE（snapshot / update / done / error）。
class KbDocSyncClient {
  KbDocSyncClient._();

  static final http.Client _client = http.Client();

  static Map<String, String> _headers() => {
        'Accept': 'text/event-stream',
        if (ApiConfig.accessToken.isNotEmpty) 'Authorization': 'Bearer ${ApiConfig.accessToken}',
      };

  /// 订阅文档解析状态流；连接关闭或收到 done 后结束。
  static Future<void> stream({
    required int kbId,
    required void Function(KbDocSyncSnapshot snapshot) onSnapshot,
    required void Function(KbDocSyncUpdate update) onUpdate,
    required void Function(int readyDocCount) onDone,
    required void Function(String message) onError,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/kb/$kbId/documents/sync/stream');
    final req = http.Request('GET', uri)..headers.addAll(_headers());

    final streamed = await _client.send(req).timeout(const Duration(seconds: 30));
    if (streamed.statusCode != 200) {
      final body = await streamed.stream.bytesToString();
      onError(body.isNotEmpty ? body : 'HTTP ${streamed.statusCode}');
      return;
    }

    var buf = '';
    var done = false;
    await for (final chunk in streamed.stream.transform(utf8.decoder)) {
      buf += chunk;
      while (true) {
        final idx = buf.indexOf('\n\n');
        if (idx < 0) break;
        final block = buf.substring(0, idx);
        buf = buf.substring(idx + 2);
        final result = _handleBlock(block, onSnapshot, onUpdate, onDone, onError);
        if (result == _BlockResult.done) {
          done = true;
          break;
        }
        if (result == _BlockResult.error) return;
      }
      if (done) break;
    }
  }

  static _BlockResult _handleBlock(
    String block,
    void Function(KbDocSyncSnapshot) onSnapshot,
    void Function(KbDocSyncUpdate) onUpdate,
    void Function(int) onDone,
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
    if (dataStr.isEmpty) return _BlockResult.continue_;

    switch (event) {
      case 'snapshot':
        try {
          onSnapshot(KbDocSyncSnapshot.fromJson(jsonDecode(dataStr) as Map<String, dynamic>));
        } catch (e) {
          onError('snapshot parse error: $e');
          return _BlockResult.error;
        }
      case 'update':
        try {
          onUpdate(KbDocSyncUpdate.fromJson(jsonDecode(dataStr) as Map<String, dynamic>));
        } catch (e) {
          onError('update parse error: $e');
          return _BlockResult.error;
        }
      case 'done':
        var ready = 0;
        try {
          final m = jsonDecode(dataStr) as Map<String, dynamic>;
          ready = m['ready_doc_count'] as int? ?? 0;
        } catch (_) {}
        onDone(ready);
        return _BlockResult.done;
      case 'error':
        try {
          final m = jsonDecode(dataStr) as Map<String, dynamic>;
          onError(m['message'] as String? ?? dataStr);
        } catch (_) {
          onError(dataStr);
        }
        return _BlockResult.error;
      case 'ping':
        break;
    }
    return _BlockResult.continue_;
  }
}

enum _BlockResult { continue_, done, error }
