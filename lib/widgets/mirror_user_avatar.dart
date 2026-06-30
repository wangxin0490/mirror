import 'package:flutter/material.dart';

import '../screens/mirror_feed_data.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../utils/media_url.dart';
import 'mirror_network_image.dart';
/// 用户头像：有 `avatar_url` 时显示网络图，否则字母渐变/纯色圆。
class MirrorUserAvatar extends StatelessWidget {
  const MirrorUserAvatar({
    super.key,
    required this.size,
    required this.letter,
    this.avatarUrl = '',
    this.gradient,
    this.color,
    this.fontSize,
  });

  final double size;
  final String letter;
  final String avatarUrl;
  final LinearGradient? gradient;
  final Color? color;
  final double? fontSize;

  factory MirrorUserAvatar.variant({
    required double size,
    required String letter,
    String avatarUrl = '',
    required FeedAvatarVariant variant,
    double? fontSize,
  }) =>
      MirrorUserAvatar(
        size: size,
        letter: letter,
        avatarUrl: avatarUrl,
        color: variant.color,
        fontSize: fontSize,
      );

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl.trim();
    if (url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: SizedBox(
          width: size,
          height: size,
          child: MirrorNetworkImage(url: resolveMediaUrl(url)),
        ),
      );
    }
    final fs = fontSize ?? size * 0.36;
    if (gradient != null) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(gradient: gradient, shape: BoxShape.circle),
        child: Text(
          letter,
          style: MirrorTheme.sans(fontSize: fs, weight: FontWeight.w500, color: Colors.white),
        ),
      );
    }
    final c = color ?? MirrorColors.accent;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      child: Text(
        letter,
        style: MirrorTheme.sans(fontSize: fs, weight: FontWeight.w500, color: Colors.white),
      ),
    );
  }
}
