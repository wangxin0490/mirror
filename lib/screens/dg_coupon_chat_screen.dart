import 'package:flutter/material.dart';

import '../api/product_agent_api.dart';
import '../models/toolbox_agent_models.dart';
import '../services/product_agent_sse_client.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../utils/dg_coupon_parser.dart';
import '../widgets/chat_markdown_body.dart';
import '../widgets/dg_coupon_product_card.dart';
import '../widgets/mirror_assistant_identity.dart';
import '../widgets/mirror_pressable.dart';
import '../widgets/phone_components.dart';
import '../widgets/simple_chat_composer.dart';
import '../widgets/ai_data_consent_dialog.dart';

/// 石化优惠券（dg-coupon renderer）聊天页。
class DgCouponChatScreen extends StatefulWidget {
  const DgCouponChatScreen({
    super.key,
    required this.agent,
    this.conversationId,
    this.onBack,
  });

  final ToolboxAgentItem agent;
  final int? conversationId;
  final VoidCallback? onBack;

  @override
  State<DgCouponChatScreen> createState() => _DgCouponChatScreenState();
}

class _DgCouponChatScreenState extends State<DgCouponChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  ProductAgentConversation? _conversation;
  List<ProductAgentConversationSummary> _conversations = [];
  List<ProductAgentMessage> _messages = [];
  bool _loading = true;
  bool _loadingHistory = false;
  bool _sending = false;
  bool _historyOpen = false;

  String get _structuredBlock =>
      widget.agent.parserConfig.structuredBlock.isNotEmpty
          ? widget.agent.parserConfig.structuredBlock
          : 'dg-coupon';

  int? get _conversationId => _conversation?.conversationId;

  String get _headerTitle {
    final t = _conversation?.title?.trim();
    if (t != null && t.isNotEmpty) return t;
    return widget.agent.displayName;
  }

  @override
  void initState() {
    super.initState();
    _input.addListener(_onInputChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _input.removeListener(_onInputChanged);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    if (mounted) setState(() {});
  }

  bool get _canSend =>
      !_loading &&
      !_sending &&
      (_conversation?.conversationId ?? 0) > 0 &&
      _input.text.trim().isNotEmpty;

  void _toast(String message) {
    if (!mounted || message.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      var conversations = await ProductAgentApi.fetchConversations(
        widget.agent.agentCode,
      );
      conversations = _sortConversations(conversations);

      ProductAgentConversation? conv;
      final initialId = widget.conversationId ?? 0;
      if (initialId > 0) {
        final summary = _findSummary(conversations, initialId);
        conv = ProductAgentConversation(
          conversationId: initialId,
          agentCode: widget.agent.agentCode,
          modelCode: summary?.modelCode ?? '',
          title: summary?.title,
        );
      } else if (conversations.isNotEmpty) {
        final first = conversations.first;
        conv = ProductAgentConversation(
          conversationId: first.conversationId,
          agentCode: first.agentCode,
          modelCode: first.modelCode,
          title: first.title,
        );
      } else {
        conv = await ProductAgentApi.createConversation(widget.agent.agentCode);
        conversations = _sortConversations(
          await ProductAgentApi.fetchConversations(widget.agent.agentCode),
        );
      }

      var messages = <ProductAgentMessage>[];
      if (conv != null && conv.conversationId > 0) {
        messages = await ProductAgentApi.fetchMessages(
          widget.agent.agentCode,
          conv.conversationId,
        );
      }
      if (!mounted) return;
      setState(() {
        _conversation = conv;
        _conversations = conversations;
        _messages = messages;
        _loading = false;
      });
      await _jumpToEndAfterLayout();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('加载失败，请重试');
    }
  }

  List<ProductAgentConversationSummary> _sortConversations(
    List<ProductAgentConversationSummary> items,
  ) {
    return List<ProductAgentConversationSummary>.from(items)
      ..sort((a, b) => b.sortTime.compareTo(a.sortTime));
  }

  ProductAgentConversationSummary? _findSummary(
    List<ProductAgentConversationSummary> items,
    int conversationId,
  ) {
    for (final item in items) {
      if (item.conversationId == conversationId) return item;
    }
    return null;
  }

  Future<void> _loadMessages(int conversationId) async {
    final list = await ProductAgentApi.fetchMessages(
      widget.agent.agentCode,
      conversationId,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _messages = list;
    });
    await _jumpToEndAfterLayout();
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (!silent) setState(() => _loadingHistory = true);
    try {
      final list = await ProductAgentApi.fetchConversations(
        widget.agent.agentCode,
      );
      if (!mounted) return;
      setState(() => _conversations = _sortConversations(list));
    } finally {
      if (mounted && !silent) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _jumpToEndAfterLayout() async {
    for (var i = 0; i < 2; i++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_scroll.hasClients) continue;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    }
  }

  Future<ProductAgentConversation?> _ensureConversation() async {
    final current = _conversation;
    if (current != null && current.conversationId > 0) return current;
    final created = await ProductAgentApi.createConversation(
      widget.agent.agentCode,
    );
    if (!mounted) return null;
    if (created == null) {
      _toast('创建会话失败');
      return null;
    }
    setState(() => _conversation = created);
    await _loadConversations(silent: true);
    return created;
  }

  Future<void> _send([String? overrideText]) async {
    final text = (overrideText ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    final conv = await _ensureConversation();
    if (conv == null || conv.conversationId <= 0) return;
    final consented = await ensureAiDataConsent(context);
    if (!consented || !mounted) return;
    if (overrideText == null) _input.clear();
    setState(() {
      _sending = true;
      _messages = [
        ..._messages,
        ProductAgentMessage(id: -1, role: 'user', content: text),
        const ProductAgentMessage(
          id: -2,
          role: 'assistant',
          content: '',
          streaming: true,
        ),
      ];
    });
    _scrollToEnd();

    ProductAgentSseClient.sendMessage(
      agentCode: widget.agent.agentCode,
      conversationId: conv.conversationId,
      content: text,
      onDelta: (delta) {
        if (!mounted) return;
        setState(() {
          final last = _messages.last;
          if (last.streaming) {
            _messages[_messages.length - 1] =
                last.copyWith(content: last.content + delta);
          }
        });
        _scrollToEnd();
      },
      onDone: (_) async {
        if (!mounted) return;
        await _loadMessages(conv.conversationId);
        await _loadConversations(silent: true);
        if (mounted) setState(() => _sending = false);
      },
      onError: (code, message) {
        if (!mounted) return;
        setState(() {
          _sending = false;
          if (_messages.isNotEmpty && _messages.last.streaming) {
            _messages.removeLast();
          }
        });
        _toast(message);
      },
    );
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _openHistory() async {
    if (_sending) {
      _toast('请等待回复完成');
      return;
    }
    setState(() => _historyOpen = true);
    await _loadConversations();
  }

  void _closeHistory() => setState(() => _historyOpen = false);

  Future<void> _createNewConversation() async {
    if (_sending) {
      _toast('请等待回复完成');
      return;
    }
    final conv =
        await ProductAgentApi.createConversation(widget.agent.agentCode);
    if (!mounted) return;
    if (conv == null) {
      _toast('创建会话失败');
      return;
    }
    setState(() {
      _conversation = conv;
      _messages = [];
    });
    await _loadConversations(silent: true);
    if (!mounted) return;
    _closeHistory();
  }

  Future<void> _switchToConversation(
    ProductAgentConversationSummary item,
  ) async {
    if (_sending) {
      _toast('请等待回复完成');
      return;
    }
    if (_conversationId == item.conversationId) {
      _closeHistory();
      return;
    }
    setState(() {
      _loading = true;
      _conversation = ProductAgentConversation(
        conversationId: item.conversationId,
        agentCode: item.agentCode,
        modelCode: item.modelCode,
        title: item.title,
      );
    });
    try {
      await _loadMessages(item.conversationId);
      if (!mounted) return;
      _closeHistory();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('加载会话失败');
    }
  }

  String _historyDateLabel(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final day = DateTime(local.year, local.month, local.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    if (diff < 7) return '$diff天前';
    final month = local.month.toString().padLeft(2, '0');
    final dayText = local.day.toString().padLeft(2, '0');
    return '${local.year}年$month月$dayText日';
  }

  List<({String label, List<ProductAgentConversationSummary> items})>
      get _groupedConversations {
    final sorted = _sortConversations(_conversations);
    final order = <String>[];
    final groups = <String, List<ProductAgentConversationSummary>>{};
    for (final c in sorted) {
      final label = _historyDateLabel(c.sortTime);
      groups.putIfAbsent(label, () => []).add(c);
      if (!order.contains(label)) order.add(label);
    }
    return [for (final label in order) (label: label, items: groups[label]!)];
  }

  Future<void> _showConversationActions(
    ProductAgentConversationSummary item,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: MirrorColors.bgApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, size: 20),
              title: Text('重命名', style: MirrorTheme.sans(fontSize: 15)),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                size: 20,
                color: MirrorColors.coral,
              ),
              title: Text(
                '删除',
                style: MirrorTheme.sans(
                  fontSize: 15,
                  color: MirrorColors.coral,
                ),
              ),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'rename') {
      await _renameConversation(item);
    } else if (action == 'delete') {
      await _deleteConversation(item);
    }
  }

  Future<void> _renameConversation(
    ProductAgentConversationSummary item,
  ) async {
    final ctrl = TextEditingController(
      text: item.displayTitle == '新对话' ? '' : item.displayTitle,
    );
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '重命名会话',
          style: MirrorTheme.sans(fontSize: 16, weight: FontWeight.w600),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 128,
          decoration: const InputDecoration(hintText: '输入会话标题'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (!mounted || title == null || title.isEmpty) return;
    final conv = await ProductAgentApi.patchConversationTitle(
      widget.agent.agentCode,
      item.conversationId,
      title,
    );
    if (!mounted) return;
    if (conv == null) {
      _toast('重命名失败');
      return;
    }
    await _loadConversations(silent: true);
    if (_conversationId == item.conversationId) {
      setState(() => _conversation = conv);
    }
  }

  Future<void> _deleteConversation(
    ProductAgentConversationSummary item,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '删除会话',
          style: MirrorTheme.sans(fontSize: 16, weight: FontWeight.w600),
        ),
        content: Text(
          '删除后无法恢复，确定删除「${item.displayTitle}」？',
          style: MirrorTheme.sans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '删除',
              style: MirrorTheme.sans(color: MirrorColors.coral),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final deleted = await ProductAgentApi.deleteConversation(
      widget.agent.agentCode,
      item.conversationId,
    );
    if (!mounted) return;
    if (!deleted) {
      _toast('删除失败');
      return;
    }
    await _loadConversations(silent: true);
    if (_conversationId != item.conversationId) return;

    if (_conversations.isNotEmpty) {
      await _switchToConversation(_conversations.first);
      return;
    }
    await _createNewConversation();
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = widget.agent.uiConfig.placeholder.isNotEmpty
        ? widget.agent.uiConfig.placeholder
        : '问问有哪些优惠券、查库存…';
    final welcome = widget.agent.uiConfig.welcomeMessage;
    final drawerW = MediaQuery.sizeOf(context).width * 0.75;

    return Stack(
      children: [
        Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                      itemCount: _messages.isEmpty && welcome.isNotEmpty
                          ? 2
                          : _messages.length + 1,
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildAiDisclaimerBanner(),
                          );
                        }
                        if (_messages.isEmpty && welcome.isNotEmpty) {
                          return _welcomeBubble(welcome);
                        }
                        final m = _messages[i - 1];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child:
                              m.isUser ? _userBubble(m) : _assistantBubble(m),
                        );
                      },
                    ),
            ),
            SimpleChatComposer(
              controller: _input,
              enabled: !_sending && !_loading,
              canSend: _canSend,
              hintText: placeholder,
              onSend: () => _send(),
            ),
          ],
        ),
        if (_historyOpen) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeHistory,
              child: Container(color: Colors.black.withValues(alpha: 0.35)),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: drawerW,
            child: _historyDrawer(),
          ),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: MirrorColors.borderSoft)),
      ),
      child: Row(
        children: [
          if (widget.onBack != null) MirrorBackButton(onTap: widget.onBack),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _headerTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MirrorTheme.sans(
                    fontSize: 14,
                    weight: FontWeight.w500,
                    letterSpacing: -0.01,
                  ),
                ),
                if (_messages.isEmpty)
                  Text(
                    '新会话',
                    style: MirrorTheme.sans(
                      fontSize: 12,
                      color: MirrorColors.text3,
                    ),
                  )
                else
                  Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: _sending
                              ? MirrorColors.accent
                              : MirrorColors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _sending ? 'responding' : 'listening',
                        style: MirrorTheme.mono(
                          fontSize: 10,
                          color: _sending
                              ? MirrorColors.accent
                              : MirrorColors.green,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          MirrorPressable(
            onTap: _sending ? null : _createNewConversation,
            borderRadius: BorderRadius.circular(8),
            padding: const EdgeInsets.all(8),
            child: Icon(
              Icons.note_add_outlined,
              size: 20,
              color: _sending ? MirrorColors.text3 : MirrorColors.text2,
            ),
          ),
          MirrorPressable(
            onTap: _openHistory,
            borderRadius: BorderRadius.circular(8),
            padding: const EdgeInsets.all(8),
            child: const Icon(
              Icons.menu_rounded,
              size: 20,
              color: MirrorColors.text2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyDrawer() {
    return Material(
      color: MirrorColors.bgApp,
      elevation: 8,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Text(
                    '会话历史',
                    style: MirrorTheme.sans(
                      fontSize: 16,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _closeHistory,
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: MirrorColors.text3,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: MirrorColors.borderSoft),
            Expanded(
              child: _loadingHistory
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _conversations.isEmpty
                      ? Center(
                          child: Text(
                            '暂无历史会话',
                            style: MirrorTheme.sans(
                              fontSize: 13,
                              color: MirrorColors.text3,
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
                          children: [
                            for (final group in _groupedConversations) ...[
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 6),
                                child: Text(
                                  group.label,
                                  style: MirrorTheme.sans(
                                    fontSize: 12,
                                    color: MirrorColors.text3,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              for (final item in group.items)
                                _historyTile(item),
                              const SizedBox(height: 4),
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyTile(ProductAgentConversationSummary item) {
    final active = _conversationId == item.conversationId;
    return ListTile(
      dense: true,
      selected: active,
      selectedTileColor: MirrorColors.accentSoft.withValues(alpha: 0.35),
      leading: Icon(
        Icons.chat_bubble_outline_rounded,
        size: 18,
        color: active ? MirrorColors.accent : MirrorColors.text3,
      ),
      title: Text(
        item.displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: MirrorTheme.sans(
          fontSize: 14,
          weight: active ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.more_horiz, size: 18, color: MirrorColors.text3),
        onPressed: () => _showConversationActions(item),
      ),
      onTap: () => _switchToConversation(item),
      onLongPress: () => _showConversationActions(item),
    );
  }

  Widget _buildAiDisclaimerBanner() {
    return Text(
      '内容由AI生成仅供参考',
      textAlign: TextAlign.center,
      style: MirrorTheme.sans(
        fontSize: 11,
        color: MirrorColors.text4,
        height: 1.4,
      ),
    );
  }

  Widget _welcomeBubble(String text) => Align(
        alignment: Alignment.center,
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.sizeOf(context).height * 0.16,
            left: 32,
            right: 32,
          ),
          child: Column(
            children: [
              Text(
                '新会话',
                style: MirrorTheme.sans(
                  fontSize: 22,
                  weight: FontWeight.w600,
                  color: MirrorColors.text,
                  letterSpacing: -0.02,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                text,
                textAlign: TextAlign.center,
                style: MirrorTheme.sans(
                  fontSize: 14,
                  color: MirrorColors.text3,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _userBubble(ProductAgentMessage m) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: MirrorColors.text,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: SelectableText(
            m.content,
            style: MirrorTheme.sans(
              fontSize: 13,
              height: 1.55,
              color: Colors.white,
            ),
          ),
        ),
      );

  Widget _assistantBubble(ProductAgentMessage m) {
    final parsed = m.streaming
        ? DgCouponParsedMessage(markdownText: m.content)
        : parseDgCouponMessage(m.content, structuredBlock: _structuredBlock);

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MirrorAssistantIdentityRow(),
            const SizedBox(height: 8),
            if (m.streaming && m.content.isEmpty)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: MirrorColors.text3.withValues(alpha: 0.6),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (parsed.markdownText.isNotEmpty)
                    ChatMarkdownBody(source: parsed.markdownText),
                  if (parsed.products.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final p in parsed.products)
                            DgCouponProductCard(
                              product: p,
                              onQueryStock: (code) =>
                                  _send('$code 还有多少库存？'),
                              onCopyFeedback: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('已复制产品码')),
                                );
                              },
                            ),
                        ],
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
