import 'package:flutter/material.dart';
import '../theme/mirror_colors.dart';

/// 轻触反馈，贴近 HTML hover/active 克制风格
class MirrorPressable extends StatelessWidget {
  const MirrorPressable({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.borderRadius,
    this.hoverColor,
    this.highlightColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Color? hoverColor;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius ?? BorderRadius.zero,
        splashColor: MirrorColors.accentSoft.withValues(alpha: 0.6),
        highlightColor: highlightColor ?? MirrorColors.bgSoft,
        hoverColor: hoverColor ?? MirrorColors.bgSoft,
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }
}
