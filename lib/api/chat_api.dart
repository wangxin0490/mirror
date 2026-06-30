import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../api/api_client.dart';
import '../api/api_result.dart';
import '../config/api_config.dart';
import '../models/chat_models.dart';
import '../utils/dm_share_message.dart';
/// 对话 / 私信接口。
class ChatApi {
  static String _encodeQuery(Map<String, String> query) => query.entries
      .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
      .join('&');
  /// [tab]：`all` | `unread` | `contacts`（与对话 Tab 筛选一致）。
  /// 成功返回列表（可为空）；失败返回 null。
  static Future<ChatConversationListResponse?> fetchConversations({
    String tab = 'all',
    int limit = 50,
    String? q,
  }) async {
    final query = <String, String>{
      'tab': tab,
      'limit': '$limit',
    };
    final trimmed = q?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      query['q'] = trimmed;
    }
    final data = await ApiClient.get('/api/v1/chat/conversations?${_encodeQuery(query)}');
    if (data == null) return null;
    return ChatConversationListResponse.fromJson(data);
  }

  /// 拉取会话历史消息（时间正序：旧 → 新）。
  static Future<ChatMessageListResponse?> fetchMessages(
    int conversationId, {
    int limit = 50,
    int? beforeId,
  }) async {
    if (conversationId <= 0) return null;
    final query = <String, String>{'limit': '$limit'};
    if (beforeId != null && beforeId > 0) {
      query['before_id'] = '$beforeId';
    }
    final data = await ApiClient.get('/api/v1/chat/conversations/$conversationId/messages?${_encodeQuery(query)}');
    if (data == null) return null;
    return ChatMessageListResponse.fromJson(data);
  }

  /// 将会话标为已读。
  static Future<bool> markConversationRead(int conversationId) async {
    if (conversationId <= 0) return false;
    final data = await ApiClient.post('/api/v1/chat/conversations/$conversationId/read', {});
    return data != null;
  }

  /// 删除与对方的私信会话（DELETE /api/v1/chat/conversations/{id}）。
  static Future<ApiResult<void>> deleteConversation(int conversationId) async {
    if (conversationId <= 0) {
      return ApiResult(code: -1, message: '无效会话');
    }
    final r = await ApiClient.deleteResult('/api/v1/chat/conversations/$conversationId');
    return ApiResult(code: r.code, message: r.message);
  }

  /// 发送文本、图片或文件消息。优先使用 [conversationId]，否则走 peer 路径自动建会话。
  static Future<ApiResult<ChatMessage>> sendMessage({
    int? conversationId,
    int? peerUserId,
    required String type,
    String body = '',
    String? mediaUrl,
  }) async {
    final payload = <String, dynamic>{
      'type': type,
      if (body.isNotEmpty) 'body': body,
      if (mediaUrl != null && mediaUrl.isNotEmpty) 'media_url': mediaUrl,
    };

    final String path;
    if (conversationId != null && conversationId > 0) {
      path = '/api/v1/chat/conversations/$conversationId/messages';
    } else if (peerUserId != null && peerUserId > 0) {
      path = '/api/v1/chat/peers/$peerUserId/messages';
    } else {
      return ApiResult(code: -1, message: '缺少会话或对方用户');
    }

    final r = await ApiClient.postResult(path, payload);
    if (!r.ok || r.data == null) {
      return ApiResult(code: r.code, message: r.message);
    }
    return ApiResult(code: 0, message: r.message, data: ChatMessage.fromJson(r.data!));
  }

  /// 私信分享生态文章（以结构化 text 消息发送）。
  static Future<ApiResult<ChatMessage>> sendFeedPostShare({
    int? conversationId,
    int? peerUserId,
    required DmFeedPostShare share,
  }) =>
      sendMessage(
        conversationId: conversationId,
        peerUserId: peerUserId,
        type: 'text',
        body: encodeFeedPostShare(share),
      );

  /// 私信分享博主主页（结构化 text 消息）。
  static Future<ApiResult<ChatMessage>> sendUserShare({
    int? conversationId,
    int? peerUserId,
    required DmUserShare share,
  }) =>
      sendMessage(
        conversationId: conversationId,
        peerUserId: peerUserId,
        type: 'text',
        body: encodeUserShare(share),
      );

  /// 上传聊天附件；返回 URL 与 object_key。
  static Future<UploadAttachmentResult?> uploadAttachmentResult(List<int> bytes, String filename) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/feed/uploads');
    try {
      final req = http.MultipartRequest('POST', uri);
      if (ApiConfig.accessToken.isNotEmpty) {
        req.headers['Authorization'] = 'Bearer ${ApiConfig.accessToken}';
      }
      req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode != 200) {
        if (kDebugMode) debugPrint('[ChatApi] upload ${res.statusCode} ${res.body}');
        return null;
      }
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      if (decoded['code'] != 0) return null;
      final data = decoded['data'] as Map<String, dynamic>?;
      if (data == null) return null;
      final objectKey = data['object_key'] as String? ?? '';
      var path = data['url'] as String? ?? '';
      if (path.isEmpty && objectKey.isNotEmpty) path = objectKey;
      if (path.isEmpty) return null;
      if (!path.startsWith('http://') && !path.startsWith('https://')) {
        path = path.startsWith('/') ? path : '/$path';
      }
      return UploadAttachmentResult(url: path, objectKey: objectKey.isNotEmpty ? objectKey : null);
    } catch (e) {
      if (kDebugMode) debugPrint('[ChatApi] upload failed: $e');
      return null;
    }
  }

  /// 上传聊天附件（兼容旧调用，仅返回 URL）。
  static Future<String?> uploadAttachment(List<int> bytes, String filename) async {
    final r = await uploadAttachmentResult(bytes, filename);
    return r?.url;
  }

  /// 获取附件 COS 预签名访问 URL。
  static Future<AttachmentAccessResult?> presignAttachmentAccess({
    required String objectKey,
    String? filename,
  }) async {
    final q = <String, String>{'object_key': objectKey};
    final fn = filename?.trim() ?? '';
    if (fn.isNotEmpty) q['filename'] = fn;
    final query = q.entries
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final data = await ApiClient.get('/api/v1/chat/attachments/access?$query');
    if (data == null) return null;
    return AttachmentAccessResult.fromJson(data);
  }
}

class UploadAttachmentResult {
  const UploadAttachmentResult({required this.url, this.objectKey});
  final String url;
  final String? objectKey;
}

class AttachmentAccessResult {
  const AttachmentAccessResult({
    required this.url,
    required this.expiresIn,
    required this.kind,
    this.previewUrl,
    this.openPath,
  });
  final String url;
  final String? previewUrl;
  final String? openPath;
  final int expiresIn;
  final String kind;

  factory AttachmentAccessResult.fromJson(Map<String, dynamic> j) => AttachmentAccessResult(
        url: j['url'] as String? ?? '',
        previewUrl: j['preview_url'] as String?,
        openPath: j['open_path'] as String?,
        expiresIn: (j['expires_in'] as num?)?.toInt() ?? 0,
        kind: j['kind'] as String? ?? 'binary',
      );
}
