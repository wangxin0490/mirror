import 'package:flutter/material.dart';

import '../config/debug_flags.dart';
import '../utils/network_ninja_mount.dart';
import 'network_ninja_fab.dart';

/// 放在 [MaterialApp.home] 子树内，挂载 Network Ninja 并显示固定抓包按钮。
class NetworkNinjaBootstrap extends StatefulWidget {
  const NetworkNinjaBootstrap({super.key, required this.child});

  final Widget child;

  @override
  State<NetworkNinjaBootstrap> createState() => _NetworkNinjaBootstrapState();
}

class _NetworkNinjaBootstrapState extends State<NetworkNinjaBootstrap> {
  @override
  void initState() {
    super.initState();
    if (DebugFlags.networkNinjaEnabled) {
      resetNetworkNinjaBubbleMountState();
      scheduleNetworkNinjaBubbleMount();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (DebugFlags.networkNinjaEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        tryMountNetworkNinjaBubbleFromContext(context);
      });
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (DebugFlags.networkNinjaEnabled) const NetworkNinjaFab(),
      ],
    );
  }
}
