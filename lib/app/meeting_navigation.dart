import 'package:flutter/material.dart';

import '../screens/meeting/meeting_detail_screen.dart';
import 'mirror_app_keys.dart';

/// 全局打开会议详情（通知点击 / Store 回调兜底）。
void openMeetingDetailScreen(int sessionId) {
  final nav = mirrorRootNavigatorKey.currentState;
  if (nav == null) return;
  nav.push<void>(
    MaterialPageRoute<void>(
      builder: (_) => MeetingDetailScreen(
        sessionId: sessionId,
        onBack: () => nav.pop(),
      ),
    ),
  );
}
