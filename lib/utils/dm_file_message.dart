import '../models/chat_models.dart';
import 'dm_share_message.dart';

/// 私信文件消息（`type=file`，`body` 为文件名，`media_url` 为上传地址）。
class DmFileMessage {
  const DmFileMessage({required this.filename, required this.url});

  final String filename;
  final String url;
}

/// 解析 `📎 name\nurl` 格式的旧版文件消息；非文件消息返回 null。
DmFileMessage? parseDmFileMessage(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return null;
  final lines = trimmed.split('\n');
  if (lines.length < 2) return null;
  final first = lines.first.trim();
  if (!first.startsWith('📎')) return null;
  final name = first.replaceFirst('📎', '').trim();
  if (name.isEmpty) return null;
  final url = lines[1].trim();
  if (url.isEmpty) return null;
  return DmFileMessage(filename: name, url: url);
}

/// 从消息中提取文件信息：优先 `media_url`，兼容旧版 body 格式。
DmFileMessage? fileMessageFromChat(ChatMessage message) {
  final legacy = parseDmFileMessage(message.body);
  if (legacy != null) return legacy;

  final url = message.mediaUrl?.trim() ?? '';
  if (url.isEmpty) return null;

  final name = message.body.trim();
  final filename = name.isNotEmpty ? name : _filenameFromUrl(url);

  // 真正的图片消息不走文件气泡
  if (message.isImage && _looksLikeImage(filename, url)) {
    return null;
  }

  // 后端仅支持 text/image：非图片文件以 image 类型发送，body 存文件名
  if (message.isImage || message.isText) {
    return DmFileMessage(filename: filename, url: url);
  }

  return null;
}

/// 会话列表预览文案。
String dmMessagePreview(ChatMessage message) {
  final user = userShareFromChat(message);
  if (user != null) return userSharePreview(user);
  final share = feedPostShareFromChat(message);
  if (share != null) return feedPostSharePreview(share);
  final article = feedPostSharePreviewFromText(message.body);
  if (article != null) return article;
  final file = fileMessageFromChat(message);
  if (file != null) return file.filename;
  if (message.isImage) return '[图片]';
  return message.body;
}

const _imagePreviewTag = '[图片]';

/// 从 `last_message` 结构化字段生成列表预览（优先于服务端拼好的字符串）。
String? conversationPreviewFromLastMessage(Map<String, dynamic>? last) {
  if (last == null || last.isEmpty) return null;
  final type = (last['type'] ?? '').toString();
  final body = (last['body'] ?? '').toString();
  final mediaUrl = (last['media_url'] ?? last['url'])?.toString();
  if (type.isEmpty && body.isEmpty && (mediaUrl == null || mediaUrl.isEmpty)) {
    return null;
  }
  return dmMessagePreview(
    ChatMessage(
      id: 0,
      conversationId: 0,
      senderId: 0,
      type: type.isNotEmpty ? type : 'text',
      body: body,
      mediaUrl: mediaUrl,
    ),
  );
}

/// 修正接口返回的 `[图片] 文件名`：非图片附件只展示文件名。
String sanitizeConversationPreview(String preview) {
  final trimmed = preview.trim();
  if (!trimmed.startsWith(_imagePreviewTag)) return preview;

  final remainder = trimmed.substring(_imagePreviewTag.length).trimLeft();
  if (remainder.isEmpty) return _imagePreviewTag;
  if (_looksLikeImage(remainder, '')) return preview;
  return remainder;
}

/// 合并结构化 last_message 与接口 preview 字符串。
String resolveConversationPreview({
  Map<String, dynamic>? lastMessage,
  required String apiPreview,
}) {
  final fromLast = conversationPreviewFromLastMessage(lastMessage);
  if (fromLast != null && fromLast.isNotEmpty) {
    return normalizeConversationPreview(fromLast);
  }
  return normalizeConversationPreview(apiPreview);
}

/// 统一修正会话列表 preview（文章卡片、文件、[图片] 等）。
String normalizeConversationPreview(String preview) {
  final profile = userSharePreviewFromText(preview);
  if (profile != null) return profile;
  final article = feedPostSharePreviewFromText(preview);
  if (article != null) return article;
  return sanitizeConversationPreview(preview);
}

bool _looksLikeImage(String filename, String url) {
  for (final value in [filename, _filenameFromUrl(url), url]) {
    final lower = value.toLowerCase();
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.heic')) {
      return true;
    }
  }
  return false;
}

String _filenameFromUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return '附件';
  final path = Uri.tryParse(trimmed)?.pathSegments.lastOrNull ?? '';
  if (path.isNotEmpty) return path;
  return trimmed.split('/').where((s) => s.isNotEmpty).lastOrNull ?? '附件';
}
