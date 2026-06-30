import 'package:flutter/material.dart';

/// App logo (MJ).
class MirrorIcon extends StatelessWidget {
  const MirrorIcon({super.key, this.size = 26, this.color = Colors.white});

  static const assetPath = 'assets/images/logo_mj.png';
  static const tabChatAssetPath = 'assets/images/tab_ai_chat.png';

  final double size;
  /// Kept for call-site compatibility; the logo asset carries its own colors.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
