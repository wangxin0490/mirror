import 'dart:typed_data';

import '../services/picked_image_bytes.dart';

/// 对话 composer 暂存附件（发送前仅保留本地 bytes，对齐后端 chat_attachment 1 图 + 1 文档）。
class PendingChatAttachment {
  PendingChatAttachment({
    required this.name,
    required this.bytes,
    required this.isImage,
  });

  final String name;
  final Uint8List bytes;
  final bool isImage;

  factory PendingChatAttachment.fromPicked(PickedImageBytes picked, {required bool isImage}) =>
      PendingChatAttachment(name: picked.name, bytes: picked.bytes, isImage: isImage);
}

/// Phase1 槽位：最多 1 图 + 1 文档（与 hylt_go chat_attachment 配置一致）。
class ComposerAttachmentSlots {
  ComposerAttachmentSlots({this.image, this.document});

  PendingChatAttachment? image;
  PendingChatAttachment? document;

  bool get hasPending => image != null || document != null;

  void clear() {
    image = null;
    document = null;
  }

  List<PendingChatAttachment> get ordered {
    final out = <PendingChatAttachment>[];
    if (image != null) out.add(image!);
    if (document != null) out.add(document!);
    return out;
  }
}

/// 与 hylt_go internal/config/chat_attachment 默认一致。
const int kChatImageMaxBytes = 10 * 1024 * 1024;
const int kChatDocumentMaxBytes = 20 * 1024 * 1024;

/// 知识库对话：PDF/Office 须先导入知识库。Agent 对话不使用此限制。
bool chatAttachmentRequiresKbImport(String filename) {
  final ext = _ext(filename);
  switch (ext) {
    case '.pdf':
    case '.doc':
    case '.docx':
    case '.ppt':
    case '.pptx':
    case '.xls':
    case '.xlsx':
      return true;
    default:
      return false;
  }
}

String? validatePendingAttachmentSize(int byteLength, {required bool isImage}) {
  final max = isImage ? kChatImageMaxBytes : kChatDocumentMaxBytes;
  if (byteLength > max) {
    final mb = isImage ? 10 : 20;
    return isImage ? '图片不能超过 ${mb}MB' : '文件不能超过 ${mb}MB';
  }
  return null;
}

bool pendingFileIsImage(String filename) {
  final ext = _ext(filename);
  switch (ext) {
    case '.png':
    case '.jpg':
    case '.jpeg':
    case '.gif':
    case '.webp':
    case '.bmp':
    case '.heic':
      return true;
    default:
      return false;
  }
}

String _ext(String filename) {
  final i = filename.lastIndexOf('.');
  if (i < 0) return '';
  return filename.substring(i).toLowerCase();
}
