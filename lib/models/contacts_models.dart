/// 通讯录模块数据模型（对齐 /api/v1/contacts/*）。
class ContactUserCard {
  ContactUserCard({
    required this.userId,
    required this.avatarLetter,
    this.avatarUrl = '',
    required this.displayName,
    required this.handle,
    required this.bio,
    this.roleBadge,
    required this.stats,
    required this.affinity,
    required this.followState,
    required this.followButtonLabel,
    this.recommendReason,
    this.matchType,
  });

  final int userId;
  final String avatarLetter;
  final String avatarUrl;
  final String displayName;
  final String handle;
  final String bio;
  final ContactRoleBadge? roleBadge;
  final ContactUserStats stats;
  final List<ContactAffinity> affinity;
  final String followState;
  final String followButtonLabel;
  final String? recommendReason;
  final String? matchType;

  bool get canFollow => followState == 'none' || followState == 'follower';

  /// 接口未返回按钮文案时的本地兜底。
  String get resolvedFollowButtonLabel {
    final label = followButtonLabel.trim();
    if (label.isNotEmpty) return label;
    return switch (followState) {
      'mutual' => '互关',
      'following' => '已关注',
      'follower' => '回关',
      _ => '+ 关注',
    };
  }

  ContactUserCard copyWith({
    String? followState,
    String? followButtonLabel,
  }) =>
      ContactUserCard(
        userId: userId,
        avatarLetter: avatarLetter,
        avatarUrl: avatarUrl,
        displayName: displayName,
        handle: handle,
        bio: bio,
        roleBadge: roleBadge,
        stats: stats,
        affinity: affinity,
        followState: followState ?? this.followState,
        followButtonLabel: followButtonLabel ?? this.followButtonLabel,
        recommendReason: recommendReason,
        matchType: matchType,
      );

  factory ContactUserCard.fromJson(Map<String, dynamic> j) {
    ContactRoleBadge? badge;
    final rb = j['role_badge'];
    if (rb is Map<String, dynamic>) {
      badge = ContactRoleBadge.fromJson(rb);
    }
    return ContactUserCard(
      userId: j['user_id'] as int? ?? 0,
      avatarLetter: j['avatar_letter'] as String? ?? '?',
      avatarUrl: j['avatar_url'] as String? ?? '',
      displayName: j['display_name'] as String? ?? '',
      handle: j['handle'] as String? ?? '',
      bio: j['bio'] as String? ?? '',
      roleBadge: badge,
      stats: ContactUserStats.fromJson(j['stats'] as Map<String, dynamic>? ?? {}),
      affinity: (j['affinity'] as List<dynamic>? ?? [])
          .map((e) => ContactAffinity.fromJson(e as Map<String, dynamic>))
          .toList(),
      followState: j['follow_state'] as String? ?? 'none',
      followButtonLabel: j['follow_button_label'] as String? ?? '+ 关注',
      recommendReason: j['recommend_reason'] as String?,
      matchType: j['match_type'] as String?,
    );
  }
}

class ContactRoleBadge {
  ContactRoleBadge({required this.key, required this.label, required this.style});

  final String key;
  final String label;
  final String style;

  factory ContactRoleBadge.fromJson(Map<String, dynamic> j) => ContactRoleBadge(
        key: j['key'] as String? ?? '',
        label: j['label'] as String? ?? '',
        style: j['style'] as String? ?? 'default',
      );
}

class ContactUserStats {
  ContactUserStats({
    required this.followerCount,
    required this.noteCount,
    required this.followerCountLabel,
  });

  final int followerCount;
  final int noteCount;
  final String followerCountLabel;

  factory ContactUserStats.fromJson(Map<String, dynamic> j) => ContactUserStats(
        followerCount: j['follower_count'] as int? ?? 0,
        noteCount: j['note_count'] as int? ?? 0,
        followerCountLabel: j['follower_count_label'] as String? ?? '0',
      );
}

class ContactAffinity {
  ContactAffinity({required this.type, required this.label, this.value});

  final String type;
  final String label;
  final Object? value;

  factory ContactAffinity.fromJson(Map<String, dynamic> j) => ContactAffinity(
        type: j['type'] as String? ?? '',
        label: j['label'] as String? ?? '',
        value: j['value'],
      );
}

class ContactFollowResult {
  ContactFollowResult({
    required this.userId,
    required this.followState,
    required this.followButtonLabel,
  });

  final int userId;
  final String followState;
  final String followButtonLabel;

  factory ContactFollowResult.fromJson(Map<String, dynamic> j) => ContactFollowResult(
        userId: j['user_id'] as int? ?? 0,
        followState: j['follow_state'] as String? ?? 'none',
        followButtonLabel: j['follow_button_label'] as String? ?? '',
      );

  String get resolvedFollowButtonLabel {
    final label = followButtonLabel.trim();
    if (label.isNotEmpty) return label;
    return switch (followState) {
      'mutual' => '互关',
      'following' => '已关注',
      'follower' => '回关',
      _ => '+ 关注',
    };
  }
}

class ContactListResponse {
  ContactListResponse({required this.tab, required this.items});

  final String tab;
  final List<ContactUserCard> items;

  factory ContactListResponse.fromJson(Map<String, dynamic> j) => ContactListResponse(
        tab: j['tab'] as String? ?? 'recommend',
        items: (j['items'] as List<dynamic>? ?? [])
            .map((e) => ContactUserCard.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ShareTargetsData {
  ShareTargetsData({
    required this.favorites,
    required this.channels,
    required this.referral,
  });

  final List<ShareFavorite> favorites;
  final List<String> channels;
  final ReferralData referral;

  factory ShareTargetsData.fromJson(Map<String, dynamic> j) => ShareTargetsData(
        favorites: (j['favorites'] as List<dynamic>? ?? [])
            .map((e) => ShareFavorite.fromJson(e as Map<String, dynamic>))
            .toList(),
        channels: (j['channels'] as List<dynamic>? ?? []).map((e) => '$e').toList(),
        referral: ReferralData.fromJson(j['referral'] as Map<String, dynamic>? ?? {}),
      );
}

class ShareFavorite {
  ShareFavorite({
    required this.targetType,
    this.userId,
    this.groupId,
    required this.label,
    this.avatarLetter,
    this.avatarKind,
  });

  final String targetType;
  final int? userId;
  final int? groupId;
  final String label;
  final String? avatarLetter;
  final String? avatarKind;

  factory ShareFavorite.fromJson(Map<String, dynamic> j) => ShareFavorite(
        targetType: j['target_type'] as String? ?? '',
        userId: j['user_id'] as int?,
        groupId: j['group_id'] as int?,
        label: j['label'] as String? ?? '',
        avatarLetter: j['avatar_letter'] as String?,
        avatarKind: j['avatar_kind'] as String?,
      );
}

class ReferralData {
  ReferralData({
    required this.commissionRate,
    required this.commissionLabel,
    required this.inviteCode,
    required this.shareUrl,
  });

  final double commissionRate;
  final String commissionLabel;
  final String inviteCode;
  final String shareUrl;

  factory ReferralData.fromJson(Map<String, dynamic> j) => ReferralData(
        commissionRate: (j['commission_rate'] as num?)?.toDouble() ?? 0.2,
        commissionLabel: j['commission_label'] as String? ?? '20% 返佣',
        inviteCode: j['invite_code'] as String? ?? '',
        shareUrl: j['share_url'] as String? ?? '',
      );
}
