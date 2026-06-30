import 'dart:async';

import 'package:flutter/foundation.dart';

import 'asr_client.dart';
import 'voice_recorder_service.dart';

/// 按住说话：录音结束后单次转写。
class VoiceInputController extends ChangeNotifier {
  VoiceInputController({VoiceRecorderService? recorder})
      : _recorder = recorder ?? VoiceRecorderService();

  final VoiceRecorderService _recorder;
  var recording = false;
  var transcribing = false;
  double amplitude = 0;
  Duration elapsed = Duration.zero;
  Duration maxDuration = const Duration(seconds: 28);

  /// 达到 [maxDuration] 后自动结束录音并转写，回调携带转写结果。
  Future<void> Function(String? text)? onAutoEnd;

  Timer? _ampTimer;
  Timer? _durationTimer;
  DateTime? _recordingStartedAt;
  var _autoEnding = false;

  /// 检查/请求麦克风权限（首次使用语音时弹出系统授权框）。
  Future<bool> ensureMicPermission() => _recorder.ensurePermission();

  Future<void> holdStart() async {
    if (recording || transcribing || _autoEnding) return;
    await _recorder.start(forAsr: true);
    recording = true;
    amplitude = 0;
    elapsed = Duration.zero;
    _recordingStartedAt = DateTime.now();
    _startAmplitudePolling();
    _startDurationTimer();
    notifyListeners();
  }

  Future<String?> holdEnd({Duration minDuration = const Duration(seconds: 1)}) async {
    if (!recording) return null;
    return _finishRecording(minDuration: minDuration);
  }

  Future<void> holdCancel() async {
    _stopTimers();
    _autoEnding = false;
    recording = false;
    transcribing = false;
    amplitude = 0;
    elapsed = Duration.zero;
    _recordingStartedAt = null;
    await _recorder.cancel();
    notifyListeners();
  }

  Future<String?> _finishRecording({
    Duration minDuration = const Duration(seconds: 1),
    bool fromAutoLimit = false,
  }) async {
    _stopTimers();
    recording = false;
    amplitude = 0;
    _recordingStartedAt = null;
    notifyListeners();
    final recorded = await _recorder.stop();
    if (recorded == null || recorded.bytes.isEmpty) {
      _autoEnding = false;
      return null;
    }
    if (recorded.duration < minDuration) {
      _autoEnding = false;
      return null;
    }
    transcribing = true;
    notifyListeners();
    try {
      return await AsrClient.transcribe(recorded.bytes, filename: recorded.filename);
    } finally {
      transcribing = false;
      _autoEnding = false;
      if (!fromAutoLimit) notifyListeners();
    }
  }

  Future<void> _onDurationLimitReached() async {
    if (!recording || _autoEnding) return;
    _autoEnding = true;
    final text = await _finishRecording(fromAutoLimit: true);
    notifyListeners();
    final handler = onAutoEnd;
    if (handler != null) {
      await handler(text);
    }
  }

  void _startAmplitudePolling() {
    _ampTimer?.cancel();
    _ampTimer = Timer.periodic(const Duration(milliseconds: 80), (_) => unawaited(_pollAmplitude()));
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!recording || _recordingStartedAt == null) return;
      elapsed = DateTime.now().difference(_recordingStartedAt!);
      if (elapsed >= maxDuration) {
        unawaited(_onDurationLimitReached());
      } else {
        notifyListeners();
      }
    });
  }

  void _stopTimers() {
    _ampTimer?.cancel();
    _ampTimer = null;
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  Future<void> _pollAmplitude() async {
    if (!recording) return;
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
    _stopTimers();
    unawaited(_recorder.cancel());
    _recorder.dispose();
    super.dispose();
  }
}
