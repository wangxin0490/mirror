import 'package:flutter/material.dart';

import '../layout/adaptive_layout.dart';
import '../models/chat_attachment.dart';
import '../screens/kb/kb_ui_helpers.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import 'chat_attachment_preview_sheet.dart';
import 'mirror_network_image.dart';
import 'mirror_pressable.dart';

/// 对话用户消息中的附件预览（图片缩略图 / 文档文件名）。
class ChatMessageAttachments extends StatelessWidget {
  const ChatMessageAttachments({
    super.key,
    required this.attachments,
    this.onDarkBackground = false,
    this.maxImageSize = 200,
  });

  final List<ChatAttachment> attachments;
  final bool onDarkBackground;
  final double maxImageSize;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    final children = <Widget>[];
    for (final a in attachments) {
      if (attachmentIsImage(a)) {
        children.add(_imageThumb(context, a));
      } else {
        children.add(_fileChip(context, a));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          children[i],
        ],
      ],
    );
  }

  Widget _imageThumb(BuildContext context, ChatAttachment a) {
    final url = a.url.trim();
    if (url.isEmpty) {
      return _placeholder(onDarkBackground, '无法预览图片');
    }
    final side = adaptiveSquareSize(
      context,
      phoneSize: maxImageSize,
      maxSize: kChatImageMaxSize,
    );
    return MirrorPressable(
      onTap: () => openChatImagePreview(
        context,
        url: url,
        title: _displayName(a),
      ),
      borderRadius: BorderRadius.circular(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: side, maxHeight: side),
          child: MirrorNetworkImage(url: url, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _fileChip(BuildContext context, ChatAttachment a) {
    final name = _displayName(a);
    final (icon, iconColor, _) = KbDocUi.fileTypeForFilename(name);
    final fg = onDarkBackground ? Colors.white.withValues(alpha: 0.9) : MirrorColors.text;
    final bg = onDarkBackground ? Colors.white.withValues(alpha: 0.12) : MirrorColors.bgSoft;
    return MirrorPressable(
      onTap: () => openChatAttachmentPreview(context, a),
      borderRadius: BorderRadius.circular(10),
      hoverColor: onDarkBackground ? Colors.white.withValues(alpha: 0.08) : null,
      highlightColor: onDarkBackground ? Colors.white.withValues(alpha: 0.06) : null,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: onDarkBackground ? null : Border.all(color: MirrorColors.borderSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: onDarkBackground ? iconColor.withValues(alpha: 0.95) : iconColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: MirrorTheme.sans(fontSize: 12, height: 1.35, color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(bool dark, String msg) {
    return Container(
      width: 120,
      height: 80,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.1) : MirrorColors.bgSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        msg,
        style: MirrorTheme.sans(
          fontSize: 11,
          color: dark ? Colors.white70 : MirrorColors.text3,
        ),
      ),
    );
  }
}

bool attachmentIsImage(ChatAttachment a) {
  final t = a.type.trim().toLowerCase();
  if (t == 'image') return true;
  final mime = (a.mime ?? '').toLowerCase();
  if (mime.startsWith('image/')) return true;
  final name = _displayName(a).toLowerCase();
  return name.endsWith('.jpg') ||
      name.endsWith('.jpeg') ||
      name.endsWith('.png') ||
      name.endsWith('.gif') ||
      name.endsWith('.webp') ||
      name.endsWith('.heic');
}

String _displayName(ChatAttachment a) {
  final fn = a.filename?.trim() ?? '';
  if (fn.isNotEmpty) return fn;
  final url = a.url.trim();
  if (url.isEmpty) return '附件';
  final path = Uri.tryParse(url)?.pathSegments.lastOrNull ?? '';
  if (path.isNotEmpty) return path;
  return url.split('/').where((s) => s.isNotEmpty).lastOrNull ?? '附件';
}
