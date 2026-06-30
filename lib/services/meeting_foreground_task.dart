import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Android / iOS 前台服务：仅保活 + 通知，录音仍在主 Isolate。
@pragma('vm:entry-point')
void meetingForegroundTaskStart() {
  FlutterForegroundTask.setTaskHandler(MeetingForegroundTaskHandler());
}

class MeetingForegroundTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {}
}

class MeetingForegroundTask {
  MeetingForegroundTask._();

  static const _serviceId = 512;
  static const _channelId = 'meeting_recording';
  static var _initialized = false;

  static void ensureInitialized() {
    if (kIsWeb || _initialized) return;
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _channelId,
        channelName: '会议助手',
        channelDescription: '后台录制或上传会议音频',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
    _initialized = true;
  }

  static Future<void> start({required String title, required String text}) async {
    if (kIsWeb) return;
    ensureInitialized();
    final perm = await FlutterForegroundTask.checkNotificationPermission();
    if (perm != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    if (await FlutterForegroundTask.isRunningService) {
      await update(title: title, text: text);
      return;
    }
    final result = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      notificationTitle: title,
      notificationText: text,
      callback: meetingForegroundTaskStart,
    );
    if (result is ServiceRequestFailure) {
      throw Exception(result.error);
    }
  }

  static Future<void> update({required String title, required String text}) async {
    if (kIsWeb || !await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }

  static Future<void> stop() async {
    if (kIsWeb || !await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.stopService();
  }
}
