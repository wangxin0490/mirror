enum VoiceRecordPhase { idle, recording, paused }

/// 单次录音中的段落标记（仅 UI 用，音频仍为单文件）。
class VoiceSegmentMarker {
  VoiceSegmentMarker({required this.index, required this.startedAt});

  final int index;
  final Duration startedAt;
  Duration? duration;
  bool active = true;
}

String voiceDurationLabel(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

String voiceTitleToFilename(String title, {String ext = 'wav'}) {
  final base = title.trim().isEmpty ? '录音纪要' : title.trim();
  final safe = base.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  for (final e in ['.m4a', '.webm', '.wav']) {
    if (safe.endsWith(e)) return safe;
  }
  return '$safe.$ext';
}

String defaultVoiceTitle(String prefix) {
  final n = DateTime.now();
  String pad2(int v) => v.toString().padLeft(2, '0');
  return '${prefix}_${n.year}${pad2(n.month)}${pad2(n.day)}${pad2(n.hour)}${pad2(n.minute)}${pad2(n.second)}';
}
