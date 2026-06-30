import 'package:flutter/material.dart';
import '../api/chat_api.dart';
import '../api/file_preview_api.dart';
import '../config/api_config.dart';
import '../models/chat_attachment.dart';
import '../screens/agent_in_app_browser_screen.dart';
import '../screens/document_preview_screen.dart';
import '../screens/office_file_open_screen.dart';
import '../theme/mirror_theme.dart';
import '../utils/external_url.dart';
import '../utils/media_url.dart';
import '../utils/office_file.dart';
import '../widgets/mirror_pressable.dart';

Map<String, String>? _imageAuthHeaders(String src) {
  if (ApiConfig.accessToken.isEmpty) return null;
  if (!src.contains('/api/v1/')) return null;
  return {'Authorization': 'Bearer ${ApiConfig.accessToken}'};
}

/// 全屏预览聊天图片。
Future<void> openChatImagePreview(
  BuildContext context, {
  required String url,
  String? title,
}) async {
  final resolved = resolveMediaUrl(url);
  if (resolved.isEmpty) {
    _toast(context, '无法预览图片');
    return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _ChatImagePreviewScreen(url: resolved, title: title),
    ),
  );
}

Future<void> _openFileGuide(
  BuildContext context, {
  required String filename,
  required String downloadUrl,
  String? openUrl,
}) {
  final dl = downloadUrl.trim();
  if (dl.isEmpty) {
    _toast(context, '无法打开附件');
    return Future.value();
  }
  return openOfficeFileGuide(
    context,
    filename: filename,
    downloadUrl: fileDownloadUrl(dl),
    openUrl: openUrl?.trim().isNotEmpty == true ? openUrl!.trim() : dl,
  );
}

/// 打开文档附件预览或外链。
Future<void> openChatAttachmentPreview(BuildContext context, ChatAttachment attachment) async {
  final title = _attachmentDisplayName(attachment);
  final objectKey = _attachmentObjectKey(attachment);
  if (objectKey != null && objectKey.isNotEmpty) {
    final preview = await FilePreviewApi.fetchChatAttachmentPreview(
      objectKey: objectKey,
      filename: title,
    );
    if (!context.mounted) return;
    if (preview != null && preview.hasInlinePreview) {
      await openDocumentPreviewScreen(context, preview: preview);
      return;
    }

    final access = await ChatApi.presignAttachmentAccess(
      objectKey: objectKey,
      filename: title,
    );
    if (!context.mounted) return;
    if (access != null) {
      final download = access.url.trim();
      if (download.isEmpty) {
        _toast(context, '无法打开附件');
        return;
      }
      if (access.kind == 'image') {
        await openChatImagePreview(context, url: download, title: title);
        return;
      }
      if (shouldUseFileOpenGuide(filename: title, kind: access.kind)) {
        await _openFileGuide(
          context,
          filename: title,
          downloadUrl: download,
          openUrl: _attachmentInlineUrl(access, download),
        );
        return;
      }
      final preview = access.previewUrl?.trim() ?? '';
      if (preview.isNotEmpty) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => AgentInAppBrowserScreen(
              url: preview,
              title: title,
            ),
          ),
        );
        return;
      }
      await _openFileGuide(
        context,
        filename: title,
        downloadUrl: download,
        openUrl: download,
      );
      return;
    }
  }
  final url = resolveMediaUrl(attachment.url);
  if (url.isEmpty) {
    if (context.mounted) _toast(context, '无法打开附件');
    return;
  }
  if (shouldUseFileOpenGuide(filename: title)) {
    if (!context.mounted) return;
    await _openFileGuide(
      context,
      filename: title,
      downloadUrl: url,
      openUrl: url,
    );
    return;
  }
  final ok = await openExternalUrl(url);
  if (!ok && context.mounted) {
    _toast(context, '无法打开附件');
  }
}

/// 使用上传返回的地址直接预览文件（不走 presign）。
Future<void> openUploadedFilePreview(
  BuildContext context, {
  required String url,
  String? title,
}) async {
  final loadUrl = resolveMediaUrl(url);
  if (loadUrl.isEmpty) {
    _toast(context, '无法打开文件');
    return;
  }
  final name = title?.trim().isNotEmpty == true ? title! : filenameFromUrl(loadUrl);
  if (shouldUseFileOpenGuide(filename: name)) {
    await _openFileGuide(
      context,
      filename: name,
      downloadUrl: loadUrl,
      openUrl: loadUrl,
    );
    return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => AgentInAppBrowserScreen(
        url: loadUrl,
        title: title,
      ),
    ),
  );
}

/// 附件 inline 打开地址（优先 COS 预览链，不用需鉴权的 open_path）。
String _attachmentInlineUrl(AttachmentAccessResult access, String download) {
  final preview = access.previewUrl?.trim() ?? '';
  if (preview.isNotEmpty) return preview;
  return download;
}

void _toast(BuildContext context, String message) {
  if (!context.mounted || message.isEmpty) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

String? _attachmentObjectKey(ChatAttachment a) {
  final key = a.objectKey?.trim() ?? '';
  if (key.isNotEmpty) return key;
  final url = a.url.trim();
  if (url.startsWith('public/feed/')) return url;
  if (url.contains('public/feed/')) {
    final i = url.indexOf('public/feed/');
    return url.substring(i);
  }
  final resolved = resolveMediaUrl(url);
  if (resolved.contains('public/feed/')) {
    final uri = Uri.tryParse(resolved);
    final path = uri?.path ?? '';
    if (path.contains('public/feed/')) {
      final i = path.indexOf('public/feed/');
      return path.substring(i).replaceFirst(RegExp(r'^/'), '');
    }
  }
  return null;
}

String _attachmentDisplayName(ChatAttachment a) {
  final fn = a.filename?.trim() ?? '';
  if (fn.isNotEmpty) return fn;
  final url = a.url.trim();
  if (url.isEmpty) return '附件';
  return Uri.tryParse(url)?.pathSegments.lastOrNull ?? url.split('/').last;
}

class _ChatImagePreviewScreen extends StatelessWidget {
  const _ChatImagePreviewScreen({required this.url, this.title});

  final String url;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final label = title?.trim();
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 12, 10),
              color: Colors.black,
              child: Row(
                children: [
                  MirrorPressable(
                    onTap: () => Navigator.of(context).pop(),
                    padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                    borderRadius: BorderRadius.circular(8),
                    child: const Icon(Icons.chevron_left, size: 22, color: Colors.white70),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label?.isNotEmpty == true ? label! : '图片预览',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MirrorTheme.sans(fontSize: 14, weight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    headers: _imageAuthHeaders(url),
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                      );
                    },
                    errorBuilder: (_, __, ___) => Text(
                      '图片加载失败',
                      style: MirrorTheme.sans(fontSize: 13, color: Colors.white54),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
