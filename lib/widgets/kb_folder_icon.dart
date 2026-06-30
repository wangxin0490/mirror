import 'package:flutter/material.dart';

import '../theme/mirror_colors.dart';

/// 知识库文件夹图标（渐变 + 折角，替代默认 folder_outlined）。
class KbFolderIcon extends StatelessWidget {
  const KbFolderIcon({
    super.key,
    this.size = 44,
    this.variant = KbFolderIconVariant.accent,
  });

  final double size;
  final KbFolderIconVariant variant;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, tab) = switch (variant) {
      KbFolderIconVariant.accent => (
          [MirrorColors.accent.withValues(alpha: 0.22), MirrorColors.accentSoft],
          MirrorColors.accentDeep,
          MirrorColors.accent.withValues(alpha: 0.45),
        ),
      KbFolderIconVariant.blue => (
          [MirrorColors.blue.withValues(alpha: 0.2), MirrorColors.blueSoft],
          MirrorColors.blue,
          MirrorColors.blue.withValues(alpha: 0.35),
        ),
    };
    final r = size * 0.27;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: bg),
        borderRadius: BorderRadius.circular(r),
        boxShadow: [
          BoxShadow(
            color: fg.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: size * 0.18,
            top: size * 0.14,
            child: Container(
              width: size * 0.42,
              height: size * 0.14,
              decoration: BoxDecoration(
                color: tab,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(size * 0.06),
                  topRight: Radius.circular(size * 0.06),
                ),
              ),
            ),
          ),
          Center(
            child: Icon(
              Icons.folder_rounded,
              size: size * 0.52,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

enum KbFolderIconVariant { accent, blue }
