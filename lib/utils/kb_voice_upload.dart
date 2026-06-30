/// 与后端 [defaultAudioExtensions] 对齐的 KB 语音文件名校验。
bool isKbVoiceFilename(String filename) {
  final n = filename.toLowerCase();
  const exts = [
    '.da', '.wave', '.wav', '.mp3', '.aac', '.flac', '.ogg', '.aiff', '.au',
    '.midi', '.wma', '.m4a', '.webm', '.opus', '.ape',
  ];
  for (final ext in exts) {
    if (n.endsWith(ext)) return true;
  }
  return false;
}

int kbVoiceMaxBytes(int maxVoiceMb) => maxVoiceMb * 1024 * 1024;

bool isKbVoiceWithinSizeLimit(int bytes, int maxVoiceMb) =>
    bytes <= kbVoiceMaxBytes(maxVoiceMb);

String kbVoiceSizeLimitMessage(int maxVoiceMb) => '音频超过 ${maxVoiceMb}MB 上限';

String kbVoiceDurationLimitMessage(int maxVoiceSeconds) {
  if (maxVoiceSeconds >= 3600 && maxVoiceSeconds % 3600 == 0) {
    return '已达最长录音 ${maxVoiceSeconds ~/ 3600} 小时，请结束保存';
  }
  if (maxVoiceSeconds >= 60 && maxVoiceSeconds % 60 == 0) {
    return '已达最长录音 ${maxVoiceSeconds ~/ 60} 分钟，请结束保存';
  }
  return '已达最长录音上限，请结束保存';
}
