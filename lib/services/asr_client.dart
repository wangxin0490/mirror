import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'sse_event_buffer.dart';

class AsrStatus {
  const AsrStatus({
    required this.enabled,
    required this.model,
    required this.segmentIntervalSeconds,
    required this.maxSegmentSeconds,
  });

  final bool enabled;
  final String model;
  final int segmentIntervalSeconds;
  final int maxSegmentSeconds;

  factory AsrStatus.fromJson(Map<String, dynamic> j) => AsrStatus(
        enabled: j['enabled'] == true,
        model: j['model'] as String? ?? 'glm-asr',
        segmentIntervalSeconds: j['segment_interval_seconds'] as int? ?? 3,
        maxSegmentSeconds: j['max_segment_seconds'] as int? ?? 28,
      );

  static const disabled = AsrStatus(
    enabled: false,
    model: 'glm-asr',
    segmentIntervalSeconds: 3,
    maxSegmentSeconds: 28,
  );
}

/// ASR 客户端：BFF → new-api 流式转写（SSE 事件格式与 Agent 聊天一致）。
class AsrClient {
  AsrClient._();

  static AsrStatus _cached = AsrStatus.disabled;

  static AsrStatus get cachedStatus => _cached;

  static const Duration _firstByteTimeout = Duration(seconds: 60);
  static const Duration _totalTimeout = Duration(minutes: 2);

  static Map<String, String> _headers({bool multipart = false}) {
    final h = <String, String>{
      'Accept': 'text/event-stream',
    };
    if (!multipart) {
      h['Content-Type'] = 'application/json';
    }
    if (ApiConfig.accessToken.isNotEmpty) {
      h['Authorization'] = 'Bearer ${ApiConfig.accessToken}';
    }
    return h;
  }

  static Future<AsrStatus> fetchStatus({bool refresh = false}) async {
    if (!refresh && _cached.enabled) return _cached;
    if (!ApiConfig.isLoggedIn) return AsrStatus.disabled;
    try {
      final res = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/v1/asr/status'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return AsrStatus.disabled;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['code'] != 0) return AsrStatus.disabled;
      final data = body['data'] as Map<String, dynamic>? ?? {};
      _cached = AsrStatus.fromJson(data);
      return _cached;
    } catch (_) {
      return AsrStatus.disabled;
    }
  }

  static String? _lastError;

  /// 最近一次转写失败原因（供 UI 提示）。
  static String? get lastError => _lastError;

  /// 按住说话转写：消费 SSE delta/done/error，与 Agent 流式一致。
  static Future<String?> transcribe(
    List<int> wavBytes, {
    String filename = 'voice.wav',
    void Function(String delta)? onDelta,
  }) async {
    _lastError = null;
    if (wavBytes.isEmpty) return null;
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/asr/transcribe?stream=true');
    final req = http.MultipartRequest('POST', uri)
      ..headers.addAll(_headers(multipart: true))
      ..files.add(http.MultipartFile.fromBytes('file', wavBytes, filename: filename));

    http.StreamedResponse streamed;
    try {
      streamed = await req.send().timeout(_firstByteTimeout);
    } catch (e) {
      _lastError = e.toString();
      return null;
    }
    if (streamed.statusCode != 200) {
      final body = await streamed.stream.bytesToString();
      _lastError = _parseHttpError(streamed.statusCode, body);
      return null;
    }

    final completer = Completer<String?>();
    final buffer = SseEventBuffer();
    final textBuffer = StringBuffer();
    var finished = false;
    Timer? timer;

    timer = Timer(_totalTimeout, () {
      if (finished) return;
      finished = true;
      if (!completer.isCompleted) {
        completer.complete(textBuffer.toString().trim().isEmpty ? null : textBuffer.toString().trim());
      }
    });

    streamed.stream.transform(utf8.decoder).listen(
      (chunk) {
        buffer.add(chunk, (event, data) {
          Map<String, dynamic>? parsed;
          try {
            parsed = jsonDecode(data) as Map<String, dynamic>;
          } catch (_) {
            return;
          }
          if (event == 'delta') {
            final d = parsed['content'] as String? ?? parsed['delta'] as String? ?? '';
            if (d.isEmpty) return;
            textBuffer.write(d);
            onDelta?.call(d);
          } else if (event == 'done') {
            finished = true;
            timer?.cancel();
            final t = parsed['text'] as String? ?? textBuffer.toString();
            if (!completer.isCompleted) completer.complete(t.trim().isEmpty ? null : t.trim());
          } else if (event == 'error') {
            finished = true;
            timer?.cancel();
            _lastError = parsed['message'] as String? ?? '语音转写失败';
            if (!completer.isCompleted) completer.complete(null);
          }
        });
      },
      onDone: () {
        timer?.cancel();
        if (!completer.isCompleted) {
          final out = textBuffer.toString().trim();
          completer.complete(out.isEmpty ? null : out);
        }
      },
      onError: (_) {
        timer?.cancel();
        _lastError ??= '语音转写连接中断';
        if (!completer.isCompleted) completer.complete(null);
      },
    );

    return completer.future;
  }

  static String _parseHttpError(int status, String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final msg = decoded['message'] as String? ?? '';
      if (msg.isNotEmpty) return msg;
    } catch (_) {}
    if (body.contains('无可用渠道')) {
      return '语音识别模型未配置可用渠道，请在 new-api 为 glm-asr 添加 distributor';
    }
    return '语音转写失败（HTTP $status）';
  }

  static Future<String?> createSession() async {
    final res = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/api/v1/asr/sessions'),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['code'] != 0) return null;
    return (body['data'] as Map<String, dynamic>?)?['session_id'] as String?;
  }

  static Future<void> deleteSession(String sessionId) async {
    try {
      await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/asr/sessions/$sessionId'),
        headers: _headers(),
      );
    } catch (_) {}
  }

  static Future<String?> uploadSegmentStream({
    required String sessionId,
    required int index,
    required List<int> wavBytes,
    required void Function(String delta) onDelta,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/asr/sessions/$sessionId/segments');
    final req = http.MultipartRequest('POST', uri)
      ..headers.addAll(_headers(multipart: true))
      ..fields['index'] = '$index'
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        wavBytes,
        filename: 'segment_$index.wav',
      ));
    http.StreamedResponse streamed;
    try {
      streamed = await req.send().timeout(_firstByteTimeout);
    } catch (_) {
      return null;
    }
    if (streamed.statusCode != 200) return null;

    final completer = Completer<String?>();
    final buffer = SseEventBuffer();
    final textBuffer = StringBuffer();

    streamed.stream.transform(utf8.decoder).listen(
      (chunk) {
        buffer.add(chunk, (event, data) {
          Map<String, dynamic>? parsed;
          try {
            parsed = jsonDecode(data) as Map<String, dynamic>;
          } catch (_) {
            return;
          }
          if (event == 'delta') {
            final d = parsed['content'] as String? ?? parsed['delta'] as String? ?? '';
            if (d.isEmpty) return;
            textBuffer.write(d);
            onDelta(d);
          } else if (event == 'segment') {
            if (!completer.isCompleted) {
              completer.complete(parsed['segment_text'] as String? ?? textBuffer.toString());
            }
          } else if (event == 'error') {
            if (!completer.isCompleted) completer.complete(null);
          }
        });
      },
      onDone: () {
        if (!completer.isCompleted) {
          final out = textBuffer.toString().trim();
          completer.complete(out.isEmpty ? null : out);
        }
      },
      onError: (_) {
        if (!completer.isCompleted) completer.complete(null);
      },
    );

    return completer.future;
  }
}
