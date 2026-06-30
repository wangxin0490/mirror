import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/models/meeting_models.dart';

void main() {
  test('failed session may have playable audio after upload', () {
    expect(meetingSessionMayHaveAudio('failed'), isTrue);
  });

  test('uploading session has no remote audio yet', () {
    expect(meetingSessionMayHaveAudio('uploading'), isFalse);
  });

  test('done and in-progress post-upload sessions may have audio', () {
    for (final status in ['uploaded', 'transcribing', 'generating', 'done']) {
      expect(meetingSessionMayHaveAudio(status), isTrue, reason: status);
    }
  });
}
