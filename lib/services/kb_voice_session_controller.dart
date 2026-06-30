import 'dart:async';

import 'package:flutter/foundation.dart';

import 'rolling_asr_controller.dart';
import 'voice_recorder_service.dart';
import 'voice_record_shared.dart';
import 'voice_session_mixin.dart';

/// 知识库语音导入：单文件 pause/resume + 滚动 ASR 字幕（行为与旧版一致）。
class KbVoiceSessionController extends ChangeNotifier with VoiceSessionMixin {
  KbVoiceSessionController({
    String? title,
    this.maxDuration = const Duration(seconds: 1800),
    int segmentIntervalSeconds = 3,
  }) : title = title ?? defaultVoiceTitle('录音纪要') {
    _rollingAsr = RollingAsrController(
      recorder: _recorder,
      intervalSeconds: segmentIntervalSeconds,
    );
    _rollingAsr.addListener(_onRollingChanged);
  }

  final VoiceRecorderService _recorder = VoiceRecorderService();
  late final RollingAsrController _rollingAsr;
  final Duration maxDuration;

  VoiceRecordPhase phase = VoiceRecordPhase.idle;
  Duration elapsed = Duration.zero;
  double amplitude = 0;
  final List<VoiceSegmentMarker> segments = [];
  String title;
  String liveTranscript = '';
  var asrSegmentBusy = false;
  bool limitReached = false;
  String? lastFinishError;
  @override
  bool finishBroken = false;

  Timer? _tickTimer;
  final Stopwatch _stopwatch = Stopwatch();
  var _titleManuallyEdited = false;

  bool get canFinish => elapsed >= const Duration(seconds: 1);

  bool get hasSession =>
      phase == VoiceRecordPhase.recording ||
      phase == VoiceRecordPhase.paused ||
      elapsed >= const Duration(seconds: 1);

  void markTitleEdited() => _titleManuallyEdited = true;

  void _onRollingChanged() {
    liveTranscript = _rollingAsr.transcript;
    asrSegmentBusy = _rollingAsr.segmentBusy;
    notifyListeners();
  }

  Future<void> start() async {
    if (limitReached) return;
    if (phase == VoiceRecordPhase.idle) {
      await _recorder.start(forAsr: true);
      await _rollingAsr.startSession();
      segments.add(VoiceSegmentMarker(index: 1, startedAt: Duration.zero));
      _stopwatch
        ..reset()
        ..start();
      phase = VoiceRecordPhase.recording;
      _startTicking();
      notifyListeners();
      return;
    }
    if (phase == VoiceRecordPhase.paused) {
      await _recorder.resume();
      _rollingAsr.resume();
      segments.add(VoiceSegmentMarker(index: segments.length + 1, startedAt: elapsed));
      _stopwatch.start();
      phase = VoiceRecordPhase.recording;
      notifyListeners();
    }
  }

  Future<void> pause() async {
    if (phase != VoiceRecordPhase.recording) return;
    await _recorder.pause();
    _rollingAsr.pause();
    _stopwatch.stop();
    elapsed = _stopwatch.elapsed;
    _closeActiveSegment(elapsed);
    phase = VoiceRecordPhase.paused;
    amplitude = 0;
    notifyListeners();
  }

  Future<RecordedVoice?> finish() async {
    if (!canFinish) return null;
    amplitude = 0;
    _stopTicking();

    if (_stopwatch.isRunning) {
      _stopwatch.stop();
      elapsed = _stopwatch.elapsed;
    }
    _closeActiveSegment(elapsed);

    await _rollingAsr.finish();
    final durationSec = (elapsed.inMilliseconds / 1000).ceil().clamp(1, 24 * 60 * 60);
    final recorded = await _recorder.stop(expectedDurationSec: durationSec);
    if (recorded == null || recorded.bytes.isEmpty) {
      notifyListeners();
      return null;
    }
    phase = VoiceRecordPhase.idle;
    if (!_titleManuallyEdited && liveTranscript.trim().isNotEmpty) {
      final t = liveTranscript.trim();
      title = t.length > 32 ? t.substring(0, 32) : t;
    }
    notifyListeners();
    return RecordedVoice(
      bytes: recorded.bytes,
      filename: voiceTitleToFilename(title),
      duration: elapsed,
    );
  }

  Future<void> discard() async {
    _stopTicking();
    _stopwatch.stop();
    await _rollingAsr.discard();
    await _recorder.cancel();
    phase = VoiceRecordPhase.idle;
    elapsed = Duration.zero;
    amplitude = 0;
    liveTranscript = '';
    segments.clear();
    limitReached = false;
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
    if (elapsed >= maxDuration) {
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

  static double _normalizeAmplitude(double dbfs) {
    const floor = -60.0;
    if (dbfs <= floor) return 0;
    return ((dbfs - floor) / -floor).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _stopTicking();
    _rollingAsr.removeListener(_onRollingChanged);
    _rollingAsr.dispose();
    unawaited(_recorder.cancel());
    _recorder.dispose();
    super.dispose();
  }
}
