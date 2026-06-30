import 'package:flutter/material.dart';
import 'package:network_ninja/network_ninja.dart';

import '../app/mirror_app_keys.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../utils/network_ninja_mount.dart';
import 'mirror_pressable.dart';

/// 应用内固定的抓包入口（不依赖第三方悬浮球是否挂载成功）。
class NetworkNinjaFab extends StatelessWidget {
  const NetworkNinjaFab({super.key});

  void _open(BuildContext context) {
    final root = mirrorRootNavigatorKey.currentContext ?? context;
    remountNetworkNinjaBubble(root);
    root.showNetworkLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 12,
      bottom: 92,
      child: MirrorPressable(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(22),
        child: Material(
          elevation: 4,
          shadowColor: Colors.black26,
          color: MirrorColors.text,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bug_report_outlined, size: 18, color: Colors.white),
                Text(
                  'API',
                  style: MirrorTheme.mono(
                    fontSize: 8,
                    color: Colors.white,
                    weight: FontWeight.w600,
                    letterSpacing: 0.02,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
