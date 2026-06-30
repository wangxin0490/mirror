import 'package:flutter/foundation.dart';

import 'base_voice_session_controller.dart';
import 'meeting_background_recording.dart';
import 'voice_record_shared.dart';

/// 会议纪要录音：无实时 ASR，默认最长 4 小时。
/// Web 为 webm；原生用 16kHz mono WAV（线性写入，被系统杀进程也能 salvage）。
/// 会议模式始终虚拟暂停，避免 pause/resume 写出空壳文件。
class MeetingVoiceSessionController extends BaseVoiceSessionController {
  MeetingVoiceSessionController({String? title})
      : super(
          title: title,
          maxDuration: const Duration(hours: 4),
          titlePrefix: '会议录音',
          forAsr: false,
          fileExt: kIsWeb ? 'webm' : 'wav',
          virtualPause: true,
          recordWav: !kIsWeb,
        );

  @override
  Future<void> start() async {
    // Android 14+ 需在录音前确保前台服务/音频会话就绪，否则系统切断麦克风。
    if (phase == VoiceRecordPhase.idle && !kIsWeb) {
      await MeetingBackgroundRecording.prepareForRecording();
    }
    await super.start();
  }
}
