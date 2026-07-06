import 'package:flutter/material.dart';
import '../models/personal_kb.dart';
import '../theme/post_carousel_gradients.dart';
import '../widgets/post_carousel.dart';
import '../widgets/post_slides.dart';
import 'mirror_feed_data.dart';

enum PostDetailId { soul, skill, review, nightCase }

class PostAuthorInfo {
  const PostAuthorInfo({
    required this.av,
    required this.avGradient,
    required this.name,
    required this.sub,
    this.avatarUrl = '',
    this.followed = false,
    this.userId = 0,
  });

  final String av;
  final LinearGradient avGradient;
  final String name;
  final String sub;
  final String avatarUrl;
  final bool followed;
  final int userId;
}

enum PostBodyBlockType { paragraph, callout, compare, code, stats }

class PostBodyBlock {
  const PostBodyBlock.paragraph(this.text) : type = PostBodyBlockType.paragraph, callout = null, compare = null, code = null, stats = null;
  const PostBodyBlock.callout({required IconData icon, required CalloutVariant variant, required String body})
      : type = PostBodyBlockType.callout,
        text = '',
        callout = (icon: icon, variant: variant, body: body),
        compare = null,
        code = null,
        stats = null;
  const PostBodyBlock.compare({required String badTitle, required String bad, required String goodTitle, required String good})
      : type = PostBodyBlockType.compare,
        text = '',
        callout = null,
        compare = (badTitle: badTitle, bad: bad, goodTitle: goodTitle, good: good),
        code = null,
        stats = null;
  const PostBodyBlock.code(this.code)
      : type = PostBodyBlockType.code,
        text = '',
        callout = null,
        compare = null,
        stats = null;
  const PostBodyBlock.stats(this.stats)
      : type = PostBodyBlockType.stats,
        text = '',
        callout = null,
        compare = null,
        code = null;

  final PostBodyBlockType type;
  final String text;
  final ({IconData icon, CalloutVariant variant, String body})? callout;
  final ({String badTitle, String bad, String goodTitle, String good})? compare;
  final String? code;
  final List<({String v, String k})>? stats;
}

enum CalloutVariant { accent, amber, green }

/// 博主在文章中分享的个人知识库
class SharedKnowledgeBaseInfo {
  const SharedKnowledgeBaseInfo({
    required this.name,
    required this.author,
    required this.docCount,
    required this.summary,
    this.apiKbId,
    this.isOwnKb = false,
  });

  final String name;
  final String author;
  final int docCount;
  final String summary;
  /// 服务端知识库 ID；生态 Mock 卡片（work/study 等）为 null，走内存订阅。
  final int? apiKbId;
  /// 当前登录用户是该知识库所有者（不可订阅）。
  final bool isOwnKb;

  bool get canSubscribe => docCount > 0 && !isOwnKb;
}

class PostActionsState {
  const PostActionsState({
    required this.likes,
    required this.bookmarks,
    required this.comments,
    this.liked = false,
    this.bookmarked = false,
    this.bookmarkAmber = false,
  });

  final String likes;
  final String bookmarks;
  final String comments;
  final bool liked;
  final bool bookmarked;
  final bool bookmarkAmber;
}

class PostDetailData {
  const PostDetailData({
    required this.id,
    required this.author,
    required this.slides,
    required this.intervalMs,
    required this.title,
    required this.meta,
    required this.blocks,
    required this.tags,
    required this.actions,
    this.markdownBody,
    this.sharedKb,
  });

  final PostDetailId id;
  final PostAuthorInfo author;
  final List<PostCarouselSlide> slides;
  final int intervalMs;
  final String title;
  final String meta;
  final List<PostBodyBlock> blocks;
  /// API 返回的 Markdown 正文；非空时详情页优先用 Markdown 渲染。
  final String? markdownBody;
  final List<String> tags;
  final PostActionsState actions;
  final SharedKnowledgeBaseInfo? sharedKb;

  static PostDetailData byId(PostDetailId id) => switch (id) {
        PostDetailId.soul => soul,
        PostDetailId.skill => skill,
        PostDetailId.review => review,
        PostDetailId.nightCase => nightCase,
      };

  static PostDetailId resolveFromCard(FeedCardData card) {
    if (card.detailId != null) return card.detailId!;
    final t = card.title;
    if (t.contains('k8s') || t.contains('K8s') || t.contains('GPU')) return PostDetailId.skill;
    if (t.contains('Claude-4 vs GPT') || t.contains('周报')) return PostDetailId.review;
    if (t.contains('凌晨 3 点') || t.contains('GPU 集群') || t.contains('夜间') || t.contains('夜班')) return PostDetailId.nightCase;
    return PostDetailId.review;
  }

  static SharedKnowledgeBaseInfo? sharedKbFromCard(FeedCardData card) {
    if (!card.hasSharedKb) return null;
    final label = card.sharedKbName?.contains(' · ') == true
        ? card.sharedKbName!.split(' · ').last
        : (PersonalKbCatalog.labelFor(card.sharedKbId) ?? card.sharedKbName ?? '知识库');
    return PersonalKbCatalog.toSharedInfo(
      kbId: card.sharedKbId ?? 'work',
      kbLabel: label,
      authorName: card.authorName.isNotEmpty ? card.authorName : card.author,
    );
  }

  static final soul = PostDetailData(
    id: PostDetailId.soul,
    author: PostAuthorInfo(av: '林', avGradient: PostCarouselGradients.authorPink, name: '林岸 · Lin Yan', sub: 'SOUL CRAFTER · 5.3k'),
    intervalMs: 3500,
    slides: [
      PostCarouselSlide(slideNum: '01 · 主题', gradient: PostCarouselGradients.pink, child: PostSlides.quote('"清醒、有据、\n敢于反对。"')),
      PostCarouselSlide(slideNum: '02 · IDENTITY', gradient: PostCarouselGradients.purple, child: PostSlides.soulCode()),
      PostCarouselSlide(slideNum: '03 · PRINCIPLES', gradient: PostCarouselGradients.paper, lightOnDark: false, child: PostSlides.principles(onPaper: true)),
      PostCarouselSlide(slideNum: '04 · TABOO', gradient: PostCarouselGradients.stone, child: PostSlides.banlist()),
      PostCarouselSlide(slideNum: '05 · BEFORE / AFTER', gradient: PostCarouselGradients.green, child: PostSlides.baxh()),
    ],
    title: '我给 Athena 的灵魂配置，用了 8 个月没改过',
    meta: '2026/05/16 · 5,346 收藏 · 412 评论',
    blocks: [
      const PostBodyBlock.paragraph('很多人问我为什么 Athena 输出这么"硬"——既不堆砌客套话，也敢于直接指出我的错误。秘诀就在 SOUL.md 里。'),
      PostBodyBlock.callout(
        icon: Icons.lightbulb_outline,
        variant: CalloutVariant.accent,
        body: '最关键的不是"我是谁"，而是"我不是谁"。TABOO 字段比 IDENTITY 字段对输出风格的影响更大。',
      ),
      const PostBodyBlock.paragraph('我把工作原则压缩成 4 条，每一条都经历过被打脸 → 写进 SOUL → 再没踩过的迭代：'),
      const PostBodyBlock.compare(
        badTitle: 'before',
        bad: '"可能是 batch 太大，也许试试 32？"',
        goodTitle: 'after',
        good: '"batch 应≥64，我之前验证过。"',
      ),
    ],
    tags: ['#SOUL.md', '#Prompt工程', '#Agent调教'],
    actions: PostActionsState(likes: '5.3k', bookmarks: '1.2k', comments: '412', liked: true),
  );

  static final skill = PostDetailData(
    id: PostDetailId.skill,
    author: PostAuthorInfo(av: '陈', avGradient: PostCarouselGradients.authorPurple, name: '陈墨 · DevOps', sub: 'K8S 大佬 · 1.8k', followed: true),
    intervalMs: 3200,
    slides: [
      PostCarouselSlide(
        slideNum: '01 · 故障',
        gradient: PostCarouselGradients.darkRed,
        child: PostSlides.alert(
          title: 'POD OOMKilled',
          icon: Icons.warning_amber_rounded,
          rows: [('Container', 'athena-rl'), ('Exit Code', '137'), ('Last State', 'Terminated'), ('Restarts', '23'), ('影响 jobs', '8')],
        ),
      ),
      PostCarouselSlide(slideNum: '02 · 触发技能', gradient: PostCarouselGradients.purple, child: PostSlides.skillTrigger()),
      PostCarouselSlide(
        slideNum: '03 · 23 个工具调用',
        gradient: PostCarouselGradients.stone,
        child: PostSlides.timeline([
          ('+0s', 'kubectl describe pod', false),
          ('+1.2s', 'kubectl logs --tail=200', false),
          ('+2.8s', 'analyze_metrics(memory)', false),
          ('+4.1s', 'check_resource_limits', false),
          ('+5.3s', 'search_recent_changes', false),
          ('+6.0s', 'suggest_fix · limits 2Gi', true),
        ]),
      ),
      PostCarouselSlide(
        slideNum: '04 · FIXED',
        gradient: PostCarouselGradients.green,
        child: PostSlides.bigsum(label: 'CLUSTER RESTORED', big: '4 min 32 s', stats: [('修复步骤', '3'), ('停机', '< 1m'), ('数据丢失', '0')]),
      ),
    ],
    title: '用 k8s-debug 技能救了我的命，附完整 prompt',
    meta: '2026/05/14 · 892 收藏 · 138 评论',
    blocks: [
      const PostBodyBlock.paragraph('那是个周二下午，整个 RL 训练 pod 突然挂了。8 个 GPU jobs 等着结果，老板的脸已经在窗口跳动。'),
      PostBodyBlock.callout(icon: Icons.bolt, variant: CalloutVariant.amber, body: '核心思路：让 Agent 先 describe → logs → metrics，再决定要不要改 manifest。不要让它直接动 kubectl apply。'),
      const PostBodyBlock.paragraph('关键技巧：限定 Agent 必须先调三个只读工具，再产出建议；任何写操作必须先 dry-run。'),
      const PostBodyBlock.code('skill: k8s-debug\nworkflow:\n  1. read-only triage\n  2. cross-check memory\n  3. dry-run before apply'),
    ],
    tags: ['#k8s', '#DevOps', '#排错'],
    actions: PostActionsState(likes: '892', bookmarks: '734', comments: '138', bookmarked: true, bookmarkAmber: true),
    sharedKb: SharedKnowledgeBaseInfo(name: '陈墨 · DevOps 笔记', author: '陈墨', docCount: 47, summary: 'K8s 排错流程、常用命令与实战案例'),
  );

  static final review = PostDetailData(
    id: PostDetailId.review,
    author: PostAuthorInfo(av: '周', avGradient: PostCarouselGradients.authorGreen, name: '周野', sub: '长文专家 · 892'),
    intervalMs: 4000,
    slides: [
      PostCarouselSlide(slideNum: '01 · 总分对比', gradient: PostCarouselGradients.violet, child: PostSlides.statCompare()),
      PostCarouselSlide(slideNum: '02 · 维度雷达', gradient: PostCarouselGradients.blue, child: PostSlides.dimensionBars()),
      PostCarouselSlide(slideNum: '03 · ROI · 月度', gradient: PostCarouselGradients.amber, child: PostSlides.costTable()),
    ],
    title: '实测对比：Claude-4 vs GPT-4o 谁更会写周报',
    meta: '2026/05/12 · 1,204 收藏 · 89 评论',
    blocks: [
      const PostBodyBlock.paragraph('我们组每月要交 50 篇内部周报。过去一个月，我用两个模型各跑 25 篇，请 5 位同事盲评。'),
      const PostBodyBlock.stats([(v: '92', k: 'CLAUDE'), (v: '87', k: 'GPT-4o'), (v: '24×', k: 'ROI')]),
      PostBodyBlock.callout(
        icon: Icons.check,
        variant: CalloutVariant.green,
        body: '简单结论：Claude-4 胜在结构与简洁；GPT-4o 胜在语气自然与速度。预算紧选 GPT，质量优先选 Claude。',
      ),
      const PostBodyBlock.paragraph('不是非此即彼。我现在的做法是：草稿用 GPT-4o（快），定稿请 Claude-4 重写一遍（稳）。两个加起来一篇成本 ¥ 8.4。'),
    ],
    tags: ['#Benchmark', '#Claude', '#GPT-4o'],
    actions: PostActionsState(likes: '1.2k', bookmarks: '403', comments: '89'),
    sharedKb: SharedKnowledgeBaseInfo(name: '周野 · AI 写作知识库', author: '周野', docCount: 32, summary: '模型对比、周报模板与写作技巧归档'),
  );

  static final nightCase = PostDetailData(
    id: PostDetailId.nightCase,
    author: PostAuthorInfo(av: '高', avGradient: PostCarouselGradients.authorStone, name: '高临', sub: '凌晨 3 点的人 · 2.0k'),
    intervalMs: 3800,
    slides: [
      PostCarouselSlide(
        slideNum: '03:14 AM · 告警',
        gradient: PostCarouselGradients.darkRed,
        child: PostSlides.alert(
          title: 'GPU CLUSTER DOWN',
          icon: Icons.bolt,
          rows: [('node-7', 'NotReady'), ('影响 jobs', '8'), ('已 down', '2 min'), ('我的状态', '熟睡中')],
          lastValueColor: '熟睡中',
        ),
      ),
      PostCarouselSlide(slideNum: '03:14:08 AM · 接管', gradient: PostCarouselGradients.violet, child: PostSlides.irisAwaken()),
      PostCarouselSlide(
        slideNum: '03:15 - 03:21 · 排错',
        gradient: PostCarouselGradients.stone,
        child: PostSlides.timeline([
          ('03:15', 'Identified node-7 hw fault', false),
          ('03:16', 'Cordon node-7 · drain', false),
          ('03:18', 'Reschedule 8 jobs to node-3,5', false),
          ('03:20', 'Verify all jobs Running', false),
          ('03:21', 'Log to /night-shift/2026-05-12.md', false),
          ('03:22', 'Send TG digest · don\'t wake', true),
        ]),
      ),
      PostCarouselSlide(
        slideNum: '07:30 AM · 我醒来时',
        gradient: PostCarouselGradients.green,
        child: PostSlides.bigsum(
          label: 'DOWN TIME',
          big: '8 min',
          stats: [('jobs 丢失', '0'), ('电话吵醒', '0'), ('新 memory', '+1')],
          quote: '"早安。\nnode-7 已经被你晚上的 Iris 处理掉了。"',
        ),
      ),
    ],
    title: '凌晨 3 点 GPU 集群挂了，Agent 自动排错并通知我',
    meta: '2026/05/12 · 2,089 收藏 · 234 评论',
    blocks: [
      const PostBodyBlock.paragraph('这是 Iris 第 14 次替我加班，也是最惊险的一次。整个集群挂了的 8 分钟里我一直在睡觉，醒来只看到一条整理好的事故报告。'),
      PostBodyBlock.callout(icon: Icons.nightlight_round, variant: CalloutVariant.accent, body: '核心是 /night-shift 技能：在凌晨 0:00-7:00 这段时间，Agent 拥有 read + triage 权限，但禁止任何破坏性操作。重启、回滚要等我醒来 confirm。'),
      const PostBodyBlock.paragraph('设计哲学：不是让 Agent 替你拍板，而是让它把"小事处理完，大事整理好"，等你醒来一目了然。'),
      const PostBodyBlock.paragraph('关键约束写在 SOUL 里："夜间禁止打电话叫醒我，除非数据丢失风险 > 50%。"'),
    ],
    tags: ['#NightShift', '#夜间值班', '#GPU'],
    actions: PostActionsState(likes: '2.0k', bookmarks: '892', comments: '234', liked: true, bookmarked: true, bookmarkAmber: true),
    sharedKb: SharedKnowledgeBaseInfo(name: '高临 · 运维手册', author: '高临', docCount: 18, summary: '夜间值班流程、告警处理与复盘记录'),
  );
}
