import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../api/api_result.dart';
import '../../api/meeting_api.dart';
import '../../models/meeting_draft.dart';
import '../../models/meeting_hub_item.dart';
import '../../models/meeting_models.dart';
import '../../models/toolbox_agent_models.dart';
import '../../services/file_picker_service.dart';
import '../../services/meeting_draft_store.dart';
import '../../services/meeting_upload_worker.dart';
import '../../services/voice_recorder_service.dart';
import '../../state/meeting_session_store.dart';
import '../kb/kb_voice_record_screen.dart';
import '../../theme/mirror_colors.dart';
import '../../theme/mirror_theme.dart';
import '../../widgets/mirror_pressable.dart';
import '../../widgets/phone_components.dart';

/// 会议纪要 Hub：历史列表 + 开始录音。
class MeetingHubScreen extends StatefulWidget {
  const MeetingHubScreen({
    super.key,
    required this.agent,
    this.onBack,
    this.onOpenDetail,
  });

  final ToolboxAgentItem agent;
  final VoidCallback? onBack;
  final void Function(int sessionId)? onOpenDetail;

  @override
  State<MeetingHubScreen> createState() => _MeetingHubScreenState();
}

class _MeetingHubScreenState extends State<MeetingHubScreen> {
  bool _loading = true;
  bool _uploadingAudio = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await MeetingSessionStore.instance.refreshList();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _startRecording() async {
    final ok = await openMeetingVoiceRecordScreen(context);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(kIsWeb ? '会议录音已上传' : '录音已保存，后台上传中')),
      );
      await _load();
    }
  }

  Future<void> _uploadAudio() async {
    if (_uploadingAudio) return;
    final picked = await pickFiles(maxCount: 1);
    if (!mounted || picked.isEmpty) return;
    final file = picked.first;
    if (!_isAudioFilename(file.name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择音频文件（m4a/wav/mp3/webm 等）')),
      );
      return;
    }
    if (!file.hasBytes && !file.hasPath) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法读取音频文件，请重试或选择其他文件')),
      );
      return;
    }

    setState(() => _uploadingAudio = true);
    final title = _titleFromFilename(file.name);
    final ApiResult<int> r;
    if (!kIsWeb && file.hasPath) {
      r = await MeetingApi.createSessionFromFile(file.path!, file.name, title: title);
    } else {
      r = await MeetingApi.createSession(
        RecordedVoice(bytes: file.bytes, filename: file.name),
        title: title,
      );
    }
    if (!mounted) return;
    setState(() => _uploadingAudio = false);
    if (r.ok && (r.data ?? 0) > 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('录音上传成功，正在生成会议纪要')));
      await _load();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(r.message.isNotEmpty ? r.message : '上传失败，请重试')),
    );
  }

  Future<void> _deleteSession(MeetingSessionSummary item) async {
    final ok = await _confirmDelete(item.title);
    if (ok != true || !mounted) return;
    final r = await MeetingApi.deleteSession(item.id);
    if (!mounted) return;
    if (r.ok) {
      MeetingSessionStore.instance.removeSession(item.id);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已删除')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r.message.isNotEmpty ? r.message : '删除失败')),
      );
    }
  }

  Future<void> _deleteDraft(MeetingDraft draft) async {
    final ok = await _confirmDelete(draft.title);
    if (ok != true || !mounted) return;
    await MeetingDraftStore.instance.removeDraft(draft.localId);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已删除')));
  }

  Future<bool?> _confirmDelete(String title) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '删除会议',
          style: MirrorTheme.sans(fontSize: 16, weight: FontWeight.w600),
        ),
        content: Text(
          '删除后无法恢复，确定删除「$title」？',
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
  }

  Future<void> _retry(MeetingSessionSummary item) async {
    final stage = item.status == 'failed' && item.minutesPreview.isNotEmpty
        ? 'minutes'
        : 'transcribe';
    final r = await MeetingApi.retrySession(item.id, stage: stage);
    if (!mounted) return;
    if (r.ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已重新提交处理')));
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r.message.isNotEmpty ? r.message : '重试失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        MeetingSessionStore.instance,
        MeetingDraftStore.instance,
        MeetingUploadWorker.instance,
      ]),
      builder: (context, _) {
        final merged = mergeMeetingHubItems(
          drafts: MeetingDraftStore.instance.drafts,
          sessions: MeetingSessionStore.instance.items,
        );
        final expiredCount = MeetingDraftStore.instance.expiredDrafts.length;
        return Column(
          children: [
            MirrorAppBar(
              title: widget.agent.displayName,
              accentPart: '会议纪要',
              onBack: widget.onBack,
            ),
            if (expiredCount > 0) _expiredDraftBanner(expiredCount),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Row(
                children: [
                  Expanded(
                    child: MirrorPressable(
                      onTap: _startRecording,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: MirrorColors.accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '开始录音',
                          style: MirrorTheme.sans(
                            fontSize: 14,
                            weight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MirrorPressable(
                      onTap: _uploadingAudio ? null : _uploadAudio,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: MirrorColors.accent),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _uploadingAudio
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                '上传录音',
                                style: MirrorTheme.sans(
                                  fontSize: 14,
                                  weight: FontWeight.w600,
                                  color: MirrorColors.accent,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : merged.isEmpty
                  ? Center(
                      child: Text(
                        '暂无会议记录\n点击上方按钮开始录音',
                        textAlign: TextAlign.center,
                        style: MirrorTheme.sans(
                          fontSize: 13,
                          color: MirrorColors.text3,
                          height: 1.6,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
                      itemCount: merged.length,
                      itemBuilder: (_, i) => _hubRow(merged[i]),
                    ),
            ),
          ],
        );
      },
    );
  }

  bool _isAudioFilename(String name) {
    final lower = name.toLowerCase();
    const exts = [
      '.m4a',
      '.wav',
      '.mp3',
      '.webm',
      '.aac',
      '.ogg',
      '.flac',
      '.amr',
      '.mp4',
    ];
    return exts.any(lower.endsWith);
  }

  String _titleFromFilename(String filename) {
    final dot = filename.lastIndexOf('.');
    final base = (dot > 0 ? filename.substring(0, dot) : filename).trim();
    if (base.isEmpty) return '会议录音_${DateTime.now().millisecondsSinceEpoch}';
    return base;
  }

  Widget _expiredDraftBanner(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: MirrorColors.coral.withValues(alpha: 0.08),
          border: Border.all(color: MirrorColors.coral.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '有 $count 条录音草稿已超过 7 天，建议清理以释放空间',
                style: MirrorTheme.sans(
                  fontSize: 12,
                  color: MirrorColors.text2,
                  height: 1.4,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                final n = await MeetingDraftStore.instance.purgeExpiredDrafts();
                if (!mounted) return;
                if (n > 0) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('已清理 $n 条过期草稿')));
                }
              },
              child: Text(
                '清理',
                style: MirrorTheme.sans(
                  fontSize: 12,
                  color: MirrorColors.coral,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hubRow(MeetingHubItem item) {
    return switch (item) {
      MeetingHubDraftItem(:final draft) => _draftRow(draft),
      MeetingHubSessionItem(:final session) => _sessionRow(session),
    };
  }

  Widget _draftRow(MeetingDraft draft) {
    final uploading = draft.state == DraftUploadState.uploading;
    final stalled = draft.state == DraftUploadState.stalled;
    return GestureDetector(
      onLongPress: () => _showDraftActions(draft),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: MirrorColors.bgApp,
          border: Border.all(color: MirrorColors.borderSoft),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        draft.title,
                        style: MirrorTheme.sans(
                          fontSize: 13.5,
                          weight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${draft.statusLabel} · ${meetingDurationLabel(draft.durationSec)}',
                        style: MirrorTheme.mono(
                          fontSize: 10,
                          color: MirrorColors.text3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (uploading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (stalled)
                  TextButton(
                    onPressed: () =>
                        MeetingUploadWorker.instance.retryDraft(draft.localId),
                    child: Text(
                      '重试',
                      style: MirrorTheme.sans(
                        fontSize: 12,
                        color: MirrorColors.accentDeep,
                      ),
                    ),
                  ),
              ],
            ),
            if (uploading && draft.uploadProgress > 0) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: draft.uploadProgress.clamp(0.0, 1.0),
                  minHeight: 3,
                  backgroundColor: MirrorColors.borderSoft,
                  color: MirrorColors.accentDeep,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sessionRow(MeetingSessionSummary item) {
    final processing = item.isProcessing;
    return GestureDetector(
      onLongPress: () => _showSessionActions(item),
      child: MirrorPressable(
        onTap: () => widget.onOpenDetail?.call(item.id),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: MirrorColors.bgApp,
            border: Border.all(color: MirrorColors.borderSoft),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: MirrorTheme.sans(
                        fontSize: 13.5,
                        weight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.statusLabel} · ${meetingDurationLabel(item.durationSec)}',
                      style: MirrorTheme.mono(
                        fontSize: 10,
                        color: MirrorColors.text3,
                      ),
                    ),
                    if (item.minutesPreview.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.minutesPreview,
                        style: MirrorTheme.sans(
                          fontSize: 11,
                          color: MirrorColors.text2,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (processing)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (item.status == 'failed')
                TextButton(
                  onPressed: () => _retry(item),
                  child: Text(
                    '重试',
                    style: MirrorTheme.sans(
                      fontSize: 12,
                      color: MirrorColors.accentDeep,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: MirrorColors.text3,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDraftActions(MeetingDraft draft) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (draft.state == DraftUploadState.stalled)
              ListTile(
                leading: const Icon(Icons.refresh, size: 20),
                title: Text('重试上传', style: MirrorTheme.sans(fontSize: 15)),
                onTap: () => Navigator.pop(ctx, 'retry'),
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
    if (action == 'retry') {
      await MeetingUploadWorker.instance.retryDraft(draft.localId);
    } else if (action == 'delete') {
      await _deleteDraft(draft);
    }
  }

  Future<void> _showSessionActions(MeetingSessionSummary item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
    if (!mounted || action != 'delete') return;
    await _deleteSession(item);
  }
}
