import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/utils/meeting_audio_mime.dart';

void main() {
  test('meetingAudioMimeType maps common extensions', () {
    expect(meetingAudioMimeType('recording.mp3'), 'audio/mpeg');
    expect(meetingAudioMimeType('voice.m4a'), 'audio/mp4');
    expect(meetingAudioMimeType('clip.wav'), 'audio/wav');
    expect(meetingAudioMimeType('notes.txt'), isNull);
  });
}
