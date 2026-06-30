import 'package:flutter/material.dart';

import '../data/mirror_authors.dart';
import '../screens/mirror_feed_data.dart';
import '../theme/mirror_colors.dart';
import '../screens/post_detail_data.dart';
import 'personal_kb.dart';
import 'post_body_envelope.dart';

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

/// 生态圈 API 模型。
class FeedPostCardDto {
  FeedPostCardDto({
    required this.postId,
    required this.coverStyle,
    required this.coverLabel,
    this.coverQuote,
    this.coverIcon,
    required this.title,
    required this.author,
    required this.likesCount,
    required this.likesLabel,
    required this.liked,
    required this.hotLabel,
    this.detailKey,
    this.coverImageUrl,
    this.sharedKbId,
    this.sharedKbLabel,
  });

  final int postId;
  final String coverStyle;
  final String coverLabel;
  final String? coverQuote;
  final String? coverIcon;
  final String title;
  final FeedAuthorDto author;
  final int likesCount;
  final String likesLabel;
  final bool liked;
  final bool hotLabel;
  final String? detailKey;
  final String? coverImageUrl;
  final String? sharedKbId;
  final String? sharedKbLabel;

  factory FeedPostCardDto.fromJson(Map<String, dynamic> j) {
    final coverLabel = j['cover_label'] as String? ?? '';
    final shared = j['shared_kb'] is Map<String, dynamic> ? j['shared_kb'] as Map<String, dynamic> : null;
    var kbId = (shared?['kb_id'] ?? shared?['id'] ?? j['shared_kb_id'])?.toString();
    var kbLabel = (shared?['name'] ?? shared?['label'] ?? j['shared_kb_name'])?.toString();
    kbId ??= PersonalKbCatalog.kbIdFromCoverLabel(coverLabel);
    if (kbId != null && (kbLabel == null || kbLabel.isEmpty)) {
      kbLabel = PersonalKbCatalog.labelFor(kbId);
    }
    return FeedPostCardDto(
        postId: _jsonInt(j['post_id']),
        coverStyle: j['cover_style'] as String? ?? 'h1',
        coverLabel: coverLabel,
        coverQuote: j['cover_quote'] as String?,
        coverIcon: j['cover_icon'] as String?,
        title: j['title'] as String? ?? '',
        author: FeedAuthorDto.fromJson(j['author'] as Map<String, dynamic>? ?? {}),
        likesCount: _jsonInt(j['likes_count']),
        likesLabel: j['likes_label'] as String? ?? '0',
        liked: _jsonBool(j['liked']),
        hotLabel: _jsonBool(j['hot_label']),
        detailKey: j['detail_key'] as String?,
        coverImageUrl: j['cover_image_url'] as String?,
        sharedKbId: kbId,
        sharedKbLabel: kbLabel,
      );
  }

  FeedCardData toFeedCardData() {
    final display = author.displayName.isNotEmpty ? author.displayName : author.subtitle;
    final key = MirrorAuthor.keyFromName(display);
    final kbLabel = sharedKbLabel ?? PersonalKbCatalog.labelFor(sharedKbId) ?? '';
    final hasKb = sharedKbId != null && sharedKbId!.isNotEmpty && kbLabel.isNotEmpty;
    final topicFromCover = coverLabel.isNotEmpty && !coverLabel.startsWith(PersonalKbCatalog.coverLabelPrefix)
        ? coverLabel
        : null;
    return FeedCardData(
      cover: _coverFromStyle(coverStyle),
      label: hotLabel ? '热门' : '',
      quote: coverQuote,
      icon: _iconFromKey(coverIcon),
      title: title,
      av: author.avatarLetter,
      avVariant: _variantFromString(author.avatarVariant),
      authorKey: key,
      authorName: display,
      author: author.handle.isNotEmpty ? '$display · ${author.handle}' : display,
      likes: likesLabel,
      liked: liked,
      hotLabel: hotLabel,
      detailId: _detailIdFromKey(detailKey),
      postId: postId,
      authorUserId: author.userId > 0 ? author.userId : null,
      authorAvatarUrl: author.avatarUrl,
      coverImageUrl: coverImageUrl,
      hasSharedKb: hasKb,
      sharedKbId: sharedKbId,
      sharedKbName: hasKb ? PersonalKbCatalog.listDisplayName(authorName: display, kbLabel: kbLabel) : null,
      topicTag: topicFromCover,
    );
  }
}

class FeedAuthorDto {
  FeedAuthorDto({
    required this.userId,
    required this.avatarLetter,
    required this.avatarVariant,
    required this.displayName,
    required this.handle,
    this.subtitle = '',
    this.avatarUrl = '',
  });

  final int userId;
  final String avatarLetter;
  final String avatarVariant;
  final String avatarUrl;
  final String displayName;
  final String handle;
  final String subtitle;

  factory FeedAuthorDto.fromJson(Map<String, dynamic> j) => FeedAuthorDto(
        userId: _jsonInt(j['user_id']),
        avatarLetter: j['avatar_letter'] as String? ?? '?',
        avatarVariant: j['avatar_variant'] as String? ?? 'accent',
        avatarUrl: j['avatar_url'] as String? ?? '',
        displayName: j['display_name'] as String? ?? '',
        handle: j['handle'] as String? ?? '',
        subtitle: j['subtitle'] as String? ?? '',
      );
}

class FeedPostDetailDto {
  FeedPostDetailDto({
    required this.postId,
    this.detailKey,
    required this.author,
    required this.followed,
    this.coverImageUrl,
    required this.title,
    required this.meta,
    required this.body,
    required this.tags,
    required this.actions,
    this.sharedKb,
    this.parsedBlocks = const [],
    this.markdownTail = '',
  });

  final int postId;
  final String? detailKey;
  final FeedAuthorDto author;
  final bool followed;
  final String? coverImageUrl;
  final String title;
  final String meta;
  final String body;
  final List<String> tags;
  final FeedActionsDto actions;
  final SharedKbAttachment? sharedKb;
  final List<PostBodyBlock> parsedBlocks;
  final String markdownTail;

  factory FeedPostDetailDto.fromJson(Map<String, dynamic> j) {
    final body = j['body'] as String? ?? '';
    final envelope = PostBodyEnvelopeCodec.parse(body);
    final shared = j['shared_kb'] is Map<String, dynamic> ? j['shared_kb'] as Map<String, dynamic> : null;
    SharedKbAttachment? sharedKb = envelope.sharedKb;
    if (shared != null) {
      final id = (shared['kb_id'] ?? shared['id'] ?? '').toString();
      final name = (shared['name'] ?? shared['label'] ?? '').toString();
      if (id.isNotEmpty) {
        final ready = shared['ready_doc_count'];
        final readyDocCount = ready is int ? ready : int.tryParse('$ready') ?? envelope.sharedKb?.readyDocCount ?? 0;
        sharedKb = SharedKbAttachment(
          kbId: id,
          name: name.isNotEmpty ? name : PersonalKbCatalog.labelFor(id) ?? id,
          readyDocCount: readyDocCount > 0 ? readyDocCount : (envelope.sharedKb?.readyDocCount ?? 0),
        );
      }
    }
    return FeedPostDetailDto(
      postId: j['post_id'] as int? ?? 0,
      detailKey: j['detail_key'] as String?,
      author: FeedAuthorDto.fromJson(j['author'] as Map<String, dynamic>? ?? {}),
      followed: j['followed'] as bool? ?? false,
      coverImageUrl: j['cover_image_url'] as String?,
      title: j['title'] as String? ?? '',
      meta: j['meta'] as String? ?? '',
      body: body,
      tags: (j['tags'] as List<dynamic>? ?? []).map((e) => '$e').toList(),
      actions: FeedActionsDto.fromJson(j['actions'] as Map<String, dynamic>? ?? {}),
      sharedKb: sharedKb,
      parsedBlocks: envelope.blocks,
      markdownTail: envelope.markdownTail,
    );
  }
}

class FeedActionsDto {
  FeedActionsDto({
    required this.likesLabel,
    required this.bookmarksLabel,
    required this.commentsLabel,
    required this.liked,
    required this.bookmarked,
  });

  final String likesLabel;
  final String bookmarksLabel;
  final String commentsLabel;
  final bool liked;
  final bool bookmarked;

  factory FeedActionsDto.fromJson(Map<String, dynamic> j) => FeedActionsDto(
        likesLabel: j['likes_label'] as String? ?? '0',
        bookmarksLabel: j['bookmarks_label'] as String? ?? '0',
        commentsLabel: j['comments_label'] as String? ?? '0',
        liked: j['liked'] as bool? ?? false,
        bookmarked: j['bookmarked'] as bool? ?? false,
      );
}

class FeedCommentDto {
  FeedCommentDto({
    required this.commentId,
    required this.author,
    this.roleLabel = '',
    required this.content,
    required this.timeLabel,
    required this.likesLabel,
    required this.liked,
    this.replyToName = '',
    this.replies = const [],
  });

  final int commentId;
  final FeedAuthorDto author;
  final String roleLabel;
  final String content;
  final String timeLabel;
  final String likesLabel;
  final bool liked;
  final String replyToName;
  final List<FeedCommentDto> replies;

  factory FeedCommentDto.fromJson(Map<String, dynamic> j) => FeedCommentDto(
        commentId: j['comment_id'] as int? ?? 0,
        author: FeedAuthorDto.fromJson(j['author'] as Map<String, dynamic>? ?? {}),
        roleLabel: j['role_label'] as String? ?? '',
        content: j['content'] as String? ?? '',
        timeLabel: j['time_label'] as String? ?? '',
        likesLabel: j['likes_label'] as String? ?? '0',
        liked: j['liked'] as bool? ?? false,
        replyToName: j['reply_to_name'] as String? ?? '',
        replies: (j['replies'] as List<dynamic>? ?? [])
            .map((e) => FeedCommentDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class FeedCommentListDto {
  FeedCommentListDto({required this.items, required this.total});

  final List<FeedCommentDto> items;
  final int total;

  factory FeedCommentListDto.fromJson(Map<String, dynamic> j) => FeedCommentListDto(
        items: (j['items'] as List<dynamic>? ?? [])
            .map((e) => FeedCommentDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: j['total'] as int? ?? 0,
      );
}

class FeedHotTagDto {
  FeedHotTagDto({required this.rank, required this.tag, required this.isHot});

  final String rank;
  final String tag;
  final bool isHot;

  factory FeedHotTagDto.fromJson(Map<String, dynamic> j) => FeedHotTagDto(
        rank: j['rank'] as String? ?? '',
        tag: j['tag'] as String? ?? '',
        isHot: j['is_hot'] as bool? ?? false,
      );
}

/// 用户主页资料（`GET /feed/users/:id/profile`）。
class FeedUserProfileDto {
  FeedUserProfileDto({
    required this.userId,
    required this.displayName,
    required this.handle,
    required this.avatarLetter,
    this.avatarUrl = '',
    required this.bio,
    required this.followerCount,
    required this.followingCount,
    required this.postCount,
    required this.likesReceived,
    required this.likesReceivedLabel,
    required this.followState,
    this.roleBadge = '',
  });

  final int userId;
  final String displayName;
  final String handle;
  final String avatarLetter;
  final String avatarUrl;
  final String bio;
  final int followerCount;
  final int followingCount;
  final int postCount;
  final int likesReceived;
  final String likesReceivedLabel;
  final String followState;
  final String roleBadge;

  factory FeedUserProfileDto.fromJson(Map<String, dynamic> j) => FeedUserProfileDto(
        userId: _jsonInt(j['user_id']),
        displayName: j['display_name'] as String? ?? '',
        handle: j['handle'] as String? ?? '',
        avatarLetter: j['avatar_letter'] as String? ?? '?',
        avatarUrl: j['avatar_url'] as String? ?? '',
        bio: j['bio'] as String? ?? '',
        followerCount: _jsonInt(j['follower_count']),
        followingCount: _jsonInt(j['following_count']),
        postCount: _jsonInt(j['post_count']),
        likesReceived: _jsonInt(j['likes_received']),
        likesReceivedLabel: j['likes_received_label'] as String? ?? '0',
        followState: j['follow_state'] as String? ?? 'none',
        roleBadge: j['role_badge'] as String? ?? '',
      );
}

class FeedUserProfileResponse {
  FeedUserProfileResponse({required this.profile, required this.posts});

  final FeedUserProfileDto profile;
  final List<FeedPostCardDto> posts;

  factory FeedUserProfileResponse.fromJson(Map<String, dynamic> j) => FeedUserProfileResponse(
        profile: FeedUserProfileDto.fromJson(j['profile'] as Map<String, dynamic>? ?? {}),
        posts: (j['posts'] as List<dynamic>? ?? [])
            .map((e) => FeedPostCardDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

FeedAvatarVariant variantFromApiString(String s) => _variantFromString(s);

FeedCover _coverFromStyle(String s) => switch (s) {
      'h2' => FeedCover.h2,
      'h3' => FeedCover.h3,
      'h4' => FeedCover.h4,
      'h5' => FeedCover.h5,
      'h6' => FeedCover.h6,
      'h7' => FeedCover.h7,
      'h8' => FeedCover.h8,
      _ => FeedCover.h1,
    };

FeedAvatarVariant _variantFromString(String s) => switch (s) {
      'green' => FeedAvatarVariant.green,
      'pink' => FeedAvatarVariant.pink,
      'blue' => FeedAvatarVariant.blue,
      'amber' => FeedAvatarVariant.amber,
      _ => FeedAvatarVariant.accent,
    };

IconData? _iconFromKey(String? key) => switch (key) {
      'bug' => Icons.bug_report_outlined,
      'balance' => Icons.balance_outlined,
      'psychology' => Icons.psychology_outlined,
      'bolt' => Icons.bolt_outlined,
      'route' => Icons.alt_route,
      _ => key != null && key.isNotEmpty ? Icons.article_outlined : null,
    };

PostDetailId? _detailIdFromKey(String? key) => switch (key) {
      'soul' => PostDetailId.soul,
      'skill' => PostDetailId.skill,
      'review' => PostDetailId.review,
      'night_case' => PostDetailId.nightCase,
      _ => null,
    };

LinearGradient authorGradient(String variant) => switch (variant) {
      'green' => MirrorGradients.green,
      'pink' => MirrorGradients.pink,
      'blue' => MirrorGradients.blue,
      'amber' => MirrorGradients.amber,
      _ => MirrorGradients.purple,
    };
