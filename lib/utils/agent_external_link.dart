import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api/agent_api.dart';
import '../api/file_preview_api.dart';
import '../config/api_config.dart';
import '../screens/agent_in_app_browser_screen.dart';
import '../screens/document_preview_screen.dart';
import '../screens/office_file_open_screen.dart';
import '../utils/media_url.dart';
import '../utils/office_file.dart';
import '../utils/safe_uri.dart';

/// 解析 Hermes grant 或 Mirror API 链接并打开。
Future<bool> openMirrorFileLink(BuildContext context, String rawUrl, {String? title}) async {
  final url = rawUrl.trim();
  if (url.isEmpty) return false;
  var loadUrl = resolveMediaUrl(url);
  Map<String, String>? headers;

  final grantId = safeParseHermesGrantId(loadUrl);
  Map<String, String>? signQuery;
  if (grantId != null) {
    loadUrl = hermesFilePreviewUrl(loadUrl);
    final signed = await AgentApi.signHermesFileAccess(grantId);
    if (signed != null && signed.url.isNotEmpty) {
      loadUrl = resolveMediaUrl(signed.url);
      if (kIsWeb) {
        loadUrl = hermesFilePreviewUrl(loadUrl);
      }
    } else if (!kIsWeb && ApiConfig.accessToken.isNotEmpty) {
      headers = {'Authorization': 'Bearer ${ApiConfig.accessToken}'};
    }
    signQuery = hermesSignQueryFromUrl(loadUrl);
    final preview = await FilePreviewApi.fetchHermesPreview(
      grantId: grantId,
      signQuery: signQuery,
    );
    if (!context.mounted) return false;
    if (preview != null && preview.hasInlinePreview) {
      return openDocumentPreviewScreen(context, preview: preview, headers: headers);
    }
  }

  if (!context.mounted) return false;

  final displayName = title?.trim().isNotEmpty == true ? title! : filenameFromUrl(loadUrl);
  if (shouldUseFileOpenGuide(filename: displayName)) {
    await openOfficeFileGuide(
      context,
      filename: displayName,
      downloadUrl: fileDownloadUrl(loadUrl),
      openUrl: loadUrl,
    );
    return true;
  }

  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => AgentInAppBrowserScreen(
        url: loadUrl,
        title: title,
        headers: headers,
      ),
    ),
  );
  return true;
}

bool isMirrorManagedFileUrl(String? url) {
  final u = url?.trim() ?? '';
  return u.contains('/agent/hermes-files/') || u.contains('/chat/attachments/');
}

bool isRawHermesFileUrl(String? url) {
  final u = url?.trim() ?? '';
  if (!u.contains('/v1/files/')) return false;
  final uri = tryParseUri(u);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}

/// Hermes 文件在应用内默认走 inline 预览；下载由预览页内的链接触发。
String hermesFilePreviewUrl(String url) => safeRemoveDownloadQuery(url);

/// 在应用内打开 Agent 引用来源或 Markdown 外链（仅 http/https）。
Future<bool> openAgentExternalLink(
  BuildContext context,
  String? url, {
  void Function(String message)? onFailure,
}) async {
  final raw = url?.trim() ?? '';
  if (raw.isEmpty) {
    onFailure?.call('链接不可用');
    return false;
  }
  final uri = tryParseUri(raw);
  final check = uri != null && (uri.scheme == 'http' || uri.scheme == 'https' || raw.startsWith('/'));
  if (!check) {
    onFailure?.call('链接不可用');
    return false;
  }
  if (isRawHermesFileUrl(raw)) {
    onFailure?.call('文件链接尚未就绪，请等待回复完成后重试');
    return false;
  }
  if (isMirrorManagedFileUrl(raw) || raw.startsWith('/api/v1/agent/hermes-files')) {
    final ok = await openMirrorFileLink(context, raw, title: agentSourceHostLabel(raw));
    if (!ok) onFailure?.call('无法打开文件');
    return ok;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => AgentInAppBrowserScreen(
        url: resolveMediaUrl(raw),
        title: agentSourceHostLabel(raw),
      ),
    ),
  );
  return true;
}

String agentSourceHostLabel(String? url) {
  final raw = url?.trim() ?? '';
  if (raw.isEmpty) return '';
  if (raw.contains('hermes-files')) {
    final name = safeFilenameFromUrl(raw);
    if (name != '附件') return name;
  }
  final uri = tryParseUri(raw);
  if (uri == null || uri.host.isEmpty) return raw;
  return uri.host;
}
