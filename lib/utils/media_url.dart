import 'package:flutter/foundation.dart';

import '../config/api_config.dart';

/// 将正文/封面中的相对路径转为可加载的完整 URL。
String resolveMediaUrl(String url) {
  final u = url.trim();
  if (u.isEmpty) return u;
  String resolved;
  if (u.startsWith('http://') || u.startsWith('https://') || u.startsWith('blob:')) {
    resolved = u;
  } else if (u.startsWith('//')) {
    resolved = 'http:$u';
  } else if (u.startsWith('public/')) {
    final base = ApiConfig.publicMediaBase.endsWith('/')
        ? ApiConfig.publicMediaBase.substring(0, ApiConfig.publicMediaBase.length - 1)
        : ApiConfig.publicMediaBase;
    resolved = '$base/$u';
  } else if (u.startsWith('legacy/feed/')) {
    final name = u.substring('legacy/feed/'.length);
    final base = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
    resolved = '$base/static/feed/$name';
  } else {
    final base = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
    resolved = u.startsWith('/') ? '$base$u' : '$base/$u';
  }
  return _alignWebApiHost(resolved);
}

/// Web 端统一用 API_BASE 的 host（与 run_web_dev 的 127.0.0.1 一致），避免 localhost/127.0.0.1 混用。
String _alignWebApiHost(String url) {
  if (!kIsWeb) return url;
  final uri = Uri.tryParse(url);
  final api = Uri.tryParse(ApiConfig.baseUrl);
  if (uri == null || api == null || !uri.hasScheme || !api.hasScheme) return url;
  if (uri.port != api.port) return url;
  final isLoopback = uri.host == 'localhost' || uri.host == '127.0.0.1';
  if (isLoopback && uri.host != api.host) {
    return uri.replace(host: api.host).toString();
  }
  return url;
}

/// 合并正文 cover_gallery 与 cover_image_url，按解析后的 URL 去重（保留 gallery 顺序）。
List<String> dedupeCoverUrls(List<String> gallery, [String apiCover = '']) {
  final seen = <String>{};
  final out = <String>[];
  void tryAdd(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    final key = resolveMediaUrl(trimmed);
    if (key.isEmpty || !seen.add(key)) return;
    out.add(trimmed);
  }
  for (final url in gallery) {
    tryAdd(url);
  }
  tryAdd(apiCover);
  return out;
}
