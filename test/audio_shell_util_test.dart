import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/utils/audio_shell_util.dart';
import 'package:mirror_mobile/utils/wav_asr_util.dart';

void main() {
  test('detects empty m4a/mp4 shell by ftyp header and small size', () {
    final shell = List<int>.filled(1500, 0);
    shell.setRange(4, 8, 'ftyp'.codeUnits);
    expect(looksLikeEmptyAudioShell(shell, durationSec: 5), isTrue);
  });

  test('accepts m4a with mdat when above duration byte threshold', () {
    final bytes = List<int>.filled(5461, 0);
    bytes.setRange(4, 8, 'ftyp'.codeUnits);
    bytes.setRange(100, 104, 'mdat'.codeUnits);
    expect(looksLikeEmptyAudioShell(bytes, durationSec: 5), isFalse);
  });

  test('detects tiny m4a with mdat but far below duration threshold', () {
    final bytes = List<int>.filled(4544, 0);
    bytes.setRange(4, 8, 'ftyp'.codeUnits);
    bytes.setRange(100, 104, 'mdat'.codeUnits);
    expect(looksLikeEmptyAudioShell(bytes, durationSec: 19), isTrue);
  });

  test('accepts short but valid m4a above duration threshold', () {
    final bytes = List<int>.filled(12000, 0);
    bytes.setRange(4, 8, 'ftyp'.codeUnits);
    expect(looksLikeEmptyAudioShell(bytes, durationSec: 1), isFalse);
  });

  test('accepts wav built by WavAsrUtil', () {
    final pcm = List<int>.filled(32000, 1);
    final wav = WavAsrUtil.buildWav(Uint8List.fromList(pcm));
    expect(looksLikeEmptyAudioShell(wav, durationSec: 1), isFalse);
  });

  test('detects wav header-only file', () {
    final wav = List<int>.filled(44, 0);
    wav.setRange(0, 4, 'RIFF'.codeUnits);
    wav.setRange(8, 12, 'WAVE'.codeUnits);
    expect(looksLikeEmptyAudioShell(wav), isTrue);
  });

  test('repairs WAV whose data size field was never written back', () {
    final pcm = Uint8List.fromList(List<int>.filled(32000, 7));
    final wav = List<int>.from(WavAsrUtil.buildWav(pcm));
    // 模拟被中断：data 块长度字段清零（PCM 仍在文件尾）。
    final dataIdx = _indexOfData(wav);
    wav.setRange(dataIdx + 4, dataIdx + 8, [0, 0, 0, 0]);
    // 损坏文件被判为空。
    expect(WavAsrUtil.extractPcm(wav), anyOf(isNull, isEmpty));

    final repaired = WavAsrUtil.repair(wav);
    expect(repaired, isNotNull);
    final recovered = WavAsrUtil.extractPcm(repaired!);
    expect(recovered, isNotNull);
    expect(recovered!.length, 32000);
    expect(looksLikeEmptyAudioShell(repaired, durationSec: 2), isFalse);
  });

  test('repair leaves a valid WAV unchanged', () {
    final pcm = Uint8List.fromList(List<int>.filled(16000, 3));
    final wav = WavAsrUtil.buildWav(pcm);
    expect(WavAsrUtil.repair(wav), equals(wav));
  });

  test('repair returns null for non-wav bytes', () {
    final m4a = List<int>.filled(2048, 0);
    m4a.setRange(4, 8, 'ftyp'.codeUnits);
    expect(WavAsrUtil.repair(m4a), isNull);
  });
}

int _indexOfData(List<int> wav) {
  for (var i = 12; i + 4 <= wav.length; i++) {
    if (wav[i] == 0x64 && wav[i + 1] == 0x61 && wav[i + 2] == 0x74 && wav[i + 3] == 0x61) {
      return i;
    }
  }
  return -1;
}
