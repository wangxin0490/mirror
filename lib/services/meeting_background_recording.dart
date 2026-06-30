import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'meeting_foreground_task.dart';

/// 系统级后台录音：前台服务通知 + 音频会话 + 唤醒锁。
class MeetingBackgroundRecording {
  MeetingBackgroundRecording._();

  static var _active = false;

  static bool get isActive => _active;

  /// 在 [AudioRecorder.start] 之前调用，避免未配置会话时写出空壳 m4a。
  static Future<void> prepareForRecording() async {
    await _configureAudioSession();
    await WakelockPlus.enable();
  }

  static Future<void> activate({String title = '正在录制会议', String text = '点击返回 Mirror 继续'}) async {
    if (_active) {
      await MeetingForegroundTask.update(title: title, text: text);
      return;
    }
    await prepareForRecording();
    if (!kIsWeb) {
      try {
        await MeetingForegroundTask.start(title: title, text: text);
      } catch (e) {
        if (kDebugMode) debugPrint('[MeetingBackground] foreground task: $e');
      }
    }
    _active = true;
  }

  static Future<void> updateNotification({required String title, required String text}) async {
    if (!_active || kIsWeb) return;
    try {
      await MeetingForegroundTask.update(title: title, text: text);
    } catch (e) {
      if (kDebugMode) debugPrint('[MeetingBackground] update: $e');
    }
  }

  static Future<void> deactivate() async {
    if (!_active) return;
    _active = false;
    await WakelockPlus.disable();
    if (!kIsWeb) {
      try {
        await MeetingForegroundTask.stop();
      } catch (e) {
        if (kDebugMode) debugPrint('[MeetingBackground] stop: $e');
      }
    }
    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (_) {}
  }

  static Future<void> _configureAudioSession() async {
    if (kIsWeb) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.defaultToSpeaker |
                  AVAudioSessionCategoryOptions.allowBluetooth,
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false,
        ),
      );
      await session.setActive(true);
    } catch (e) {
      if (kDebugMode) debugPrint('[MeetingBackground] audio session: $e');
    }
  }
}
