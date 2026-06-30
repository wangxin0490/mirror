import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/chat_api.dart';
import '../api/contacts_api.dart';
import '../config/api_config.dart';
import '../models/chat_models.dart';
import '../models/contacts_models.dart';
import '../state/dm_thread_store.dart';
import '../data/mirror_authors.dart';
import '../utils/dm_share_message.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../widgets/mirror_pressable.dart';
import '../widgets/mirror_scroll.dart';
import '../widgets/phone_components.dart';
import '../api/feed_api.dart';
import '../api/kb_api.dart';
import '../models/feed_models.dart';
import '../models/kb_models.dart';
import '../state/kb_store.dart';
import '../utils/media_url.dart';
import '../layout/adaptive_layout.dart';
import '../widgets/mirror_network_image.dart';
import '../widgets/mirror_user_avatar.dart';
import '../config/feed_search_history.dart';
import 'mirror_feed_data.dart';
import 'post_detail_data.dart';
import 'post_detail_screen.dart';

// ─── S4 Feed（生态圈）────────────────────────────────────────────
class FeedScreen extends StatefulWidget {
  const FeedScreen({
    super.key,
    this.pill = FeedPill.rec,
    this.onPillChanged,
    this.onPostTap,
    this.onAuthorTap,
    this.onComposeTap,
    this.onRegisterRefresh,
  });

  final FeedPill pill;
  final ValueChanged<FeedPill>? onPillChanged;
  final void Function(FeedCardData card)? onPostTap;
  final void Function(FeedCardData card)? onAuthorTap;
  final VoidCallback? onComposeTap;

  /// 注册列表刷新函数（发帖成功后调用）。
  final void Function(VoidCallback refresh)? onRegisterRefresh;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late FeedPill _pill;
  bool _searchOpen = false;
  List<String> _searchHistory = [];
  bool _loading = true;
  bool _loadFailed = false;
  List<FeedCardData> _cards = [];
  List<KbExploreItem> _kbSearchResults = [];
  String? _kbSearchCursor;
  bool _kbSearchHasMore = false;
  String _feedSearchQuery = '';
  bool _kbSearchLoadingMore = false;
  final Map<FeedPill, List<FeedCardData>> _pillCache = {};
  List<(String, String, bool)> _hotTags = MirrorFeedData.searchHotTags;
  late final AnimationController _searchCtrl;
  late final Animation<Offset> _searchSlide;
  late final Animation<double> _searchFade;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  static String _tabParam(FeedPill p) => switch (p) {
    FeedPill.rec => 'recommend',
    FeedPill.fol => 'following',
  };

  @override
  void initState() {
    super.initState();
    _pill = widget.pill;
    if (MirrorFeedData.preferPrototypeOverApi) {
      _cards = MirrorFeedData.forPill(_pill);
      _pillCache[_pill] = _cards;
      _loading = false;
    }
    _loadSearchHistory();
    _searchCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    final curve = CurvedAnimation(parent: _searchCtrl, curve: Curves.ease);
    _searchSlide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(curve);
    _searchFade = Tween<double>(begin: 0, end: 1).animate(curve);
    _load();
    _loadHotTags();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onRegisterRefresh?.call(_refreshAfterPublish);
    });
  }

  void _refreshAfterPublish() {
    _pillCache.clear();
    _load(forceSpinner: true);
  }

  @override
  void didUpdateWidget(FeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pill != widget.pill && widget.pill != _pill) {
      _clearSearchOnPillChange();
      _pill = widget.pill;
      _load();
    }
  }

  Future<void> _loadSearchHistory() async {
    final h = await FeedSearchHistory.load();
    if (!mounted) return;
    setState(() => _searchHistory = h);
  }

  Future<void> _load({bool forceSpinner = false}) async {
    // 原型演示：仅用本地数据，不请求后端，避免旧接口数据覆盖 UI
    if (MirrorFeedData.preferPrototypeOverApi) {
      final cards = MirrorFeedData.forPill(_pill);
      _pillCache[_pill] = cards;
      if (mounted) {
        setState(() {
          _cards = cards;
          _loading = false;
          _loadFailed = false;
        });
      }
      return;
    }

    final cached = _pillCache[_pill];
    if (!forceSpinner && cached != null) {
      setState(() {
        _cards = cached;
        _loading = false;
        _loadFailed = false;
      });
    } else if (_cards.isEmpty) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }
    final dtos = await FeedApi.fetchPosts(tab: _tabParam(_pill));
    if (!mounted) return;
    final apiCards = dtos?.map((e) => e.toFeedCardData()).toList() ?? [];
    final cards = apiCards.isEmpty ? MirrorFeedData.forPill(_pill) : apiCards;
    _pillCache[_pill] = cards;
    setState(() {
      _loadFailed = dtos == null && apiCards.isEmpty;
      _cards = cards;
      _loading = false;
      _kbSearchResults = [];
      _kbSearchCursor = null;
      _kbSearchHasMore = false;
      _feedSearchQuery = '';
    });
  }

  String _emptyHint() {
    if (_feedSearchQuery.isNotEmpty) {
      return '未找到匹配的笔记或知识库';
    }
    if (_loadFailed) return '加载失败，请确认后端已启动\n（go run ./cmd/server）';
    return switch (_pill) {
      FeedPill.fol => '还没有关注任何笔记\n在帖子详情点击「关注」即可收藏到这里',
      FeedPill.rec => '暂无推荐内容',
    };
  }

  Future<void> _loadHotTags() async {
    final tags = await FeedApi.fetchHotTags();
    if (!mounted || tags.isEmpty) return;
    setState(() {
      _hotTags = tags.map((t) => (t.rank, t.tag, t.isHot)).toList();
    });
  }

  Future<void> _runSearch(String q) async {
    final query = q.trim();
    if (query.isEmpty) return;
    await FeedSearchHistory.add(query);
    await _loadSearchHistory();
    setState(() {
      _loading = true;
      _loadFailed = false;
      _feedSearchQuery = query;
    });
    List<FeedPostCardDto> dtos = [];
    KbPaginatedExploreResponse? kbPage;
    final results = await Future.wait([
      if (MirrorFeedData.preferPrototypeOverApi)
        Future<List<FeedPostCardDto>>.value(const [])
      else
        FeedApi.search(query),
      KbApi.searchExplore(q: query),
    ]);
    dtos = results[0] as List<FeedPostCardDto>;
    kbPage = results[1] as KbPaginatedExploreResponse?;
    if (!mounted) return;
    setState(() {
      _cards = dtos.map((e) => e.toFeedCardData()).toList();
      _kbSearchResults = kbPage?.items ?? [];
      _kbSearchCursor = (kbPage?.nextCursor.isEmpty ?? true) ? null : kbPage!.nextCursor;
      _kbSearchHasMore = kbPage?.hasMore ?? false;
      _loading = false;
    });
    widget.onPillChanged?.call(_pill);
    // 收起搜索层但保留输入框关键词，便于再次编辑
    _toggleSearch(open: false, restoreFeedOnClose: false);
  }

  Future<void> _loadMoreKbSearch() async {
    if (!_kbSearchHasMore || _kbSearchLoadingMore || _feedSearchQuery.isEmpty) return;
    setState(() => _kbSearchLoadingMore = true);
    final page = await KbApi.searchExplore(q: _feedSearchQuery, cursor: _kbSearchCursor);
    if (!mounted) return;
    setState(() {
      if (page != null) {
        _kbSearchResults = [..._kbSearchResults, ...page.items];
        _kbSearchCursor = page.nextCursor.isEmpty ? null : page.nextCursor;
        _kbSearchHasMore = page.hasMore;
      }
      _kbSearchLoadingMore = false;
    });
  }

  Future<void> _subscribeKbFromSearch(KbExploreItem item, int index) async {
    final result = await KbStore.instance.subscribe(item.id);
    if (!mounted) return;
    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? '订阅失败')),
      );
      return;
    }
    setState(() {
      _kbSearchResults[index] = KbExploreItem(
        id: item.id,
        name: item.name,
        ownerName: item.ownerName,
        ownerHandle: item.ownerHandle,
        subscriberCount: item.subscriberCount,
        docCount: item.docCount,
        readyDocCount: item.readyDocCount,
        subscribed: true,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('订阅成功')),
    );
  }

  Widget _buildKbSearchSection() {
    return Container(
      decoration: const BoxDecoration(
        color: MirrorColors.bgApp,
        border: Border(bottom: BorderSide(color: MirrorColors.borderSoft)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '知识库',
            style: MirrorTheme.sans(
              fontSize: 13,
              weight: FontWeight.w600,
              color: MirrorColors.text2,
            ),
          ),
          const SizedBox(height: 10),
          if (_kbSearchResults.isEmpty)
            Text(
              '未找到相关知识库',
              style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text3),
            ),
          for (var i = 0; i < _kbSearchResults.length; i++)
            _buildKbSearchTile(_kbSearchResults[i], i),
          if (_kbSearchHasMore)
            Center(
              child: TextButton(
                onPressed: _kbSearchLoadingMore ? null : _loadMoreKbSearch,
                child: Text(_kbSearchLoadingMore ? '加载中…' : '加载更多知识库'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKbSearchTile(KbExploreItem item, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MirrorPressable(
        onTap: item.subscribed
            ? null
            : () => _subscribeKbFromSearch(item, index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: MirrorColors.borderSoft),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: MirrorColors.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.folder_outlined,
                  color: MirrorColors.accentDeep,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: MirrorTheme.sans(
                        fontSize: 14,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.metaLine,
                      style: MirrorTheme.sans(
                        fontSize: 11,
                        color: MirrorColors.text3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                item.subscribed
                    ? Icons.check_circle_outline
                    : Icons.add_circle_outline,
                size: 20,
                color: item.subscribed ? MirrorColors.green : MirrorColors.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedSearchNotesHeader() {
    return Container(
      width: double.infinity,
      color: MirrorColors.bgSoft,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Text(
        '笔记',
        style: MirrorTheme.sans(
          fontSize: 13,
          weight: FontWeight.w600,
          color: MirrorColors.text2,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchInputChanged(String v) {
    if (v.trim().isNotEmpty) return;
    if (_feedSearchQuery.isEmpty && _kbSearchResults.isEmpty) return;
    _feedSearchQuery = '';
    _load();
  }

  /// 切换推荐/关注 Tab 时清空搜索框与搜索结果。
  void _clearSearchOnPillChange() {
    _searchController.clear();
    _feedSearchQuery = '';
    _kbSearchResults = [];
    _kbSearchCursor = null;
    _kbSearchHasMore = false;
    _kbSearchLoadingMore = false;
    if (_searchOpen) {
      _searchFocus.unfocus();
      _searchCtrl.reverse();
      _searchOpen = false;
    }
  }

  void _toggleSearch({bool? open, bool restoreFeedOnClose = false}) {
    final next = open ?? !_searchOpen;
    if (next) {
      setState(() => _searchOpen = true);
      _searchCtrl.forward();
      Future.delayed(const Duration(milliseconds: 260), () {
        if (mounted && _searchOpen) _searchFocus.requestFocus();
      });
    } else {
      _searchFocus.unfocus();
      final hadSearchResults =
          _feedSearchQuery.isNotEmpty || _kbSearchResults.isNotEmpty;
      if (restoreFeedOnClose) {
        _searchController.clear();
      }
      _searchCtrl.reverse().whenComplete(() {
        if (!mounted) return;
        setState(() => _searchOpen = false);
        if (restoreFeedOnClose && hadSearchResults) {
          _load();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cards = _cards;
    // 对齐 hermes：search-drawer 浮在 feed-head 上方滑入，feed-head 始终保留小放大镜
    final searchBlocking = _searchOpen || _searchCtrl.isAnimating;
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        IgnorePointer(
          ignoring: searchBlocking,
          child: Column(
            children: [
              _buildFeedHead(),
              Expanded(child: _buildFeedBody(cards)),
            ],
          ),
        ),
        if (searchBlocking)
          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeTransition(
                  opacity: _searchFade,
                  child: SlideTransition(
                    position: _searchSlide,
                    child: _FeedSearchDrawer(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      onChanged: _onSearchInputChanged,
                      onCancel: () => _toggleSearch(open: false, restoreFeedOnClose: true),
                      hotTags: _hotTags,
                      recentSearches: _searchHistory,
                      onHistoryTap: (t) {
                        _searchController.text = t;
                        _runSearch(t);
                      },
                      onHistoryRemove: (t) async {
                        await FeedSearchHistory.remove(t);
                        await _loadSearchHistory();
                      },
                      onTagTap: (t) {
                        _searchController.text = t;
                        _runSearch(t);
                      },
                      onSubmitted: _runSearch,
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _toggleSearch(open: false),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// `.feed-head` — padding 8px 16px 10px，右侧仅 18px 搜索图标
  Widget _buildFeedHead() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: MirrorColors.bgApp,
        border: Border(bottom: BorderSide(color: MirrorColors.borderSoft)),
      ),
      child: Row(
        children: [
          Row(
            children: [
              Text(
                '发现',
                style: MirrorTheme.sans(
                  fontSize: 18,
                  weight: FontWeight.w700,
                  letterSpacing: -0.02,
                ),
              ),
              if (MirrorFeedData.preferPrototypeOverApi) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: MirrorColors.accentSoft,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '演示',
                    style: MirrorTheme.mono(
                      fontSize: 9,
                      color: MirrorColors.accentDeep,
                      letterSpacing: 0.02,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [
                _pillTab('推荐', FeedPill.rec),
                _pillTab('关注', FeedPill.fol),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _toggleSearch(open: true),
            behavior: HitTestBehavior.opaque,
            child: const Icon(
              Icons.search,
              size: 18,
              color: MirrorColors.text2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedBody(List<FeedCardData> cards) {
    if (_loading) {
      return const ColoredBox(
        color: MirrorColors.bgSoft,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (cards.isEmpty && _kbSearchResults.isEmpty) {
      return ColoredBox(
        color: MirrorColors.bgSoft,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _emptyHint(),
                  textAlign: TextAlign.center,
                  style: MirrorTheme.sans(
                    fontSize: 13,
                    color: MirrorColors.text3,
                    height: 1.5,
                  ),
                ),
                if (_loadFailed) ...[
                  const SizedBox(height: 12),
                  MirrorPressable(
                    onTap: _load,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: MirrorColors.accent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '重试',
                        style: MirrorTheme.sans(
                          fontSize: 12,
                          color: Colors.white,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ColoredBox(
          color: MirrorColors.bgSoft,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: ScrollConfiguration(
              key: ValueKey('${_pill}_${cards.length}_${_kbSearchResults.length}'),
              behavior: const MirrorScrollBehavior(),
              child: CustomScrollView(
                slivers: [
                  if (_feedSearchQuery.isNotEmpty)
                    SliverToBoxAdapter(child: _buildKbSearchSection()),
                  if (_feedSearchQuery.isNotEmpty && cards.isNotEmpty)
                    SliverToBoxAdapter(child: _buildFeedSearchNotesHeader()),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      8,
                      _feedSearchQuery.isNotEmpty && cards.isNotEmpty ? 4 : 10,
                      8,
                      100,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, row) {
                          final left = row * 2;
                          final right = left + 1;
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: row < (cards.length / 2).ceil() - 1 ? 8 : 0,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _FeedCard(
                                    data: cards[left],
                                    onTap: widget.onPostTap == null
                                        ? null
                                        : () => widget.onPostTap!(cards[left]),
                                    onAuthorTap: widget.onAuthorTap == null
                                        ? null
                                        : () => widget.onAuthorTap!(cards[left]),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: right < cards.length
                                      ? _FeedCard(
                                          data: cards[right],
                                          onTap: widget.onPostTap == null
                                              ? null
                                              : () => widget.onPostTap!(cards[right]),
                                          onAuthorTap: widget.onAuthorTap == null
                                              ? null
                                              : () => widget.onAuthorTap!(cards[right]),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          );
                        },
                        childCount: cards.isEmpty ? 0 : (cards.length / 2).ceil(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: 14,
          bottom: 26,
          child: MirrorPressable(
            onTap: widget.onComposeTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: MirrorColors.accent,
                shape: BoxShape.circle,
                boxShadow: [MirrorShadows.fab],
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 22),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pillTab(String label, FeedPill pill) {
    final on = _pill == pill;
    return MirrorPressable(
      onTap: () {
        if (_pill != pill) {
          _clearSearchOnPillChange();
          setState(() => _pill = pill);
          widget.onPillChanged?.call(pill);
          _load();
        }
      },
      child: _pillLabel(label, on),
    );
  }

  Widget _pillLabel(String t, bool on) => Padding(
    padding: const EdgeInsets.only(right: 14),
    child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            t,
            style: MirrorTheme.sans(
              fontSize: 14,
              weight: FontWeight.w500,
              color: on ? MirrorColors.text : MirrorColors.text3,
              letterSpacing: -0.005,
            ),
          ),
        ),
        if (on)
          Positioned(
            bottom: -4,
            child: Container(
              width: 20,
              height: 3,
              decoration: BoxDecoration(
                color: MirrorColors.pink,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    ),
  );
}

/// `.search-drawer` — 白底、底边框、`.sb` 圆角输入框 + 取消 + 热搜
class _FeedSearchDrawer extends StatelessWidget {
  const _FeedSearchDrawer({
    required this.controller,
    required this.focusNode,
    required this.onCancel,
    required this.onTagTap,
    required this.onSubmitted,
    required this.hotTags,
    this.onChanged,
    this.recentSearches = const [],
    this.onHistoryTap,
    this.onHistoryRemove,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onCancel;
  final ValueChanged<String>? onChanged;
  final void Function(String) onTagTap;
  final void Function(String) onSubmitted;
  final List<(String, String, bool)> hotTags;
  final List<String> recentSearches;
  final void Function(String)? onHistoryTap;
  final void Function(String)? onHistoryRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MirrorColors.bgApp,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: MirrorColors.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: MirrorColors.bgSoft,
                      border: Border.all(color: MirrorColors.border),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search,
                          size: 15,
                          color: MirrorColors.text3,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: controller,
                            focusNode: focusNode,
                            onChanged: onChanged,
                            onSubmitted: onSubmitted,
                            style: MirrorTheme.sans(
                              fontSize: 12.5,
                              color: MirrorColors.text,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              isCollapsed: true,
                              hintText: '搜索笔记、知识库、用户…',
                              hintStyle: MirrorTheme.sans(
                                fontSize: 12.5,
                                color: MirrorColors.text3,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onCancel,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    '取消',
                    style: MirrorTheme.sans(
                      fontSize: 13,
                      color: MirrorColors.accent,
                      weight: MirrorFontWeight.medium,
                    ),
                  ),
                ),
              ],
            ),
            if (recentSearches.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '最近搜索',
                style: MirrorTheme.mono(
                  fontSize: 9.5,
                  color: MirrorColors.text3,
                  letterSpacing: 0.06,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final q in recentSearches)
                    Container(
                      decoration: BoxDecoration(
                        color: MirrorColors.bgSoft,
                        border: Border.all(color: MirrorColors.borderSoft),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MirrorPressable(
                            onTap: onHistoryTap == null ? null : () => onHistoryTap!(q),
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(14),
                            ),
                            padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
                            child: Text(
                              q,
                              style: MirrorTheme.sans(
                                fontSize: 11,
                                color: MirrorColors.text2,
                              ),
                            ),
                          ),
                          if (onHistoryRemove != null)
                            MirrorPressable(
                              onTap: () => onHistoryRemove!(q),
                              borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(14),
                              ),
                              padding: const EdgeInsets.fromLTRB(2, 4, 8, 4),
                              child: const Icon(
                                Icons.close,
                                size: 12,
                                color: MirrorColors.text3,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(
              '热搜 · TRENDING',
              style: MirrorTheme.mono(
                fontSize: 9.5,
                color: MirrorColors.text3,
                letterSpacing: 0.06,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in hotTags)
                  MirrorPressable(
                    onTap: () => onTagTap(tag.$2),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tag.$3
                            ? MirrorColors.pinkSoft
                            : MirrorColors.bgSoft,
                        border: Border.all(
                          color: tag.$3
                              ? Colors.transparent
                              : MirrorColors.borderSoft,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text.rich(
                        TextSpan(
                          style: MirrorTheme.sans(
                            fontSize: 11,
                            color: tag.$3
                                ? const Color(0xFF8C2950)
                                : MirrorColors.text2,
                          ),
                          children: [
                            TextSpan(
                              text: '${tag.$1} ',
                              style: MirrorTheme.mono(
                                fontSize: 9,
                                color: tag.$3
                                    ? MirrorColors.pink
                                    : MirrorColors.accent,
                                weight: MirrorFontWeight.medium,
                                letterSpacing: 0,
                              ),
                            ),
                            TextSpan(text: tag.$2),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedCard extends StatefulWidget {
  const _FeedCard({required this.data, this.onTap, this.onAuthorTap});

  final FeedCardData data;
  final VoidCallback? onTap;
  final VoidCallback? onAuthorTap;

  @override
  State<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<_FeedCard> {
  late bool _liked;
  late String _likesLabel;

  @override
  void initState() {
    super.initState();
    _liked = widget.data.liked;
    _likesLabel = widget.data.likes;
  }

  Future<void> _toggleLike() async {
    final id = widget.data.postId;
    if (id == null) {
      setState(() => _liked = !_liked);
      return;
    }
    final label = await FeedApi.toggleLike(id, like: !_liked);
    if (label != null && mounted) {
      setState(() {
        _liked = !_liked;
        _likesLabel = label;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return MirrorPressable(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: MirrorColors.bgApp,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              adaptiveAspectFrame(
                context: context,
                phoneHeight: data.cover.height,
                widthOverHeight: kPhoneContentWidth / data.cover.height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(gradient: data.cover.gradient),
                    ),
                    if (data.coverImageUrl != null &&
                        data.coverImageUrl!.trim().isNotEmpty)
                      Positioned.fill(
                        child: MirrorNetworkImage(
                          url: resolveMediaUrl(data.coverImageUrl!.trim()),
                        ),
                      ),
                    if (data.hotLabel ||
                        (data.topicTag != null && data.topicTag!.isNotEmpty))
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            data.hotLabel
                                ? (data.label.isNotEmpty ? data.label : '热门')
                                : data.topicTag!,
                            style: MirrorTheme.sans(
                              fontSize: 9,
                              color: Colors.white,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    if (data.coverImageUrl == null ||
                        data.coverImageUrl!.trim().isEmpty)
                      Center(
                        child: data.quote != null
                            ? Text(
                                data.quote!,
                                textAlign: TextAlign.center,
                                style: MirrorTheme.serif(
                                  fontSize: 14,
                                  weight: FontWeight.w500,
                                  color: Colors.white,
                                  style: FontStyle.italic,
                                  height: 1.4,
                                ).copyWith(letterSpacing: -0.01),
                              )
                            : Icon(
                                data.icon ?? Icons.article_outlined,
                                size: 38,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (data.subtitle != null && data.subtitle!.isNotEmpty) ...[
                      Text(
                        data.subtitle!,
                        style: MirrorTheme.mono(
                          fontSize: 9.5,
                          color: MirrorColors.text3,
                          letterSpacing: 0.02,
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    Text(
                      data.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: MirrorTheme.sans(
                        fontSize: 12.5,
                        weight: FontWeight.w600,
                        height: 1.38,
                        letterSpacing: -0.01,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        MirrorPressable(
                          onTap: widget.onAuthorTap,
                          borderRadius: BorderRadius.circular(12),
                          child: MirrorUserAvatar.variant(
                            size: 18,
                            letter: data.av,
                            avatarUrl: data.authorAvatarUrl ?? '',
                            variant: data.avVariant,
                            fontSize: 9,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: MirrorPressable(
                            onTap: widget.onAuthorTap,
                            child: Text(
                              data.authorName.isNotEmpty
                                  ? data.authorName
                                  : data.author,
                              style: MirrorTheme.sans(
                                fontSize: 10.5,
                                color: MirrorColors.text3,
                                weight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        _FeedLikes(
                          count: _likesLabel,
                          liked: _liked,
                          onTap: _toggleLike,
                        ),
                      ],
                    ),
                    if (data.hasSharedKb) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: MirrorColors.blueSoft.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.menu_book_outlined,
                              size: 11,
                              color: MirrorColors.blue,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                data.sharedKbName != null &&
                                        data.sharedKbName!.isNotEmpty
                                    ? '文末可订阅 · ${data.sharedKbName}'
                                    : '文末可订阅知识库',
                                style: MirrorTheme.sans(
                                  fontSize: 10,
                                  color: MirrorColors.blueText,
                                  weight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedLikes extends StatelessWidget {
  const _FeedLikes({required this.count, required this.liked, this.onTap});

  final String count;
  final bool liked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = liked ? MirrorColors.pink : MirrorColors.text3;
    return MirrorPressable(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            liked ? Icons.favorite : Icons.favorite_border,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            count,
            style: MirrorTheme.mono(
              fontSize: 10,
              color: color,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

// S6 PostScreen → lib/screens/post_detail_screen.dart（post-details-4.html）

// ─── S7 Share Sheet ────────────────────────────────────────────
class ShareSheetScreen extends StatefulWidget {
  const ShareSheetScreen({
    super.key,
    this.onDismiss,
    this.postId,
    this.previewCard,
    this.shareAuthor,
  });

  final VoidCallback? onDismiss;
  final int? postId;
  final FeedCardData? previewCard;
  /// 分享博主主页时传入：仅联系人 + 博主名片，无复制链接。
  final MirrorAuthor? shareAuthor;

  bool get _isProfileShare => shareAuthor != null && shareAuthor!.userId > 0;

  @override
  State<ShareSheetScreen> createState() => _ShareSheetScreenState();
}

class _ShareSheetScreenState extends State<ShareSheetScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  List<ChatConversationItem> _shareContacts = [];
  String? _shareUrl;
  bool _contactsLoading = true;
  int? _sharingPeerId;
  String? _hintMessage;
  Timer? _hintTimer;
  PostDetailData? _previewDetail;
  FeedCardData? _previewCard;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
    _slide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _loadTargets();
  }

  Future<void> _loadTargets() async {
    setState(() => _contactsLoading = true);
    final pid = widget.postId;
    final card = widget.previewCard;
    if (widget._isProfileShare) {
      final convRes = ApiConfig.isLoggedIn
          ? await ChatApi.fetchConversations(tab: 'all', limit: 20)
          : null;
      if (!mounted) return;
      setState(() {
        _contactsLoading = false;
        _shareContacts = convRes?.items ?? [];
      });
      return;
    }
    final results = await Future.wait<Object?>([
      ApiConfig.isLoggedIn
          ? ChatApi.fetchConversations(tab: 'all', limit: 20)
          : Future<ChatConversationListResponse?>.value(null),
      if (pid != null) FeedApi.fetchPost(pid) else Future<FeedPostDetailDto?>.value(null),
      if (pid != null)
        ContactsApi.createShareLink(resourceType: 'feed_post', resourceId: pid)
      else
        Future<String?>.value(null),
    ]);
    if (!mounted) return;
    final convRes = results[0] as ChatConversationListResponse?;
    final dto = results[1] as FeedPostDetailDto?;
    final link = results[2] as String?;
    setState(() {
      _contactsLoading = false;
      _shareContacts = convRes?.items ?? [];
      _shareUrl = link;
      _previewDetail = _buildPreviewDetail(dto, card);
      _previewCard = card ?? (dto != null ? _cardFromDto(dto) : null);
    });
  }

  PostDetailData? _buildPreviewDetail(FeedPostDetailDto? dto, FeedCardData? card) {
    if (dto != null) {
      final a = dto.author;
      return PostDetailData(
        id: PostDetailId.review,
        author: PostAuthorInfo(
          av: a.avatarLetter,
          avGradient: authorGradient(a.avatarVariant),
          name: a.displayName,
          sub: a.subtitle.isNotEmpty ? a.subtitle : (a.handle.isNotEmpty ? '@${a.handle}' : ''),
          avatarUrl: a.avatarUrl,
        ),
        slides: const [],
        intervalMs: 4000,
        title: dto.title,
        meta: dto.meta,
        blocks: const [],
        tags: const [],
        actions: const PostActionsState(likes: '', bookmarks: '', comments: ''),
      );
    }
    if (card != null) {
      final display = card.authorName.isNotEmpty ? card.authorName : card.author;
      return PostDetailData(
        id: card.detailId ?? PostDetailId.review,
        author: PostAuthorInfo(
          av: card.av,
          avGradient: card.cover.gradient,
          name: display,
          sub: card.subtitle ?? '',
          avatarUrl: card.authorAvatarUrl ?? '',
        ),
        slides: const [],
        intervalMs: 4000,
        title: card.title,
        meta: '',
        blocks: const [],
        tags: const [],
        actions: PostActionsState(likes: card.likes, bookmarks: '', comments: ''),
      );
    }
    return null;
  }

  FeedCardData _cardFromDto(FeedPostDetailDto dto) {
    final a = dto.author;
    final display = a.displayName.isNotEmpty ? a.displayName : a.handle;
    return FeedCardData(
      cover: FeedCover.h2,
      title: dto.title,
      av: a.avatarLetter,
      avVariant: FeedAvatarVariant.accent,
      author: display,
      authorName: display,
      likes: dto.actions.likesLabel,
      coverImageUrl: dto.coverImageUrl,
    );
  }

  void _toast(String msg, {Duration duration = const Duration(seconds: 1)}) {
    _hintTimer?.cancel();
    setState(() => _hintMessage = msg);
    _hintTimer = Timer(duration, () {
      if (mounted) setState(() => _hintMessage = null);
    });
  }

  Widget _shareHintOverlay() {
    final msg = _hintMessage;
    if (msg == null || msg.isEmpty) return const SizedBox.shrink();
    return Positioned(
      top: 36,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xE6282620),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                msg,
                style: MirrorTheme.sans(fontSize: 13, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  DmUserShare? _buildUserSharePayload() {
    final a = widget.shareAuthor;
    if (a == null || a.userId <= 0) return null;
    return DmUserShare(
      userId: a.userId,
      displayName: a.name,
      handle: a.handle,
      avatarLetter: a.av,
      avatarUrl: a.avatarUrl,
      avatarVariant: switch (a.variant) {
        FeedAvatarVariant.green => 'green',
        FeedAvatarVariant.pink => 'pink',
        FeedAvatarVariant.blue => 'blue',
        FeedAvatarVariant.amber => 'amber',
        FeedAvatarVariant.accent => 'accent',
      },
      tagline: a.tagline,
      bio: a.bio,
    );
  }

  DmFeedPostShare? _buildSharePayload() {
    final postId = widget.postId;
    if (postId == null || postId <= 0) return null;
    final card = _previewCard;
    final detail = _previewDetail;
    return DmFeedPostShare(
      postId: postId,
      title: detail?.title ?? card?.title ?? '分享内容',
      authorName: detail?.author.name ?? card?.authorName ?? card?.author ?? '',
      coverImageUrl: card?.coverImageUrl,
      quote: card?.quote,
      shareUrl: _shareUrl,
    );
  }

  Future<void> _copyPostShareLink() async {
    var url = _shareUrl;
    if ((url == null || url.isEmpty) && widget.postId != null && ApiConfig.isLoggedIn) {
      url = await ContactsApi.createShareLink(
        resourceType: 'feed_post',
        resourceId: widget.postId!,
      );
      if (mounted && url != null && url.isNotEmpty) {
        setState(() => _shareUrl = url);
      }
    }
    if (url == null || url.isEmpty) {
      if (!ApiConfig.isLoggedIn) {
        _toast('请先登录后再复制链接');
      } else {
        _toast('暂无分享链接');
      }
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    _toast('链接已复制');
  }

  Future<void> _shareToContact(ChatConversationItem contact) async {
    if (_sharingPeerId != null) return;
    if (!ApiConfig.isLoggedIn) {
      _toast('请先登录');
      return;
    }
    if (widget._isProfileShare) {
      await _shareUserToContact(contact);
      return;
    }
    final payload = _buildSharePayload();
    if (payload == null) {
      _toast('无法分享该内容');
      return;
    }
    if (contact.peerUserId <= 0 && contact.conversationId <= 0) {
      _toast('无法识别联系人');
      return;
    }

    setState(() => _sharingPeerId = contact.peerUserId);
    final r = await ChatApi.sendFeedPostShare(
      conversationId: contact.conversationId > 0 ? contact.conversationId : null,
      peerUserId: contact.conversationId > 0 ? null : contact.peerUserId,
      share: payload,
    );
    if (!mounted) return;
    setState(() => _sharingPeerId = null);

    if (!r.ok || r.data == null) {
      _toast(r.message.isNotEmpty ? r.message : '分享失败');
      return;
    }

    final preview = feedPostSharePreview(payload);
    DmThreadStore.instance.bumpThread(
      contact.threadKey,
      preview: preview,
      unread: false,
      conversationId: r.data!.conversationId > 0 ? r.data!.conversationId : contact.conversationId,
    );
    _toast('分享成功');
  }

  Future<void> _shareUserToContact(ChatConversationItem contact) async {
    final payload = _buildUserSharePayload();
    if (payload == null) {
      _toast('无法分享该博主');
      return;
    }
    if (contact.peerUserId <= 0 && contact.conversationId <= 0) {
      _toast('无法识别联系人');
      return;
    }

    setState(() => _sharingPeerId = contact.peerUserId);
    final r = await ChatApi.sendUserShare(
      conversationId: contact.conversationId > 0 ? contact.conversationId : null,
      peerUserId: contact.conversationId > 0 ? null : contact.peerUserId,
      share: payload,
    );
    if (!mounted) return;
    setState(() => _sharingPeerId = null);

    if (!r.ok || r.data == null) {
      _toast(r.message.isNotEmpty ? r.message : '分享失败');
      return;
    }

    final preview = userSharePreview(payload);
    DmThreadStore.instance.bumpThread(
      contact.threadKey,
      preview: preview,
      unread: false,
      conversationId: r.data!.conversationId > 0 ? r.data!.conversationId : contact.conversationId,
    );
    _toast('分享成功');
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Widget _profileSheetHead() {
    final a = widget.shareAuthor!;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 10),
      decoration: const BoxDecoration(
        color: MirrorColors.bgApp,
        border: Border(bottom: BorderSide(color: MirrorColors.borderSoft)),
      ),
      child: Row(
        children: [
          MirrorBackButton(onTap: widget.onDismiss),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '分享博主',
              style: MirrorTheme.sans(fontSize: 16, weight: FontWeight.w600),
            ),
          ),
          Text(
            a.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MirrorTheme.sans(fontSize: 13, color: MirrorColors.text3),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget._isProfileShare)
          _profileSheetHead()
        else
          Opacity(
            opacity: 0.5,
            child: PostDetailHead(
              data: _previewDetail ?? PostDetailData.soul,
              followed: false,
              onBack: widget.onDismiss,
            ),
          ),
        Expanded(
          child: GestureDetector(
            onTap: widget.onDismiss,
            child: ColoredBox(
              color: MirrorColors.overlayDim,
              child: Column(
                children: [
                  const Spacer(),
                  SlideTransition(
                    position: _slide,
                    child: GestureDetector(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                        decoration: const BoxDecoration(
                          color: MirrorColors.bgApp,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: MirrorColors.border,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _previewPin(),
                                const SizedBox(height: 16),
                                _favContacts(),
                                if (!widget._isProfileShare) ...[
                                  const SizedBox(height: 16),
                                  _postCopyLinkRow(),
                                ],
                                const SizedBox(height: 16),
                                MirrorPressable(
                                  onTap: widget.onDismiss,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                    decoration: BoxDecoration(
                                      color: MirrorColors.bgSoft,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '取消',
                                      style: MirrorTheme.sans(
                                        fontSize: 13.5,
                                        weight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            _shareHintOverlay(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _previewPin() {
    if (widget._isProfileShare) {
      return _profilePreviewPin(widget.shareAuthor!);
    }
    final card = _previewCard;
    final detail = _previewDetail;
    if (_contactsLoading && card == null && detail == null) {
      return Container(
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: MirrorColors.bgSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final title = detail?.title ?? card?.title ?? '分享内容';
    final author = detail?.author.name ?? card?.authorName ?? card?.author ?? '';
    final quote = card?.quote;
    final imageUrl = card?.coverImageUrl?.trim();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MirrorColors.bgSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _previewThumb(card: card, quote: quote, imageUrl: imageUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MirrorTheme.sans(fontSize: 13, weight: FontWeight.w500),
                ),
                if (author.isNotEmpty)
                  Text(
                    author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MirrorTheme.mono(fontSize: 10, letterSpacing: 0),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 动态详情分享：复制外链（无微信/飞书等渠道）。
  Widget _postCopyLinkRow() => MirrorPressable(
        onTap: _copyPostShareLink,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
          decoration: BoxDecoration(
            color: MirrorColors.bgSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MirrorColors.borderSoft),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.link, size: 18, color: MirrorColors.text2),
              const SizedBox(width: 8),
              Text(
                '复制链接',
                style: MirrorTheme.sans(
                  fontSize: 13.5,
                  weight: FontWeight.w500,
                  color: MirrorColors.text2,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _profilePreviewPin(MirrorAuthor author) {
    final handle = author.handle.replaceAll('@', '').trim();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MirrorColors.bgSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          MirrorUserAvatar(
            size: 48,
            letter: author.av,
            avatarUrl: author.avatarUrl,
            gradient: MirrorGradients.avatar(author.avatarColors),
            fontSize: 17,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  author.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MirrorTheme.sans(fontSize: 13, weight: FontWeight.w600),
                ),
                if (handle.isNotEmpty)
                  Text(
                    '@$handle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MirrorTheme.mono(fontSize: 10, letterSpacing: 0),
                  ),
                if (author.tagline.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      author.tagline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MirrorTheme.sans(fontSize: 11, color: MirrorColors.text3),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewThumb({FeedCardData? card, String? quote, String? imageUrl}) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 48,
          height: 48,
          child: MirrorNetworkImage(
            url: imageUrl,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    final gradient = card?.cover.gradient ?? MirrorGradients.pink;
    final label = (quote?.trim().isNotEmpty == true)
        ? quote!.trim()
        : (card?.title ?? '分享');
    return Container(
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: MirrorTheme.serif(fontSize: 8.5, color: Colors.white),
      ),
    );
  }

  Widget _favContacts() {
    if (_contactsLoading) {
      return const SizedBox(
        height: 72,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (!ApiConfig.isLoggedIn) {
      return SizedBox(
        height: 72,
        child: Center(
          child: Text(
            '登录后查看消息联系人',
            style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text3),
          ),
        ),
      );
    }
    if (_shareContacts.isEmpty) {
      return SizedBox(
        height: 72,
        child: Center(
          child: Text(
            '暂无消息联系人',
            style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text3),
          ),
        ),
      );
    }
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _shareContacts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 20),
        itemBuilder: (context, index) {
          final c = _shareContacts[index];
          final sharing = _sharingPeerId == c.peerUserId;
          final av = MirrorUserAvatar(
            size: 48,
            letter: c.avatarLetter,
            avatarUrl: c.avatarUrl,
            gradient: MirrorGradients.avatar(c.avatarColors),
            fontSize: 17,
          );
          return _fav(
            c.displayName,
            sharing
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(opacity: 0.45, child: av),
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  )
                : av,
            onTap: _sharingPeerId == null ? () => _shareToContact(c) : null,
          );
        },
      ),
    );
  }

  Widget _fav(String n, Widget av, {VoidCallback? onTap}) => MirrorPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            av,
            const SizedBox(height: 6),
            SizedBox(
              width: 56,
              child: Text(
                n,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MirrorTheme.sans(fontSize: 11, color: MirrorColors.text2),
              ),
            ),
          ],
        ),
      );

  // ─── end ShareSheetScreen ───
}

// ─── S8 Contacts ───────────────────────────────────────────────
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key, this.onBack, this.initialTabIndex = 0});

  final VoidCallback? onBack;

  /// 0 = 关注，1 = 粉丝
  final int initialTabIndex;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  static const _tabs = ['following', 'followers'];
  static const _avatarColors = [
    MirrorAvatars.a2,
    MirrorAvatars.a1,
    MirrorAvatars.a3,
    MirrorAvatars.a4,
    MirrorAvatars.a5,
    MirrorAvatars.a6,
  ];

  late int _tabIndex;
  bool _loading = true;
  bool _loadFailed = false;
  bool _searchMode = false;
  List<ContactUserCard> _users = [];
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _searchDebounce;
  static const _searchDebounceMs = 300;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTabIndex.clamp(0, _tabs.length - 1);
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
      _searchMode = false;
    });
    final res = await ContactsApi.fetchUsers(tab: _tabs[_tabIndex]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _loadFailed = res == null;
      _users = res?.items ?? [];
    });
  }

  void _applySearchInput(String v) {
    final q = v.trim();
    if (q.length < 2) {
      if (_searchMode) _load();
      return;
    }
    _runSearch(q);
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: _searchDebounceMs),
      () {
        if (!mounted) return;
        _applySearchInput(v);
      },
    );
  }

  void _onSearchSubmitted(String v) {
    _searchDebounce?.cancel();
    _applySearchInput(v);
  }

  Future<void> _runSearch(String q) async {
    if (q.trim().length < 2) return;
    setState(() {
      _loading = true;
      _searchMode = true;
      _loadFailed = false;
    });
    final items = await ContactsApi.search(q.trim());
    if (!mounted) return;
    setState(() {
      _loading = false;
      _users = items;
      _loadFailed = false;
    });
  }

  void _selectTab(int i) {
    if (_tabIndex == i) return;
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    setState(() => _tabIndex = i);
    _load();
  }

  Future<void> _toggleFollow(int index) async {
    final u = _users[index];
    if (u.userId <= 0) return;
    ContactFollowResult? res;
    if (u.canFollow) {
      res = await ContactsApi.follow(u.userId);
    } else if (u.followState == 'following' || u.followState == 'mutual') {
      res = await ContactsApi.unfollow(u.userId);
    } else {
      return;
    }
    if (!mounted || res == null) {
      _toast('操作失败');
      return;
    }
    final result = res;
    setState(() {
      _users[index] = u.copyWith(
        followState: result.followState,
        followButtonLabel: result.followButtonLabel,
      );
    });
  }

  Future<void> _showAddUser() async {
    final ctrl = TextEditingController();
    final found = await showDialog<ContactUserCard?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '添加用户',
          style: MirrorTheme.sans(fontSize: 15, weight: FontWeight.w500),
        ),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: '输入 handle，如 lin.yan'),
          style: MirrorTheme.sans(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final u = await ContactsApi.lookup(ctrl.text);
              if (!ctx.mounted) return;
              Navigator.pop(ctx, u);
            },
            child: const Text('查找'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (!mounted || found == null) return;
    if (found.canFollow) {
      await ContactsApi.follow(found.userId);
    }
    _toast('已添加 ${found.displayName}');
    _load();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: MirrorTheme.sans(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _title(ContactUserCard u) => u.displayName.contains('·')
      ? u.displayName
      : '${u.displayName} · ${u.handle}';

  String _subtitle(ContactUserCard u) {
    if (u.bio.isNotEmpty) return u.bio;
    if (u.recommendReason != null && u.recommendReason!.isNotEmpty)
      return u.recommendReason!;
    if (u.affinity.isNotEmpty)
      return u.affinity.map((a) => a.label).join(' · ');
    if (u.stats.followerCountLabel.isNotEmpty &&
        u.stats.followerCountLabel != '0') {
      return '${u.stats.followerCountLabel} 粉丝';
    }
    return '';
  }

  String _emptyHint() {
    if (_loadFailed) return '加载失败，请确认已登录且后端已启动';
    if (_searchMode) return '未找到相关用户';
    return switch (_tabIndex) {
      1 => '还没有粉丝',
      _ => '还没有关注任何人',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              if (widget.onBack != null) ...[
                MirrorBackButton(onTap: widget.onBack),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: MirrorColors.bgSoft,
                    border: Border.all(color: MirrorColors.border),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        size: 14,
                        color: MirrorColors.text3,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          focusNode: _searchFocus,
                          onChanged: _onSearchChanged,
                          onSubmitted: _onSearchSubmitted,
                          style: MirrorTheme.sans(
                            fontSize: 12,
                            color: MirrorColors.text,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: '搜索用户',
                            hintStyle: MirrorTheme.sans(
                              fontSize: 12,
                              color: MirrorColors.text3,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              MirrorPressable(
                onTap: _showAddUser,
                borderRadius: BorderRadius.circular(17),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: MirrorColors.bgSoft,
                    border: Border.all(color: MirrorColors.border),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_add_outlined,
                    size: 18,
                    color: MirrorColors.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            key: const Key('contacts-tab-bar'),
            children: [
              _ct('关注', _tabIndex == 0, () => _selectTab(0)),
              _ct('粉丝', _tabIndex == 1, () => _selectTab(1)),
            ],
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _emptyHint(),
                textAlign: TextAlign.center,
                style: MirrorTheme.sans(
                  fontSize: 13,
                  color: MirrorColors.text3,
                ),
              ),
              if (_loadFailed) ...[
                const SizedBox(height: 12),
                MirrorPressable(
                  onTap: _load,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: MirrorColors.accent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '重试',
                      style: MirrorTheme.sans(
                        fontSize: 12,
                        color: Colors.white,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return MirrorListView(
      children: [for (var i = 0; i < _users.length; i++) _userRow(i)],
    );
  }

  Widget _userRow(int i) {
    final u = _users[i];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          MirrorUserAvatar(
            size: 44,
            letter: u.avatarLetter,
            avatarUrl: u.avatarUrl,
            gradient: MirrorGradients.avatar(_avatarColors[i % _avatarColors.length]),
            fontSize: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _title(u),
                      style: MirrorTheme.sans(
                        fontSize: 14,
                        weight: FontWeight.w500,
                      ),
                    ),
                    if (u.roleBadge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: MirrorColors.accentSoft,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          u.roleBadge!.label,
                          style: MirrorTheme.mono(
                            fontSize: 8.5,
                            color: MirrorColors.accentDeep,
                          ),
                        ),
                      ),
                  ],
                ),
                if (_subtitle(u).isNotEmpty)
                  Text(
                    _subtitle(u),
                    style: MirrorTheme.sans(
                      fontSize: 12,
                      color: MirrorColors.text3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          MirrorPressable(
            onTap: () => _toggleFollow(i),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: u.canFollow ? MirrorColors.text : MirrorColors.bgSoft,
                border: u.canFollow
                    ? null
                    : Border.all(color: MirrorColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                u.followButtonLabel,
                style: MirrorTheme.sans(
                  fontSize: 11.5,
                  weight: FontWeight.w500,
                  color: u.canFollow ? Colors.white : MirrorColors.text2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ct(String t, bool on, VoidCallback onTap) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: MirrorPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: on ? MirrorColors.text : Colors.transparent,
            border: on ? null : Border.all(color: MirrorColors.borderSoft),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            t,
            textAlign: TextAlign.center,
            style: MirrorTheme.sans(
              fontSize: 13,
              weight: FontWeight.w500,
              color: on ? Colors.white : MirrorColors.text2,
            ),
          ),
        ),
      ),
    ),
  );
}
