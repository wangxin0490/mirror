import 'package:flutter/material.dart';

import '../theme/mirror_colors.dart';
import 'platform_shell.dart';
import 'phone_frame.dart';

/// 应用内容区：Web 为手机原型框；真机为全宽全高（无黑边缩放）。
class AppFrame extends StatelessWidget {
  const AppFrame({
    super.key,
    required this.child,
    this.time = '9:42',
    this.statusBarLight = false,
  });

  final Widget child;
  final String time;
  final bool statusBarLight;

  @override
  Widget build(BuildContext context) {
    if (useNativeLayout) {
      return ColoredBox(
        color: MirrorColors.bgApp,
        child: child,
      );
    }
    return PhoneFrame(
      time: time,
      statusBarLight: statusBarLight,
      child: child,
    );
  }
}

/// 原型顶栏时间（仅 Web 手机框内展示；真机用系统状态栏）。
class AppStatusBar extends StatelessWidget {
  const AppStatusBar({super.key, required this.time, this.light = false});

  final String time;
  final bool light;

  @override
  Widget build(BuildContext context) {
    if (useNativeLayout) return const SizedBox.shrink();
    return PhoneStatusBar(time: time, light: light);
  }
}
