import 'package:flutter/material.dart';

import '../api/product_agent_api.dart';
import '../models/toolbox_agent_models.dart';
import '../services/product_agent_sse_client.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../utils/toolbox_agent_icon.dart';
import '../widgets/agent_thinking_bubble.dart';
import '../widgets/mirror_pressable.dart';
import '../widgets/phone_components.dart';

/// 工具箱智能体不可用时的提示文案。
String toolboxAgentDisabledMessage(ToolboxAgentItem agent) {
  if (agent.isModelUnavailable) {
    final model = agent.requiredModel.isNotEmpty
        ? agent.requiredModel
        : agent.defaultModel;
    return model.isNotEmpty ? '暂无 $model 模型权限，请联系管理员' : '该工具暂不可用';
  }
  return '该工具暂不可用';
}

bool toolboxAgentUsesMeetingHub(ToolboxAgentItem agent) =>
    agent.hubScreen == 'meeting' || agent.agentCode == 'meeting-minutes';

/// 全部工具箱智能体列表。
class AgentsListScreen extends StatefulWidget {
  const AgentsListScreen({super.key, this.onBack, this.onAgentTap});

  final VoidCallback? onBack;
  final ValueChanged<ToolboxAgentItem>? onAgentTap;

  @override
  State<AgentsListScreen> createState() => _AgentsListScreenState();
}

class _AgentsListScreenState extends State<AgentsListScreen> {
  List<ToolboxAgentItem> _agents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await ProductAgentApi.fetchAgents(scope: 'all');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (list.isNotEmpty) _agents = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MirrorAppBar(
          title: ' Tools',
          accentPart: '全部工具',
          onBack: widget.onBack,
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                  children: [
                    for (final a in _agents)
                      MirrorPressable(
                        onTap: widget.onAgentTap == null
                            ? null
                            : () => widget.onAgentTap!(a),
                        child: _agentRow(a),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _agentRow(ToolboxAgentItem a) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: MirrorColors.bgApp,
          border: Border.all(color: MirrorColors.borderSoft),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: MirrorColors.accentSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                toolboxAgentIcon(a.iconKey),
                size: 20,
                color: MirrorColors.accentDeep,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.displayName,
                    style: MirrorTheme.sans(
                      fontSize: 13.5,
                      weight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    a.usageSubtitle,
                    style: MirrorTheme.mono(
                      fontSize: 10,
                      color: MirrorColors.text3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 16, color: MirrorColors.text3),
          ],
        ),
      );
}

/// 单个智能体的会话列表 Hub。
class ProductAgentHubScreen extends StatefulWidget {
  const ProductAgentHubScreen({
    super.key,
    required this.agent,
    this.onBack,
    this.onOpenChat,
  });

  final ToolboxAgentItem agent;
  final VoidCallback? onBack;
  final void Function(int conversationId)? onOpenChat;

  @override
  State<ProductAgentHubScreen> createState() => _ProductAgentHubScreenState();
}

class _ProductAgentHubScreenState extends State<ProductAgentHubScreen> {
  List<ProductAgentConversationSummary> _conversations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list =
        await ProductAgentApi.fetchConversations(widget.agent.agentCode);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _conversations = list;
    });
  }

  Future<void> _createAndOpen() async {
    if (!widget.agent.enabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(toolboxAgentDisabledMessage(widget.agent))),
      );
      return;
    }
    if (widget.agent.entryType != 'chat') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该智能体功能即将推出')),
      );
      return;
    }
    final conv =
        await ProductAgentApi.createConversation(widget.agent.agentCode);
    if (!mounted || conv == null) return;
    widget.onOpenChat?.call(conv.conversationId);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MirrorAppBar(
          title: widget.agent.displayName,
          accentPart: '智能体',
          onBack: widget.onBack,
        ),
        if (!widget.agent.enabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
            child: Text(
              toolboxAgentDisabledMessage(widget.agent),
              style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text2),
            ),
          )
        else if (widget.agent.entryType != 'chat')
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
            child: Text(
              '该智能体（${widget.agent.entryType}）即将推出，敬请期待。',
              style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text2),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          child: MirrorPressable(
            onTap: widget.agent.enabled ? _createAndOpen : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: MirrorColors.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '+ 新建对话',
                style: MirrorTheme.sans(
                  fontSize: 13,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _conversations.isEmpty
                  ? Center(
                      child: Text(
                        '暂无对话',
                        style: MirrorTheme.sans(
                          fontSize: 13,
                          color: MirrorColors.text3,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      itemCount: _conversations.length,
                      itemBuilder: (_, i) {
                        final c = _conversations[i];
                        final title = c.title.isNotEmpty
                            ? c.title
                            : '对话 #${c.conversationId}';
                        return MirrorPressable(
                          onTap: widget.onOpenChat == null
                              ? null
                              : () => widget.onOpenChat!(c.conversationId),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: MirrorColors.borderSoft,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: MirrorTheme.sans(fontSize: 13.5),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: MirrorColors.text3,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

/// 工具箱智能体对话页（chat entry_type）。
class ProductAgentChatScreen extends StatefulWidget {
  const ProductAgentChatScreen({
    super.key,
    required this.agent,
    required this.conversationId,
    this.onBack,
  });

  final ToolboxAgentItem agent;
  final int conversationId;
  final VoidCallback? onBack;

  @override
  State<ProductAgentChatScreen> createState() => _ProductAgentChatScreenState();
}

class _ProductAgentChatScreenState extends State<ProductAgentChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<ProductAgentMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await ProductAgentApi.fetchMessages(
      widget.agent.agentCode,
      widget.conversationId,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _messages = list;
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
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
    _input.clear();

    ProductAgentSseClient.sendMessage(
      agentCode: widget.agent.agentCode,
      conversationId: widget.conversationId,
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
      },
      onDone: (_) async {
        if (!mounted) return;
        await _load();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MirrorAppBar(
          title: widget.agent.displayName,
          accentPart: '对话',
          onBack: widget.onBack,
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final m = _messages[i];
                    if (m.streaming && m.content.isEmpty) {
                      return const AgentThinkingBubble();
                    }
                    final align = m.isUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start;
                    final bg =
                        m.isUser ? MirrorColors.accentSoft : MirrorColors.bgApp;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: align,
                        children: [
                          Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * 0.82,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: MirrorColors.borderSoft,
                              ),
                            ),
                            child: Text(
                              m.content,
                              style: MirrorTheme.sans(fontSize: 13.5),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    decoration: InputDecoration(
                      hintText: '输入消息…',
                      filled: true,
                      fillColor: MirrorColors.bgApp,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: MirrorColors.borderSoft,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send_rounded),
                  color: MirrorColors.accent,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
