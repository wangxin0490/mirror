import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/meeting_models.dart';

/// 会议纪要状态 SSE（update / done / ping）。
class MeetingSseClient {
  MeetingSseClient._();

  static final http.Client _client = http.Client();

  static Map<String, String> _headers() => {
        'Accept': 'text/event-stream',
        if (ApiConfig.accessToken.isNotEmpty) 'Authorization': 'Bearer ${ApiConfig.accessToken}',
      };

  /// 订阅用户级会议状态；连接断开时由调用方决定是否重连。
  static Future<void> stream({
    required void Function(MeetingStatusEvent event, String eventName) onEvent,
    required void Function(String message) onError,
    void Function()? onDisconnected,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/meeting-sessions/events');
    final req = http.Request('GET', uri)..headers.addAll(_headers());

    try {
      final streamed = await _client.send(req).timeout(const Duration(seconds: 30));
      if (streamed.statusCode != 200) {
        final body = await streamed.stream.bytesToString();
        onError(body.isNotEmpty ? body : 'HTTP ${streamed.statusCode}');
        onDisconnected?.call();
        return;
      }

      var buf = '';
      await for (final chunk in streamed.stream.transform(utf8.decoder)) {
        buf += chunk;
        while (true) {
          final idx = buf.indexOf('\n\n');
          if (idx < 0) break;
          final block = buf.substring(0, idx);
          buf = buf.substring(idx + 2);
          final err = _handleBlock(block, onEvent);
          if (err != null) {
            onError(err);
            onDisconnected?.call();
            return;
          }
        }
      }
      onDisconnected?.call();
    } catch (e) {
      onError(e.toString());
      onDisconnected?.call();
    }
  }

  static String? _handleBlock(
    String block,
    void Function(MeetingStatusEvent event, String eventName) onEvent,
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
    if (dataStr.isEmpty || event == null || event == 'ping') return null;

    try {
      final m = jsonDecode(dataStr) as Map<String, dynamic>;
      onEvent(MeetingStatusEvent.fromJson(m), event);
    } catch (e) {
      return 'parse error: $e';
    }
    return null;
  }
}
