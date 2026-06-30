import 'dart:convert';

import '../models/chat_models.dart';

/// 私信内分享的生态文章卡片（以 text 消息 + 结构化 body 存储）。
class DmFeedPostShare {
  const DmFeedPostShare({
    required this.postId,
    required this.title,
    this.authorName = '',
    this.coverImageUrl,
    this.quote,
    this.shareUrl,
  });

  final int postId;
  final String title;
  final String authorName;
  final String? coverImageUrl;
  final String? quote;
  final String? shareUrl;

  Map<String, dynamic> toJson() => {
        'post_id': postId,
        'title': title,
        if (authorName.isNotEmpty) 'author_name': authorName,
        if (coverImageUrl != null && coverImageUrl!.isNotEmpty) 'cover_image_url': coverImageUrl,
        if (quote != null && quote!.isNotEmpty) 'quote': quote,
        if (shareUrl != null && shareUrl!.isNotEmpty) 'share_url': shareUrl,
      };

  factory DmFeedPostShare.fromJson(Map<String, dynamic> j) => DmFeedPostShare(
        postId: _jsonInt(j['post_id']),
        title: (j['title'] ?? '').toString(),
        authorName: (j['author_name'] ?? '').toString(),
        coverImageUrl: (j['cover_image_url'] ?? '').toString().trim().isEmpty
            ? null
            : (j['cover_image_url'] ?? '').toString(),
        quote: (j['quote'] ?? '').toString().trim().isEmpty ? null : (j['quote'] ?? '').toString(),
        shareUrl: (j['share_url'] ?? '').toString().trim().isEmpty ? null : (j['share_url'] ?? '').toString(),
      );
}

const kFeedPostSharePrefix = '[[mirror:feed_post]]';

String encodeFeedPostShare(DmFeedPostShare share) => '$kFeedPostSharePrefix${jsonEncode(share.toJson())}';

DmFeedPostShare? parseFeedPostShareBody(String body) {
  final trimmed = body.trim();
  if (!trimmed.startsWith(kFeedPostSharePrefix)) return null;
  final raw = trimmed.substring(kFeedPostSharePrefix.length).trim();
  if (raw.isEmpty) return null;
  try {
    final j = jsonDecode(raw);
    if (j is! Map<String, dynamic>) return null;
    final share = DmFeedPostShare.fromJson(j);
    if (share.postId <= 0 || share.title.isEmpty) return null;
    return share;
  } catch (_) {
    return null;
  }
}

DmFeedPostShare? feedPostShareFromChat(ChatMessage message) {
  if (!message.isText) return null;
  return parseFeedPostShareBody(message.body);
}

String feedPostSharePreview(DmFeedPostShare share) {
  final title = share.title.trim();
  if (title.isEmpty) return '[文章]';
  return '[文章] $title';
}

String feedPostSharePreviewFromChat(ChatMessage message) {
  final share = feedPostShareFromChat(message);
  if (share == null) return message.body;
  return feedPostSharePreview(share);
}

/// 会话列表等场景的原始 preview：完整或截断的 feed_post body。
String? feedPostSharePreviewFromText(String text) {
  final trimmed = text.trim();
  if (!trimmed.startsWith(kFeedPostSharePrefix)) return null;

  final share = parseFeedPostShareBody(trimmed);
  if (share != null) return feedPostSharePreview(share);

  final title = _feedPostTitleFromPartialJson(trimmed.substring(kFeedPostSharePrefix.length));
  if (title != null && title.isNotEmpty) return feedPostSharePreview(DmFeedPostShare(postId: 1, title: title));
  return '[文章]';
}

String? _feedPostTitleFromPartialJson(String raw) {
  // 接口 preview 常被截断，title 可能没有闭合引号
  final match = RegExp(r'"title"\s*:\s*"((?:\\.|[^"\\])*)"?').firstMatch(raw);
  if (match == null) return null;
  return _cleanFeedPostTitle(_unescapeJsonString(match.group(1) ?? ''));
}

String _cleanFeedPostTitle(String title) {
  return title.replaceAll(RegExp(r'\s*\.\.\.\s*$'), '').trim();
}

String _unescapeJsonString(String value) {
  return value
      .replaceAll(r'\"', '"')
      .replaceAll(r'\\', r'\')
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\r', '\r')
      .replaceAll(r'\t', '\t');
}

int _jsonInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? fallback;
}

/// 私信内分享的博主主页卡片（text + 结构化 body）。
class DmUserShare {
  const DmUserShare({
    required this.userId,
    required this.displayName,
    this.handle = '',
    this.avatarLetter = '',
    this.avatarUrl = '',
    this.avatarVariant = 'accent',
    this.tagline = '',
    this.bio = '',
  });

  final int userId;
  final String displayName;
  final String handle;
  final String avatarLetter;
  final String avatarUrl;
  /// 与 feed `avatar_variant` 一致：accent / green / pink / blue / amber
  final String avatarVariant;
  final String tagline;
  final String bio;

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'display_name': displayName,
        if (handle.isNotEmpty) 'handle': handle,
        if (avatarLetter.isNotEmpty) 'avatar_letter': avatarLetter,
        if (avatarUrl.isNotEmpty) 'avatar_url': avatarUrl,
        if (avatarVariant.isNotEmpty) 'avatar_variant': avatarVariant,
        if (tagline.isNotEmpty) 'tagline': tagline,
        if (bio.isNotEmpty) 'bio': bio,
      };

  factory DmUserShare.fromJson(Map<String, dynamic> j) => DmUserShare(
        userId: _jsonInt(j['user_id']),
        displayName: (j['display_name'] ?? '').toString(),
        handle: (j['handle'] ?? '').toString(),
        avatarLetter: (j['avatar_letter'] ?? '').toString(),
        avatarUrl: (j['avatar_url'] ?? '').toString(),
        avatarVariant: (j['avatar_variant'] ?? 'accent').toString(),
        tagline: (j['tagline'] ?? '').toString(),
        bio: (j['bio'] ?? '').toString(),
      );
}

const kUserSharePrefix = '[[mirror:user]]';

String encodeUserShare(DmUserShare share) => '$kUserSharePrefix${jsonEncode(share.toJson())}';

DmUserShare? parseUserShareBody(String body) {
  final trimmed = body.trim();
  if (!trimmed.startsWith(kUserSharePrefix)) return null;
  final raw = trimmed.substring(kUserSharePrefix.length).trim();
  if (raw.isEmpty) return null;
  try {
    final j = jsonDecode(raw);
    if (j is! Map<String, dynamic>) return null;
    final share = DmUserShare.fromJson(j);
    if (share.userId <= 0 || share.displayName.isEmpty) return null;
    return share;
  } catch (_) {
    return null;
  }
}

DmUserShare? userShareFromChat(ChatMessage message) {
  if (!message.isText) return null;
  return parseUserShareBody(message.body);
}

String userSharePreview(DmUserShare share) {
  final name = share.displayName.trim();
  if (name.isEmpty) return '[主页]';
  return '[主页] $name';
}

String userSharePreviewFromChat(ChatMessage message) {
  final share = userShareFromChat(message);
  if (share == null) return message.body;
  return userSharePreview(share);
}

String? userSharePreviewFromText(String text) {
  final trimmed = text.trim();
  if (!trimmed.startsWith(kUserSharePrefix)) return null;

  final share = parseUserShareBody(trimmed);
  if (share != null) return userSharePreview(share);

  final name = _userDisplayNameFromPartialJson(trimmed.substring(kUserSharePrefix.length));
  if (name != null && name.isNotEmpty) {
    return userSharePreview(DmUserShare(userId: 1, displayName: name));
  }
  return '[主页]';
}

String? _userDisplayNameFromPartialJson(String raw) {
  final match = RegExp(r'"display_name"\s*:\s*"((?:\\.|[^"\\])*)"?').firstMatch(raw);
  if (match == null) return null;
  return _cleanFeedPostTitle(_unescapeJsonString(match.group(1) ?? ''));
}
