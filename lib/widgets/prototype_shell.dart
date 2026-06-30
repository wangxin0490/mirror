import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/mirror_colors.dart';
import 'phone_frame.dart';

class PrototypeShell extends StatelessWidget {
  const PrototypeShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MirrorColors.bgPage,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          color: MirrorColors.bgPage,
          gradient: LinearGradient(
            begin: Alignment(-0.8, -1),
            end: Alignment(0.95, 0.2),
            colors: [
              Color(0x0A5B47E8),
              Colors.transparent,
              Color(0x081D9E75),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scale = _fitScale(constraints);
                  // Web 上 Transform.scale 会导致点击坐标与视觉错位，输入框无法聚焦。
                  if (kIsWeb) {
                    return Center(child: child);
                  }
                  return Transform.scale(scale: scale, child: child);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _fitScale(BoxConstraints c) {
    final maxW = c.maxWidth;
    final maxH = c.maxHeight;
    if (maxW <= 0 || maxH <= 0) return 1;
    final fit = (maxW / kPhoneWidth) < (maxH / kPhoneHeight) ? maxW / kPhoneWidth : maxH / kPhoneHeight;
    // 大屏可放大到 1.25，小屏最少缩到 0.88
    return fit.clamp(0.88, 1.25);
  }
}
