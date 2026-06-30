import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../app/meeting_navigation.dart';

/// 会议纪要完成本地通知（后台 / 前台服务存活期间）。
class MeetingNotificationService {
  MeetingNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static const _channelId = 'meeting_minutes_done';
  static const _channelName = '会议纪要';
  static var _initialized = false;

  static Future<void> init() async {
    if (_initialized || kIsWeb) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onTap,
      onDidReceiveBackgroundNotificationResponse: _onTapBackground,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: '会议录音处理完成提醒',
            importance: Importance.high,
          ),
        );

    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  static Future<void> showDone({required int sessionId, required String title}) async {
    if (kIsWeb || !_initialized) return;
    final safeTitle = title.trim().isEmpty ? '会议 #$sessionId' : title.trim();
    await _plugin.show(
      sessionId,
      '会议纪要已生成',
      '《$safeTitle》纪要已生成，点击查看',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: '会议录音处理完成提醒',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: '$sessionId',
    );
  }

  static void _onTap(NotificationResponse response) {
    _openDetailFromPayload(response.payload);
  }

  @pragma('vm:entry-point')
  static void _onTapBackground(NotificationResponse response) {
    _openDetailFromPayload(response.payload);
  }

  static void _openDetailFromPayload(String? payload) {
    final id = int.tryParse(payload ?? '');
    if (id == null || id <= 0) return;
    openMeetingDetailScreen(id);
  }
}
