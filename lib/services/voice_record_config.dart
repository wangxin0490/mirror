import 'package:flutter/foundation.dart';

import 'kb_voice_session_controller.dart';
import 'meeting_voice_session_controller.dart';

/// 全屏录音页配置。
class VoiceRecordConfig {
  const VoiceRecordConfig({
    required this.enableLiveAsr,
    required this.maxDuration,
    required this.titlePrefix,
    required this.showTranscriptArea,
    required this.backgroundCapable,
    required this.fileExt,
    required this.createController,
  });

  final bool enableLiveAsr;
  final Duration? maxDuration;
  final String titlePrefix;
  final bool showTranscriptArea;
  final bool backgroundCapable;
  final String fileExt;
  final ChangeNotifier Function({String? title}) createController;

  /// 知识库语音导入（滚动 ASR + 默认 30 分钟上限）。
  static VoiceRecordConfig kb({Duration? maxDuration}) {
    final d = maxDuration ?? const Duration(seconds: 1800);
    return VoiceRecordConfig(
      enableLiveAsr: true,
      maxDuration: d,
      titlePrefix: '录音纪要',
      showTranscriptArea: true,
      backgroundCapable: false,
      fileExt: 'wav',
      createController: ({String? title}) => KbVoiceSessionController(title: title, maxDuration: d),
    );
  }

  static final meeting = VoiceRecordConfig(
    enableLiveAsr: false,
    maxDuration: const Duration(hours: 4),
    titlePrefix: '会议录音',
    showTranscriptArea: false,
    backgroundCapable: true,
    fileExt: kIsWeb ? 'webm' : 'm4a',
    createController: ({String? title}) => MeetingVoiceSessionController(title: title),
  );
}
