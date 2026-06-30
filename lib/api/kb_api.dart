import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../api/api_client.dart';
import '../api/api_result.dart';
import '../config/api_config.dart';
import '../models/chat_attachment.dart';
import '../models/kb_chat_models.dart';
import '../models/kb_models.dart';
import '../models/media_upload_result.dart';
import '../utils/media_url.dart';

class KbFileUrl {
  const KbFileUrl({required this.url, required this.filename, this.isDirectBytes = false, this.bytes});

  final String url;
  final String filename;
  final bool isDirectBytes;
  final List<int>? bytes;
}

class KbApi {
  static Future<KbUploadLimits> fetchUploadLimits() async {
    final data = await ApiClient.get('/api/v1/kb/upload-limits');
    if (data == null) return KbUploadLimits.defaults;
    return KbUploadLimits.fromJson(data);
  }

  static Future<KbMineList?> listMine() async {
    final data = await ApiClient.get('/api/v1/kb/mine');
    if (data == null) return null;
    return KbMineList.fromJson(data);
  }

  static Future<List<KbSubscribedItem>> listSubscribed() async {
    final data = await ApiClient.getList('/api/v1/kb/subscribed');
    if (data == null) return [];
    return data.map((e) => KbSubscribedItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String _searchQuery({String q = '', int limit = 20, String? cursor}) {
    final parts = <String>[];
    final trimmed = q.trim();
    if (trimmed.isNotEmpty) {
      parts.add('q=${Uri.encodeQueryComponent(trimmed)}');
    }
    parts.add('limit=$limit');
    final c = cursor?.trim() ?? '';
    if (c.isNotEmpty) {
      parts.add('cursor=${Uri.encodeQueryComponent(c)}');
    }
    return parts.join('&');
  }

  static Future<KbPaginatedMineResponse?> searchMine({String q = '', int limit = 20, String? cursor}) async {
    final data = await ApiClient.get('/api/v1/kb/mine/search?${_searchQuery(q: q, limit: limit, cursor: cursor)}');
    if (data == null) return null;
    return KbPaginatedMineResponse.fromJson(data);
  }

  static Future<KbPaginatedSubscribedResponse?> searchSubscribed({String q = '', int limit = 20, String? cursor}) async {
    final data = await ApiClient.get('/api/v1/kb/subscribed/search?${_searchQuery(q: q, limit: limit, cursor: cursor)}');
    if (data == null) return null;
    return KbPaginatedSubscribedResponse.fromJson(data);
  }

  static Future<KbPaginatedExploreResponse?> searchExplore({String q = '', int limit = 20, String? cursor}) async {
    final base = q.trim().isEmpty ? '/api/v1/kb/explore' : '/api/v1/kb/search';
    final data = await ApiClient.get('$base?${_searchQuery(q: q, limit: limit, cursor: cursor)}');
    if (data == null) return null;
    return KbPaginatedExploreResponse.fromJson(data);
  }

  @Deprecated('Use searchExplore')
  static Future<List<KbExploreItem>> explore({String q = ''}) async {
    final page = await searchExplore(q: q);
    return page?.items ?? [];
  }

  /// 上传知识库封面，成功返回 object_key（存库）与 url（预览）。
  static Future<MediaUploadResult?> uploadCover(List<int> bytes, String filename) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/kb/uploads/cover');
    try {
      final req = http.MultipartRequest('POST', uri);
      if (ApiConfig.accessToken.isNotEmpty) {
        req.headers['Authorization'] = 'Bearer ${ApiConfig.accessToken}';
      }
      req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode != 200) {
        if (kDebugMode) debugPrint('[KbApi] cover upload ${res.statusCode} ${res.body}');
        return null;
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['code'] != 0) return null;
      final data = body['data'] as Map<String, dynamic>?;
      if (data == null) return null;
      final result = MediaUploadResult.fromJson(data);
      if (result.objectKey.isEmpty) return null;
      final preview = result.url.startsWith('http')
          ? result.url
          : resolveMediaUrl(result.url);
      return MediaUploadResult(objectKey: result.objectKey, url: preview, storage: result.storage);
    } catch (e) {
      if (kDebugMode) debugPrint('[KbApi] cover upload failed: $e');
      return null;
    }
  }

  static Future<KbListItem?> createKb(String name, {String description = '', String coverUrl = ''}) async {
    final body = <String, dynamic>{'name': name, 'description': description};
    if (coverUrl.isNotEmpty) body['cover_url'] = coverUrl;
    final data = await ApiClient.post('/api/v1/kb', body);
    if (data == null) return null;
    return KbListItem.fromJson(data);
  }

  static Future<KbListItem?> patchKb(int kbId, {required String name, String? coverUrl}) async {
    final body = <String, dynamic>{'name': name};
    if (coverUrl != null) body['cover_url'] = coverUrl;
    final r = await ApiClient.patchResult('/api/v1/kb/$kbId', body);
    if (!r.ok || r.data == null) return null;
    return KbListItem.fromJson(r.data!);
  }

  static Future<bool> deleteKb(int kbId) async {
    final data = await ApiClient.delete('/api/v1/kb/$kbId');
    return data != null;
  }

  static Future<KbDetail?> getDetail(int kbId) async {
    final data = await ApiClient.get('/api/v1/kb/$kbId');
    if (data == null) return null;
    return KbDetail.fromJson(data);
  }

  static Future<KbDocSyncSnapshot?> getDocumentSyncStatus(int kbId) async {
    final data = await ApiClient.get('/api/v1/kb/$kbId/documents/sync/status');
    if (data == null) return null;
    return KbDocSyncSnapshot.fromJson(data);
  }

  static Future<KbFolderItem?> createFolder(int kbId, String name) async {
    final data = await ApiClient.post('/api/v1/kb/$kbId/folders', {'name': name});
    if (data == null) return null;
    return KbFolderItem.fromJson(data);
  }

  static Future<ApiResult<void>> subscribe(int kbId) async {
    final r = await ApiClient.postResult('/api/v1/kb/$kbId/subscribe', {});
    return ApiResult(code: r.code, message: r.message);
  }

  static Future<ApiResult<void>> cancelSubscription(int subId) async {
    final r = await ApiClient.deleteResult('/api/v1/kb/subscriptions/$subId');
    return ApiResult(code: r.code, message: r.message);
  }

  static Future<ApiResult<void>> deleteDocument(int kbId, int docId) async {
    final r = await ApiClient.deleteResult('/api/v1/kb/$kbId/documents/$docId');
    return ApiResult(code: r.code, message: r.message);
  }

  /// 通过 URL 将网页导入知识库（POST .../documents/import-web，202）。
  static Future<ApiResult<void>> importWebDocument(
    int kbId,
    String url, {
    String? name,
    int? folderId,
  }) async {
    final body = <String, dynamic>{'url': url};
    if (name != null && name.isNotEmpty) body['name'] = name;
    if (folderId != null && folderId > 0) body['folder_id'] = folderId;
    final r = await ApiClient.postResult('/api/v1/kb/$kbId/documents/import-web', body);
    return ApiResult(code: r.code, message: r.message);
  }

  static Future<ApiResult<KbUploadResult>> uploadDocument(
    int kbId,
    List<int> bytes,
    String filename, {
    int? folderId,
    void Function(double progress)? onProgress,
  }) async {
    if (onProgress != null) {
      return _uploadDocumentWithProgress(kbId, bytes, filename, folderId: folderId, onProgress: onProgress);
    }
    final path = '/api/v1/kb/$kbId/documents';
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    try {
      final req = http.MultipartRequest('POST', uri);
      if (ApiConfig.accessToken.isNotEmpty) {
        req.headers['Authorization'] = 'Bearer ${ApiConfig.accessToken}';
      }
      if (folderId != null && folderId > 0) {
        req.fields['folder_id'] = '$folderId';
      }
      req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
      final resp = await req.send().timeout(const Duration(minutes: 5));
      final body = await resp.stream.bytesToString();
      if (resp.statusCode != 200 && resp.statusCode != 202) {
        if (kDebugMode) {
          debugPrint('[Mirror API] POST $path -> ${resp.statusCode} body=$body');
        }
        return ApiResult(code: -1, message: '上传失败（HTTP ${resp.statusCode}）');
      }
      final j = jsonDecode(body) as Map<String, dynamic>;
      final code = j['code'] as int? ?? -1;
      final message = j['message'] as String? ?? '';
      if (code != 0) {
        if (kDebugMode) {
          debugPrint('[Mirror API] POST $path biz code=$code msg=$message');
        }
        return ApiResult(code: code, message: message.isNotEmpty ? message : '上传失败');
      }
      final data = j['data'];
      if (data is! Map<String, dynamic>) {
        return ApiResult(code: -1, message: '上传响应格式错误');
      }
      return ApiResult(code: 0, message: message, data: KbUploadResult.fromJson(data));
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[Mirror API] POST $path failed: $e');
        debugPrint('$st');
      }
      return ApiResult(code: -1, message: '无法连接服务器');
    }
  }

  static Future<ApiResult<KbUploadResult>> _uploadDocumentWithProgress(
    int kbId,
    List<int> bytes,
    String filename, {
    int? folderId,
    required void Function(double progress) onProgress,
  }) async {
    final path = '/api/v1/kb/$kbId/documents';
    try {
      final headers = <String, String>{};
      if (ApiConfig.accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${ApiConfig.accessToken}';
      }
      final form = FormData.fromMap({
        if (folderId != null && folderId > 0) 'folder_id': '$folderId',
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final dio = Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(minutes: 5),
        sendTimeout: const Duration(minutes: 5),
        headers: headers,
      ));
      onProgress(0);
      final resp = await dio.post<Map<String, dynamic>>(
        path,
        data: form,
        onSendProgress: (sent, total) {
          if (total > 0) onProgress((sent / total).clamp(0.0, 1.0));
        },
      );
      final status = resp.statusCode ?? 0;
      if (status != 200 && status != 202) {
        return ApiResult(code: -1, message: '上传失败（HTTP $status）');
      }
      final j = resp.data;
      if (j == null) return ApiResult(code: -1, message: '上传响应格式错误');
      final code = j['code'] as int? ?? -1;
      final message = j['message'] as String? ?? '';
      if (code != 0) {
        return ApiResult(code: code, message: message.isNotEmpty ? message : '上传失败');
      }
      final data = j['data'];
      if (data is! Map<String, dynamic>) {
        return ApiResult(code: -1, message: '上传响应格式错误');
      }
      onProgress(1);
      return ApiResult(code: 0, message: message, data: KbUploadResult.fromJson(data));
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[Mirror API] POST $path failed: $e');
        debugPrint('$st');
      }
      return ApiResult(code: -1, message: '无法连接服务器');
    }
  }

  static Future<String?> previewText(int kbId, int docId) async {
    final data = await ApiClient.get('/api/v1/kb/$kbId/documents/$docId/preview');
    if (data == null) return null;
    return data['content'] as String?;
  }

  static Future<List<KbChatConversation>> listChatConversations({
    required List<int> kbIds,
    String scopeType = 'personal',
    int limit = 50,
  }) async {
    final kbParam = kbIds.map((e) => '$e').join(',');
    final r = await ApiClient.getResult(
      '/api/v1/kb/chat/conversations?scope_type=$scopeType&limit=$limit&kb_ids=$kbParam',
    );
    if (!r.ok || r.data == null) return [];
    final raw = r.data!['items'] as List<dynamic>? ?? [];
    return raw.map((e) => KbChatConversation.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<int?> createChatConversation({
    required List<int> kbIds,
    String scopeType = 'personal',
  }) async {
    final data = await ApiClient.post('/api/v1/kb/chat/conversations', {
      'kb_ids': kbIds,
      'scope_type': scopeType,
    });
    if (data == null) return null;
    return (data['conversation_id'] as num?)?.toInt();
  }

  static Future<List<KbMessage>> listChatMessages(int conversationId, {int limit = 50}) async {
    final data = await ApiClient.get('/api/v1/kb/chat/conversations/$conversationId/messages?limit=$limit');
    final raw = data?['items'] as List<dynamic>? ?? [];
    return raw
        .map((e) {
          final j = e as Map<String, dynamic>;
          final sourcesRaw = j['sources'] as List<dynamic>? ?? [];
          final sources = sourcesRaw.map((s) => KbMessageSource.fromJson(s as Map<String, dynamic>)).toList();
          final attRaw = j['attachments'] as List<dynamic>? ?? [];
          final attachments = attRaw
              .map((e) => ChatAttachment.fromJson(e as Map<String, dynamic>))
              .toList();
          return KbMessage(
            role: j['role'] as String? ?? '',
            content: j['content'] as String? ?? '',
            sources: sources,
            attachments: attachments,
          );
        })
        .where((m) => m.content.trim().isNotEmpty || m.attachments.isNotEmpty)
        .toList();
  }

  /// 获取源文件：COS 返回预签名 URL；本地存储返回带鉴权的字节流。
  static Future<KbFileUrl?> getFile(int kbId, int docId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/kb/$kbId/documents/$docId/file');
    final headers = <String, String>{};
    if (ApiConfig.accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${ApiConfig.accessToken}';
    }
    final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 60));
    final ct = resp.headers['content-type'] ?? '';
    if (ct.contains('application/json')) {
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      if (j['code'] != 0) return null;
      final data = j['data'] as Map<String, dynamic>;
      return KbFileUrl(
        url: data['url'] as String? ?? '',
        filename: data['filename'] as String? ?? '',
      );
    }
    return KbFileUrl(
      url: uri.toString(),
      filename: 'document',
      isDirectBytes: true,
      bytes: resp.bodyBytes,
    );
  }
}
