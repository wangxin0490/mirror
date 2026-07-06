import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../widgets/mirror_pressable.dart';
import '../config/api_config.dart';
import '../models/personal_kb.dart';
import '../utils/kb_subscribe_messages.dart';
import '../widgets/mirror_markdown_body.dart';
import '../widgets/post_body_blocks_view.dart';
import '../widgets/mirror_network_image.dart';
import '../widgets/mirror_scroll.dart';
import '../widgets/phone_components.dart';
import '../widgets/mirror_user_avatar.dart';
import '../widgets/post_carousel.dart';
import '../api/feed_api.dart';
import '../mappers/feed_comment_mapper.dart';
import '../models/feed_models.dart';
import '../models/post_body_envelope.dart';
import '../theme/post_carousel_gradients.dart';
import '../utils/media_url.dart';
import 'mirror_compose_comments.dart';
import 'post_detail_data.dart';
import '../state/kb_store.dart';
import '../state/kb_subscription_store.dart';
import '../widgets/moderation_action_sheet.dart';

/// post-details-4.html 帖子详情（轮播 + 正文 + post-actions-bar）
class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({
    super.key,
    required this.data,
    this.postId,
    this.onBack,
    this.onShare,
    this.onAuthorTap,
  });

  final PostDetailData data;
  final int? postId;
  final VoidCallback? onBack;
  final VoidCallback? onShare;
  final VoidCallback? onAuthorTap;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late bool _followed = widget.data.author.followed; // 关注帖子 = 收藏
  late bool _liked = widget.data.actions.liked;
  late bool _bookmarked = widget.data.actions.bookmarked;
  late String _likesLabel = widget.data.actions.likes;
  late String _bookmarksLabel = widget.data.actions.bookmarks;
  bool _kbSubscribed = false;
  bool _kbSubscribing = false;
  final _likedComments = <int>{};
  final _commentInput = TextEditingController();
  final _commentFocus = FocusNode();
  final _commentsAnchor = GlobalKey();
  String? _replyTo;
  List<CommentRowView> _commentRows = [];
  String _commentsLabel = '';
  int? _replyParentId;
  int? _replyToUserId;
  bool? _commentsLoaded;

  @override
  void initState() {
    super.initState();
    _commentsLabel = widget.data.actions.comments;
    final kb = widget.data.sharedKb;
    if (kb?.apiKbId != null) {
      KbStore.instance.addListener(_onKbStore);
      unawaited(_refreshKbSubscriptionFromServer());
    } else {
      _syncKbSubscription();
    }
    if (widget.postId != null) {
      _loadComments();
    }
  }

  Future<void> _refreshKbSubscriptionFromServer() async {
    await KbStore.instance.refresh();
    if (!mounted) return;
    _syncKbSubscription();
    setState(() {});
  }

  void _onKbStore() {
    if (!mounted) return;
    final kb = widget.data.sharedKb;
    if (kb?.apiKbId == null) return;
    final next = KbStore.instance.subscribed.any((s) => s.kbId == kb!.apiKbId);
    if (next != _kbSubscribed) {
      setState(() => _kbSubscribed = next);
    }
  }

  void _syncKbSubscription() {
    final kb = widget.data.sharedKb;
    if (kb == null) return;
    if (kb.apiKbId != null) {
      _kbSubscribed = KbStore.instance.subscribed.any((s) => s.kbId == kb.apiKbId);
    } else {
      _kbSubscribed = KbSubscriptionStore.instance.contains(kb.name);
    }
  }

  void _showKbSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: MirrorTheme.sans(fontSize: 13, color: Colors.white)),
        backgroundColor: MirrorColors.text,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      ),
    );
  }

  Future<void> _onKbSubscribe(SharedKnowledgeBaseInfo kb) async {
    if (kb.isOwnKb) {
      _showKbSnack('不能订阅自己的知识库');
      return;
    }
    if (!kb.canSubscribe) {
      _showKbSnack('知识库暂无可订阅文档');
      return;
    }
    if (kb.apiKbId != null) {
      setState(() => _kbSubscribing = true);
      final result = await KbStore.instance.subscribe(kb.apiKbId!);
      if (!mounted) return;
      setState(() {
        _kbSubscribing = false;
        if (result.ok) _kbSubscribed = true;
      });
      if (!result.ok) {
        _showKbSnack(KbSubscribeMessages.failure(result.message));
      }
      return;
    }
    if (kb.apiKbId == null) {
      _showKbSnack('该知识库暂不支持订阅，请稍后再试');
      return;
    }
  }

  @override
  void didUpdateWidget(PostDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _followed = widget.data.author.followed;
      _liked = widget.data.actions.liked;
      _bookmarked = widget.data.actions.bookmarked;
      _likesLabel = widget.data.actions.likes;
      _bookmarksLabel = widget.data.actions.bookmarks;
      final kb = widget.data.sharedKb;
      if (kb?.apiKbId != null) {
        unawaited(_refreshKbSubscriptionFromServer());
      } else {
        _syncKbSubscription();
      }
      if (_commentsLabel.isEmpty) {
        _commentsLabel = widget.data.actions.comments;
      }
    }
  }

  Future<void> _loadComments() async {
    final list = await FeedApi.fetchComments(widget.postId!);
    if (!mounted || list == null) return;
    setState(() {
      _commentsLoaded = true;
      _commentRows = mapCommentsToRows(list.items);
      _commentsLabel = '${list.total}';
      _likedComments
        ..clear()
        ..addAll([
          for (final c in list.items)
            if (c.liked) c.commentId,
          for (final c in list.items)
            for (final r in c.replies)
              if (r.liked) r.commentId,
        ]);
    });
  }

  @override
  void dispose() {
    KbStore.instance.removeListener(_onKbStore);
    _commentInput.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  void _startReply(String name, {int? parentId, int? userId, int? replyUserId}) {
    setState(() {
      _replyTo = name;
      _replyParentId = parentId;
      _replyToUserId = replyUserId ?? userId;
    });
    _commentFocus.requestFocus();
  }

  Future<void> _submitComment() async {
    final pid = widget.postId;
    if (pid == null) return;
    final text = _commentInput.text.trim();
    if (text.isEmpty) return;
    await FeedApi.postComment(
      pid,
      content: text,
      parentId: _replyParentId ?? 0,
      replyToUserId: _replyToUserId ?? 0,
    );
    _clearReply();
    await _loadComments();
  }

  Future<void> _togglePostLike() async {
    final pid = widget.postId;
    if (pid == null) {
      setState(() => _liked = !_liked);
      return;
    }
    final next = !_liked;
    final label = await FeedApi.toggleLike(pid, like: next);
    if (!mounted || label == null) return;
    setState(() {
      _liked = next;
      _likesLabel = label;
    });
  }

  Future<void> _togglePostBookmark() async {
    final pid = widget.postId;
    if (pid == null) {
      setState(() => _bookmarked = !_bookmarked);
      return;
    }
    final next = !_bookmarked;
    final label = await FeedApi.toggleBookmark(pid, bookmark: next);
    if (!mounted || label == null) return;
    setState(() {
      _bookmarked = next;
      _followed = next;
      _bookmarksLabel = label;
    });
  }

  Future<void> _toggleFollow() async {
    final pid = widget.postId;
    if (pid == null) {
      setState(() => _followed = !_followed);
      return;
    }
    final next = !_followed;
    final label = await FeedApi.toggleBookmark(pid, bookmark: next);
    if (!mounted || label == null) return;
    setState(() {
      _followed = next;
      _bookmarked = next;
      _bookmarksLabel = label;
    });
  }

  Future<void> _toggleCommentLike(int id) async {
    final on = _likedComments.contains(id);
    final label = await FeedApi.toggleCommentLike(id, like: !on);
    if (label == null) return;
    setState(() {
      if (on) {
        _likedComments.remove(id);
      } else {
        _likedComments.add(id);
      }
    });
    if (widget.postId != null) await _loadComments();
  }

  void _clearReply() => setState(() {
        _replyTo = null;
        _replyParentId = null;
        _replyToUserId = null;
        _commentInput.clear();
      });

  void _scrollToComments() {
    final ctx = _commentsAnchor.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic, alignment: 0);
    }
  }

  Future<void> _showPostModeration() async {
    final d = widget.data;
    final authorId = d.author.userId;
    await showModerationActionSheet(
      context,
      title: '帖子操作',
      userId: authorId > 0 ? authorId : null,
      userName: d.author.name,
      targetType: 'post',
      targetId: '${widget.postId ?? 0}',
      contentPreview: d.title,
      onBlocked: widget.onBack,
    );
  }

  Future<void> _reportComment(CommentRowView row) async {
    await showModerationActionSheet(
      context,
      title: '评论操作',
      userId: row.userId > 0 ? row.userId : null,
      userName: row.name,
      targetType: 'comment',
      targetId: '${row.id}',
      contentPreview: row.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Column(
      children: [
        PostDetailHead(
          data: d,
          followed: _followed,
          onBack: widget.onBack,
          onFollowToggle: _toggleFollow,
          onAuthorTap: widget.onAuthorTap,
          onMore: ApiConfig.isLoggedIn ? _showPostModeration : null,
        ),
        Expanded(
          child: MirrorScrollView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PostCarousel(slides: d.slides, intervalMs: d.intervalMs),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.title, style: MirrorTheme.sans(fontSize: 17, weight: FontWeight.w500, height: 1.35, letterSpacing: -0.015)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 12, color: MirrorColors.text3),
                          const SizedBox(width: 8),
                          Text(d.meta, style: MirrorTheme.mono(fontSize: 10, letterSpacing: 0.02, color: MirrorColors.text3)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (d.sharedKb != null) ...[
                        _KbSubscribeCard(
                          kb: d.sharedKb!,
                          subscribed: _kbSubscribed,
                          subscribing: _kbSubscribing,
                          onSubscribe: () => _onKbSubscribe(d.sharedKb!),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (d.blocks.isNotEmpty) PostBodyBlocksView(blocks: d.blocks),
                      if (d.markdownBody != null && d.markdownBody!.trim().isNotEmpty)
                        MirrorMarkdownBody(source: d.markdownBody!),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: d.tags.map((t) => MirrorChip(t, variant: ChipVariant.accent)).toList(),
                      ),
                      const SizedBox(height: 20),
                      _CommentsSectionInline(
                        key: _commentsAnchor,
                        commentCount: _commentsLabel.isEmpty ? d.actions.comments : _commentsLabel,
                        liked: _likedComments,
                        onLikeToggle: _toggleCommentLike,
                        onReply: (name, {parentId = 0, userId = 0}) => _startReply(
                          name,
                          parentId: parentId > 0 ? parentId : null,
                          replyUserId: userId > 0 ? userId : null,
                        ),
                        onReportComment: _reportComment,
                        rows: widget.postId != null ? _commentRows : null,
                        commentsLoaded: _commentsLoaded,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _actionsBar(d),
      ],
    );
  }

  Widget _block(PostBodyBlock b) {
    switch (b.type) {
      case PostBodyBlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(b.text, style: MirrorTheme.sans(fontSize: 13, height: 1.7, letterSpacing: -0.003)),
        );
      case PostBodyBlockType.callout:
        final c = b.callout!;
        return _callout(c.icon, c.variant, c.body);
      case PostBodyBlockType.compare:
        final c = b.compare!;
        return _compare(c.badTitle, c.bad, c.goodTitle, c.good);
      case PostBodyBlockType.code:
        return _codeSnip(b.code!);
      case PostBodyBlockType.stats:
        return _statsRow(b.stats!);
    }
  }

  Widget _callout(IconData icon, CalloutVariant v, String body) {
    Color border;
    Color bg;
    Color fg;
    switch (v) {
      case CalloutVariant.amber:
        border = MirrorColors.amber;
        bg = MirrorColors.amberSoft;
        fg = const Color(0xFF5D3508);
      case CalloutVariant.green:
        border = MirrorColors.green;
        bg = MirrorColors.greenSoft;
        fg = MirrorColors.greenText;
      case CalloutVariant.accent:
        border = MirrorColors.accent;
        bg = MirrorColors.accentSoft;
        fg = MirrorColors.accentDeep;
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border(left: BorderSide(color: border, width: 3)),
        borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 8),
          Expanded(child: Text(body, style: MirrorTheme.sans(fontSize: 12.5, height: 1.6, color: fg))),
        ],
      ),
    );
  }

  Widget _compare(String badH, String bad, String goodH, String good) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(child: _compareCol(badH, bad, const Color(0xFFFEE2E2), const Color(0xFF7F1D1D), const Color(0xFFFECACA))),
            const SizedBox(width: 8),
            Expanded(child: _compareCol(goodH, good, MirrorColors.greenSoft, MirrorColors.greenText, const Color(0xFFC7E9DA))),
          ],
        ),
      );

  Widget _compareCol(String h, String t, Color bg, Color fg, Color border) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(h, style: MirrorTheme.mono(fontSize: 9.5, letterSpacing: 0.06, color: fg.withValues(alpha: 0.7))),
            const SizedBox(height: 5),
            Text(t, style: MirrorTheme.sans(fontSize: 11.5, height: 1.5, color: fg)),
          ],
        ),
      );

  Widget _codeSnip(String code) => Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: MirrorColors.bgCard, borderRadius: BorderRadius.circular(8)),
        child: Text(code, style: MirrorTheme.mono(fontSize: 11, height: 1.7, color: MirrorColors.text)),
      );

  Widget _statsRow(List<({String v, String k})> items) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: MirrorColors.bgSoft,
                    border: Border.all(color: MirrorColors.borderSoft),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(items[i].v, style: MirrorTheme.sans(fontSize: 18, weight: FontWeight.w500, color: MirrorColors.accent, letterSpacing: -0.02)),
                      const SizedBox(height: 4),
                      Text(items[i].k, style: MirrorTheme.mono(fontSize: 9, letterSpacing: 0.04, color: MirrorColors.text3)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );

  Widget _actionsBar(PostDetailData d) {
    final hint = _replyTo == null ? '说点什么…' : '回复 $_replyTo…';
    final commentsLabel = _commentsLabel.isEmpty ? d.actions.comments : _commentsLabel;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      decoration: const BoxDecoration(
        color: MirrorColors.bgApp,
        border: Border(top: BorderSide(color: MirrorColors.borderSoft)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_replyTo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text('回复 $_replyTo', style: MirrorTheme.mono(fontSize: 10, color: MirrorColors.accent, letterSpacing: 0)),
                  const Spacer(),
                  MirrorPressable(
                    onTap: _clearReply,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text('取消', style: MirrorTheme.sans(fontSize: 11, color: MirrorColors.text3)),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: MirrorColors.bgSoft,
                    border: Border.all(color: MirrorColors.border),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: TextField(
                    controller: _commentInput,
                    focusNode: _commentFocus,
                    onSubmitted: (_) => _submitComment(),
                    style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: hint,
                      hintStyle: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text3),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),
          const SizedBox(width: 12),
          _act(
            icon: _liked ? Icons.favorite : Icons.favorite_border,
            label: _likesLabel,
            on: _liked,
            color: MirrorColors.pink,
            onTap: _togglePostLike,
          ),
          _act(
            icon: _bookmarked ? Icons.bookmark : Icons.bookmark_border,
            label: _bookmarksLabel,
            on: _bookmarked,
            color: d.actions.bookmarkAmber ? MirrorColors.amber : MirrorColors.text2,
            onTap: _togglePostBookmark,
          ),
          _act(icon: Icons.chat_bubble_outline, label: commentsLabel, onTap: _scrollToComments),
          if (widget.onShare != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: MirrorPressable(onTap: widget.onShare, child: const Icon(Icons.share_outlined, size: 19, color: MirrorColors.accent)),
            ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _act({required IconData icon, required String label, bool on = false, Color? color, VoidCallback? onTap}) {
    final c = on ? (color ?? MirrorColors.pink) : MirrorColors.text2;
    return MirrorPressable(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        width: 32,
        child: Column(
          children: [
            Icon(icon, size: 19, color: c),
            const SizedBox(height: 1),
            Text(label, style: MirrorTheme.mono(fontSize: 9.5, color: c, letterSpacing: 0)),
          ],
        ),
      ),
    );
  }
}

/// 帖子正文下方完整评论区（下滑即见）
class _CommentsSectionInline extends StatelessWidget {
  const _CommentsSectionInline({
    super.key,
    required this.commentCount,
    required this.liked,
    required this.onLikeToggle,
    required this.onReply,
    this.onReportComment,
    this.rows,
    this.commentsLoaded,
  });

  final String commentCount;
  final Set<int> liked;
  final void Function(int id) onLikeToggle;
  final void Function(String name, {int parentId, int userId}) onReply;
  final void Function(CommentRowView row)? onReportComment;
  final List<CommentRowView>? rows;
  final bool? commentsLoaded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('评论', style: MirrorTheme.sans(fontSize: 14, weight: FontWeight.w500, letterSpacing: -0.01)),
            const SizedBox(width: 6),
            Text('共 $commentCount 条', style: MirrorTheme.mono(fontSize: 10, color: MirrorColors.text3, letterSpacing: 0)),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, color: MirrorColors.borderSoft),
        CommentsThreadList(
          liked: liked,
          onLikeToggle: onLikeToggle,
          onReply: onReply,
          onReportComment: onReportComment,
          rows: rows,
          commentsLoaded: commentsLoaded,
        ),
      ],
    );
  }
}

/// 画廊与默认导航入口
class PostScreen extends StatefulWidget {
  const PostScreen({
    super.key,
    this.detailId = PostDetailId.soul,
    this.postId,
    this.sharedKb,
    this.onBack,
    this.onShare,
    this.onAuthorTap,
  });

  final PostDetailId detailId;
  final int? postId;
  final SharedKnowledgeBaseInfo? sharedKb;
  final VoidCallback? onBack;
  final VoidCallback? onShare;
  final VoidCallback? onAuthorTap;

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  PostDetailData? _data;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    if (widget.postId == null) {
      final base = PostDetailData.byId(widget.detailId);
      _data = widget.sharedKb != null
          ? PostDetailData(
              id: base.id,
              author: base.author,
              slides: base.slides,
              intervalMs: base.intervalMs,
              title: base.title,
              meta: base.meta,
              blocks: base.blocks,
              tags: base.tags,
              actions: base.actions,
              markdownBody: base.markdownBody,
              sharedKb: widget.sharedKb,
            )
          : base;
    } else {
      _loading = true;
      _loadPost(widget.postId!);
    }
  }

  Future<void> _loadPost(int id) async {
    final dto = await FeedApi.fetchPost(id);
    if (!mounted) return;
    var data = dto != null ? _buildFromDto(dto) : PostDetailData.byId(widget.detailId);
    // 详情 API 含实时 ready_doc_count；列表卡片默认 docCount=0，不可覆盖 API。
    final kb = data.sharedKb ?? widget.sharedKb;
    if (kb != null) {
      data = PostDetailData(
        id: data.id,
        author: data.author,
        slides: data.slides,
        intervalMs: data.intervalMs,
        title: data.title,
        meta: data.meta,
        blocks: data.blocks,
        tags: data.tags,
        actions: data.actions,
        markdownBody: data.markdownBody,
        sharedKb: kb,
      );
    }
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  static PostDetailId? _detailIdFromKey(String? key) => switch (key) {
        'soul' => PostDetailId.soul,
        'skill' => PostDetailId.skill,
        'review' => PostDetailId.review,
        'night_case' => PostDetailId.nightCase,
        _ => null,
      };

  PostDetailData _buildFromDto(FeedPostDetailDto dto) {
    final a = dto.author;
    final envelope = PostBodyEnvelopeCodec.parse(dto.body);
    final coverUrls = dedupeCoverUrls(
      envelope.coverImageUrls,
      dto.coverImageUrl?.trim() ?? '',
    );
    final slides = coverUrls.isEmpty
        ? [
            PostCarouselSlide(
              slideNum: '01',
              gradient: PostCarouselGradients.paper,
              lightOnDark: false,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  dto.title,
                  textAlign: TextAlign.center,
                  style: MirrorTheme.serif(fontSize: 16, weight: FontWeight.w500, height: 1.4),
                ),
              ),
            ),
          ]
        : [
            for (var i = 0; i < coverUrls.length; i++)
              PostCarouselSlide(
                slideNum: (i + 1).toString().padLeft(2, '0'),
                gradient: PostCarouselGradients.paper,
                lightOnDark: false,
                fullBleed: true,
                child: MirrorNetworkImage(url: coverUrls[i]),
              ),
          ];
    return PostDetailData(
      id: widget.detailId,
      author: PostAuthorInfo(
        av: a.avatarLetter,
        avGradient: authorGradient(a.avatarVariant),
        name: a.displayName,
        sub: a.subtitle.isNotEmpty ? a.subtitle : '@${a.handle}',
        avatarUrl: a.avatarUrl,
        followed: dto.followed || dto.actions.bookmarked,
        userId: a.userId,
      ),
      slides: slides,
      intervalMs: 4000,
      title: dto.title,
      meta: dto.meta,
      markdownBody: dto.markdownTail.isNotEmpty ? dto.markdownTail : null,
      blocks: dto.parsedBlocks,
      sharedKb: _sharedKbFromDto(dto),
      tags: dto.tags,
      actions: PostActionsState(
        likes: dto.actions.likesLabel,
        bookmarks: dto.actions.bookmarksLabel,
        comments: dto.actions.commentsLabel,
        liked: dto.actions.liked,
        bookmarked: dto.actions.bookmarked || dto.followed,
        bookmarkAmber: dto.actions.bookmarked || dto.followed,
      ),
    );
  }

  SharedKnowledgeBaseInfo? _sharedKbFromDto(FeedPostDetailDto dto) {
    final kb = dto.sharedKb;
    if (kb == null || kb.kbId.isEmpty) return null;
    final authorName = dto.author.displayName.isNotEmpty ? dto.author.displayName : dto.author.handle;
    final label = kb.name.isNotEmpty ? kb.name : (PersonalKbCatalog.labelFor(kb.kbId) ?? '知识库');
    final isOwn = dto.author.userId > 0 && dto.author.userId == ApiConfig.userId;
    return PersonalKbCatalog.toSharedInfo(
      kbId: kb.kbId,
      kbLabel: label,
      authorName: authorName,
      docCount: kb.readyDocCount,
      isOwnKb: isOwn,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _data == null) {
      return const Column(
        children: [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      );
    }
    return PostDetailScreen(
      data: _data!,
      postId: widget.postId,
      onBack: widget.onBack,
      onShare: widget.onShare,
      onAuthorTap: widget.onAuthorTap,
    );
  }
}

class PostDetailHead extends StatelessWidget {
  const PostDetailHead({
    super.key,
    required this.data,
    required this.followed,
    this.onBack,
    this.onFollowToggle,
    this.onAuthorTap,
    this.onMore,
  });

  final PostDetailData data;
  final bool followed;
  final VoidCallback? onBack;
  final VoidCallback? onFollowToggle;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final a = data.author;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 2, 14, 10),
      decoration: const BoxDecoration(
        color: MirrorColors.bgApp,
        border: Border(bottom: BorderSide(color: MirrorColors.borderSoft)),
      ),
      child: Row(
        children: [
          MirrorBackButton(onTap: onBack),
          const SizedBox(width: 4),
          MirrorPressable(
            onTap: onAuthorTap,
            borderRadius: BorderRadius.circular(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MirrorUserAvatar(
                  size: 30,
                  letter: a.av,
                  avatarUrl: a.avatarUrl,
                  gradient: a.avGradient,
                  fontSize: 13,
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: MirrorTheme.sans(fontSize: 13, weight: FontWeight.w500, letterSpacing: -0.005)),
                    Text(a.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: MirrorTheme.mono(fontSize: 10, letterSpacing: 0.02, color: MirrorColors.text3)),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          if (onMore != null)
            IconButton(
              icon: const Icon(Icons.more_horiz, size: 20, color: MirrorColors.text3),
              onPressed: onMore,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          if (onMore != null) const SizedBox(width: 4),
          GestureDetector(
            onTap: onFollowToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: followed ? MirrorColors.bgCard : MirrorColors.accent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                followed ? '已关注' : '关注',
                style: MirrorTheme.sans(fontSize: 11, weight: FontWeight.w500, color: followed ? MirrorColors.text2 : Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KbSubscribeCard extends StatelessWidget {
  const _KbSubscribeCard({
    required this.kb,
    required this.subscribed,
    required this.subscribing,
    required this.onSubscribe,
  });

  final SharedKnowledgeBaseInfo kb;
  final bool subscribed;
  final bool subscribing;
  final VoidCallback onSubscribe;

  String get _actionLabel {
    if (kb.isOwnKb) return '你的知识库 · 前往「个人知识库」';
    if (subscribed) return '已订阅 · 可在知识库「订阅」中查看';
    if (!kb.canSubscribe) return '暂无可订阅文档';
    return '订阅知识库';
  }

  @override
  Widget build(BuildContext context) {
    final canTap = !subscribed && kb.canSubscribe && !subscribing;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MirrorColors.blueSoft,
        border: Border.all(color: MirrorColors.blue.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.menu_book_outlined, size: 18, color: MirrorColors.blue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('附带知识库', style: MirrorTheme.mono(fontSize: 9, color: MirrorColors.blueText, letterSpacing: 0.04)),
                    Text(kb.name, style: MirrorTheme.sans(fontSize: 14, weight: FontWeight.w600)),
                    Text('${kb.docCount} 篇 · ${kb.author}', style: MirrorTheme.sans(fontSize: 11, color: MirrorColors.text3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(kb.summary, style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text2, height: 1.45)),
          const SizedBox(height: 12),
          MirrorPressable(
            onTap: canTap ? onSubscribe : null,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: subscribed || !kb.canSubscribe
                    ? MirrorColors.bgApp
                    : MirrorColors.blue,
                borderRadius: BorderRadius.circular(10),
                border: subscribed || !kb.canSubscribe
                    ? Border.all(color: MirrorColors.border)
                    : null,
              ),
              child: subscribing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _actionLabel,
                      style: MirrorTheme.sans(
                        fontSize: 13,
                        weight: FontWeight.w600,
                        color: subscribed || !kb.canSubscribe
                            ? MirrorColors.text2
                            : Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
