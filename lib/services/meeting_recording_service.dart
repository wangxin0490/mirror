import 'dart:async';

import 'package:flutter/foundation.dart';

import 'meeting_background_recording.dart';
import 'meeting_voice_session_controller.dart';
import 'voice_record_shared.dart';
import '../screens/voice_record_screen.dart' show VoiceUploadFn;

/// 会议录音全局单例：App 内导航不销毁会话，配合系统前台服务保活。
class MeetingRecordingService extends ChangeNotifier {
  MeetingRecordingService._();

  static final MeetingRecordingService instance = MeetingRecordingService._();

  MeetingVoiceSessionController? _controller;
  VoiceUploadFn? _uploadFn;
  var _screenAttached = false;

  bool get hasController => _controller != null;

  bool get isActive {
    final c = _controller;
    if (c == null) return false;
    return c.phase != VoiceRecordPhase.idle || c.hasSession;
  }

  bool get showOverlay => isActive && !_screenAttached;

  MeetingVoiceSessionController? get controller => _controller;

  VoiceUploadFn? get uploadFn => _uploadFn;

  void ensureSession({String? title}) {
    if (_controller != null) return;
    _controller = MeetingVoiceSessionController(title: title);
    _controller!.addListener(_onControllerChanged);
    notifyListeners();
  }

  void attachScreen(VoiceUploadFn onUpload) {
    _uploadFn = onUpload;
    _screenAttached = true;
    notifyListeners();
  }

  void detachScreen() {
    _screenAttached = false;
    notifyListeners();
  }

  Future<void> clearSession({bool discard = true}) async {
    final c = _controller;
    if (c == null) return;
    if (discard && c.hasSession) {
      await c.discard();
    }
    c.removeListener(_onControllerChanged);
    c.dispose();
    _controller = null;
    _uploadFn = null;
    _screenAttached = false;
    await MeetingBackgroundRecording.deactivate();
    notifyListeners();
  }

  void _onControllerChanged() {
    final c = _controller;
    if (c == null) return;

    if (c.phase == VoiceRecordPhase.recording) {
      final label = voiceDurationLabel(c.elapsed);
      unawaited(
        MeetingBackgroundRecording.activate(
          title: '正在录制会议 · $label',
          text: c.title,
        ),
      );
    } else if (c.phase == VoiceRecordPhase.paused) {
      unawaited(
        MeetingBackgroundRecording.updateNotification(
          title: '会议录音已暂停 · ${voiceDurationLabel(c.elapsed)}',
          text: c.title,
        ),
      );
    }

    notifyListeners();
  }
}
