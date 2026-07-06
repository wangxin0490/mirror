import 'package:flutter/material.dart';

import '../api/contacts_api.dart';
import '../api/feed_api.dart';
import '../api/me_api.dart';
import '../config/api_config.dart';
import '../data/mirror_authors.dart';
import '../models/contacts_models.dart';
import '../models/feed_models.dart';
import '../screens/mirror_feed_data.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../utils/media_url.dart';
import '../widgets/mirror_avatar_preview.dart';
import '../widgets/mirror_network_image.dart';
import '../widgets/mirror_pressable.dart';
import '../widgets/mirror_scroll.dart';
import '../widgets/moderation_action_sheet.dart';
import '../widgets/phone_components.dart';

/// 博主 / 我的个人主页（小红书风格）
class AuthorProfileScreen extends StatefulWidget {
  const AuthorProfileScreen({
    super.key,
    this.author,
    this.userId,
    this.isSelf = false,
    this.onBack,
    this.onMessage,
    this.onEditProfile,
    this.onFollowingList,
    this.onFollowersList,
    this.onPostTap,
    this.onShare,
  });

  final MirrorAuthor? author;
  final int? userId;
  final bool isSelf;
  final VoidCallback? onBack;
  final void Function(MirrorAuthor author)? onMessage;
  final VoidCallback? onEditProfile;
  final VoidCallback? onFollowingList;
  final VoidCallback? onFollowersList;
  final void Function(FeedCardData card)? onPostTap;
  final void Function(MirrorAuthor author)? onShare;

  @override
  State<AuthorProfileScreen> createState() => _AuthorProfileScreenState();
}

class _AuthorProfileScreenState extends State<AuthorProfileScreen> {
  bool _loading = true;
  bool _loadFailed = false;
  bool _followBusy = false;
  MirrorAuthor? _author;
  List<FeedCardData> _notes = [];
  String _followState = 'none';

  MirrorAuthor get _display =>
      _author ??
      widget.author ??
      (widget.isSelf ? MirrorAuthor.currentUser() : MirrorAuthor.catalog.first);

  @override
  void initState() {
    super.initState();
    _followState = _display.followState;
    _load();
  }

  Future<void> _load() async {
    var uid = widget.isSelf ? ApiConfig.userId : (widget.userId ?? widget.author?.userId ?? 0);
    if (uid <= 0 && widget.author != null && widget.author!.handle.isNotEmpty) {
      final card = await ContactsApi.lookup(widget.author!.handle);
      uid = card?.userId ?? 0;
    }

    if (!ApiConfig.isLoggedIn || uid <= 0) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = uid <= 0 && !widget.isSelf;
        _notes = _localNotes();
      });
      return;
    }

    final resFuture = FeedApi.fetchUserProfile(uid);
    final meFuture = widget.isSelf && ApiConfig.isLoggedIn ? MeApi.fetchProfile() : null;
    final res = await resFuture;
    final meProfile = meFuture != null ? await meFuture : null;
    if (!mounted) return;
    if (res == null) {
      setState(() {
        _loading = false;
        _loadFailed = true;
        _notes = _localNotes();
      });
      return;
    }

    final variant = res.posts.isNotEmpty
        ? variantFromApiString(res.posts.first.author.avatarVariant)
        : _display.variant;
    var author = MirrorAuthor.fromProfile(res.profile, variant: variant, isSelf: widget.isSelf);
    if (meProfile != null) {
      final m = meProfile;
      author = MirrorAuthor(
        key: author.key,
        userId: author.userId,
        name: m.displayName.isNotEmpty ? m.displayName : author.name,
        av: m.avatarLetter.isNotEmpty ? m.avatarLetter : author.av,
        variant: author.variant,
        handle: m.handle.isNotEmpty ? m.handle : author.handle,
        bio: m.bio.isNotEmpty ? m.bio : author.bio,
        tagline: author.tagline,
        avatarUrl: m.avatarUrl.isNotEmpty ? m.avatarUrl : author.avatarUrl,
        followers: author.followers,
        following: author.following,
        notes: author.notes,
        likesReceivedLabel: author.likesReceivedLabel,
        followState: author.followState,
      );
    }
    setState(() {
      _author = author;
      _followState = res.profile.followState;
      _notes = res.posts.map((e) => e.toFeedCardData()).toList();
      _loading = false;
      _loadFailed = false;
    });
  }

  List<FeedCardData> _localNotes() {
    if (widget.isSelf) return MirrorFeedData.myPosts;
    final a = widget.author;
    if (a == null) return [];
    final all = [...MirrorFeedData.rec, ...MirrorFeedData.fol];
    return all.where((c) => c.authorKey == a.key || c.authorName == a.name).toList();
  }

  String get _followLabel => switch (_followState) {
        'mutual' => '互关',
        'following' => '已关注',
        _ => '关注',
      };

  bool get _isFollowing => _followState == 'following' || _followState == 'mutual';

  /// 本人主页（含从帖子点进自己但未传 isSelf 的情况）
  bool get _isOwnProfile {
    if (widget.isSelf) return true;
    if (!ApiConfig.isLoggedIn || ApiConfig.userId <= 0) return false;
    final uid = _display.userId;
    return uid > 0 && uid == ApiConfig.userId;
  }

  Future<void> _toggleFollow() async {
    final uid = _display.userId;
    if (uid <= 0 || _followBusy || _isOwnProfile) return;

    setState(() => _followBusy = true);
    ContactFollowResult? res;
    if (_followState == 'none' || _followState == 'follower') {
      res = await ContactsApi.follow(uid);
    } else if (_isFollowing) {
      res = await ContactsApi.unfollow(uid);
    }
    if (!mounted) return;
    setState(() => _followBusy = false);
    if (res != null) {
      setState(() => _followState = res!.followState);
    }
  }

  Future<void> _showUserModeration() async {
    final author = _display;
    await showModerationActionSheet(
      context,
      title: '用户操作',
      userId: author.userId,
      userName: author.name,
      targetType: 'user',
      targetId: '${author.userId}',
      onBlocked: widget.onBack,
    );
  }

  @override
  Widget build(BuildContext context) {
    final author = _display;
    final notes = _notes;
    final likesLabel = author.likesReceivedLabel.isNotEmpty ? author.likesReceivedLabel : '0';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 12),
          decoration: const BoxDecoration(
            color: MirrorColors.bgApp,
            border: Border(bottom: BorderSide(color: MirrorColors.borderSoft)),
          ),
          child: Row(
            children: [
              MirrorBackButton(onTap: widget.onBack),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.isSelf ? '我的主页' : author.name,
                  style: MirrorTheme.sans(
                    fontSize: 16,
                    weight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.isSelf)
                MirrorPressable(
                  onTap: widget.onEditProfile,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  borderRadius: BorderRadius.circular(18),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_outlined, size: 14, color: MirrorColors.text2),
                      const SizedBox(width: 4),
                      Text(
                        '编辑资料',
                        style: MirrorTheme.sans(fontSize: 13, weight: FontWeight.w500, color: MirrorColors.text2),
                      ),
                    ],
                  ),
                )
              else
                MirrorPressable(
                  onTap: widget.onShare == null ? null : () => widget.onShare!(author),
                  padding: const EdgeInsets.all(6),
                  borderRadius: BorderRadius.circular(20),
                  child: const Icon(Icons.share_outlined, size: 20, color: MirrorColors.text2),
                ),
              if (!_isOwnProfile && _display.userId > 0)
                IconButton(
                  icon: const Icon(Icons.more_horiz, size: 20, color: MirrorColors.text2),
                  onPressed: _showUserModeration,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : MirrorScrollView(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_loadFailed)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                          child: Text(
                            '资料加载失败，显示缓存内容',
                            style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text3),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _profileHero(author, likesLabel),
                            const SizedBox(height: 18),
                            Text(
                              '笔记',
                              style: MirrorTheme.sans(
                                fontSize: 15,
                                weight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (notes.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 32),
                                child: Center(
                                  child: Text(
                                    '暂无公开笔记',
                                    style: MirrorTheme.sans(
                                      fontSize: 13,
                                      color: MirrorColors.text3,
                                    ),
                                  ),
                                ),
                              )
                            else
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: 0.72,
                                ),
                                itemCount: notes.length,
                                itemBuilder: (context, i) => _noteTile(notes[i]),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _profileHero(MirrorAuthor author, String likesLabel) => Container(
        key: const Key('author-profile-header-bg'),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        decoration: BoxDecoration(
          color: MirrorColors.bgApp,
          border: Border.all(color: MirrorColors.borderSoft),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MirrorPressable(
                  onTap: widget.isSelf
                      ? () => openMirrorAvatarPreview(
                            context,
                            letter: author.av,
                            colors: author.avatarColors,
                            avatarUrl: author.avatarUrl,
                            title: author.name,
                          )
                      : null,
                  borderRadius: BorderRadius.circular(40),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: MirrorColors.bgApp,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: author.avatarColors.first.withValues(alpha: 0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: _profileAvatar(author, 74, 37),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          author.name,
                          style: MirrorTheme.sans(
                            fontSize: 22,
                            weight: FontWeight.w700,
                            letterSpacing: -0.02,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '@${author.handle}',
                          style: MirrorTheme.sans(
                            fontSize: 12.5,
                            color: MirrorColors.text3,
                          ),
                        ),
                        if (author.tagline.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: MirrorColors.bgSoft,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: MirrorColors.borderSoft),
                            ),
                            child: Text(
                              author.tagline,
                              style: MirrorTheme.sans(
                                fontSize: 12,
                                color: MirrorColors.text2,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (author.bio.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                author.bio,
                style: MirrorTheme.sans(
                  fontSize: 13,
                  color: MirrorColors.text2,
                  height: 1.55,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: MirrorColors.bgSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MirrorColors.borderSoft),
              ),
              child: Row(
                children: [
                  _stat(
                    '${author.following}',
                    '关注',
                    onTap: _isOwnProfile ? widget.onFollowingList : null,
                  ),
                  _stat(
                    _fmt(author.followers),
                    '粉丝',
                    onTap: _isOwnProfile ? widget.onFollowersList : null,
                  ),
                  _stat('${author.notes}', '笔记'),
                  _stat(likesLabel, '获赞'),
                ],
              ),
            ),
            if (!_isOwnProfile) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: MirrorPressable(
                      onTap: _followBusy ? null : _toggleFollow,
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _isFollowing ? MirrorColors.bgSoft : MirrorColors.bgApp,
                          border: Border.all(color: MirrorColors.border),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Text(
                          _followBusy ? '...' : _followLabel,
                          style: MirrorTheme.sans(
                            fontSize: 14,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MirrorPressable(
                      onTap: widget.onMessage == null ? null : () => widget.onMessage!(author),
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: MirrorColors.text,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          '私信',
                          style: MirrorTheme.sans(
                            fontSize: 14,
                            weight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );

  static String _fmt(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}w';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  Widget _stat(String v, String label, {VoidCallback? onTap}) => Expanded(
        child: MirrorPressable(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Text(v, style: MirrorTheme.sans(fontSize: 15, weight: FontWeight.w700)),
              Text(
                label,
                style: MirrorTheme.sans(fontSize: 10.5, color: MirrorColors.text3),
              ),
            ],
          ),
        ),
      );

  Widget _profileAvatar(MirrorAuthor author, double size, double radius) {
    final url = author.avatarUrl.trim();
    if (url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: size,
          height: size,
          child: MirrorNetworkImage(url: resolveMediaUrl(url)),
        ),
      );
    }
    return AvatarGradient(
      label: author.av,
      colors: author.avatarColors,
      size: size,
      radius: radius,
    );
  }

  Widget _noteTile(FeedCardData card) => MirrorPressable(
        onTap: widget.onPostTap == null ? null : () => widget.onPostTap!(card),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: MirrorColors.bgApp,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: MirrorColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _noteCover(card)),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: MirrorTheme.sans(
                        fontSize: 11.5,
                        weight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.favorite_border,
                          size: 10,
                          color: MirrorColors.text3,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          card.likes,
                          style: MirrorTheme.mono(
                            fontSize: 9,
                            color: MirrorColors.text3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _noteCover(FeedCardData card) => Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(gradient: card.cover.gradient),
          ),
          if (card.coverImageUrl != null && card.coverImageUrl!.trim().isNotEmpty)
            Positioned.fill(
              child: MirrorNetworkImage(
                url: resolveMediaUrl(card.coverImageUrl!.trim()),
              ),
            ),
          if ((card.coverImageUrl == null || card.coverImageUrl!.trim().isEmpty) &&
              card.quote != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  card.quote!,
                  textAlign: TextAlign.center,
                  style: MirrorTheme.serif(
                    fontSize: 12,
                    color: Colors.white,
                    height: 1.35,
                    style: FontStyle.italic,
                  ),
                ),
              ),
            )
          else if ((card.coverImageUrl == null || card.coverImageUrl!.trim().isEmpty) &&
              card.icon != null)
            Center(
              child: Icon(
                card.icon,
                color: Colors.white.withValues(alpha: 0.9),
                size: 28,
              ),
            ),
        ],
      );
}
