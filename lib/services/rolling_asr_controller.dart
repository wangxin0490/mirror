import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utils/wav_asr_util.dart';
import 'asr_client.dart';
import 'voice_recorder_service.dart';

/// 滚动分段 ASR：定时切片上传，累积实时字幕。
class RollingAsrController extends ChangeNotifier {
  RollingAsrController({
    required this.recorder,
    this.intervalSeconds = 3,
  });

  final VoiceRecorderService recorder;
  final int intervalSeconds;

  String transcript = '';
  var segmentBusy = false;
  String? _sessionId;
  var _nextIndex = 0;
  Timer? _timer;
  var _paused = false;
  var _running = false;

  Future<void> startSession() async {
    if (kIsWeb) return;
    transcript = '';
    _nextIndex = 0;
    _paused = false;
    _sessionId = await AsrClient.createSession();
    if (_sessionId == null) return;
    _running = true;
    _startTimer();
    notifyListeners();
  }

  void pause() {
    _paused = true;
    _timer?.cancel();
    _timer = null;
  }

  void resume() {
    if (!_running || _sessionId == null) return;
    _paused = false;
    _startTimer();
  }

  Future<void> finish() async {
    _timer?.cancel();
    _timer = null;
    if (_sessionId != null) {
      await _uploadTail(flush: true);
      await AsrClient.deleteSession(_sessionId!);
    }
    _running = false;
    _sessionId = null;
    notifyListeners();
  }

  Future<void> discard() async {
    _timer?.cancel();
    _timer = null;
    final id = _sessionId;
    _sessionId = null;
    _running = false;
    transcript = '';
    _nextIndex = 0;
    if (id != null) await AsrClient.deleteSession(id);
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: intervalSeconds), (_) {
      unawaited(_uploadNextSegment());
    });
  }

  Future<void> _uploadNextSegment() async {
    if (_paused || _sessionId == null || segmentBusy) return;
    final bytes = await recorder.readCurrentBytes();
    if (bytes.isEmpty) return;
    final segment = WavAsrUtil.sliceSegmentWav(bytes, _nextIndex, intervalSeconds);
    if (segment == null) return;
    await _sendSegment(segment);
  }

  Future<void> _uploadTail({required bool flush}) async {
    if (_sessionId == null || segmentBusy) return;
    final bytes = await recorder.readCurrentBytes();
    if (bytes.isEmpty) return;
    final tail = WavAsrUtil.sliceTailWav(bytes, _nextIndex, intervalSeconds);
    if (tail == null) return;
    await _sendSegment(tail);
  }

  Future<void> _sendSegment(List<int> wav) async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    segmentBusy = true;
    notifyListeners();
    try {
      final index = _nextIndex;
      await AsrClient.uploadSegmentStream(
        sessionId: sessionId,
        index: index,
        wavBytes: wav,
        onDelta: (d) {
          transcript += d;
          notifyListeners();
        },
      );
      _nextIndex++;
    } finally {
      segmentBusy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(discard());
    super.dispose();
  }
}
