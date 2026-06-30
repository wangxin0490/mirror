import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../api/api_client.dart';
import '../api/kb_api.dart';
import '../config/api_config.dart';
import '../models/feed_models.dart';
import '../models/media_upload_result.dart';
import '../models/personal_kb.dart';
import '../utils/media_url.dart';

/// 生态圈 API。
class FeedApi {
  /// 成功返回列表（可为空）；接口失败返回 null。
  static Future<List<FeedPostCardDto>?> fetchPosts({String tab = 'recommend', int limit = 30}) async {
    final data = await ApiClient.get('/api/v1/feed/posts?tab=$tab&limit=$limit');
    if (data == null) return null;
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => FeedPostCardDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<FeedPostDetailDto?> fetchPost(int id) async {
    final data = await ApiClient.get('/api/v1/feed/posts/$id');
    if (data == null) return null;
    return FeedPostDetailDto.fromJson(data);
  }

  static Future<List<FeedPostCardDto>> search(String q, {int limit = 20}) async {
    final enc = Uri.encodeQueryComponent(q);
    final data = await ApiClient.get('/api/v1/feed/search?q=$enc&limit=$limit&type=posts');
    if (data == null) return [];
    final items = data['items'] as List<dynamic>? ?? data['posts'] as List<dynamic>? ?? [];
    return items.map((e) => FeedPostCardDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<FeedHotTagDto>> fetchHotTags() async {
    final data = await ApiClient.get('/api/v1/feed/search/hot-tags');
    if (data == null) return [];
    final tags = data['tags'] as List<dynamic>? ?? [];
    return tags.map((e) => FeedHotTagDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<ShareablePersonalKb>> fetchPersonalKbsForShare() async {
    final mine = await KbApi.listMine();
    if (mine == null || mine.items.isEmpty) return [];
    return mine.items
        .map((k) => ShareablePersonalKb(kbId: k.id, name: k.name, readyDocCount: k.readyDocCount))
        .toList();
  }

  static Future<FeedPostCardDto?> createPost({
    required String category,
    required String title,
    required String body,
    String coverStyle = 'h2',
    String coverLabel = '',
    List<String> tags = const [],
    String visibility = 'public',
    String status = 'published',
    String coverImageUrl = '',
    String? sharedKbId,
    String? sharedKbName,
    bool sharePersonalKb = false,
  }) async {
    final r = await createPostResult(
      category: category,
      title: title,
      body: body,
      coverStyle: coverStyle,
      coverLabel: coverLabel,
      tags: tags,
      visibility: visibility,
      status: status,
      coverImageUrl: coverImageUrl,
      sharedKbId: sharedKbId,
      sharedKbName: sharedKbName,
      sharePersonalKb: sharePersonalKb,
    );
    return r.card;
  }

  /// 发帖并返回错误信息（便于 UI 提示）。
  static Future<({FeedPostCardDto? card, String? error})> createPostResult({
    required String category,
    required String title,
    required String body,
    String coverStyle = 'h2',
    String coverLabel = '',
    List<String> tags = const [],
    String visibility = 'public',
    String status = 'published',
    String coverImageUrl = '',
    String? sharedKbId,
    String? sharedKbName,
    bool sharePersonalKb = false,
  }) async {
    final kbId = sharedKbId?.trim();
    final hasKb = sharePersonalKb && kbId != null && kbId.isNotEmpty && kbId != 'draft' && kbId != 'legacy';
    final label = hasKb ? (sharedKbName ?? PersonalKbCatalog.labelFor(kbId) ?? '') : '';
    final resolvedCoverLabel = hasKb
        ? PersonalKbCatalog.coverLabelFor(kbId)
        : (coverLabel.isEmpty ? category.toUpperCase() : coverLabel);
    final res = await ApiClient.postResult('/api/v1/feed/posts', {
      'category': category.toLowerCase(),
      'title': title,
      'body': body,
      'cover_style': coverStyle,
      'cover_label': resolvedCoverLabel,
      'tags': tags,
      'visibility': visibility,
      'status': status,
      if (coverImageUrl.isNotEmpty) 'cover_image_url': coverImageUrl,
      if (hasKb) ...{
        'share_personal_kb': true,
        'shared_kb_id': kbId,
        'shared_kb_name': label,
      },
    });
    if (!res.ok) {
      final msg = res.message.isNotEmpty ? res.message : '发布失败';
      return (card: null, error: msg);
    }
    final data = res.data;
    if (data == null || data.isEmpty) {
      return (card: null, error: '服务器未返回帖子数据');
    }
    try {
      return (card: FeedPostCardDto.fromJson(data), error: null);
    } catch (e) {
      if (kDebugMode) debugPrint('[FeedApi] createPost parse: $e data=$data');
      return (card: null, error: '解析发帖结果失败');
    }
  }

  static Future<String?> toggleLike(int postId, {required bool like}) async {
    final data = like
        ? await ApiClient.post('/api/v1/feed/posts/$postId/like', {})
        : await ApiClient.delete('/api/v1/feed/posts/$postId/like');
    if (data == null) return null;
    return data['likes_label'] as String?;
  }

  static Future<String?> toggleBookmark(int postId, {required bool bookmark}) async {
    final data = bookmark
        ? await ApiClient.post('/api/v1/feed/posts/$postId/bookmark', {})
        : await ApiClient.delete('/api/v1/feed/posts/$postId/bookmark');
    if (data == null) return null;
    return data['bookmarks_label'] as String?;
  }

  static Future<FeedCommentListDto?> fetchComments(int postId, {String sort = 'hot'}) async {
    final data = await ApiClient.get('/api/v1/feed/posts/$postId/comments?sort=$sort&limit=50');
    if (data == null) return null;
    return FeedCommentListDto.fromJson(data);
  }

  static Future<FeedCommentDto?> postComment(
    int postId, {
    required String content,
    int parentId = 0,
    int replyToUserId = 0,
  }) async {
    final body = <String, dynamic>{'content': content};
    if (parentId > 0) body['parent_id'] = parentId;
    if (replyToUserId > 0) body['reply_to_user_id'] = replyToUserId;
    final data = await ApiClient.post('/api/v1/feed/posts/$postId/comments', body);
    if (data == null) return null;
    return FeedCommentDto.fromJson(data);
  }

  static Future<String?> toggleCommentLike(int commentId, {required bool like}) async {
    final data = like
        ? await ApiClient.post('/api/v1/feed/comments/$commentId/like', {})
        : await ApiClient.delete('/api/v1/feed/comments/$commentId/like');
    if (data == null) return null;
    return data['likes_label'] as String?;
  }

  /// 上传图片（multipart），成功返回统一媒体上传结果。
  static Future<MediaUploadResult?> uploadImage(List<int> bytes, String filename) async {
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
        if (kDebugMode) debugPrint('[FeedApi] upload ${res.statusCode} ${res.body}');
        return null;
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['code'] != 0) return null;
      final data = body['data'] as Map<String, dynamic>?;
      if (data == null) return null;
      final result = MediaUploadResult.fromJson(data);
      if (result.objectKey.isEmpty) return null;
      final preview = result.url.startsWith('http') || result.url.startsWith('/')
          ? (result.url.startsWith('http') ? result.url : resolveMediaUrl(result.url))
          : resolveMediaUrl(result.url);
      return MediaUploadResult(objectKey: result.objectKey, url: preview, storage: result.storage);
    } catch (e) {
      if (kDebugMode) debugPrint('[FeedApi] upload failed: $e');
      return null;
    }
  }

  static Future<bool> saveDraft(Map<String, String> fields) async {
    final data = await ApiClient.post('/api/v1/feed/drafts', Map<String, dynamic>.from(fields));
    return data != null;
  }

  static Future<Map<String, String>?> getDraft() async {
    final data = await ApiClient.get('/api/v1/feed/drafts');
    if (data == null) return null;
    return data.map((k, v) => MapEntry(k, '$v'));
  }

  static Future<FeedUserProfileResponse?> fetchUserProfile(int userId) async {
    final data = await ApiClient.get('/api/v1/feed/users/$userId/profile');
    if (data == null) return null;
    return FeedUserProfileResponse.fromJson(data);
  }
}
