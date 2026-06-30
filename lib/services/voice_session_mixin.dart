import 'voice_recorder_service.dart';
import 'voice_record_shared.dart';

/// 录音会话 UI 所需的最小接口（KB / 会议共用）。
mixin VoiceSessionMixin {
  VoiceRecordPhase get phase;
  Duration get elapsed;
  double get amplitude;
  List<VoiceSegmentMarker> get segments;
  String get title;
  set title(String value);
  String get liveTranscript;
  bool get asrSegmentBusy;
  bool get canFinish;
  bool get hasSession;
  bool get limitReached;
  String? get lastFinishError;
  bool get finishBroken;

  void markTitleEdited();
  Future<void> start();
  Future<void> pause();
  Future<RecordedVoice?> finish();
  Future<void> discard();
}
