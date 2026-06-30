import 'package:flutter/material.dart';

import '../models/agent_models.dart';
import '../models/kb_chat_models.dart';
import '../screens/kb/kb_ui_helpers.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../utils/agent_external_link.dart';
import '../utils/mixed_markup.dart';
import 'mirror_pressable.dart';

/// 引用来源 BottomSheet 展示项（知识库 / Agent 共用）。
class CitationSourceEntry {
  const CitationSourceEntry({
    required this.title,
    required this.snippet,
    required this.icon,
    required this.iconColor,
    required this.typeLabel,
    this.trailingLabel,
    this.onTap,
  });

  final String title;
  final String snippet;
  final IconData icon;
  final Color iconColor;
  final String typeLabel;
  final String? trailingLabel;
  final VoidCallback? onTap;
}

/// 半屏 / 全屏吸附高度（相对屏幕比例）。
const double _citationSheetHalfSize = 0.55;
const double _citationSheetFullSize = 1.0;
const double _citationSheetDismissExtent = 0.28;

Future<void> _showCitationEntriesSheet({
  required BuildContext context,
  required List<CitationSourceEntry> entries,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: true,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      final height = MediaQuery.sizeOf(sheetCtx).height;
      return SizedBox(
        height: height,
        child: NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            if (notification.extent <= _citationSheetDismissExtent) {
              Navigator.of(sheetCtx).pop();
              return true;
            }
            return false;
          },
          child: DraggableScrollableSheet(
            initialChildSize: _citationSheetHalfSize,
            minChildSize: _citationSheetDismissExtent,
            maxChildSize: _citationSheetFullSize,
            expand: false,
            snap: true,
            snapSizes: const [_citationSheetHalfSize, _citationSheetFullSize],
            builder: (context, scrollController) {
              return _CitationSourceSheetBody(
                entries: entries,
                scrollController: scrollController,
              );
            },
          ),
        ),
      );
    },
  );
}

/// 知识库引用来源 BottomSheet。
Future<void> showKbSourceSheet({
  required BuildContext context,
  required List<KbMessageSourceGroup> groups,
  void Function(KbMessageSource source)? onOpenSource,
}) {
  final entries = [
    for (final group in groups)
      CitationSourceEntry(
        title: group.primary.title,
        snippet: _kbSnippetText(group.primary),
        icon: KbDocUi.fileTypeForFilename(group.primary.title).$1,
        iconColor: KbDocUi.fileTypeForFilename(group.primary.title).$2,
        typeLabel: KbDocUi.fileTypeForFilename(group.primary.title).$3,
        trailingLabel: group.indices.length > 1 ? group.idLabel : null,
        onTap: onOpenSource == null
            ? null
            : () {
                Navigator.pop(context);
                onOpenSource(group.primary);
              },
      ),
  ];
  return _showCitationEntriesSheet(context: context, entries: entries);
}

/// Agent 联网搜索等引用来源 BottomSheet。
Future<void> showAgentSourceSheet({
  required BuildContext context,
  required List<AgentMessageSourceGroup> groups,
  void Function(AgentMessageSource source)? onOpenSource,
}) {
  final entries = [
    for (final group in groups)
      CitationSourceEntry(
        title: group.primary.title,
        snippet: _agentSnippetText(group.primary),
        icon: Icons.language,
        iconColor: MirrorColors.accentDeep,
        typeLabel: agentSourceHostLabel(group.primary.url),
        trailingLabel: group.indices.length > 1 ? group.idLabel : null,
        onTap: onOpenSource == null
            ? null
            : () {
                Navigator.pop(context);
                onOpenSource(group.primary);
              },
      ),
  ];
  return _showCitationEntriesSheet(context: context, entries: entries);
}

String _kbSnippetText(KbMessageSource source) {
  final raw = source.snippet?.trim() ?? '';
  if (raw.isNotEmpty) return plainTextFromMixedMarkup(raw);
  if (source.canPreview) return '点击查看正文';
  return '';
}

String _agentSnippetText(AgentMessageSource source) {
  final raw = source.snippet?.trim() ?? '';
  if (raw.isNotEmpty) return raw;
  if (source.hasUrl) return '点击打开网页';
  return '';
}

class _CitationSourceSheetBody extends StatelessWidget {
  const _CitationSourceSheetBody({
    required this.entries,
    required this.scrollController,
  });

  final List<CitationSourceEntry> entries;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: MirrorColors.bgApp,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Color(0x26000000), blurRadius: 24, offset: Offset(0, -6)),
        ],
      ),
      child: CustomScrollView(
        controller: scrollController,
        physics: const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(child: _CitationSheetDragHeader()),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 24 + bottomInset),
            sliver: SliverList.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                return _CitationSourceCard(
                  index: index + 1,
                  entry: entries[index],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 顶部拖拽区：与 [DraggableScrollableSheet] 共用 scrollController，上拉全屏、下拉缩回。
class _CitationSheetDragHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: MirrorColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            '引用来源',
            textAlign: TextAlign.center,
            style: MirrorTheme.sans(fontSize: 17, weight: FontWeight.w600),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: MirrorColors.borderSoft),
      ],
    );
  }
}

class _CitationSourceCard extends StatelessWidget {
  const _CitationSourceCard({
    required this.index,
    required this.entry,
  });

  final int index;
  final CitationSourceEntry entry;

  @override
  Widget build(BuildContext context) {
    return MirrorPressable(
      onTap: entry.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MirrorColors.borderSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$index. ${entry.title}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: MirrorTheme.sans(fontSize: 15, weight: FontWeight.w600, height: 1.35),
            ),
            if (entry.snippet.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                entry.snippet,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: MirrorTheme.sans(fontSize: 13, color: MirrorColors.text3, height: 1.5),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(entry.icon, size: 14, color: entry.iconColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    entry.typeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text3),
                  ),
                ),
                if (entry.trailingLabel != null)
                  Text(
                    entry.trailingLabel!,
                    style: MirrorTheme.mono(fontSize: 10, color: MirrorColors.text3),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
