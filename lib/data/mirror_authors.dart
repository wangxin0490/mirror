import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/feed_models.dart';
import '../screens/mirror_feed_data.dart';
import '../widgets/phone_components.dart';

/// 生态博主资料（API 加载失败时可作占位）。
class MirrorAuthor {
  const MirrorAuthor({
    required this.key,
    required this.name,
    required this.av,
    required this.variant,
    required this.handle,
    required this.bio,
    this.userId = 0,
    this.followers = 0,
    this.following = 0,
    this.notes = 0,
    this.tagline = '',
    this.likesReceivedLabel = '',
    this.followState = 'none',
    this.avatarUrl = '',
  });

  final String key;
  final String name;
  final String av;
  final FeedAvatarVariant variant;
  final String handle;
  final String bio;
  final String tagline;
  final int userId;
  final int followers;
  final int following;
  final int notes;
  final String likesReceivedLabel;
  final String followState;
  final String avatarUrl;

  bool get canFollow => followState == 'none' || followState == 'follower';
  bool get isFollowing => followState == 'following' || followState == 'mutual';

  List<Color> get avatarColors => switch (variant) {
        FeedAvatarVariant.green => MirrorAvatars.zhou,
        FeedAvatarVariant.accent => MirrorAvatars.chen,
        FeedAvatarVariant.amber => MirrorAvatars.shen,
        FeedAvatarVariant.pink => MirrorAvatars.lin,
        FeedAvatarVariant.blue => MirrorAvatars.a5,
      };

  static String keyFromName(String raw) {
    final n = raw.split('·').first.split('·').first.trim();
    return switch (n) {
      '周野' => 'zhouye',
      '陈墨' => 'chenmo',
      '沈知微' => 'shenzhiwei',
      '高临' => 'gaolin',
      '小苇' => 'xiaowei',
      '徐潼' => 'xutong',
      '钟意' => 'zhongyi',
      '李伯' => 'libo',
      '林岸' => 'linan',
      _ => n.toLowerCase().replaceAll(' ', '_'),
    };
  }

  static MirrorAuthor fromCard(FeedCardData card) {
    final key = card.authorKey.isNotEmpty ? card.authorKey : keyFromName(card.authorName);
    final base = byKey(key);
    if (base != null) {
      return MirrorAuthor(
        key: base.key,
        name: card.authorName.isNotEmpty ? card.authorName : base.name,
        av: card.av.isNotEmpty ? card.av : base.av,
        variant: card.avVariant,
        handle: base.handle,
        bio: base.bio,
        userId: card.authorUserId ?? base.userId,
        followers: base.followers,
        following: base.following,
        notes: base.notes,
        tagline: base.tagline,
        likesReceivedLabel: base.likesReceivedLabel,
        followState: base.followState,
      );
    }
    return MirrorAuthor(
      key: key,
      name: card.authorName,
      av: card.av,
      variant: card.avVariant,
      handle: key,
      bio: 'Mirror 生态创作者',
      userId: card.authorUserId ?? 0,
      followers: 1200,
      following: 86,
      notes: 12,
      tagline: '分享 AI 工作流与知识库实践',
    );
  }

  static MirrorAuthor fromProfile(FeedUserProfileDto p, {FeedAvatarVariant? variant, bool isSelf = false}) {
    final key = isSelf ? 'me' : keyFromName(p.displayName);
    return MirrorAuthor(
      key: key,
      userId: p.userId,
      name: p.displayName,
      av: p.avatarLetter.isNotEmpty ? p.avatarLetter : '?',
      variant: variant ?? FeedAvatarVariant.pink,
      handle: p.handle,
      bio: p.bio,
      tagline: p.roleBadge,
      avatarUrl: p.avatarUrl,
      followers: p.followerCount,
      following: p.followingCount,
      notes: p.postCount,
      likesReceivedLabel: p.likesReceivedLabel,
      followState: p.followState,
    );
  }

  static MirrorAuthor? byKey(String key) => _all[key];

  /// 当前登录用户（「我的主页」占位，真实数据由 profile API 覆盖）。
  static MirrorAuthor currentUser() {
    final p = ApiConfig.cachedProfile;
    final letter = p.avatarLetter.isNotEmpty ? p.avatarLetter : '我';
    return MirrorAuthor(
      key: 'me',
      userId: ApiConfig.userId,
      name: p.displayName.isNotEmpty ? p.displayName : 'Mirror 用户',
      av: letter.isNotEmpty ? letter.substring(0, 1) : '我',
      variant: FeedAvatarVariant.accent,
      handle: p.handle.isNotEmpty ? p.handle : 'mirror_user',
      tagline: '记录 AI 工作流与知识库实践',
      bio: '在 Mirror 发布笔记、管理个人知识库，并与生态创作者互动。',
      followers: 128,
      following: 46,
      notes: 12,
    );
  }

  static final Map<String, MirrorAuthor> _all = {
    for (final a in catalog) a.key: a,
  };

  static const catalog = [
    MirrorAuthor(
      key: 'linan',
      userId: 3,
      name: '林岸 · Lin Yan',
      av: '林',
      variant: FeedAvatarVariant.pink,
      handle: 'lin.an',
      tagline: 'SOUL CRAFTER',
      bio: '"清醒、有据、敢于反对"的作者',
      followers: 5300,
      following: 86,
      notes: 23,
    ),
    MirrorAuthor(
      key: 'zhouye',
      userId: 5,
      name: '周野',
      av: '周',
      variant: FeedAvatarVariant.green,
      handle: 'zhou.ye',
      tagline: '长文写作 · 模型评测',
      bio: '专注大模型写作与评测，分享可复用的 Prompt 与周报工作流。',
      followers: 8920,
      following: 214,
      notes: 48,
    ),
    MirrorAuthor(
      key: 'chenmo',
      userId: 4,
      name: '陈墨',
      av: '陈',
      variant: FeedAvatarVariant.accent,
      handle: 'chen.mo',
      tagline: 'DevOps · K8s 排错',
      bio: '云原生与 GPU 集群运维，记录排障 SOP 与自动化脚本。',
      followers: 5310,
      following: 156,
      notes: 36,
    ),
    MirrorAuthor(
      key: 'shenzhiwei',
      userId: 6,
      name: '沈知微',
      av: '沈',
      variant: FeedAvatarVariant.amber,
      handle: 'shen.zw',
      tagline: 'Prompt 工程',
      bio: '研究 Agent 语气与禁词设计，产出可直接复制的模板。',
      followers: 12400,
      following: 98,
      notes: 62,
    ),
    MirrorAuthor(
      key: 'gaolin',
      userId: 8,
      name: '高临',
      av: '高',
      variant: FeedAvatarVariant.accent,
      handle: 'gao.lin',
      tagline: '夜间值班 · SRE',
      bio: '值班自动化与告警收敛，分享 Agent 辅助运维案例。',
      followers: 7680,
      following: 132,
      notes: 29,
    ),
    MirrorAuthor(
      key: 'xiaowei',
      userId: 9,
      name: '小苇',
      av: '小',
      variant: FeedAvatarVariant.pink,
      handle: 'xiao.wei',
      tagline: '产品 · 职场效率',
      bio: '飞书生态重度用户，整理模板库与协作技巧。',
      followers: 3420,
      following: 201,
      notes: 21,
    ),
    MirrorAuthor(
      key: 'xutong',
      userId: 7,
      name: '徐潼',
      av: '徐',
      variant: FeedAvatarVariant.blue,
      handle: 'xu.tong',
      tagline: '金融 · 研报',
      bio: '财报与 AI 投入对比，维护可订阅的研报知识库。',
      followers: 2890,
      following: 77,
      notes: 18,
    ),
    MirrorAuthor(
      key: 'zhongyi',
      userId: 11,
      name: '钟意',
      av: '钟',
      variant: FeedAvatarVariant.green,
      handle: 'zhong.yi',
      tagline: '知识库 · 订阅',
      bio: '教你从生态发现优质知识库并建立个人第二大脑。',
      followers: 4560,
      following: 189,
      notes: 15,
    ),
    MirrorAuthor(
      key: 'libo',
      userId: 10,
      name: '李伯',
      av: '李',
      variant: FeedAvatarVariant.green,
      handle: 'li.bo',
      tagline: '多模型路由',
      bio: '按任务分配模型，平衡成本与效果。',
      followers: 6120,
      following: 145,
      notes: 27,
    ),
  ];
}
