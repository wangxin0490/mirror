import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/auth_screens.dart';
import '../screens/edit_profile_screen.dart';
import '../models/me_models.dart';
import '../models/toolbox_agent_models.dart';
import '../models/chat_launch_intent.dart';
import '../screens/mirror_screens.dart';
import '../screens/mirror_feed_data.dart';
import '../screens/mirror_screens_part2.dart';
import '../screens/post_detail_screen.dart';
import '../screens/mirror_screens_part3.dart';
import '../screens/dg_coupon_chat_screen.dart';
import '../screens/meeting/meeting_hub_screen.dart';
import '../screens/meeting/meeting_detail_screen.dart';
import '../screens/mirror_compose_comments.dart';
import '../screens/post_detail_data.dart';
import '../screens/author_profile_screen.dart';
import '../screens/account_settings_screen.dart';
import '../screens/token_usage_detail_screen.dart';
import '../services/ai_consent_store.dart';
import '../state/block_store.dart';
import '../data/mirror_authors.dart';
import '../state/dm_thread_store.dart';
import '../services/meeting_draft_store.dart';
import '../services/meeting_upload_worker.dart';
import '../state/meeting_session_store.dart';
import '../api/api_client.dart';
import '../api/auth_api.dart';
import '../api/chat_inbox_ws.dart';
import '../config/api_config.dart';
import '../models/chat_models.dart';
import '../utils/dm_share_message.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../widgets/app_frame.dart';
import '../widgets/phone_components.dart';
import 'prototype_route.dart';

/// 可点击、可切换 Tab 的 Mirror 手机原型
class MirrorPrototype extends StatefulWidget {
  const MirrorPrototype({super.key});

  @override
  State<MirrorPrototype> createState() => _MirrorPrototypeState();
}

enum _NavDirection { forward, back }

class _MirrorPrototypeState extends State<MirrorPrototype> {
  static const double _edgeSwipeWidth = 24;
  static const double _edgeSwipeTriggerDistance = 72;

  bool _entered = false;
  bool _bootstrapping = true;
  String? _authHint;
  MirrorTab _tab = MirrorTab.feed;

  /// 已构建过的主 Tab，避免每次切换销毁子页面（尤其生态列表重复请求）。
  final Set<MirrorTab> _builtTabs = {MirrorTab.feed};
  FeedPill _feedPill = FeedPill.rec;
  final List<PrototypeRoute> _stack = [];
  PostDetailId _postDetailId = PostDetailId.soul;
  int? _postId;
  SharedKnowledgeBaseInfo? _postSharedKb;
  FeedCardData? _postAuthorCard;
  VoidCallback? _refreshFeed;
  ToolboxAgentItem? _selectedAgent;
  ChatLaunchIntent? _chatLaunchIntent;
  int? _productConversationId;
  int? _meetingSessionId;
  String? _selectedToolName;
  MirrorAuthor? _profileAuthor;
  int? _profileUserId;
  MirrorAuthor? _shareSheetAuthor;
  MirrorAuthor? _chatAuthor;
  MeProfile? _editProfileInitial;
  String _registerPhone = '';
  String _registerToken = '';
  MeQuota? _tokenQuota;
  List<SkillData> _tokenSkills = const [];
  int _meRefresh = 0;
  int _contactsInitialTab = 0;
  _NavDirection _navDirection = _NavDirection.forward;
  bool _navLocked = false;
  bool _edgeSwipeActive = false;
  double _edgeSwipeDistance = 0;
  DateTime? _lastExitBackAt;
  bool Function()? _kbSystemBackHandler;

  bool get _showTabBar => _entered && _stack.isEmpty;

  /// 欢迎页允许系统直接退出；主界面由 [_handleRootBack] 处理。
  bool get _canSystemPop => _stack.isEmpty && !_entered;

  Object get _bodyKey => _stack.isNotEmpty
      ? 'stack:${_stack.last.name}'
      : (!_entered || _bootstrapping ? 'welcome' : 'main-tabs');

  @override
  void initState() {
    super.initState();
    ApiClient.onAuthError = _onAuthError;
    ApiConfig.onTokenChanged = () => ChatInboxWs.instance.reconnect();
    ApiConfig.onSessionCleared = () {
      ChatInboxWs.instance.disconnect(reconnect: false);
      _stopMeetingServices();
    };
    MeetingSessionStore.instance.openMeetingDetail = _openMeetingDetail;
    _restoreSession();
  }

  @override
  void dispose() {
    ApiClient.onAuthError = null;
    ApiConfig.onTokenChanged = null;
    ApiConfig.onSessionCleared = null;
    ChatInboxWs.instance.disconnect(reconnect: false);
    MeetingSessionStore.instance.openMeetingDetail = null;
    _stopMeetingServices();
    super.dispose();
  }

  void _openMeetingDetail(int sessionId) {
    setState(() => _meetingSessionId = sessionId);
    _push(PrototypeRoute.meetingDetail);
  }

  void _openToolboxAgent(ToolboxAgentItem agent) {
    if (!agent.enabled) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(content: Text(toolboxAgentDisabledMessage(agent))),
      );
      return;
    }
    setState(() => _selectedAgent = agent);
    if (agent.opensMirrorChat) {
      setState(() {
        _chatLaunchIntent = ChatLaunchIntent.fromToolbox(agent);
      });
      _push(PrototypeRoute.mirrorChat);
      return;
    }
    if (agent.agentCode == 'dg-coupon' || agent.renderer == 'dg-coupon') {
      setState(() => _productConversationId = null);
      _push(PrototypeRoute.productAgentChat);
      return;
    }
    _push(PrototypeRoute.agentHub);
  }

  Future<void> _restoreSession() async {
    await ApiConfig.loadFromStorage();
    unawaited(BlockStore.instance.ensureLoaded());
    if (!ApiConfig.isLoggedIn) {
      if (mounted) setState(() => _bootstrapping = false);
      return;
    }
    final res = await AuthApi.fetchSession();
    if (!mounted) return;
    if (res.ok) {
      ChatInboxWs.instance.connect();
      await _startMeetingServices();
      setState(() {
        _entered = true;
        _bootstrapping = false;
        _authHint = null;
      });
      return;
    }
    ChatInboxWs.instance.disconnect(reconnect: false);
    await ApiConfig.resetSession();
    setState(() {
      _entered = false;
      _bootstrapping = false;
      if (res.code == 40102) {
        _authHint = '账号已在其他设备登录，请重新登录';
      } else if (res.code == 40101) {
        _authHint = '登录已过期，请重新登录';
      }
    });
  }

  void _onAuthError(int code, String message) {
    if (!_entered) return;
    ChatInboxWs.instance.disconnect(reconnect: false);
    ApiConfig.resetSession();
    DmThreadStore.instance.clear();
    _stopMeetingServices();
    setState(() {
      _entered = false;
      _stack.clear();
      _tab = MirrorTab.feed;
      _authHint = message.isNotEmpty
          ? message
          : (code == 40102 ? '账号已在其他设备登录，请重新登录' : '请重新登录');
    });
  }

  Future<void> _startMeetingServices() async {
    if (kIsWeb) return;
    await MeetingDraftStore.instance.restore();
    MeetingSessionStore.instance.start();
    MeetingUploadWorker.instance.start();
  }

  void _stopMeetingServices() {
    if (kIsWeb) return;
    MeetingUploadWorker.instance.stop();
    MeetingSessionStore.instance.stop();
  }

  void _enterApp() {
    unawaited(_startMeetingServices());
    ChatInboxWs.instance.connect();
    setState(() {
      _entered = true;
      _stack.clear();
      _registerPhone = '';
      _registerToken = '';
      _authHint = null;
    });
  }

  Future<void> _logout() async {
    await AuthApi.logout();
    if (!mounted) return;
    await BlockStore.instance.clear();
    ChatInboxWs.instance.disconnect(reconnect: false);
    DmThreadStore.instance.clear();
    _stopMeetingServices();
    setState(() {
      _entered = false;
      _stack.clear();
      _tab = MirrorTab.feed;
      _navDirection = _NavDirection.back;
      _navLocked = false;
      _authHint = null;
    });
  }

  void _selectTab(MirrorTab tab) {
    if (_stack.isNotEmpty) return;
    final switchingToMe = tab == MirrorTab.me && _tab != MirrorTab.me;
    setState(() {
      _tab = tab;
      _builtTabs.add(tab);
      _lastExitBackAt = null;
      if (switchingToMe) _meRefresh++;
    });
    if (tab == MirrorTab.sessions && ApiConfig.isLoggedIn) {
      DmThreadStore.instance.refreshFromApi(
        tab: DmThreadStore.instance.lastTab,
      );
    }
  }

  void _push(PrototypeRoute route) {
    if (_navLocked) return;
    setState(() {
      _navDirection = _NavDirection.forward;
      _stack.add(route);
    });
  }

  void _openContacts({int tabIndex = 0}) {
    if (_navLocked) return;
    setState(() {
      _contactsInitialTab = tabIndex.clamp(0, 1);
      _navDirection = _NavDirection.forward;
      _stack.add(PrototypeRoute.contacts);
    });
  }

  void _pushPost(FeedCardData card) {
    if (_navLocked) return;
    setState(() {
      _navDirection = _NavDirection.forward;
      _postId = card.postId;
      _postDetailId = card.detailId ?? PostDetailData.resolveFromCard(card);
      _postSharedKb = PostDetailData.sharedKbFromCard(card);
      _postAuthorCard = card;
      _stack.add(PrototypeRoute.post);
    });
  }

  void _pushAuthor(FeedCardData card) {
    if (_navLocked) return;
    final author = MirrorAuthor.fromCard(card);
    final uid = card.authorUserId ?? author.userId;
    setState(() {
      _profileAuthor = author;
      _profileUserId = uid;
      _navDirection = _NavDirection.forward;
      if (ApiConfig.isLoggedIn && uid > 0 && uid == ApiConfig.userId) {
        _stack.add(PrototypeRoute.myHome);
      } else {
        _stack.add(PrototypeRoute.authorProfile);
      }
    });
  }

  void _openDm(MirrorAuthor author) {
    if (_navLocked) return;
    DmThreadStore.instance.ensureThread(author);
    setState(() {
      _chatAuthor = author;
      _navDirection = _NavDirection.forward;
      _stack.add(PrototypeRoute.humanChat);
    });
  }

  void _openPostById(int postId) {
    if (_navLocked || postId <= 0) return;
    setState(() {
      _postId = postId;
      _postDetailId = PostDetailId.review;
      _postAuthorCard = null;
      _postSharedKb = null;
      _navDirection = _NavDirection.forward;
      _stack.add(PrototypeRoute.post);
    });
  }

  void _pushProfileShare(MirrorAuthor author) {
    if (_navLocked || author.userId <= 0) return;
    setState(() {
      _shareSheetAuthor = author;
      _postId = null;
      _postAuthorCard = null;
      _navDirection = _NavDirection.forward;
      _stack.add(PrototypeRoute.shareSheet);
    });
  }

  void _openAuthorByUserId(int userId, {DmUserShare? hint}) {
    if (_navLocked || userId <= 0) return;
    final author = hint != null
        ? MirrorAuthor(
            key: MirrorAuthor.keyFromName(hint.displayName),
            name: hint.displayName,
            av: hint.avatarLetter.isNotEmpty ? hint.avatarLetter : '?',
            variant: variantEnum(hint.avatarVariant),
            handle: hint.handle,
            bio: hint.bio,
            userId: hint.userId,
            tagline: hint.tagline,
            avatarUrl: hint.avatarUrl,
          )
        : (_profileAuthor?.userId == userId
              ? _profileAuthor!
              : MirrorAuthor(
                  key: 'user_$userId',
                  name: '用户',
                  av: '?',
                  variant: FeedAvatarVariant.accent,
                  handle: '',
                  bio: '',
                  userId: userId,
                ));
    setState(() {
      _profileAuthor = author;
      _profileUserId = userId;
      _navDirection = _NavDirection.forward;
      if (ApiConfig.isLoggedIn && userId == ApiConfig.userId) {
        _stack.add(PrototypeRoute.myHome);
      } else {
        _stack.add(PrototypeRoute.authorProfile);
      }
    });
  }

  void _pop() {
    if (_stack.isEmpty || _navLocked) return;
    final leaving = _stack.last;
    final leavingHumanChat = leaving == PrototypeRoute.humanChat;
    final leavingMyHome = leaving == PrototypeRoute.myHome;
    final leavingAgentStatsSurface =
        leaving == PrototypeRoute.agentHub ||
        leaving == PrototypeRoute.productAgentChat ||
        leaving == PrototypeRoute.meetingDetail;
    _navLocked = true;
    setState(() {
      _navDirection = _NavDirection.back;
      _stack.removeLast();
      if (leavingMyHome || (leavingAgentStatsSurface && _tab == MirrorTab.me)) {
        _meRefresh++;
      }
    });
    if (leavingHumanChat &&
        _tab == MirrorTab.sessions &&
        ApiConfig.isLoggedIn) {
      DmThreadStore.instance.refreshFromApi(
        tab: DmThreadStore.instance.lastTab,
      );
    }
    Future.delayed(const Duration(milliseconds: 280), () {
      if (mounted) _navLocked = false;
    });
  }

  void _onEdgeDragStart(DragStartDetails details) {
    _edgeSwipeActive =
        _stack.isNotEmpty &&
        !_navLocked &&
        details.localPosition.dx <= _edgeSwipeWidth;
    _edgeSwipeDistance = 0;
  }

  void _onEdgeDragUpdate(DragUpdateDetails details) {
    if (!_edgeSwipeActive) return;
    _edgeSwipeDistance += details.primaryDelta ?? 0;
  }

  void _onEdgeDragEnd(DragEndDetails details) {
    if (!_edgeSwipeActive) return;
    final velocity = details.primaryVelocity ?? 0;
    final shouldPop =
        velocity > 360 || _edgeSwipeDistance > _edgeSwipeTriggerDistance;
    _edgeSwipeActive = false;
    _edgeSwipeDistance = 0;
    if (shouldPop) _pop();
  }

  void _onEdgeDragCancel() {
    _edgeSwipeActive = false;
    _edgeSwipeDistance = 0;
  }

  void _handleRootBack() {
    if (_stack.isNotEmpty) {
      _pop();
      return;
    }
    if (!_entered) {
      SystemNavigator.pop();
      return;
    }
    if (_tab == MirrorTab.knowledge &&
        (_kbSystemBackHandler?.call() ?? false)) {
      return;
    }
    if (_tab != MirrorTab.feed) {
      setState(() {
        _tab = MirrorTab.feed;
        _builtTabs.add(MirrorTab.feed);
        _lastExitBackAt = null;
      });
      return;
    }
    final now = DateTime.now();
    if (_lastExitBackAt != null &&
        now.difference(_lastExitBackAt!) <= const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastExitBackAt = now;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '再按一次退出应用',
            style: MirrorTheme.sans(fontSize: 13, color: Colors.white),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    const statusLight = false;

    return PopScope(
      canPop: _canSystemPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleRootBack();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: _onEdgeDragStart,
        onHorizontalDragUpdate: _onEdgeDragUpdate,
        onHorizontalDragEnd: _onEdgeDragEnd,
        onHorizontalDragCancel: _onEdgeDragCancel,
        child: AppFrame(
          time: '9:42',
          statusBarLight: statusLight,
          child: Column(
            children: [
              Expanded(
                child: ClipRect(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder: (currentChild, _) =>
                        currentChild ?? const SizedBox.shrink(),
                    transitionBuilder: (child, animation) {
                      if (kIsWeb) return child;
                      final fromRight = _navDirection == _NavDirection.forward;
                      return SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: Offset(fromRight ? 0.22 : -0.22, 0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: child,
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey(_bodyKey),
                      child: _buildBody(),
                    ),
                  ),
                ),
              ),
              if (_showTabBar)
                MirrorTabBar(
                  active: _tab,
                  onSelect: _selectTab,
                  onSmartChatTap: () => _push(PrototypeRoute.mirrorChat),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_bootstrapping) {
      return Center(
        child: Text(
          '加载中…',
          style: MirrorTheme.mono(fontSize: 11, color: MirrorColors.text3),
        ),
      );
    }
    if (!_entered) {
      if (_stack.isNotEmpty) {
        return _buildAuthPushed(_stack.last);
      }
      return WelcomeScreen(
        authHint: _authHint,
        onPhoneLogin: () => _push(PrototypeRoute.phoneLogin),
      );
    }

    if (_stack.isNotEmpty) {
      return _buildPushed(_stack.last);
    }

    return _buildMainTabs();
  }

  Widget _buildMainTabs() {
    return IndexedStack(
      index: MirrorTab.values.indexOf(_tab),
      sizing: StackFit.expand,
      children: [for (final tab in MirrorTab.values) _buildLazyTab(tab)],
    );
  }

  Widget _buildLazyTab(MirrorTab tab) {
    if (!_builtTabs.contains(tab)) {
      return const SizedBox.shrink();
    }
    return TickerMode(
      enabled: _tab == tab,
      child: KeyedSubtree(
        key: ValueKey('tab:${tab.name}'),
        child: _buildTab(tab),
      ),
    );
  }

  Widget _buildTab(MirrorTab tab) {
    switch (tab) {
      case MirrorTab.feed:
        return FeedScreen(
          key: const ValueKey('feed-demo-v4'),
          pill: _feedPill,
          onPillChanged: (p) => setState(() => _feedPill = p),
          onPostTap: _pushPost,
          onAuthorTap: _pushAuthor,
          onComposeTap: () => _push(PrototypeRoute.compose),
          onRegisterRefresh: (fn) => _refreshFeed = fn,
        );
      case MirrorTab.knowledge:
        return KnowledgeBaseScreen(
          key: const ValueKey('kb-v3-inphone-import'),
          onAsk: () => _push(PrototypeRoute.kbChat),
          registerSystemBackHandler: (handler) =>
              _kbSystemBackHandler = handler,
        );
      case MirrorTab.sessions:
        return SessionsScreen(
          key: const ValueKey('sessions-ui-v3-dm'),
          onThreadTap: (key) {
            final author =
                DmThreadStore.instance.authorForKey(key) ??
                MirrorAuthor.byKey(key);
            if (author != null) {
              _openDm(author);
            } else {
              _chatAuthor = null;
              _push(PrototypeRoute.humanChat);
            }
          },
          onContactsTap: () => _openContacts(),
        );
      case MirrorTab.me:
        return MeScreen(
          key: ValueKey('me-xhs-v2-$_meRefresh'),
          onEditProfile: (profile) {
            setState(() {
              _editProfileInitial = profile;
              _navDirection = _NavDirection.forward;
              _stack.add(PrototypeRoute.editProfile);
            });
          },
          onFollowingList: () => _openContacts(tabIndex: 0),
          onFollowersList: () => _openContacts(tabIndex: 1),
          onMyHome: () {
            setState(() {
              _profileAuthor = MirrorAuthor.currentUser();
              _navDirection = _NavDirection.forward;
              _stack.add(PrototypeRoute.myHome);
            });
          },
          onComposeTap: () => _push(PrototypeRoute.compose),
          onAgentsList: () => _push(PrototypeRoute.agentsList),
          onQuotaTap: (quota, skills) {
            setState(() {
              _tokenQuota = quota;
              _tokenSkills = skills;
              _navDirection = _NavDirection.forward;
              _stack.add(PrototypeRoute.tokenUsage);
            });
          },
          onAgentTap: _openToolboxAgent,
          onLogout: _logout,
          onAccountSettings: () => _push(PrototypeRoute.accountSettings),
        );
    }
  }

  Widget _buildPushed(PrototypeRoute route) {
    switch (route) {
      case PrototypeRoute.welcome:
        return WelcomeScreen(
          onPhoneLogin: () => _push(PrototypeRoute.phoneLogin),
        );
      case PrototypeRoute.phoneLogin:
        return _buildPhoneLoginScreen();
      case PrototypeRoute.phoneRegister:
        return _buildPhoneRegisterScreen();
      case PrototypeRoute.editProfile:
        final initial = _editProfileInitial ?? ApiConfig.cachedProfile;
        return EditProfileScreen(
          initial: initial,
          onBack: _pop,
          onSaved: (p) {
            setState(() {
              _editProfileInitial = p;
              _meRefresh++;
            });
          },
        );
      case PrototypeRoute.mirrorChat:
        return ChatScreen(
          onBack: _pop,
          launchIntent: _chatLaunchIntent,
          onLaunchIntentConsumed: () {
            if (!mounted) return;
            setState(() => _chatLaunchIntent = null);
          },
        );
      case PrototypeRoute.humanChat:
        return HumanChatScreen(
          author: _chatAuthor,
          onBack: _pop,
          onPostTap: _openPostById,
          onUserTap: (share) => _openAuthorByUserId(share.userId, hint: share),
        );
      case PrototypeRoute.authorProfile:
        final author = _profileAuthor ?? MirrorAuthor.catalog.first;
        return AuthorProfileScreen(
          author: author,
          userId: _profileUserId ?? author.userId,
          onBack: _pop,
          onMessage: _openDm,
          onShare: _pushProfileShare,
          onFollowingList: () => _openContacts(tabIndex: 0),
          onFollowersList: () => _openContacts(tabIndex: 1),
          onPostTap: _pushPost,
        );
      case PrototypeRoute.myHome:
        return AuthorProfileScreen(
          author: MirrorAuthor.currentUser(),
          userId: ApiConfig.userId,
          isSelf: true,
          onBack: _pop,
          onEditProfile: () {
            setState(() {
              _editProfileInitial = ApiConfig.cachedProfile;
              _navDirection = _NavDirection.forward;
              _stack.add(PrototypeRoute.editProfile);
            });
          },
          onFollowingList: () => _openContacts(tabIndex: 0),
          onFollowersList: () => _openContacts(tabIndex: 1),
          onPostTap: _pushPost,
        );
      case PrototypeRoute.post:
        return PostScreen(
          detailId: _postDetailId,
          postId: _postId,
          sharedKb: _postSharedKb,
          onBack: _pop,
          onShare: () => _push(PrototypeRoute.shareSheet),
          onAuthorTap: () {
            if (_postAuthorCard != null) {
              _pushAuthor(_postAuthorCard!);
            }
          },
        );
      case PrototypeRoute.shareSheet:
        return ShareSheetScreen(
          onDismiss: () {
            setState(() => _shareSheetAuthor = null);
            _pop();
          },
          postId: _shareSheetAuthor == null ? _postId : null,
          previewCard: _shareSheetAuthor == null ? _postAuthorCard : null,
          shareAuthor: _shareSheetAuthor,
        );
      case PrototypeRoute.compose:
        return ComposeScreen(
          onBack: _pop,
          onPublished: () {
            setState(() => _feedPill = FeedPill.rec);
            _refreshFeed?.call();
          },
        );
      case PrototypeRoute.comments:
        return CommentsScreen(onBack: _pop);
      case PrototypeRoute.skills:
        return SkillsScreen(
          onBack: _pop,
          onToolTap: (name) {
            _selectedToolName = name;
            _push(PrototypeRoute.toolChat);
          },
        );
      case PrototypeRoute.contacts:
        return ContactsScreen(
          onBack: _pop,
          initialTabIndex: _contactsInitialTab,
        );
      case PrototypeRoute.kbChat:
        return KbChatScreen(onBack: _pop);
      case PrototypeRoute.agentsList:
        return AgentsListScreen(onBack: _pop, onAgentTap: _openToolboxAgent);
      case PrototypeRoute.agentHub:
        final agent = _selectedAgent;
        if (agent == null) return const SizedBox.shrink();
        if (toolboxAgentUsesMeetingHub(agent)) {
          return MeetingHubScreen(
            agent: agent,
            onBack: _pop,
            onOpenDetail: _openMeetingDetail,
          );
        }
        return ProductAgentHubScreen(
          agent: agent,
          onBack: _pop,
          onOpenChat: (convId) {
            setState(() => _productConversationId = convId);
            _push(PrototypeRoute.productAgentChat);
          },
        );
      case PrototypeRoute.meetingDetail:
        final sessionId = _meetingSessionId;
        if (sessionId == null) return const SizedBox.shrink();
        return MeetingDetailScreen(sessionId: sessionId, onBack: _pop);
      case PrototypeRoute.productAgentChat:
        final agent = _selectedAgent;
        final convId = _productConversationId;
        if (agent == null) return const SizedBox.shrink();
        if (agent.agentCode == 'dg-coupon' || agent.renderer == 'dg-coupon') {
          return DgCouponChatScreen(
            agent: agent,
            conversationId: convId,
            onBack: _pop,
          );
        }
        if (convId == null) return const SizedBox.shrink();
        return ProductAgentChatScreen(
          agent: agent,
          conversationId: convId,
          onBack: _pop,
        );
      case PrototypeRoute.toolChat:
        return ToolChatScreen(
          toolName: _selectedToolName ?? '智能助手',
          onBack: _pop,
        );
      case PrototypeRoute.soul:
        return SoulScreen(onBack: _pop);
      case PrototypeRoute.memory:
        return MemoryScreen(onBack: _pop);
      case PrototypeRoute.routing:
        return RoutingScreen(onBack: _pop);
      case PrototypeRoute.cron:
        return CronScreen(onBack: _pop);
      case PrototypeRoute.tokenUsage:
        return TokenUsageDetailScreen(
          quota: _tokenQuota ?? MeQuota.walletPlaceholder(),
          skills: _tokenSkills,
          onBack: _pop,
        );
      case PrototypeRoute.accountSettings:
        return AccountSettingsScreen(
          onBack: _pop,
          onAccountDeleted: () async {
            await AiConsentStore.clear();
            await BlockStore.instance.clear();
            await ApiConfig.resetSession();
            if (!mounted) return;
            ChatInboxWs.instance.disconnect(reconnect: false);
            DmThreadStore.instance.clear();
            _stopMeetingServices();
            setState(() {
              _entered = false;
              _stack.clear();
              _tab = MirrorTab.feed;
              _authHint = null;
            });
          },
        );
    }
  }

  Widget _buildAuthPushed(PrototypeRoute route) {
    switch (route) {
      case PrototypeRoute.phoneLogin:
        return _buildPhoneLoginScreen();
      case PrototypeRoute.phoneRegister:
        return _buildPhoneRegisterScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPhoneLoginScreen() => PhoneLoginScreen(
    onBack: _pop,
    onLoggedIn: (_) => _enterApp(),
    onNeedsRegister: (phone, token) {
      setState(() {
        _registerPhone = phone;
        _registerToken = token;
      });
      _push(PrototypeRoute.phoneRegister);
    },
  );

  Widget _buildPhoneRegisterScreen() => PhoneRegisterScreen(
    phone: _registerPhone,
    registerToken: _registerToken,
    onBack: _pop,
    onRegistered: (_) => _enterApp(),
  );
}
