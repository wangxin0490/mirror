import 'package:flutter/material.dart';

import '../models/agent_models.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../utils/agent_external_link.dart';
import '../utils/dg_coupon_parser.dart';
import '../widgets/agent_copy_button.dart';
import '../widgets/chat_markdown_body.dart';
import '../widgets/dg_coupon_product_card.dart';
import '../widgets/kb_source_sheet.dart';
import '../widgets/mirror_pressable.dart';
import '../widgets/mirror_assistant_identity.dart';

/// DeepSeek / 豆包式助手消息：身份、工具状态、Markdown 正文、可点击引用。
class AgentAssistantMessage extends StatefulWidget {
  const AgentAssistantMessage({
    super.key,
    required this.message,
    this.onLinkFailure,
    this.onCopyFeedback,
    this.onDgCouponQueryStock,
  });

  final AgentMessage message;
  final void Function(String message)? onLinkFailure;
  final VoidCallback? onCopyFeedback;
  final ValueChanged<String>? onDgCouponQueryStock;

  @override
  State<AgentAssistantMessage> createState() => _AgentAssistantMessageState();
}

class _AgentAssistantMessageState extends State<AgentAssistantMessage> {
  Future<void> _openUrl(String? url) async {
    if (!mounted) return;
    await openAgentExternalLink(context, url, onFailure: widget.onLinkFailure);
  }

  void _openSource(AgentMessageSource source) {
    if (source.hasUrl) {
      _openUrl(source.url);
      return;
    }
    widget.onLinkFailure?.call('链接不可用');
  }

  void _openSourceSheet(List<AgentMessageSourceGroup> groups) {
    showAgentSourceSheet(
      context: context,
      groups: groups,
      onOpenSource: _openSource,
    );
  }

  void _handleCitation(int index) {
    final sources = widget.message.sources ?? const <AgentMessageSource>[];
    AgentMessageSource? source;
    for (final s in sources) {
      if (s.index == index) {
        source = s;
        break;
      }
    }
    if (source == null) {
      return;
    }
    if (source.hasUrl) {
      _openSource(source);
      return;
    }
    _openSourceSheet([
      AgentMessageSourceGroup(primary: source, indices: [source.index]),
    ]);
  }

  Widget _assistantBody(AgentMessage m) {
    final parsed = m.streaming
        ? DgCouponParsedMessage(markdownText: m.content)
        : parseDgCouponMessage(m.content);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (parsed.markdownText.isNotEmpty)
          ChatMarkdownBody(
            source: parsed.markdownText,
            onCitationTap: _handleCitation,
            onLinkTap: _openUrl,
            onCopyFeedback: widget.onCopyFeedback,
            showAiGeneratedLabel: !m.streaming,
          ),
        if (parsed.products.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final p in parsed.products)
                DgCouponProductCard(
                  product: p,
                  onQueryStock: widget.onDgCouponQueryStock,
                  onCopyFeedback: widget.onCopyFeedback,
                ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final sources = m.sources ?? const <AgentMessageSource>[];
    final sourceGroups = groupAgentMessageSources(sources);

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MirrorAssistantIdentityRow(
              trailing: !m.streaming && m.content.trim().isNotEmpty
                  ? AgentCopyButton(
                      text: m.content,
                      tooltip: '复制回复',
                      onCopied: widget.onCopyFeedback,
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            if (m.searching)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: MirrorColors.accent.withValues(alpha: 0.8)),
                    ),
                    const SizedBox(width: 6),
                    Text('正在联网搜索', style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text3)),
                  ],
                ),
              ),
            if (sourceGroups.isNotEmpty) ...[
              MirrorPressable(
                onTap: () => _openSourceSheet(sourceGroups),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: MirrorColors.bgSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: MirrorColors.borderSoft),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book_outlined, size: 14, color: MirrorColors.accentDeep),
                      const SizedBox(width: 6),
                      Text(
                        '引用 ${sourceGroups.length} 篇资料作为参考',
                        style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text2, weight: FontWeight.w500),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 16, color: MirrorColors.text3),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (m.streaming && m.content.isEmpty)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: MirrorColors.text3.withValues(alpha: 0.6)),
              )
            else
              _assistantBody(m),
          ],
        ),
      ),
    );
  }
}
