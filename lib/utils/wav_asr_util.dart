import 'dart:typed_data';

/// WAV 解析与 ASR 分段切片（16kHz mono PCM16）。
class WavAsrUtil {
  WavAsrUtil._();

  static const int defaultSampleRate = 16000;
  static const int bytesPerSample = 2;

  static int pcmBytesForDuration(int seconds, {int sampleRate = defaultSampleRate}) {
    return seconds * sampleRate * bytesPerSample;
  }

  /// 从完整 WAV 提取第 [index] 段（每段 [intervalSeconds] 秒）。
  /// 仅当该段 PCM 数据已满 [intervalSeconds] 时返回；否则 null。
  static List<int>? sliceSegmentWav(
    List<int> fullWav,
    int index,
    int intervalSeconds, {
    int sampleRate = defaultSampleRate,
  }) {
    final pcm = extractPcm(fullWav);
    if (pcm == null) return null;
    final segBytes = pcmBytesForDuration(intervalSeconds, sampleRate: sampleRate);
    final start = index * segBytes;
    if (start >= pcm.length) return null;
    final end = start + segBytes;
    if (end > pcm.length) return null;
    return buildWav(Uint8List.fromList(pcm.sublist(start, end)), sampleRate: sampleRate);
  }

  /// 提取尾部不足一整段或 finish 时的剩余 PCM。
  static List<int>? sliceTailWav(
    List<int> fullWav,
    int fromIndex,
    int intervalSeconds, {
    int sampleRate = defaultSampleRate,
  }) {
    final pcm = extractPcm(fullWav);
    if (pcm == null) return null;
    final segBytes = pcmBytesForDuration(intervalSeconds, sampleRate: sampleRate);
    final start = fromIndex * segBytes;
    if (start >= pcm.length) return null;
    final tail = pcm.sublist(start);
    if (tail.length < sampleRate * bytesPerSample ~/ 2) return null;
    return buildWav(Uint8List.fromList(tail), sampleRate: sampleRate);
  }

  /// 修复被中断录音常见的 WAV 头长度错误（RIFF/data size 为占位 0 或越界）。
  ///
  /// 录音进程被系统杀死时，PCM 已写入磁盘但 `data` 块的长度字段没回填，
  /// 导致 [extractPcm] 读不到音频。此方法按文件实际长度回填 RIFF/data 长度。
  /// 已正确的 WAV 原样返回；非 WAV 或无 data 块返回 null。
  static List<int>? repair(List<int> data) {
    if (data.length < 44) return null;
    if (String.fromCharCodes(data.sublist(0, 4)) != 'RIFF') return null;
    if (String.fromCharCodes(data.sublist(8, 12)) != 'WAVE') return null;

    var pos = 12;
    int? dataBodyStart;
    while (pos + 8 <= data.length) {
      final id = String.fromCharCodes(data.sublist(pos, pos + 4));
      final size = _le32(data, pos + 4);
      final body = pos + 8;
      if (id == 'data') {
        // 长度合法且未越界：文件完好，无需修复。
        if (size > 0 && body + size <= data.length) return data;
        dataBodyStart = body;
        break;
      }
      // 中间块长度异常，无法安全前进。
      if (size <= 0 || body + size > data.length) break;
      pos = body + size;
    }
    if (dataBodyStart == null || dataBodyStart >= data.length) return null;

    final actualDataSize = data.length - dataBodyStart;
    final out = List<int>.from(data);
    final riffSize = data.length - 8;
    out.setRange(4, 8, _u32le(riffSize));
    final dataSizeOff = dataBodyStart - 4;
    out.setRange(dataSizeOff, dataSizeOff + 4, _u32le(actualDataSize));
    return out;
  }

  static List<int>? extractPcm(List<int> data) {
    if (data.length < 44) return null;
    if (String.fromCharCodes(data.sublist(0, 4)) != 'RIFF') return null;
    if (String.fromCharCodes(data.sublist(8, 12)) != 'WAVE') return null;
    var pos = 12;
    while (pos + 8 <= data.length) {
      final id = String.fromCharCodes(data.sublist(pos, pos + 4));
      final size = _le32(data, pos + 4);
      pos += 8;
      if (pos + size > data.length) break;
      if (id == 'data') {
        return data.sublist(pos, pos + size);
      }
      pos += size;
    }
    return null;
  }

  static List<int> buildWav(Uint8List pcm, {int sampleRate = defaultSampleRate, int channels = 1}) {
    final byteRate = sampleRate * channels * bytesPerSample;
    final blockAlign = channels * bytesPerSample;
    final dataSize = pcm.length;
    final chunkSize = 36 + dataSize;
    final out = BytesBuilder(copy: false);
    out.add('RIFF'.codeUnits);
    out.add(_u32le(chunkSize));
    out.add('WAVE'.codeUnits);
    out.add('fmt '.codeUnits);
    out.add(_u32le(16));
    out.add(_u16le(1));
    out.add(_u16le(channels));
    out.add(_u32le(sampleRate));
    out.add(_u32le(byteRate));
    out.add(_u16le(blockAlign));
    out.add(_u16le(16));
    out.add('data'.codeUnits);
    out.add(_u32le(dataSize));
    out.add(pcm);
    return out.toBytes();
  }

  static int _le32(List<int> b, int off) =>
      b[off] | (b[off + 1] << 8) | (b[off + 2] << 16) | (b[off + 3] << 24);

  static List<int> _u32le(int v) => [v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff];

  static List<int> _u16le(int v) => [v & 0xff, (v >> 8) & 0xff];
}
