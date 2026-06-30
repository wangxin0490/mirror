/// 对话附件（Agent / KbChat API）。
class ChatAttachment {
  const ChatAttachment({
    required this.type,
    required this.url,
    this.objectKey,
    this.mime,
    this.filename,
    this.size,
  });

  final String type;
  final String url;
  final String? objectKey;
  final String? mime;
  final String? filename;
  final int? size;

  Map<String, dynamic> toJson() => {
        'type': type,
        'url': url,
        if (objectKey != null && objectKey!.isNotEmpty) 'object_key': objectKey,
        if (mime != null && mime!.isNotEmpty) 'mime': mime,
        if (filename != null && filename!.isNotEmpty) 'filename': filename,
        if (size != null) 'size': size,
      };

  factory ChatAttachment.fromJson(Map<String, dynamic> j) => ChatAttachment(
        type: j['type'] as String? ?? '',
        url: j['url'] as String? ?? '',
        objectKey: j['object_key'] as String?,
        mime: j['mime'] as String?,
        filename: j['filename'] as String?,
        size: (j['size'] as num?)?.toInt(),
      );
}
