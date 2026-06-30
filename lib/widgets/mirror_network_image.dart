import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../utils/media_url.dart';

/// 详情轮播/正文用网络图，铺满容器并在失败时显示占位。
class MirrorNetworkImage extends StatelessWidget {
  const MirrorNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
  });

  final String url;
  final BoxFit fit;

  static Map<String, String>? _authHeaders(String src) {
    if (ApiConfig.accessToken.isEmpty) return null;
    if (!src.contains('/api/v1/')) return null;
    return {'Authorization': 'Bearer ${ApiConfig.accessToken}'};
  }

  @override
  Widget build(BuildContext context) {
    final src = resolveMediaUrl(url);
    if (src.isEmpty) {
      return _placeholder(compact: true, msg: '无效图片地址');
    }
    final headers = _authHeaders(src);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 72 || constraints.maxWidth < 72;
        return Image.network(
          src,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          headers: headers,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Container(
              color: MirrorColors.bgSoft,
              alignment: Alignment.center,
              child: SizedBox(
                width: compact ? 18 : 28,
                height: compact ? 18 : 28,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
          errorBuilder: (_, __, ___) {
            if (kDebugMode) {
              debugPrint('[MirrorNetworkImage] load failed: $src');
            }
            return _placeholder(compact: compact, msg: '图片加载失败');
          },
        );
      },
    );
  }

  Widget _placeholder({required bool compact, required String msg}) => Container(
        color: MirrorColors.bgSoft,
        alignment: Alignment.center,
        padding: compact ? EdgeInsets.zero : const EdgeInsets.all(16),
        child: compact
            ? Icon(Icons.image_not_supported_outlined, size: 20, color: MirrorColors.text3)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.image_not_supported_outlined, size: 32, color: MirrorColors.text3),
                  const SizedBox(height: 8),
                  Text(msg, style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text3), textAlign: TextAlign.center),
                ],
              ),
      );
}
