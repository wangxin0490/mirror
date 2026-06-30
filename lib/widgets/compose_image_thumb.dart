import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import 'compose_image_thumb_stub.dart'
    if (dart.library.js_interop) 'compose_image_thumb_web.dart' as web_thumb;

/// 发帖预览缩略图（Web 用 blob URL，移动端用 memory）。
class ComposeImageThumb extends StatelessWidget {
  const ComposeImageThumb({super.key, required this.bytes, this.size = 96});

  final Uint8List bytes;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return web_thumb.ComposeImageThumbWeb(bytes: bytes, size: size);
    }
    return Image.memory(
      bytes,
      width: size,
      height: size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => errorPlaceholder(size),
    );
  }

  static Widget errorPlaceholder(double size) => Container(
        width: size,
        height: size,
        color: MirrorColors.bgSoft,
        alignment: Alignment.center,
        child: Text('无法预览', style: MirrorTheme.sans(fontSize: 10, color: MirrorColors.text3)),
      );
}
