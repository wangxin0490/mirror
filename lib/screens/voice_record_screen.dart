import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api/api_result.dart';
import '../api/meeting_api.dart';
import '../models/kb_models.dart';
import '../services/meeting_draft_store.dart';
import '../services/meeting_recording_service.dart';
import '../services/meeting_upload_worker.dart';
import '../state/meeting_session_store.dart';
import '../services/voice_record_config.dart';
import '../services/voice_recorder_service.dart';
import '../services/voice_record_shared.dart';
import '../services/voice_session_mixin.dart';
import '../utils/kb_voice_upload.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../widgets/mirror_pressable.dart';

typedef VoiceUploadFn = Future<ApiResult<dynamic>> Function(
  RecordedVoice recorded, {
  void Function(double progress)? onProgress,
});

/// 全屏录音：单文件 pause/resume，确认后上传。
class VoiceRecordScreen extends StatefulWidget {
  const VoiceRecordScreen({
    super.key,
    required this.config,
    this.onUpload,
  });

  final VoiceRecordConfig config;
  /// 知识库同步上传；会议模式为 null，录完写本地草稿后后台上传。
  final VoiceUploadFn? onUpload;

  @override
  State<VoiceRecordScreen> createState() => _VoiceRecordScreenState();
}

class _VoiceRecordScreenState extends State<VoiceRecordScreen> {
  late final ChangeNotifier _raw;
  late final VoiceSessionMixin _session;
  late final bool _meetingBackground;
  var _uploading = false;
  var _uploadProgress = 0;
  var _limitNotified = false;

  @override
  void initState() {
    super.initState();
    _meetingBackground = widget.config.backgroundCapable;
    if (_meetingBackground) {
      final svc = MeetingRecordingService.instance;
      svc.ensureSession();
      svc.attachScreen(widget.onUpload ?? _noopUpload);
      _raw = svc.controller!;
    } else {
      _raw = widget.config.createController();
    }
    _session = _raw as VoiceSessionMixin;
    _raw.addListener(_onSessionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_requestMicPermission()));
  }

  Future<void> _requestMicPermission() async {
    final granted = await ensureMicrophonePermission();
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('需要麦克风权限才能录音')),
      );
    }
  }

  void _onSessionChanged() {
    if (_session.limitReached && !_limitNotified && !widget.config.backgroundCapable) {
      _limitNotified = true;
      final sec = widget.config.maxDuration?.inSeconds ?? KbUploadLimits.defaults.maxVoiceSeconds;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(kbVoiceDurationLimitMessage(sec))),
        );
      });
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _raw.removeListener(_onSessionChanged);
    if (_meetingBackground) {
      MeetingRecordingService.instance.detachScreen();
    } else {
      _raw.dispose();
    }
    super.dispose();
  }

  Future<bool> _confirmDiscard() async {
    if (!_session.hasSession) return true;
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: MirrorColors.overlayDim,
      builder: (ctx) => Dialog(
        backgroundColor: MirrorColors.bgApp,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('确认放弃录音', style: MirrorTheme.sans(fontSize: 17, weight: FontWeight.w600)),
              const SizedBox(height: 10),
              Text(
                '放弃本次录音，并删除已录内容',
                style: MirrorTheme.sans(fontSize: 14, color: MirrorColors.text2, height: 1.5),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('取消', style: MirrorTheme.sans(fontSize: 15, color: MirrorColors.text)),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('确认', style: MirrorTheme.sans(fontSize: 15, color: MirrorColors.coral)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return ok == true;
  }

  Future<void> _onBack() async {
    if (_uploading) return;
    if (await _confirmDiscard()) {
      await _session.discard();
      if (mounted) Navigator.pop(context, false);
    }
  }

  Future<void> _onDiscardTap() async {
    if (_uploading) return;
    if (await _confirmDiscard()) {
      if (_meetingBackground) {
        await MeetingRecordingService.instance.clearSession();
      } else {
        await _session.discard();
      }
      if (mounted) Navigator.pop(context, false);
    }
  }

  Future<void> _onCenterTap() async {
    if (_uploading) return;
    if (_session.limitReached && _session.phase == VoiceRecordPhase.paused) {
      final sec = widget.config.maxDuration?.inSeconds ?? KbUploadLimits.defaults.maxVoiceSeconds;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(kbVoiceDurationLimitMessage(sec))),
      );
      return;
    }
    try {
      if (_session.phase == VoiceRecordPhase.recording) {
        await _session.pause();
      } else {
        await _session.start();
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('StateError: ', '').replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.isNotEmpty ? msg : '无法开始录音，请检查麦克风权限')),
      );
    }
  }

  Future<void> _onFinishTap() async {
    if (_uploading) return;
    if (!_session.canFinish) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('录音太短，请至少录 1 秒')));
      return;
    }
    _uploading = true;
    _uploadProgress = 0;
    setState(() {});
    final recorded = await _session.finish();
    if (!mounted) return;
    if (recorded == null) {
      setState(() => _uploading = false);
      final detail = _session.lastFinishError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            detail?.isNotEmpty == true
                ? detail!
                : '未录到有效音频，请重新录制',
          ),
        ),
      );
      return;
    }

    if (_meetingBackground) {
      try {
        if (kIsWeb) {
          final r = await MeetingApi.createSession(
            recorded,
            title: _session.title,
            onProgress: (p) {
              if (!mounted) return;
              setState(() => _uploadProgress = (p * 100).round().clamp(0, 100));
            },
          );
          if (!mounted) return;
          if (r.ok) {
            await MeetingRecordingService.instance.clearSession(discard: false);
            await MeetingSessionStore.instance.refreshList();
            if (mounted) Navigator.pop(context, true);
          } else {
            setState(() => _uploading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(r.message.isNotEmpty ? r.message : '上传失败')),
            );
          }
          return;
        }

        final draft = await MeetingDraftStore.instance.saveFromRecording(
          bytes: recorded.bytes,
          filename: recorded.filename,
          title: _session.title,
          durationSec: recorded.duration.inSeconds,
        );
        MeetingUploadWorker.instance.enqueue(draft.localId);
        await MeetingRecordingService.instance.clearSession(discard: false);
        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        if (!mounted) return;
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(
              kIsWeb ? '上传失败，请检查网络后重试' : '保存录音失败，请检查存储空间或重新录制',
            )),
          );
      }
      return;
    }

    final onUpload = widget.onUpload;
    if (onUpload == null) {
      setState(() => _uploading = false);
      return;
    }
    final r = await onUpload(
      recorded,
      onProgress: (p) {
        if (!mounted) return;
        setState(() => _uploadProgress = (p * 100).round().clamp(0, 100));
      },
    );
    if (!mounted) return;
    if (r.ok) {
      if (mounted) Navigator.pop(context, true);
    } else {
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r.message.isNotEmpty ? r.message : '上传失败')),
      );
    }
  }

  static Future<ApiResult<dynamic>> _noopUpload(
    RecordedVoice recorded, {
    void Function(double progress)? onProgress,
  }) async {
    return ApiResult(code: 0, message: '', data: null);
  }

  Future<void> _editTitle() async {
    if (_uploading) return;
    final ctrl = TextEditingController(text: _session.title);
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('编辑标题', style: MirrorTheme.sans(fontSize: 16, weight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 64,
          decoration: InputDecoration(hintText: widget.config.titlePrefix),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('确定')),
        ],
      ),
    );
    if (next != null && next.isNotEmpty) {
      setState(() {
        _session.title = next;
        _session.markTitleEdited();
      });
    }
  }

  String get _statusLabel {
    if (_uploading) return '正在保存…';
    if (_session.finishBroken) return '录音保存失败';
    if (_session.limitReached) return '已达上限';
    return switch (_session.phase) {
      VoiceRecordPhase.recording => '录音中',
      VoiceRecordPhase.paused => '已暂停',
      VoiceRecordPhase.idle => '待开始',
    };
  }

  String get _centerLabel {
    if (_uploading) return '…';
    if (_session.finishBroken) return '需重录';
    if (_session.limitReached && _session.phase == VoiceRecordPhase.paused) return '已达上限';
    return switch (_session.phase) {
      VoiceRecordPhase.recording => '暂停',
      VoiceRecordPhase.paused => '继续',
      VoiceRecordPhase.idle => '开始',
    };
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _onBack();
      },
      child: Scaffold(
        backgroundColor: MirrorColors.bgApp,
        appBar: AppBar(
          backgroundColor: MirrorColors.bgApp,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: MirrorColors.text2),
            onPressed: _uploading ? null : _onBack,
          ),
          title: Text(
            _session.title,
            style: MirrorTheme.sans(fontSize: 15, weight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20, color: MirrorColors.text2),
              onPressed: _uploading ? null : _editTitle,
            ),
          ],
        ),
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.config.showTranscriptArea && _session.liveTranscript.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                            child: Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(maxHeight: 120),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: MirrorColors.borderSoft),
                              ),
                              child: SingleChildScrollView(
                                child: Text(
                                  _session.liveTranscript,
                                  style: MirrorTheme.sans(
                                    fontSize: 14,
                                    color: MirrorColors.text2,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        _VoiceWaveform(
                          amplitude: _session.amplitude,
                          active: _session.phase == VoiceRecordPhase.recording,
                        ),
                        const SizedBox(height: 28),
                        Text(
                          voiceDurationLabel(_session.elapsed),
                          style: MirrorTheme.mono(
                            fontSize: 40,
                            weight: FontWeight.w500,
                            color: MirrorColors.text,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_statusLabel.isNotEmpty)
                          Text(_statusLabel, style: MirrorTheme.sans(fontSize: 14, color: MirrorColors.text3)),
                        if (_meetingBackground && _session.hasSession)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '返回可后台继续录音',
                              style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text4),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_session.segments.isNotEmpty) ...[
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _session.segments.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => _SegmentChip(marker: _session.segments[i]),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _SideActionButton(
                          icon: Icons.close_rounded,
                          enabled: !_uploading,
                          onTap: _onDiscardTap,
                        ),
                        _CenterRecordButton(
                          label: _centerLabel,
                          enabled: !_uploading &&
                              !_session.finishBroken &&
                              !(_session.limitReached && _session.phase == VoiceRecordPhase.paused),
                          recording: _session.phase == VoiceRecordPhase.recording,
                          onTap: _onCenterTap,
                        ),
                        _SideActionButton(
                          icon: Icons.check_rounded,
                          enabled: _session.canFinish && !_uploading,
                          onTap: _onFinishTap,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_uploading) _UploadOverlay(progress: _uploadProgress),
          ],
        ),
      ),
    );
  }
}

class _VoiceWaveform extends StatelessWidget {
  const _VoiceWaveform({required this.amplitude, required this.active});

  final double amplitude;
  final bool active;

  @override
  Widget build(BuildContext context) {
    const barCount = 8;
    return SizedBox(
      height: 72,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(barCount, (i) {
          final wave = active ? (0.25 + amplitude * 0.75) * (0.6 + 0.4 * ((i % 3) + 1) / 3) : 0.12;
          final h = 12.0 + 48.0 * wave;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: 5,
              height: h,
              decoration: BoxDecoration(
                color: active
                    ? MirrorColors.accentDeep.withValues(alpha: 0.35 + amplitude * 0.45)
                    : MirrorColors.borderSoft,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _UploadOverlay extends StatelessWidget {
  const _UploadOverlay({required this.progress});

  final int progress;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: MirrorColors.overlayDim,
        child: Center(
          child: Container(
            width: 200,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: const Color(0xFF2B2A28),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Text(
                  '上传中...$progress%',
                  style: MirrorTheme.sans(fontSize: 15, color: Colors.white, weight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text('请勿退出', style: MirrorTheme.sans(fontSize: 13, color: MirrorColors.white70)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({required this.marker});

  final VoiceSegmentMarker marker;

  static const _chipHeight = 28.0;

  @override
  Widget build(BuildContext context) {
    final label = marker.active
        ? '段${marker.index} · 录音中'
        : '段${marker.index} · ${voiceDurationLabel(marker.duration ?? Duration.zero)}';
    return Center(
      child: Container(
        height: _chipHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: marker.active ? MirrorColors.accentSoft : MirrorColors.bgCard,
          borderRadius: BorderRadius.circular(_chipHeight / 2),
          border: Border.all(color: marker.active ? MirrorColors.accentBorder : MirrorColors.borderSoft),
        ),
        child: Text(
          label,
          style: MirrorTheme.mono(fontSize: 11, color: MirrorColors.text2, height: 1),
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
        ),
      ),
    );
  }
}

class _SideActionButton extends StatelessWidget {
  const _SideActionButton({required this.icon, required this.enabled, required this.onTap});

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MirrorPressable(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? MirrorColors.bgCard : MirrorColors.bgSoft,
          border: Border.all(color: MirrorColors.borderSoft),
        ),
        child: Icon(icon, size: 22, color: enabled ? MirrorColors.text2 : MirrorColors.text4),
      ),
    );
  }
}

class _CenterRecordButton extends StatelessWidget {
  const _CenterRecordButton({
    required this.label,
    required this.enabled,
    required this.recording,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final bool recording;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MirrorPressable(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(44),
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? MirrorColors.text : MirrorColors.borderSoft,
          border: Border.all(color: enabled ? MirrorColors.text : MirrorColors.borderSoft, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: MirrorTheme.sans(
            fontSize: 15,
            weight: FontWeight.w600,
            color: enabled ? Colors.white : MirrorColors.text4,
          ),
        ),
      ),
    );
  }
}

Future<bool> openVoiceRecordScreen(
  BuildContext context, {
  required VoiceRecordConfig config,
  VoiceUploadFn? onUpload,
}) {
  return Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => VoiceRecordScreen(config: config, onUpload: onUpload),
    ),
  ).then((v) => v == true);
}
