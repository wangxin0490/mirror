import 'wav_asr_util.dart';

/// m4a/mp4 是否包含 `mdat` 媒体盒（有则通常已写入音频帧）。
bool mp4ContainsMdat(List<int> bytes) {
  const tag = [0x6d, 0x64, 0x61, 0x74]; // mdat
  for (var i = 0; i <= bytes.length - 4; i++) {
    if (bytes[i] == tag[0] &&
        bytes[i + 1] == tag[1] &&
        bytes[i + 2] == tag[2] &&
        bytes[i + 3] == tag[3]) {
      return true;
    }
  }
  return false;
}

/// AAC 语音按秒估算最小合理体积（约 32kbps 的 1/4 容差，短录音不低于 2KB）。
int minM4aBytesForDuration(int sec) {
  if (sec <= 0) return 8192;
  return (sec * 1024).clamp(2048, 1 << 30);
}

/// 识别仅有容器头、几乎没有音频数据的「空壳」文件。
/// [durationSec] 为录音时长（秒），用于按预期大小判断，避免误杀短录音。
bool looksLikeEmptyAudioShell(List<int> bytes, {int? durationSec}) {
  if (bytes.isEmpty) return true;

  final sec = durationSec != null && durationSec > 0 ? durationSec : null;

  if (bytes.length >= 8 && String.fromCharCodes(bytes.sublist(4, 8)) == 'ftyp') {
    if (bytes.length < 2048) return true;
    // 有 mdat 标签不等于有音频数据；真机 pause/resume 后常见 4KB 空壳仍带 mdat。
    if (sec != null) {
      return bytes.length < minM4aBytesForDuration(sec);
    }
    if (mp4ContainsMdat(bytes)) return false;
    return bytes.length < 8192;
  }

  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WAVE') {
    final pcm = WavAsrUtil.extractPcm(bytes);
    if (pcm == null || pcm.isEmpty) return true;
    if (sec != null) {
      final minPcm = sec * WavAsrUtil.defaultSampleRate * WavAsrUtil.bytesPerSample ~/ 4;
      return pcm.length < minPcm;
    }
    return pcm.length < 1000;
  }

  if (sec != null) {
    return bytes.length < sec * 1024;
  }
  return bytes.length < 2000;
}
