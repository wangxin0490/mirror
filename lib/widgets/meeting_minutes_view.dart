import 'package:flutter/material.dart';

import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../utils/meeting_minutes_parser.dart';
import 'mirror_markdown_body.dart';
import 'mirror_pressable.dart';

enum MeetingMinutesSection { overview, agenda, resolutions, todos }

/// 结构化会议纪要卡片视图（对齐设计稿：概览 / 议题 / 决议 / 待办）。
class MeetingMinutesView extends StatefulWidget {
  const MeetingMinutesView({
    super.key,
    required this.parsed,
  });

  final ParsedMeetingMinutes parsed;

  @override
  State<MeetingMinutesView> createState() => _MeetingMinutesViewState();
}

class _MeetingMinutesViewState extends State<MeetingMinutesView> {
  MeetingMinutesSection _section = MeetingMinutesSection.overview;
  var _agendaExpanded = true;
  var _resolutionsExpanded = true;
  var _todosExpanded = true;

  ParsedMeetingMinutes get _p => widget.parsed;

  @override
  Widget build(BuildContext context) {
    if (!_p.hasStructure) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        child: MirrorMarkdownBody(source: _p.rawMarkdown),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionNav(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
            children: _sectionCards(),
          ),
        ),
      ],
    );
  }

  List<Widget> _sectionCards() {
    switch (_section) {
      case MeetingMinutesSection.overview:
        return [
          if (_p.agenda.isNotEmpty) _expandableSectionCard(
            title: '会议议题',
            icon: Icons.format_list_numbered_rounded,
            iconBg: MirrorColors.blueSoft,
            iconColor: MirrorColors.blue,
            body: _p.agenda,
            expanded: _agendaExpanded,
            onToggle: () => setState(() => _agendaExpanded = !_agendaExpanded),
          ),
          if (_p.resolutions.isNotEmpty) _expandableSectionCard(
            title: '会议决议',
            icon: Icons.check_circle_outline_rounded,
            iconBg: MirrorColors.greenSoft,
            iconColor: MirrorColors.green,
            body: _p.resolutions,
            expanded: _resolutionsExpanded,
            onToggle: () => setState(() => _resolutionsExpanded = !_resolutionsExpanded),
          ),
          if (_p.todosMarkdown.isNotEmpty || _p.todos.isNotEmpty)
            _todosContentCard(hideTitle: false),
        ];
      case MeetingMinutesSection.agenda:
        if (_p.agenda.isEmpty) return [_emptyHint('暂无议题')];
        return [_sectionBodyCard(_p.agenda)];
      case MeetingMinutesSection.resolutions:
        if (_p.resolutions.isEmpty) return [_emptyHint('暂无决议')];
        return [_sectionBodyCard(_p.resolutions)];
      case MeetingMinutesSection.todos:
        if (_p.todosMarkdown.isEmpty && _p.todos.isEmpty) return [_emptyHint('暂无待办')];
        return [_todosContentCard(hideTitle: true)];
    }
  }

  Widget _sectionNav() {
    const items = <(MeetingMinutesSection, String, IconData)>[
      (MeetingMinutesSection.overview, '概览', Icons.auto_awesome_outlined),
      (MeetingMinutesSection.agenda, '议题', Icons.format_list_numbered_rounded),
      (MeetingMinutesSection.resolutions, '决议', Icons.check_circle_outline_rounded),
      (MeetingMinutesSection.todos, '待办', Icons.task_alt_outlined),
    ];
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (sec, label, icon) = items[i];
          final selected = _section == sec;
          return MirrorPressable(
            onTap: () => setState(() => _section = sec),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 62,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: selected ? MirrorColors.accentSoft.withValues(alpha: 0.55) : MirrorColors.bgSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? MirrorColors.accentBorder : MirrorColors.borderSoft,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: selected ? MirrorColors.accentDeep : MirrorColors.text3),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: MirrorTheme.sans(
                      fontSize: 11,
                      weight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? MirrorColors.accentDeep : MirrorColors.text3,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _expandableSectionCard({
    required String title,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String body,
    required bool expanded,
    required VoidCallback onToggle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: MirrorColors.bgApp,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MirrorColors.borderSoft),
      ),
      child: Column(
        children: [
          MirrorPressable(
            onTap: onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  _iconBadge(icon, iconBg, iconColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title, style: MirrorTheme.sans(fontSize: 14, weight: FontWeight.w600)),
                  ),
                  Icon(
                    expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: MirrorColors.text3,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: MirrorMarkdownBody(source: body),
            ),
        ],
      ),
    );
  }

  Widget _sectionBodyCard(String body) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MirrorColors.bgApp,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MirrorColors.borderSoft),
      ),
      child: MirrorMarkdownBody(source: body),
    );
  }

  Widget _todosContentCard({required bool hideTitle}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: MirrorColors.bgApp,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MirrorColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!hideTitle)
            MirrorPressable(
              onTap: () => setState(() => _todosExpanded = !_todosExpanded),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    _iconBadge(Icons.task_alt_outlined, MirrorColors.amberSoft, MirrorColors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('待办事项', style: MirrorTheme.sans(fontSize: 14, weight: FontWeight.w600)),
                    ),
                    Icon(
                      _todosExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: MirrorColors.text3,
                    ),
                  ],
                ),
              ),
            ),
          if (hideTitle || _todosExpanded)
            Padding(
              padding: EdgeInsets.fromLTRB(14, hideTitle ? 14 : 0, 14, 14),
              child: _todosBody(fullWidth: hideTitle),
            ),
        ],
      ),
    );
  }

  Widget _todosBody({required bool fullWidth}) {
    if (_p.todosIsTable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _p.todos
            .map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _todoRow(row, compact: !fullWidth && _section == MeetingMinutesSection.overview),
              ),
            )
            .toList(),
      );
    }
    if (_p.todosMarkdown.isNotEmpty) {
      return MirrorMarkdownBody(source: _p.todosMarkdown);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _p.todos
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _todoRow(row, compact: !fullWidth && _section == MeetingMinutesSection.overview),
            ),
          )
          .toList(),
    );
  }

  Widget _todoRow(MeetingTodoRow row, {required bool compact}) {
    if (compact && row.owner.isEmpty && row.deadline.isEmpty && row.status.isEmpty) {
      return Text('• ${row.item}', style: MirrorTheme.sans(fontSize: 13, height: 1.5));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: MirrorColors.bgSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MirrorColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.item, style: MirrorTheme.sans(fontSize: 13, weight: FontWeight.w500, height: 1.45)),
          if (row.owner.isNotEmpty || row.deadline.isNotEmpty || row.status.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (row.owner.isNotEmpty)
                  Text('负责人 ${row.owner}', style: MirrorTheme.sans(fontSize: 11, color: MirrorColors.text3)),
                if (row.deadline.isNotEmpty)
                  Text('截止 ${row.deadline}', style: MirrorTheme.mono(fontSize: 11, color: MirrorColors.text3)),
                if (row.status.isNotEmpty) _statusBadge(row.status),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final (bg, fg) = switch (status) {
      '待处理' => (MirrorColors.amberSoft, MirrorColors.amber),
      '进行中' => (MirrorColors.blueSoft, MirrorColors.blue),
      '待确认' => (MirrorColors.accentSoft, MirrorColors.accentDeep),
      '已完成' => (MirrorColors.greenSoft, MirrorColors.green),
      _ => (MirrorColors.bgCard, MirrorColors.text2),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(status, style: MirrorTheme.sans(fontSize: 10, weight: FontWeight.w600, color: fg)),
    );
  }

  Widget _iconBadge(IconData icon, Color bg, Color fg) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: fg),
    );
  }

  Widget _emptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(text, style: MirrorTheme.sans(fontSize: 13, color: MirrorColors.text3)),
      ),
    );
  }

}
