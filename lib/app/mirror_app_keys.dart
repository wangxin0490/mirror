import 'package:flutter/material.dart';

/// 根 [Navigator]，供 Network Ninja 等挂在稳定 Overlay 上。
final GlobalKey<NavigatorState> mirrorRootNavigatorKey =
    GlobalKey<NavigatorState>();

/// 全局 [ScaffoldMessenger]，供会议完成 SnackBar 等跨页面提示。
final GlobalKey<ScaffoldMessengerState> mirrorScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
