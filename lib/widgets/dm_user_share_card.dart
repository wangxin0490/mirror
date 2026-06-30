import 'package:flutter/material.dart';

import '../data/mirror_authors.dart';
import '../models/feed_models.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../utils/dm_share_message.dart';
import '../utils/media_url.dart';
import '../widgets/mirror_network_image.dart';
import '../widgets/mirror_pressable.dart';

/// 私信中的博主名片（布局参考微信「个人名片」：头像 + 昵称 + 底栏类型）。
class DmUserShareCard extends StatelessWidget {
  const DmUserShareCard({
    super.key,
    required this.share,
    this.onTap,
    this.alignEnd = false,
  });

  final DmUserShare share;
  final VoidCallback? onTap;
  final bool alignEnd;

  static const Color _wxBorder = Color(0xFFE6E6E6);
  static const Color _wxFooterBg = Color(0xFFF7F7F7);
  static const Color _wxFooterText = Color(0xFF999999);
  static const Color _wxSubtitle = Color(0xFF888888);

  @override
  Widget build(BuildContext context) {
    final handle = share.handle.replaceAll('@', '').trim();
    final letter = share.avatarLetter.isNotEmpty
        ? share.avatarLetter
        : (share.displayName.isNotEmpty ? share.displayName[0] : '?');
    final subtitle = _subtitle(handle);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: MirrorPressable(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 232,
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
            decoration: BoxDecoration(
              color: MirrorColors.bgApp,
              border: Border.all(color: _wxBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _wechatAvatar(letter),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              share.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MirrorTheme.sans(
                                fontSize: 16,
                                weight: FontWeight.w500,
                                color: MirrorColors.text,
                                height: 1.25,
                              ),
                            ),
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MirrorTheme.sans(
                                  fontSize: 13,
                                  color: _wxSubtitle,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 0.5, color: _wxBorder),
                Container(
                  color: _wxFooterBg,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Text(
                    '个人名片',
                    style: MirrorTheme.sans(fontSize: 12, color: _wxFooterText, height: 1.2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle(String handle) {
    if (share.tagline.trim().isNotEmpty) return share.tagline.trim();
    if (handle.isNotEmpty) return '@$handle';
    if (share.bio.trim().isNotEmpty) return share.bio.trim();
    return '';
  }

  LinearGradient _letterAvatarGradient() {
    final catalog = MirrorAuthor.byKey(MirrorAuthor.keyFromName(share.displayName));
    if (catalog != null) {
      return MirrorGradients.avatar(catalog.avatarColors);
    }
    return authorGradient(share.avatarVariant);
  }

  Widget _wechatAvatar(String letter) {
    const size = 48.0;
    const radius = 6.0;
    final url = share.avatarUrl.trim();
    if (url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: size,
          height: size,
          child: MirrorNetworkImage(url: resolveMediaUrl(url), fit: BoxFit.cover),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: _letterAvatarGradient(),
        ),
        child: Text(
          letter,
          style: MirrorTheme.sans(
            fontSize: 20,
            weight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
