import 'package:flutter/material.dart';
import '../theme/mirror_colors.dart';
import 'post_detail_data.dart';

enum FeedPill { rec, fol }

enum FeedCover { h1, h2, h3, h4, h5, h6, h7, h8 }

enum FeedAvatarVariant { accent, green, pink, blue, amber }

extension FeedCoverStyle on FeedCover {
  double get height => switch (this) {
        FeedCover.h1 => 152,
        FeedCover.h2 => 172,
        FeedCover.h3 => 136,
        FeedCover.h4 => 160,
        FeedCover.h5 => 144,
        FeedCover.h6 => 156,
        FeedCover.h7 => 142,
        FeedCover.h8 => 164,
      };

  LinearGradient get gradient => switch (this) {
        FeedCover.h1 => const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF6B5CE8), Color(0xFF9B8FFF)]),
        FeedCover.h2 => const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFE84A85), Color(0xFFFFB4D0)]),
        FeedCover.h3 => const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1D9E75), Color(0xFF56C9A0)]),
        FeedCover.h4 => const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFBA7517), Color(0xFFE8AC55)]),
        FeedCover.h5 => const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF185FA5), Color(0xFF56A8E8)]),
        FeedCover.h6 => const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2D2A26), Color(0xFF5C5A54)]),
        FeedCover.h7 => const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFE85D4C), Color(0xFFFF9A8B)]),
        FeedCover.h8 => const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF4A3FB8), Color(0xFF7C6FE8)]),
      };
}

extension FeedAvatarVariantColor on FeedAvatarVariant {
  Color get color => switch (this) {
        FeedAvatarVariant.accent => MirrorColors.accent,
        FeedAvatarVariant.green => MirrorColors.green,
        FeedAvatarVariant.pink => MirrorColors.pink,
        FeedAvatarVariant.blue => MirrorColors.blue,
        FeedAvatarVariant.amber => MirrorColors.amber,
      };
}

class FeedCardData {
  const FeedCardData({
    required this.cover,
    required this.title,
    required this.av,
    required this.avVariant,
    required this.author,
    required this.likes,
    this.authorKey = '',
    this.authorName = '',
    this.label = '',
    this.quote,
    this.icon,
    this.liked = false,
    this.hotLabel = false,
    this.detailId,
    this.postId,
    this.authorUserId,
    this.authorAvatarUrl,
    this.coverImageUrl,
    this.hasSharedKb = false,
    this.sharedKbName,
    this.sharedKbId,
    this.topicTag,
    this.subtitle,
  });

  final FeedCover cover;
  final String? coverImageUrl;
  final String label;
  final String? topicTag;
  final String? subtitle;
  final String? quote;
  final IconData? icon;
  final String title;
  final String av;
  final FeedAvatarVariant avVariant;
  final String author;
  final String authorKey;
  final String authorName;
  final String likes;
  final bool liked;
  final bool hotLabel;
  final PostDetailId? detailId;
  final int? postId;
  final int? authorUserId;
  final String? authorAvatarUrl;
  final bool hasSharedKb;
  final String? sharedKbName;
  final String? sharedKbId;
}

/// 生态 Tab 演示数据（原型专用，优先于后端列表展示）
abstract final class MirrorFeedData {
  static const bool preferPrototypeOverApi = false;

  static List<FeedCardData> forPill(FeedPill pill) => switch (pill) {
        FeedPill.rec => rec,
        FeedPill.fol => fol,
      };

  /// 推荐流：第 1、3 条等带知识库，详情页可订阅
  static const rec = [
    FeedCardData(
      cover: FeedCover.h4,
      quote: 'Agent\n语气',
      subtitle: '可直接复制',
      title: '7 条约束让 Agent 不再「我可以为您」：附禁词表',
      av: '沈',
      avVariant: FeedAvatarVariant.amber,
      authorKey: 'shenzhiwei',
      authorName: '沈知微',
      author: '沈知微',
      likes: '3.1k',
      topicTag: 'Prompt',
      liked: true,
      detailId: PostDetailId.review,
      hasSharedKb: true,
      sharedKbName: '沈知微 · Prompt 模板库',
    ),
    FeedCardData(
      cover: FeedCover.h6,
      icon: Icons.nightlight_round,
      subtitle: '夜间值班',
      title: '告警风暴下的自动收敛：从 47 条告警到 3 条可执行项',
      av: '高',
      avVariant: FeedAvatarVariant.accent,
      authorKey: 'gaolin',
      authorName: '高临',
      author: '高临',
      likes: '2.0k',
      topicTag: 'SRE',
      detailId: PostDetailId.nightCase,
      hasSharedKb: true,
      sharedKbName: '高临 · 运维手册',
    ),
    FeedCardData(
      cover: FeedCover.h7,
      quote: '飞书\n周报',
      subtitle: '零返工结构',
      title: '一套被团队复用 30 天的周报框架（含段落示例）',
      av: '小',
      avVariant: FeedAvatarVariant.pink,
      authorKey: 'xiaowei',
      authorName: '小苇',
      author: '小苇',
      likes: '674',
      topicTag: '职场',
      hasSharedKb: true,
      sharedKbName: '小苇 · 职场模板库',
    ),
    FeedCardData(
      cover: FeedCover.h8,
      icon: Icons.route_outlined,
      subtitle: '效率提升',
      title: '多模型路由落地：按任务拆分后的效果对比',
      av: '李',
      avVariant: FeedAvatarVariant.green,
      authorKey: 'libo',
      authorName: '李伯',
      author: '李伯',
      likes: '1.5k',
      topicTag: '架构',
    ),
    FeedCardData(
      cover: FeedCover.h5,
      icon: Icons.analytics_outlined,
      subtitle: 'Q1 财报',
      title: '三家互联网公司 AI 资本开支：结构、节奏与隐含信号',
      av: '徐',
      avVariant: FeedAvatarVariant.blue,
      authorKey: 'xutong',
      authorName: '徐潼',
      author: '徐潼',
      likes: '478',
      topicTag: '金融',
      hasSharedKb: true,
      sharedKbName: '徐潼 · 金融研报库',
    ),
    FeedCardData(
      cover: FeedCover.h2,
      quote: '知识库\n订阅',
      subtitle: '3 步上手',
      title: '从生态笔记到订阅知识库：建立个人第二大脑',
      av: '钟',
      avVariant: FeedAvatarVariant.green,
      authorKey: 'zhongyi',
      authorName: '钟意',
      author: '钟意',
      likes: '956',
      topicTag: '指南',
      hasSharedKb: true,
      sharedKbName: '钟意 · 知识库精选',
    ),
  ];

  static const fol = [
    FeedCardData(
      cover: FeedCover.h1,
      icon: Icons.bug_report_outlined,
      subtitle: 'v2 发布',
      title: 'k8s-debug v2：OOMKilled 自动归因与修复建议',
      av: '陈',
      avVariant: FeedAvatarVariant.accent,
      authorKey: 'chenmo',
      authorName: '陈墨',
      author: '陈墨 · 2h',
      likes: '132',
      label: '热门',
      hotLabel: true,
      detailId: PostDetailId.skill,
      hasSharedKb: true,
      sharedKbName: '陈墨 · DevOps 笔记',
    ),
    FeedCardData(
      cover: FeedCover.h3,
      quote: 'DeepSeek\nGemini',
      subtitle: '中文长文',
      title: '中文长文写作并排实测：DeepSeek 与 Gemini 2.5',
      av: '周',
      avVariant: FeedAvatarVariant.green,
      authorKey: 'zhouye',
      authorName: '周野',
      author: '周野 · 5h',
      likes: '87',
      hotLabel: true,
      detailId: PostDetailId.review,
      hasSharedKb: true,
      sharedKbName: '周野 · AI 写作知识库',
    ),
    FeedCardData(
      cover: FeedCover.h4,
      subtitle: '12 条模板',
      title: '极简 Prompt 清单：工作场景越短越准',
      av: '沈',
      avVariant: FeedAvatarVariant.amber,
      authorKey: 'shenzhiwei',
      authorName: '沈知微',
      author: '沈知微 · 昨天',
      likes: '456',
      hotLabel: true,
      detailId: PostDetailId.review,
      hasSharedKb: true,
      sharedKbName: '沈知微 · Prompt 模板库',
    ),
    FeedCardData(
      cover: FeedCover.h6,
      quote: '值班\n自动化',
      subtitle: '省 40 次介入',
      title: '三个月夜间值班交给 Agent 的复盘',
      av: '高',
      avVariant: FeedAvatarVariant.accent,
      authorKey: 'gaolin',
      authorName: '高临',
      author: '高临 · 2 天',
      likes: '1.2k',
      hotLabel: true,
      detailId: PostDetailId.nightCase,
      hasSharedKb: true,
      sharedKbName: '高临 · 运维手册',
    ),
    FeedCardData(
      cover: FeedCover.h2,
      subtitle: '长上下文',
      title: '200k 窗口横评：长文档任务谁更稳定',
      av: '周',
      avVariant: FeedAvatarVariant.green,
      authorKey: 'zhouye',
      authorName: '周野',
      author: '周野 · 3 天',
      likes: '389',
      detailId: PostDetailId.review,
      hasSharedKb: true,
      sharedKbName: '周野 · AI 写作知识库',
    ),
    FeedCardData(
      cover: FeedCover.h5,
      quote: '研报\n框架',
      subtitle: '方法论',
      title: '三家券商 AI 研报写作框架对比',
      av: '徐',
      avVariant: FeedAvatarVariant.blue,
      authorKey: 'xutong',
      authorName: '徐潼',
      author: '徐潼 · 4 天',
      likes: '567',
      hasSharedKb: true,
      sharedKbName: '徐潼 · 金融研报库',
    ),
  ];

  /// 「我的主页」展示的笔记
  static const myPosts = [
    FeedCardData(
      cover: FeedCover.h2,
      quote: '知识库\n实践',
      title: '我把一周的 AI 对话沉淀成可检索知识库',
      av: '我',
      avVariant: FeedAvatarVariant.accent,
      authorKey: 'me',
      authorName: '我',
      author: '我',
      likes: '86',
      topicTag: '笔记',
      hasSharedKb: true,
      sharedKbName: '我的工作笔记',
    ),
    FeedCardData(
      cover: FeedCover.h5,
      icon: Icons.auto_awesome_outlined,
      title: 'Mirror 生态首发：如何整理可订阅的内容',
      av: '我',
      avVariant: FeedAvatarVariant.accent,
      authorKey: 'me',
      authorName: '我',
      author: '我',
      likes: '124',
      detailId: PostDetailId.review,
      hasSharedKb: true,
      sharedKbName: '我的精选库',
    ),
    FeedCardData(
      cover: FeedCover.h4,
      subtitle: '工具箱',
      title: '我常用的 4 个技能使用复盘',
      av: '我',
      avVariant: FeedAvatarVariant.accent,
      authorKey: 'me',
      authorName: '我',
      author: '我',
      likes: '52',
    ),
  ];

  static const searchHotTags = [
    ('01', '知识库订阅', true),
    ('02', '模型评测', true),
    ('03', 'K8s 排错', false),
    ('04', '周报模板', false),
    ('05', '夜间值班', false),
    ('06', '财报解读', false),
  ];
}
