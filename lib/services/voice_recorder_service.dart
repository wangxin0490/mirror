import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../utils/audio_shell_util.dart';
import '../utils/wav_asr_util.dart';

/// 按住说话结束后的录音数据，用于 [KbStore.uploadDocument] 入库。
class RecordedVoice {
  const RecordedVoice({
    required this.bytes,
    required this.filename,
    this.duration = Duration.zero,
  });

  /// 录音原始字节（m4a / wav 等）。
  final List<int> bytes;
  /// 建议上传用的文件名（含扩展名）。
  final String filename;
  final Duration duration;
}

/// 请求麦克风权限（首次会弹出系统对话框）。
Future<bool> ensureMicrophonePermission() async {
  final svc = VoiceRecorderService();
  try {
    return await svc.ensurePermission();
  } finally {
    svc.dispose();
  }
}

/// 跨平台录音服务，支持暂停/继续写入同一文件。
class VoiceRecorderService {
  VoiceRecorderService() : _rec = AudioRecorder();

  final AudioRecorder _rec;
  String? _path;
  String? _filename;
  DateTime? _startedAt;

  /// 当前实际录制格式扩展名（wav / m4a / webm）。回退后会变化。
  String _ext = 'wav';
  bool _startForAsr = false;
  bool _startWav = false;
  bool _fallbackUsed = false;

  /// 当前实际录制使用的扩展名（供时长/体积校验与文件名使用）。
  String get currentExt => _ext;

  /// 检查/请求麦克风权限。
  Future<bool> ensurePermission() => _rec.hasPermission();

  /// 是否正在录音（含暂停中的会话）。
  Future<bool> isRecording() => _rec.isRecording();

  /// 是否处于暂停状态。
  Future<bool> isPaused() => _rec.isPaused();

  /// 当前音量（dBFS），用于波形展示。
  Future<Amplitude> getAmplitude() => _rec.getAmplitude();

  /// 当前录音文件路径（录音中可读增量字节）。
  String? get recordingPath => _path;

  /// 开始录音。
  ///
  /// - [forAsr]：滚动 ASR 专用，16kHz mono WAV。
  /// - [wav]：原生端用线性 WAV 录制（会议模式）。WAV 边录边写 PCM，
  ///   即使进程被系统杀死也能从磁盘 salvage，避免 m4a 仅在 stop 时回填
  ///   moov 索引、被中断即成空壳的问题。
  Future<void> start({bool forAsr = false, bool wav = false}) async {
    if (await _rec.isRecording()) return;
    if (!await ensurePermission()) {
      throw StateError('需要麦克风权限');
    }
    _startForAsr = forAsr;
    _startWav = wav;
    _fallbackUsed = false;
    await _begin(useAac: false);
  }

  /// 部分机型的原生 WAV/PCM 采集会静默失败（产出几 KB 空壳）。
  /// 检测到后调用本方法丢弃当前文件并改用 AAC(m4a) 重新开始。
  /// ASR(16k PCM)、Web 或已回退过则不再回退，返回 false。
  Future<bool> restartWithAacFallback() async {
    if (_startForAsr || kIsWeb || _fallbackUsed) return false;
    _fallbackUsed = true;
    try {
      await _rec.cancel();
    } catch (_) {}
    _clearSessionState();
    await _begin(useAac: true);
    if (kDebugMode) {
      debugPrint('[VoiceRecorder] WAV capture failed, restarted with AAC fallback');
    }
    return true;
  }

  Future<void> _begin({required bool useAac}) async {
    final useWav = !useAac && (_startForAsr || (_startWav && !kIsWeb));
    final ext = kIsWeb ? 'webm' : (useWav ? 'wav' : 'm4a');
    _ext = ext;
    final name = 'mirror_voice_${DateTime.now().millisecondsSinceEpoch}.$ext';
    _filename = name;
    if (kIsWeb) {
      _path = name;
    } else {
      final dir = await getTemporaryDirectory();
      _path = '${dir.path}/$name';
    }
    await _rec.start(
      useWav
          ? const RecordConfig(
              encoder: AudioEncoder.wav,
              sampleRate: WavAsrUtil.defaultSampleRate,
              numChannels: 1,
            )
          : RecordConfig(
              encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc,
              sampleRate: 44100,
              numChannels: 1,
              bitRate: 64000,
            ),
      path: _path!,
    );
    _startedAt = DateTime.now();
  }

  /// 暂停录音，继续写入同一文件。
  Future<void> pause() async {
    if (await _rec.isRecording() && !await _rec.isPaused()) {
      await _rec.pause();
    }
  }

  /// 从暂停处继续录音。
  Future<void> resume() async {
    if (await _rec.isPaused()) {
      await _rec.resume();
    }
  }

  /// 当前录音文件已写入的字节数（用于检测底层采集是否在增长）。
  Future<int> currentByteLength() async {
    final path = _path;
    if (path == null || path.isEmpty || kIsWeb) return 0;
    try {
      final file = File(path);
      if (!await file.exists()) return 0;
      return await file.length();
    } catch (_) {
      return 0;
    }
  }

  /// 读取当前录音文件字节（滚动分段 ASR 用）。
  Future<List<int>> readCurrentBytes() async {
    final path = _path;
    if (path == null || path.isEmpty) return const [];
    if (kIsWeb) return const [];
    try {
      return await XFile(path).readAsBytes();
    } catch (_) {
      return const [];
    }
  }

  /// 底层录音是否仍在进行（含原生 pause 态）。
  Future<bool> hasActiveSession() async {
    return (await _rec.isRecording()) || (await _rec.isPaused());
  }

  /// stop 前准备：虚拟暂停时等待编码落盘；否则先从原生 pause resume。
  Future<void> prepareForStop({
    bool virtualPause = false,
    int? expectedDurationSec,
  }) async {
    if (virtualPause) {
      // 会议模式底层持续录音，stop 前给 AAC 编码器留足 flush 时间（真机常 >250ms）。
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (expectedDurationSec != null &&
          expectedDurationSec >= 1 &&
          !kIsWeb &&
          _path != null) {
        final minBytes = minM4aBytesForDuration(expectedDurationSec);
        for (var i = 0; i < 8; i++) {
          final partial = await readCurrentBytes();
          if (partial.length >= minBytes ~/ 4) break;
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }
      }
      return;
    }
    if (await _rec.isPaused()) {
      await _rec.resume();
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }
  }

  /// 停止录音并返回音频字节；未在录或为空则返回 null。
  Future<RecordedVoice?> stop({
    int? expectedDurationSec,
    bool virtualPause = false,
  }) async {
    await prepareForStop(
      virtualPause: virtualPause,
      expectedDurationSec: expectedDurationSec,
    );

    final recording = await _rec.isRecording();
    final paused = await _rec.isPaused();
    final savedPath = _path;
    final started = _startedAt;
    final savedName = _filename;

    String? usePath;
    if (recording || paused) {
      final path = await _rec.stop();
      usePath = path ?? savedPath;
    } else if (savedPath != null && savedPath.isNotEmpty && !kIsWeb) {
      // 原生层会话已丢但 UI 计时仍在：尝试从磁盘 salvage 已写入片段。
      if (kDebugMode) {
        debugPrint('[VoiceRecorder] stop: native session gone, salvage path=$savedPath');
      }
      usePath = savedPath;
      try {
        await _rec.cancel();
      } catch (_) {}
    } else {
      _clearSessionState();
      return null;
    }

    _path = null;
    _filename = null;
    _startedAt = null;
    if (usePath == null || usePath.isEmpty) return null;

    final durationSec = expectedDurationSec ??
        (started != null
            ? (DateTime.now().difference(started).inMilliseconds / 1000).ceil()
            : 0);
    final bytes = await _readStoppedFileBytes(
      usePath,
      durationSec: durationSec > 0 ? durationSec : null,
    );
    if (bytes.isEmpty) return null;

    if (kDebugMode) {
      debugPrint(
        '[VoiceRecorder] stop path=$usePath bytes=${bytes.length} '
        'durationSec=$durationSec',
      );
    }

    final name = savedName ?? voiceRecorderFilenameFromPath(usePath);
    final duration = started != null ? DateTime.now().difference(started) : Duration.zero;
    return RecordedVoice(bytes: bytes, filename: name, duration: duration);
  }

  void _clearSessionState() {
    _path = null;
    _filename = null;
    _startedAt = null;
  }

  /// stop 后 AAC/M4A 编码器可能异步落盘，重试读取避免只拿到 ftyp 空壳。
  Future<List<int>> _readStoppedFileBytes(String path, {int? durationSec}) async {
    const delaysMs = [
      100, 150, 250, 400, 600, 800, 1000, 1500, 2000, 2500, 3000,
    ];
    var lastLen = -1;
    var stableCount = 0;
    List<int> best = const [];
    final minAccept = durationSec != null && durationSec > 0
        ? minM4aBytesForDuration(durationSec)
        : 8192;

    for (var i = 0; i < delaysMs.length; i++) {
      await Future<void>.delayed(Duration(milliseconds: delaysMs[i]));
      try {
        if (!kIsWeb) {
          final file = File(path);
          if (!await file.exists()) continue;
        }
        List<int> bytes = await XFile(path).readAsBytes();
        if (bytes.isEmpty) continue;
        // 被中断的 WAV 头长度未回填：按实际长度修复后再校验，避免误判为空。
        final repaired = WavAsrUtil.repair(bytes);
        if (repaired != null) bytes = repaired;
        if (bytes.length == lastLen) {
          stableCount++;
        } else {
          stableCount = 0;
          lastLen = bytes.length;
        }
        best = bytes;
        final looksValid = !looksLikeEmptyAudioShell(bytes, durationSec: durationSec);
        if (looksValid &&
            bytes.length >= minAccept &&
            (stableCount >= 1 || bytes.length > 16384)) {
          break;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[VoiceRecorder] read retry failed: $e');
      }
    }
    if (looksLikeEmptyAudioShell(best, durationSec: durationSec)) {
      if (kDebugMode) {
        debugPrint('[VoiceRecorder] empty audio shell after stop, bytes=${best.length}');
      }
      return const [];
    }
    return best;
  }

  /// 取消录音，丢弃当前缓冲。
  Future<void> cancel() async {
    if (await _rec.isRecording() || await _rec.isPaused()) {
      await _rec.cancel();
    }
    _clearSessionState();
  }

  /// 释放底层 [AudioRecorder]。
  void dispose() {
    _rec.dispose();
  }
}

/// Web 上 [stop] 返回 blob URL，不能从路径解析扩展名（会丢失 .wav）。
String voiceRecorderFilenameFromPath(String path) {
  final base = path.split('/').last.split(r'\').last;
  if (base.contains('.')) return base;
  return 'voice.wav';
}
