import '../api/chat_api.dart';
import '../models/chat_attachment.dart';
import '../models/pending_chat_attachment.dart';

/// 将 composer 暂存槽位上传为 API 附件；失败返回 null（调用方保留 pending）。
Future<List<ChatAttachment>?> uploadComposerSlots(ComposerAttachmentSlots slots) async {
  final out = <ChatAttachment>[];
  for (final pending in slots.ordered) {
    final uploaded = await ChatApi.uploadAttachmentResult(pending.bytes, pending.name);
    if (uploaded == null || uploaded.url.isEmpty) return null;
    out.add(ChatAttachment(
      type: pending.isImage ? 'image' : 'document',
      url: uploaded.url,
      objectKey: uploaded.objectKey,
      filename: pending.name,
      size: pending.bytes.length,
      mime: pending.isImage ? 'image/jpeg' : null,
    ));
  }
  return out;
}
