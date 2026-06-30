import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/services/base_voice_session_controller.dart';
import 'package:mirror_mobile/services/meeting_voice_session_controller.dart';
import 'package:mirror_mobile/services/voice_record_shared.dart';

void main() {
  test('minBytesPerSecond uses stricter threshold for wav', () {
    expect(BaseVoiceSessionController.minBytesPerSecond('wav'), 16000);
    expect(BaseVoiceSessionController.minBytesPerSecond('m4a'), 1024);
    expect(BaseVoiceSessionController.minBytesPerSecond('webm'), 1024);
  });

  test('finishBroken disables canFinish and hasSession', () {
    final c = MeetingVoiceSessionController();
    c.phase = VoiceRecordPhase.paused;
    c.elapsed = const Duration(seconds: 5);
    expect(c.canFinish, isTrue);
    expect(c.hasSession, isTrue);

    c.finishBroken = true;
    expect(c.canFinish, isFalse);
    expect(c.hasSession, isFalse);
  });

  test('meeting controller always uses virtual pause', () {
    final c = MeetingVoiceSessionController();
    expect(c.virtualPause, isTrue);
  });
}
