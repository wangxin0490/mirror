import 'package:flutter/material.dart';

import '../layout/adaptive_layout.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../utils/dm_share_message.dart';
import '../utils/media_url.dart';
import '../widgets/mirror_network_image.dart';
import '../widgets/mirror_pressable.dart';

/// 私信中的文章分享卡片（对齐 HTML `.share-card`）。
class DmFeedPostShareCard extends StatelessWidget {
  const DmFeedPostShareCard({
    super.key,
    required this.share,
    this.onTap,
    this.alignEnd = false,
  });

  final DmFeedPostShare share;
  final VoidCallback? onTap;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: MirrorPressable(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
            decoration: BoxDecoration(
              color: MirrorColors.bgApp,
              border: Border.all(color: MirrorColors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _cover(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        share.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MirrorTheme.sans(fontSize: 13, weight: FontWeight.w500, height: 1.4),
                      ),
                      if (share.authorName.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          share.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MirrorTheme.mono(fontSize: 10, color: MirrorColors.text3, letterSpacing: 0),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        '查看文章 →',
                        style: MirrorTheme.sans(
                          fontSize: 11.5,
                          color: MirrorColors.accent,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cover(BuildContext context) {
    final imageUrl = share.coverImageUrl?.trim() ?? '';
    if (imageUrl.isNotEmpty) {
      return adaptiveAspectFrame(
        context: context,
        phoneHeight: 88,
        widthOverHeight: kShareCardCoverAspectRatio,
        child: MirrorNetworkImage(url: resolveMediaUrl(imageUrl), fit: BoxFit.cover),
      );
    }
    final quote = share.quote?.trim();
    final label = (quote != null && quote.isNotEmpty)
        ? quote
        : (share.title.length > 24 ? '${share.title.substring(0, 24)}…' : share.title);
    return adaptiveAspectFrame(
      context: context,
      phoneHeight: 88,
      widthOverHeight: kShareCardCoverAspectRatio,
      child: Container(
        padding: const EdgeInsets.all(14),
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE84A85), Color(0xFFFFB4D0)],
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: MirrorTheme.serif(fontSize: 14, color: Colors.white, height: 1.3),
        ),
      ),
    );
  }
}
