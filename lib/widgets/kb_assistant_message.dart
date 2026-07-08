import 'package:flutter/material.dart';

import '../models/kb_chat_models.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../widgets/agent_copy_button.dart';
import '../widgets/chat_empty_hint_card.dart';
import '../widgets/chat_markdown_body.dart';
import '../widgets/kb_source_sheet.dart';
import '../widgets/mirror_assistant_identity.dart';
import '../widgets/mirror_pressable.dart';

/// 知识库问答助手消息：身份、引用资料、Markdown 正文（含 [ID:N] 角标）。
class KbAssistantMessage extends StatefulWidget {
  const KbAssistantMessage({
    super.key,
    required this.message,
    this.onOpenSource,
    this.onCopyFeedback,
  });

  final KbMessage message;
  final void Function(KbMessageSource source)? onOpenSource;
  final VoidCallback? onCopyFeedback;

  @override
  State<KbAssistantMessage> createState() => _KbAssistantMessageState();
}

class _KbAssistantMessageState extends State<KbAssistantMessage> {
  void _openSourceSheet(List<KbMessageSourceGroup> groups) {
    showKbSourceSheet(
      context: context,
      groups: groups,
      onOpenSource: widget.onOpenSource,
    );
  }

  void _handleCitation(int index) {
    final sources = widget.message.sources;
    KbMessageSource? source;
    for (final s in sources) {
      if (s.index == index) {
        source = s;
        break;
      }
    }
    if (source == null) {
      return;
    }
    if (widget.onOpenSource != null && source.canPreview) {
      widget.onOpenSource!(source);
      return;
    }
    _openSourceSheet([
      KbMessageSourceGroup(primary: source, indices: [source.index]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final sources = m.sources;
    final sourceGroups = groupKbMessageSources(sources);
    final content = m.content.trim();
    final showEmptyHint = !m.streaming && ChatEmptyHintCard.isKbEmptyHintContent(content);

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MirrorAssistantIdentityRow(
              trailing: !m.streaming && content.isNotEmpty
                  ? AgentCopyButton(
                      text: m.content,
                      tooltip: '复制回复',
                      onCopied: widget.onCopyFeedback,
                    )
                  : null,
            ),
            const SizedBox(height: 8),
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
            else if (showEmptyHint)
              ChatEmptyHintCard(message: content)
            else
              ChatMarkdownBody(
                source: m.content,
                onCitationTap: _handleCitation,
                showAiGeneratedLabel: !m.streaming,
              ),
          ],
        ),
      ),
    );
  }
}
