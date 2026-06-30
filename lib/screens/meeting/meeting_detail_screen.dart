import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/meeting_api.dart';
import '../../models/meeting_models.dart';
import '../../state/meeting_session_store.dart';
import '../../theme/mirror_colors.dart';
import '../../theme/mirror_theme.dart';
import '../../utils/meeting_minutes_parser.dart';
import '../../widgets/agent_copy_button.dart';
import '../../widgets/kb_audio_player.dart';
import '../../widgets/meeting_minutes_view.dart';
import '../../widgets/mirror_markdown_body.dart';
import '../../widgets/mirror_pressable.dart';
import '../../widgets/phone_components.dart';

/// 会议详情：结构化纪要卡片 + 转写 Tab + 录音播放。
class MeetingDetailScreen extends StatefulWidget {
  const MeetingDetailScreen({
    super.key,
    required this.sessionId,
    this.onBack,
  });

  final int sessionId;
  final VoidCallback? onBack;

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> with SingleTickerProviderStateMixin {
  MeetingSessionDetail? _detail;
  String? _audioUrl;
  bool _loading = true;
  late final TabController _tabs;

  String? _lastKnownStatus;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      if (mounted) setState(() {});
    });
    MeetingSessionStore.instance.addListener(_onStoreChanged);
    _load();
  }

  @override
  void dispose() {
    MeetingSessionStore.instance.removeListener(_onStoreChanged);
    _tabs.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    final summary = MeetingSessionStore.instance.summaryFor(widget.sessionId);
    if (summary == null) return;
    if (_lastKnownStatus == summary.status) return;
    _lastKnownStatus = summary.status;
    final d = _detail;
    if (d == null || d.status != summary.status || (meetingSessionMayHaveAudio(summary.status) && _audioUrl == null)) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final detail = await MeetingApi.getSession(widget.sessionId);
    String? audio;
    if (detail != null && meetingSessionMayHaveAudio(detail.status)) {
      audio = await MeetingApi.getAudioUrl(widget.sessionId);
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _detail = detail;
      _audioUrl = audio;
      _lastKnownStatus = detail?.status;
    });
  }

  Future<void> _retry() async {
    final d = _detail;
    if (d == null) return;
    final stage = d.transcriptText.isNotEmpty ? 'minutes' : 'transcribe';
    final r = await MeetingApi.retrySession(d.id, stage: stage);
    if (!mounted) return;
    if (r.ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已重新提交处理')));
      setState(() => _loading = true);
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r.message.isNotEmpty ? r.message : '重试失败')),
      );
    }
  }

  Future<void> _delete() async {
    final d = _detail;
    if (d == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除会议', style: MirrorTheme.sans(fontSize: 16, weight: FontWeight.w600)),
        content: Text(
          '删除后无法恢复，确定删除「${d.title}」？',
          style: MirrorTheme.sans(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('删除', style: MirrorTheme.sans(color: MirrorColors.coral)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final r = await MeetingApi.deleteSession(d.id);
    if (!mounted) return;
    if (r.ok) {
      MeetingSessionStore.instance.removeSession(d.id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除')));
      widget.onBack?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r.message.isNotEmpty ? r.message : '删除失败')),
      );
    }
  }

  ParsedMeetingMinutes? get _parsedMinutes {
    final md = _detail?.minutesMarkdown ?? '';
    if (md.isEmpty) return null;
    return parseMeetingMinutes(md);
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    return Column(
      children: [
        MirrorAppBar(
          title: d?.title ?? '会议详情',
          onBack: widget.onBack,
          trailing: d == null
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AgentCopyButton(
                      assetIcon: 'assets/images/icon_copy.png',
                      text: _tabs.index == 0 ? d.minutesMarkdown : d.transcriptText,
                      tooltip: _tabs.index == 0 ? '复制纪要' : '复制转写',
                      onCopied: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_tabs.index == 0 ? '纪要已复制' : '转写已复制')),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    MirrorPressable(
                      onTap: _delete,
                      borderRadius: BorderRadius.circular(6),
                      padding: const EdgeInsets.all(4),
                      child: Image.asset(
                        'assets/images/icon_ashbin.png',
                        width: 16,
                        height: 16,
                      ),
                    ),
                  ],
                ),
        ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
        else if (d == null)
          Expanded(
            child: Center(
              child: Text('无法加载会议详情', style: MirrorTheme.sans(color: MirrorColors.text3)),
            ),
          )
        else
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                  child: _audioHeaderCard(d),
                ),
                if (d.status == 'failed') ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: MirrorPressable(
                        onTap: _retry,
                        child: Text(
                          '重试',
                          style: MirrorTheme.sans(fontSize: 13, weight: FontWeight.w500, color: MirrorColors.accentDeep),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                _mainTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _minutesPane(d),
                      _transcriptPane(d),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _mainTabBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Expanded(child: _mainTabItem(0, '纪要')),
              const SizedBox(width: 10),
              Expanded(child: _mainTabItem(1, '转写')),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Divider(height: 1, thickness: 1, color: MirrorColors.borderSoft),
        ),
      ],
    );
  }

  Widget _mainTabItem(int index, String label) {
    final selected = _tabs.index == index;
    const tabMinWidth = 148.0;
    const tabHPadding = 52.0;
    return Column(
      children: [
        Center(
          child: MirrorPressable(
            onTap: () {
              if (_tabs.index == index) return;
              _tabs.animateTo(index);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(minWidth: tabMinWidth),
              padding: const EdgeInsets.symmetric(horizontal: tabHPadding, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? MirrorColors.accentSoft.withValues(alpha: 0.55) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: MirrorTheme.sans(
                  fontSize: 14,
                  weight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? MirrorColors.accentDeep : MirrorColors.text3,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: selected ? 40 : 0,
          height: 3,
          decoration: BoxDecoration(
            color: MirrorColors.accentDeep,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ],
    );
  }

  Widget _audioHeaderCard(MeetingSessionDetail d) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MirrorColors.bgApp,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MirrorColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                meetingDurationLabel(d.durationSec),
                style: MirrorTheme.mono(fontSize: 13, weight: FontWeight.w600),
              ),
              const SizedBox(width: 10),
              Expanded(child: _waveformPlaceholder()),
              const SizedBox(width: 10),
              _statusBadge(d),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _formatDateTime(d.createdAt),
            style: MirrorTheme.mono(fontSize: 11, color: MirrorColors.text3),
          ),
          if (_audioUrl != null && _audioUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            KbAudioPlayer(
              url: _audioUrl!,
              filename: d.originalFilename.isNotEmpty ? d.originalFilename : 'recording.m4a',
            ),
          ],
        ],
      ),
    );
  }

  Widget _waveformPlaceholder() {
    const heights = [6.0, 10.0, 14.0, 8.0, 16.0, 12.0, 18.0, 10.0, 14.0, 8.0, 12.0, 16.0, 10.0];
    return SizedBox(
      height: 20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final h in heights)
            Container(
              width: 3,
              height: h,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                color: MirrorColors.accent.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusBadge(MeetingSessionDetail d) {
    final (bg, fg, icon) = switch (d.status) {
      'done' => (MirrorColors.greenSoft, MirrorColors.green, Icons.check_circle_rounded),
      'failed' => (MirrorColors.coralSoft, MirrorColors.coral, Icons.error_outline_rounded),
      _ => (MirrorColors.accentSoft, MirrorColors.accentDeep, Icons.hourglass_top_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(d.statusLabel, style: MirrorTheme.sans(fontSize: 10, weight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }

  Widget _emptyContentPane(String text) {
    return Center(
      child: Text(
        text,
        style: MirrorTheme.sans(fontSize: 15, color: MirrorColors.text3),
      ),
    );
  }

  Widget _minutesPane(MeetingSessionDetail d) {
    if (d.minutesMarkdown.isEmpty) {
      return _emptyContentPane(d.isProcessing ? '纪要生成中，请稍候…' : '暂无纪要');
    }
    final parsed = _parsedMinutes!;
    return MeetingMinutesView(parsed: parsed);
  }

  Widget _transcriptPane(MeetingSessionDetail d) {
    if (d.transcriptText.isEmpty) {
      return _emptyContentPane(d.isProcessing ? '转写进行中…' : '暂无转写');
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      child: MirrorMarkdownBody(source: d.transcriptText),
    );
  }

  static String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year;
    final m = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$day $h:$min';
  }
}
