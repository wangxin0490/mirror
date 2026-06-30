import 'dart:async';

import 'package:flutter/foundation.dart';

import 'voice_recorder_service.dart';
import 'voice_record_shared.dart';
import 'voice_session_mixin.dart';

/// 纯录音：pause/resume、计时、波形，无实时 ASR。
class BaseVoiceSessionController extends ChangeNotifier with VoiceSessionMixin {
  BaseVoiceSessionController({
    String? title,
    this.maxDuration,
    String titlePrefix = '录音纪要',
    this.forAsr = false,
    this.fileExt = 'wav',
    this.virtualPause = false,
    this.recordWav = false,
  }) : title = title ?? defaultVoiceTitle(titlePrefix);

  final VoiceRecorderService _recorder = VoiceRecorderService();
  final Duration? maxDuration;
  final bool forAsr;
  final String fileExt;

  /// 原生端用线性 WAV 录制（被中断也能 salvage，避免 m4a 空壳）。
  final bool recordWav;

  /// 为 true 时暂停/继续只影响 UI 计时，底层录音不中断（避免 Android pause/resume 空壳）。
  final bool virtualPause;

  VoiceRecordPhase phase = VoiceRecordPhase.idle;
  Duration elapsed = Duration.zero;
  double amplitude = 0;
  final List<VoiceSegmentMarker> segments = [];
  String title;
  bool limitReached = false;

  /// 最近一次 [finish] 失败原因（供 UI 展示）。
  String? lastFinishError;

  /// finish 失败后录音器已停止，需放弃后重录。
  bool finishBroken = false;

  Timer? _tickTimer;
  Timer? _probeTimer;
  bool _captureProbed = false;
  final Stopwatch _stopwatch = Stopwatch();

  @override
  String get liveTranscript => '';
  bool get asrSegmentBusy => false;

  bool get canFinish => !finishBroken && elapsed >= const Duration(seconds: 1);

  bool get hasSession =>
      !finishBroken &&
      (phase == VoiceRecordPhase.recording ||
          phase == VoiceRecordPhase.paused ||
          elapsed >= const Duration(seconds: 1));

  @override
  void markTitleEdited() {}

  Future<void> start() async {
    if (finishBroken || limitReached) return;
    if (phase == VoiceRecordPhase.idle) {
      await _recorder.start(forAsr: forAsr, wav: recordWav);
      segments.add(VoiceSegmentMarker(index: 1, startedAt: Duration.zero));
      _stopwatch
        ..reset()
        ..start();
      phase = VoiceRecordPhase.recording;
      _startTicking();
      _scheduleCaptureProbe();
      notifyListeners();
      return;
    }
    if (phase == VoiceRecordPhase.paused) {
      if (!virtualPause) {
        await _recorder.resume();
      }
      segments.add(VoiceSegmentMarker(index: segments.length + 1, startedAt: elapsed));
      _stopwatch.start();
      phase = VoiceRecordPhase.recording;
      notifyListeners();
    }
  }

  Future<void> pause() async {
    if (phase != VoiceRecordPhase.recording) return;
    if (!virtualPause) {
      await _recorder.pause();
    }
    _stopwatch.stop();
    elapsed = _stopwatch.elapsed;
    _closeActiveSegment(elapsed);
    phase = VoiceRecordPhase.paused;
    amplitude = 0;
    notifyListeners();
  }

  /// 按格式估算每秒最小字节数（用于拦截空壳文件）。
  static int minBytesPerSecond(String ext) {
    switch (ext.toLowerCase()) {
      case 'wav':
        return 16000; // 16kHz mono 16-bit ≈ 32KB/s，取一半容差
      case 'webm':
      case 'm4a':
      default:
        return 1024; // AAC 语音可低至 ~32kbps，避免误杀真机短录音
    }
  }

  Future<RecordedVoice?> finish() async {
    lastFinishError = null;
    if (!canFinish) return null;
    amplitude = 0;
    _stopTicking();
    _probeTimer?.cancel();
    _captureProbed = true;

    if (_stopwatch.isRunning) {
      _stopwatch.stop();
      elapsed = _stopwatch.elapsed;
    }
    _closeActiveSegment(elapsed);

    final hasNativeSession = await _recorder.hasActiveSession();
    final salvagePath = _recorder.recordingPath;
    if (!hasNativeSession &&
        (salvagePath == null || salvagePath.isEmpty) &&
        !virtualPause) {
      lastFinishError = '录音会话已中断，请放弃后重新录制';
      await _markFinishBroken();
      notifyListeners();
      return null;
    }

    final durationSec = _durationSecForValidation(elapsed);
    final recordedExt = _recorder.currentExt;
    final recorded = await _recorder.stop(
      expectedDurationSec: durationSec,
      virtualPause: virtualPause,
    );
    if (recorded == null || recorded.bytes.isEmpty) {
      lastFinishError = '录音文件读取失败或为空，请放弃后重新录制';
      await _markFinishBroken();
      notifyListeners();
      return null;
    }
    final minBytes = durationSec * minBytesPerSecond(recordedExt);
    if (durationSec >= 1 && recorded.bytes.length < minBytes) {
      lastFinishError =
          '录音文件偏小（${recorded.bytes.length} 字节 / ${durationSec}s），请放弃后重新录制';
      if (kDebugMode) {
        debugPrint(
          '[VoiceSession] recording too small: elapsed=${durationSec}s '
          'bytes=${recorded.bytes.length} minExpected=$minBytes',
        );
      }
      await _markFinishBroken();
      notifyListeners();
      return null;
    }
    finishBroken = false;
    phase = VoiceRecordPhase.idle;
    notifyListeners();
    return RecordedVoice(
      bytes: recorded.bytes,
      filename: voiceTitleToFilename(title, ext: recordedExt),
      duration: elapsed,
    );
  }

  Future<void> _markFinishBroken() async {
    finishBroken = true;
    phase = VoiceRecordPhase.paused;
    amplitude = 0;
    await _recorder.cancel();
  }

  /// 录音开始后探测底层采集是否真的在写入数据。部分机型原生 WAV/PCM
  /// 采集会静默失败（文件停在几 KB），此时自动丢弃并改用 AAC 重录。
  void _scheduleCaptureProbe() {
    if (kIsWeb) return;
    _captureProbed = false;
    _probeTimer?.cancel();
    _probeTimer = Timer(
      const Duration(milliseconds: 1500),
      () => unawaited(_runCaptureProbe()),
    );
  }

  Future<void> _runCaptureProbe() async {
    if (_captureProbed || finishBroken || kIsWeb) return;
    if (phase == VoiceRecordPhase.idle) return;
    if (!await _recorder.hasActiveSession()) return;

    final ext = _recorder.currentExt;
    final perSec = minBytesPerSecond(ext);
    final len1 = await _recorder.currentByteLength();
    // 间隔 ~1.2s 再采样，按是否增长判断（避免预分配/单次落盘误判）。
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (_captureProbed || finishBroken || phase == VoiceRecordPhase.idle) return;
    if (!await _recorder.hasActiveSession()) return;
    final len2 = await _recorder.currentByteLength();

    // 1.2s 内至少应写入 ~1s 的数据；否则视为底层静默失败。
    if (len2 - len1 >= perSec) {
      _captureProbed = true;
      return;
    }

    final restarted = await _recorder.restartWithAacFallback();
    if (!restarted) {
      // 无法回退（AAC 也失败 / ASR / Web）：交由 finish 校验兜底。
      _captureProbed = true;
      if (kDebugMode) {
        debugPrint('[VoiceSession] capture silent and no fallback available');
      }
      return;
    }
    _restartTimingAfterFallback();
    _scheduleCaptureProbe();
  }

  /// 回退到 AAC 重录后，重置计时与分段，从头开始。
  void _restartTimingAfterFallback() {
    segments
      ..clear()
      ..add(VoiceSegmentMarker(index: 1, startedAt: Duration.zero));
    _stopwatch.reset();
    elapsed = Duration.zero;
    amplitude = 0;
    limitReached = false;
    if (phase == VoiceRecordPhase.recording) {
      _stopwatch.start();
    } else if (phase == VoiceRecordPhase.paused) {
      segments.last
        ..duration = Duration.zero
        ..active = false;
    }
    notifyListeners();
  }

  Future<void> discard() async {
    _stopTicking();
    _probeTimer?.cancel();
    _captureProbed = true;
    _stopwatch.stop();
    await _recorder.cancel();
    phase = VoiceRecordPhase.idle;
    elapsed = Duration.zero;
    amplitude = 0;
    segments.clear();
    limitReached = false;
    finishBroken = false;
    lastFinishError = null;
    notifyListeners();
  }

  void _closeActiveSegment(Duration at) {
    if (segments.isEmpty) return;
    final last = segments.last;
    if (!last.active) return;
    last.duration = at - last.startedAt;
    last.active = false;
  }

  void _startTicking() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(milliseconds: 80), (_) => _onTick());
  }

  void _stopTicking() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  Future<void> _onTick() async {
    if (phase != VoiceRecordPhase.recording) return;
    elapsed = _stopwatch.elapsed;
    if (maxDuration != null && elapsed >= maxDuration!) {
      if (!limitReached) {
        limitReached = true;
        await pause();
      }
      return;
    }
    try {
      final amp = await _recorder.getAmplitude();
      amplitude = _normalizeAmplitude(amp.current);
    } catch (_) {
      amplitude = 0;
    }
    notifyListeners();
  }

  static int _durationSecForValidation(Duration elapsed) {
    final ms = elapsed.inMilliseconds;
    if (ms <= 0) return 0;
    return (ms / 1000).ceil().clamp(1, 24 * 60 * 60);
  }

  static double _normalizeAmplitude(double dbfs) {
    const floor = -60.0;
    if (dbfs <= floor) return 0;
    return ((dbfs - floor) / -floor).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _stopTicking();
    _probeTimer?.cancel();
    unawaited(_recorder.cancel());
    _recorder.dispose();
    super.dispose();
  }
}
