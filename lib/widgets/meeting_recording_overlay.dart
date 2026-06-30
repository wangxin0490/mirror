import 'package:flutter/material.dart';

import '../app/mirror_app_keys.dart';
import '../services/meeting_recording_service.dart';
import '../services/voice_record_config.dart';
import '../services/voice_record_shared.dart';
import '../screens/voice_record_screen.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../widgets/mirror_pressable.dart';

/// App 内后台录音浮条：离开录音页后显示，点击返回录音界面。
class MeetingRecordingOverlay extends StatelessWidget {
  const MeetingRecordingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MeetingRecordingService.instance,
      builder: (context, _) {
        final svc = MeetingRecordingService.instance;
        if (!svc.showOverlay) return const SizedBox.shrink();

        final session = svc.controller;
        final elapsed = session?.elapsed ?? Duration.zero;
        final title = session?.title ?? '会议录音';
        final phaseLabel = switch (session?.phase) {
          VoiceRecordPhase.recording => '录音中',
          VoiceRecordPhase.paused => '已暂停',
          _ => '待开始',
        };

        return Positioned(
          top: MediaQuery.paddingOf(context).top + 6,
          left: 14,
          right: 14,
          child: IgnorePointer(
            ignoring: false,
            child: Material(
              color: Colors.transparent,
              child: MirrorPressable(
                onTap: () => _returnToRecordScreen(),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B2A28),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: MirrorColors.coral,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$phaseLabel · ${voiceDurationLabel(elapsed)}',
                              style: MirrorTheme.sans(
                                fontSize: 13,
                                weight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              title,
                              style: MirrorTheme.sans(fontSize: 11, color: MirrorColors.white70),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '返回',
                        style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.accentSoft),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _returnToRecordScreen() {
    final svc = MeetingRecordingService.instance;
    final upload = svc.uploadFn;
    if (upload == null) return;

    final nav = mirrorRootNavigatorKey.currentState;
    if (nav == null) return;

    svc.attachScreen(upload);
    nav.push<bool>(
      MaterialPageRoute(
        builder: (_) => VoiceRecordScreen(
          config: VoiceRecordConfig.meeting,
          onUpload: upload,
        ),
      ),
    );
  }
}
