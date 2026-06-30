import 'package:flutter/material.dart';

import '../models/pending_chat_attachment.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import 'compose_image_thumb.dart';
import 'mirror_pressable.dart';

/// Composer 内待发送附件条（图缩略图 + 文件 chip，可删除）。
class ChatComposerAttachmentStrip extends StatelessWidget {
  const ChatComposerAttachmentStrip({
    super.key,
    required this.slots,
    this.onRemoveImage,
    this.onRemoveDocument,
  });

  final ComposerAttachmentSlots slots;
  final VoidCallback? onRemoveImage;
  final VoidCallback? onRemoveDocument;

  @override
  Widget build(BuildContext context) {
    if (!slots.hasPending) return const SizedBox.shrink();
    final children = <Widget>[];
    if (slots.image != null) {
      children.add(_imageTile(slots.image!, onRemoveImage));
    }
    if (slots.document != null) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 8));
      children.add(_fileChip(slots.document!, onRemoveDocument));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _imageTile(PendingChatAttachment att, VoidCallback? onRemove) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ComposeImageThumb(bytes: att.bytes, size: 72),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: _removeButton(onRemove),
        ),
      ],
    );
  }

  Widget _fileChip(PendingChatAttachment att, VoidCallback? onRemove) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 200),
          padding: const EdgeInsets.fromLTRB(10, 8, 28, 8),
          decoration: BoxDecoration(
            color: MirrorColors.bgSoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: MirrorColors.borderSoft),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insert_drive_file_outlined, size: 18, color: MirrorColors.text3),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  att.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text, height: 1.3),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: _removeButton(onRemove),
        ),
      ],
    );
  }

  Widget _removeButton(VoidCallback? onRemove) {
    return MirrorPressable(
      onTap: onRemove,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: MirrorColors.text.withValues(alpha: 0.75),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: const Icon(Icons.close, size: 14, color: Colors.white),
      ),
    );
  }
}
