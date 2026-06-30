import 'package:flutter/foundation.dart';

import 'meeting_foreground_task.dart';

/// 系统级后台上传：前台服务通知 + 进度更新（与录音共用 [MeetingForegroundTask]）。
class MeetingBackgroundUpload {
  MeetingBackgroundUpload._();

  static var _active = false;

  static bool get isActive => _active;

  static Future<void> activate({
    String title = '正在上传会议录音',
    String text = '点击返回 Mirror 查看进度',
  }) async {
    if (kIsWeb) return;
    if (_active) {
      await MeetingForegroundTask.update(title: title, text: text);
      return;
    }
    try {
      await MeetingForegroundTask.start(title: title, text: text);
      _active = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[MeetingBackgroundUpload] foreground task: $e');
    }
  }

  static Future<void> updateNotification({required String title, required String text}) async {
    if (!_active || kIsWeb) return;
    try {
      await MeetingForegroundTask.update(title: title, text: text);
    } catch (e) {
      if (kDebugMode) debugPrint('[MeetingBackgroundUpload] update: $e');
    }
  }

  static Future<void> deactivate() async {
    if (!_active || kIsWeb) return;
    _active = false;
    try {
      await MeetingForegroundTask.stop();
    } catch (e) {
      if (kDebugMode) debugPrint('[MeetingBackgroundUpload] stop: $e');
    }
  }
}
