import 'package:flutter/material.dart';
import '../theme/mirror_colors.dart';

/// Android / iOS 真机：全屏铺满，不做手机外框缩放（避免变形）。
class NativeShell extends StatelessWidget {
  const NativeShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MirrorColors.bgApp,
      body: SafeArea(
        bottom: false,
        child: child,
      ),
    );
  }
}
