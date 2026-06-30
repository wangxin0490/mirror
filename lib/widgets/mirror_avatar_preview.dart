import 'package:flutter/material.dart';

import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../utils/media_url.dart';
import '../widgets/chat_attachment_preview_sheet.dart';
import '../widgets/mirror_pressable.dart';
import '../widgets/phone_components.dart';

/// 全屏预览用户头像（有图放大查看，无图展示大号字母渐变）。
Future<void> openMirrorAvatarPreview(
  BuildContext context, {
  required String letter,
  required List<Color> colors,
  String avatarUrl = '',
  String? title,
}) async {
  final url = avatarUrl.trim();
  if (url.isNotEmpty) {
    await openChatImagePreview(
      context,
      url: resolveMediaUrl(url),
      title: title?.trim().isNotEmpty == true ? title : '头像',
    );
    return;
  }
  final label = letter.trim().isNotEmpty ? letter.trim() : '?';
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _LetterAvatarPreviewScreen(
        letter: label,
        colors: colors,
        title: title,
      ),
    ),
  );
}

class _LetterAvatarPreviewScreen extends StatelessWidget {
  const _LetterAvatarPreviewScreen({
    required this.letter,
    required this.colors,
    this.title,
  });

  final String letter;
  final List<Color> colors;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final label = title?.trim();
    return Scaffold(
      backgroundColor: MirrorColors.bgPage,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 12, 10),
              child: Row(
                children: [
                  MirrorPressable(
                    onTap: () => Navigator.of(context).pop(),
                    padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                    borderRadius: BorderRadius.circular(8),
                    child: const Icon(Icons.chevron_left, size: 22, color: MirrorColors.text2),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label?.isNotEmpty == true ? label! : '头像预览',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MirrorTheme.sans(fontSize: 15, weight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: AvatarGradient(
                  label: letter,
                  colors: colors,
                  size: 220,
                  radius: 110,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
