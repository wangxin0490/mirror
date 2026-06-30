import 'package:flutter/material.dart';

import '../screens/mirror_feed_data.dart';
import '../utils/dm_file_message.dart';
import '../widgets/phone_components.dart';

int _jsonInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? fallback;
}

bool _jsonBool(dynamic v, [bool fallback = false]) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = '$v'.toLowerCase();
  return s == 'true' || s == '1';
}

/// 对话列表项（对齐 GET /api/v1/chat/conversations）。
class ChatConversationItem {
  ChatConversationItem({
    required this.conversationId,
    required this.peerUserId,
    required this.displayName,
    required this.handle,
    required this.avatarLetter,
    this.avatarUrl = '',
    required this.avatarVariant,
    required this.preview,
    required this.timeLabel,
    required this.unread,
    this.atMe = false,
  });

  final int conversationId;
  final int peerUserId;
  final String displayName;
  final String handle;
  final String avatarLetter;
  final String avatarUrl;
  final String avatarVariant;
  final String preview;
  final String timeLabel;
  final bool unread;
  final bool atMe;

  String get threadKey {
    final h = handle.replaceAll('@', '').trim();
    if (h.isNotEmpty) return h;
    if (peerUserId > 0) return 'u$peerUserId';
    if (conversationId > 0) return 'c$conversationId';
    return displayName;
  }

  List<Color> get avatarColors => _colorsForVariant(avatarVariant);

  factory ChatConversationItem.fromJson(Map<String, dynamic> j) {
    final peer = j['peer'] is Map<String, dynamic> ? j['peer'] as Map<String, dynamic> : null;
    final peerUser = j['peer_user'] is Map<String, dynamic> ? j['peer_user'] as Map<String, dynamic> : null;
    final last = j['last_message'] is Map<String, dynamic>
        ? j['last_message'] as Map<String, dynamic>
        : (j['last_msg'] is Map<String, dynamic> ? j['last_msg'] as Map<String, dynamic> : null);

    final userId = _jsonInt(
      j['peer_user_id'] ?? j['user_id'] ?? peer?['user_id'] ?? peerUser?['user_id'],
    );
    final name = (j['display_name'] ?? j['peer_name'] ?? peer?['display_name'] ?? peerUser?['display_name'] ?? '')
        .toString();
    final handle = (j['handle'] ?? peer?['handle'] ?? peerUser?['handle'] ?? '').toString();
    final letter = (j['avatar_letter'] ?? peer?['avatar_letter'] ?? peerUser?['avatar_letter'] ?? '')
        .toString();
    final avatarUrl = (j['avatar_url'] ?? peer?['avatar_url'] ?? peerUser?['avatar_url'] ?? '')
        .toString();
    final variant =
        (j['avatar_variant'] ?? peer?['avatar_variant'] ?? peerUser?['avatar_variant'] ?? 'accent').toString();

    final rawPreview = (j['preview'] ??
            j['last_preview'] ??
            j['message_preview'] ??
            last?['preview'] ??
            last?['text'] ??
            last?['content'] ??
            '')
        .toString();
    final preview = resolveConversationPreview(
      lastMessage: last,
      apiPreview: rawPreview,
    );
    final timeRaw = (j['time_label'] ??
            j['time'] ??
            j['updated_at_label'] ??
            j['last_message_at_label'] ??
            '')
        .toString();
    var time = timeRaw;
    if (time.isEmpty) {
      final lastAt = j['last_at']?.toString();
      if (lastAt != null && lastAt.isNotEmpty) {
        final dt = DateTime.tryParse(lastAt);
        if (dt != null) {
          final diff = DateTime.now().difference(dt.toLocal());
          if (diff.inMinutes < 1) {
            time = '刚刚';
          } else if (diff.inHours < 1) {
            time = '${diff.inMinutes} 分钟前';
          } else if (diff.inHours < 24) {
            time = '${diff.inHours} 小时前';
          }
        }
      }
    }

    final unreadCount = _jsonInt(j['unread_count'] ?? j['unread']);
    final unread = _jsonBool(j['unread'] ?? j['has_unread'], unreadCount > 0) || unreadCount > 0;
    final atMe = _jsonBool(j['at_me'] ?? j['mentioned'] ?? last?['at_me'] ?? last?['mentioned']);

    return ChatConversationItem(
      conversationId: _jsonInt(j['conversation_id'] ?? j['id']),
      peerUserId: userId,
      displayName: name.isNotEmpty ? name : handle,
      handle: handle,
      avatarLetter: letter.isNotEmpty ? letter : (name.isNotEmpty ? name[0] : '?'),
      avatarUrl: avatarUrl,
      avatarVariant: variant,
      preview: preview,
      timeLabel: time,
      unread: unread,
      atMe: atMe,
    );
  }
}

class ChatConversationListResponse {
  ChatConversationListResponse({required this.items, this.tab = 'all'});

  final List<ChatConversationItem> items;
  final String tab;

  factory ChatConversationListResponse.fromJson(Map<String, dynamic> j) {
    final raw = j['items'] as List<dynamic>? ?? [];
    return ChatConversationListResponse(
      tab: j['tab'] as String? ?? 'all',
      items: raw.map((e) => ChatConversationItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

/// 单条私信（GET/POST /api/v1/chat/conversations/{id}/messages）。
class ChatMessage {
  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    this.body = '',
    this.mediaUrl,
    this.createdAt,
    this.isMe = false,
  });

  final int id;
  final int conversationId;
  final int senderId;
  final String type;
  final String body;
  final String? mediaUrl;
  final DateTime? createdAt;
  final bool isMe;

  bool get isText => type == 'text';
  bool get isImage => type == 'image';

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final created = j['created_at']?.toString();
    return ChatMessage(
      id: _jsonInt(j['id']),
      conversationId: _jsonInt(j['conversation_id']),
      senderId: _jsonInt(j['sender_id']),
      type: (j['type'] ?? 'text').toString(),
      body: (j['body'] ?? '').toString(),
      mediaUrl: (j['media_url'] ?? j['url'])?.toString(),
      createdAt: created != null && created.isNotEmpty ? DateTime.tryParse(created) : null,
      isMe: _jsonBool(j['is_me']),
    );
  }
}

class ChatMessageListResponse {
  ChatMessageListResponse({required this.items, this.hasMore = false});

  final List<ChatMessage> items;
  final bool hasMore;

  factory ChatMessageListResponse.fromJson(Map<String, dynamic> j) {
    final raw = j['items'] as List<dynamic>? ?? [];
    return ChatMessageListResponse(
      items: raw.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList(),
      hasMore: _jsonBool(j['has_more']),
    );
  }
}

List<Color> _colorsForVariant(String variant) {
  switch (variant) {
    case 'green':
      return MirrorAvatars.zhou;
    case 'pink':
      return MirrorAvatars.lin;
    case 'blue':
      return MirrorAvatars.a5;
    case 'amber':
      return MirrorAvatars.shen;
    default:
      return MirrorAvatars.chen;
  }
}

FeedAvatarVariant variantEnum(String variant) => switch (variant) {
      'green' => FeedAvatarVariant.green,
      'pink' => FeedAvatarVariant.pink,
      'blue' => FeedAvatarVariant.blue,
      'amber' => FeedAvatarVariant.amber,
      _ => FeedAvatarVariant.accent,
    };
