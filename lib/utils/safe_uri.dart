/// 安全解析 URI，避免非法 `%` 编码导致 Flutter 红屏（Hermes 文件名常含 `%`、括号等）。
library;

/// 将 lone `%` 或非法 `%X` 转为 `%25`，便于 [Uri.parse] / [Uri.decodeComponent]。
String sanitizePercentEncoding(String input) {
  if (!input.contains('%')) return input;
  final buf = StringBuffer();
  var i = 0;
  while (i < input.length) {
    if (input[i] != '%') {
      buf.write(input[i]);
      i++;
      continue;
    }
    if (i + 2 < input.length) {
      final h1 = input[i + 1];
      final h2 = input[i + 2];
      final ok = _isHex(h1) && _isHex(h2);
      if (ok) {
        buf.write('%$h1$h2');
        i += 3;
        continue;
      }
    }
    buf.write('%25');
    i++;
  }
  return buf.toString();
}

bool _isHex(String c) {
  final code = c.codeUnitAt(0);
  return (code >= 0x30 && code <= 0x39) ||
      (code >= 0x41 && code <= 0x46) ||
      (code >= 0x61 && code <= 0x66);
}

Uri? tryParseUri(String url) {
  final raw = url.trim();
  if (raw.isEmpty) return null;
  final normalized = raw.startsWith('/') ? 'http://local${sanitizePercentEncoding(raw)}' : sanitizePercentEncoding(raw);
  try {
    return Uri.parse(normalized);
  } catch (_) {
    return null;
  }
}

String safeDecodeUriComponent(String value) {
  try {
    return Uri.decodeComponent(sanitizePercentEncoding(value));
  } catch (_) {
    return value;
  }
}

/// 从 URL 路径末段提取展示用文件名（不抛异常）。
String safeFilenameFromUrl(String url) {
  final uri = tryParseUri(url);
  if (uri == null) return '附件';
  try {
    final segments = uri.pathSegments;
    if (segments.isEmpty) return '附件';
    final last = segments.last;
    if (last.isEmpty) return '附件';
    return safeDecodeUriComponent(last);
  } catch (_) {
    final path = uri.path;
    if (path.isEmpty) return '附件';
    final last = path.split('/').where((s) => s.isNotEmpty).lastOrNull ?? '';
    return last.isEmpty ? '附件' : safeDecodeUriComponent(last);
  }
}

/// 追加 `download=1` 查询参数（非法编码时 fallback 字符串拼接）。
String safeFileDownloadUrl(String url) {
  final raw = url.trim();
  if (raw.isEmpty) return raw;
  final uri = tryParseUri(raw);
  if (uri == null) {
    if (raw.contains('download=1')) return raw;
    return raw.contains('?') ? '$raw&download=1' : '$raw?download=1';
  }
  try {
    final q = Map<String, String>.from(uri.queryParameters);
    q['download'] = '1';
    return uri.replace(queryParameters: q).toString();
  } catch (_) {
    if (raw.contains('download=1')) return raw;
    return raw.contains('?') ? '$raw&download=1' : '$raw?download=1';
  }
}

/// 去掉 `download=1`，用于 inline 打开。
String safeRemoveDownloadQuery(String url) {
  final raw = url.trim();
  if (raw.isEmpty) return raw;
  final uri = tryParseUri(raw);
  if (uri == null) return raw;
  try {
    final q = Map<String, String>.from(uri.queryParameters)..remove('download');
    return uri.replace(queryParameters: q.isEmpty ? null : q).toString();
  } catch (_) {
    return raw.replaceAll(RegExp(r'([?&])download=1&?'), r'$1').replaceAll(RegExp(r'\?&'), '?').replaceAll(RegExp(r'\?$'), '');
  }
}

/// 解析 `/api/v1/agent/hermes-files/:id/...` 中的 grant id。
int? safeParseHermesGrantId(String url) {
  final uri = tryParseUri(url);
  if (uri != null) {
    try {
      final segments = uri.pathSegments;
      final i = segments.indexOf('hermes-files');
      if (i >= 0 && i + 1 < segments.length) {
        return int.tryParse(segments[i + 1]);
      }
    } catch (_) {}
  }
  final m = RegExp(r'/agent/hermes-files/(\d+)').firstMatch(url);
  return m != null ? int.tryParse(m.group(1)!) : null;
}

/// 从已签名 Hermes URL 提取 st/exp 供 preview API 复用。
Map<String, String>? hermesSignQueryFromUrl(String url) {
  final uri = tryParseUri(url);
  if (uri == null) return null;
  final st = uri.queryParameters['st']?.trim() ?? '';
  if (st.isEmpty) return null;
  final exp = uri.queryParameters['exp']?.trim() ?? '';
  return {
    'st': st,
    if (exp.isNotEmpty) 'exp': exp,
  };
}
