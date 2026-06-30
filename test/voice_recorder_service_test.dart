import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/services/voice_recorder_service.dart' show voiceRecorderFilenameFromPath;

void main() {
  test('blob URL keeps wav fallback when extension missing', () {
    expect(
      voiceRecorderFilenameFromPath('blob:http://127.0.0.1:50802/abc-def-123'),
      'voice.wav',
    );
  });

  test('native path preserves filename', () {
    expect(
      voiceRecorderFilenameFromPath(r'C:\tmp\mirror_voice_1.wav'),
      'mirror_voice_1.wav',
    );
  });
}
