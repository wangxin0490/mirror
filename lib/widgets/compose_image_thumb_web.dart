import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';

/// Web：blob URL 预览，避免部分环境下 Image.memory 不刷新。
class ComposeImageThumbWeb extends StatefulWidget {
  const ComposeImageThumbWeb({super.key, required this.bytes, required this.size});

  final Uint8List bytes;
  final double size;

  @override
  State<ComposeImageThumbWeb> createState() => _ComposeImageThumbWebState();
}

class _ComposeImageThumbWebState extends State<ComposeImageThumbWeb> {
  String? _url;

  @override
  void initState() {
    super.initState();
    _url = html.Url.createObjectUrlFromBlob(html.Blob([widget.bytes]));
  }

  @override
  void didUpdateWidget(covariant ComposeImageThumbWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bytes != widget.bytes) {
      _revoke();
      _url = html.Url.createObjectUrlFromBlob(html.Blob([widget.bytes]));
    }
  }

  @override
  void dispose() {
    _revoke();
    super.dispose();
  }

  void _revoke() {
    final u = _url;
    if (u != null) html.Url.revokeObjectUrl(u);
    _url = null;
  }

  Widget _errorPlaceholder() => Container(
        width: widget.size,
        height: widget.size,
        color: MirrorColors.bgSoft,
        alignment: Alignment.center,
        child: Text('无法预览', style: MirrorTheme.sans(fontSize: 10, color: MirrorColors.text3)),
      );

  @override
  Widget build(BuildContext context) {
    final url = _url;
    if (url == null) {
      return _errorPlaceholder();
    }
    return Image.network(
      url,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => _errorPlaceholder(),
    );
  }
}
