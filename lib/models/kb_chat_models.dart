import 'chat_attachment.dart';

class KbMessageSource {
  const KbMessageSource({
    required this.index,
    required this.title,
    this.kbId,
    this.documentId,
    this.ragflowDocumentId,
    this.snippet,
  });

  final int index;
  final String title;
  final int? kbId;
  final int? documentId;
  final String? ragflowDocumentId;
  final String? snippet;

  bool get canPreview => documentId != null && documentId! > 0 && kbId != null && kbId! > 0;

  factory KbMessageSource.fromJson(Map<String, dynamic> j) => KbMessageSource(
        index: (j['index'] as num?)?.toInt() ?? 0,
        title: j['title'] as String? ?? '',
        kbId: (j['kb_id'] as num?)?.toInt(),
        documentId: (j['document_id'] as num?)?.toInt(),
        ragflowDocumentId: j['ragflow_document_id'] as String?,
        snippet: j['snippet'] as String?,
      );
}

/// 同一文档的多处引用片段（用于资料列表去重展示）。
class KbMessageSourceGroup {
  const KbMessageSourceGroup({
    required this.primary,
    required this.indices,
  });

  final KbMessageSource primary;
  final List<int> indices;

  String get idLabel {
    if (indices.length == 1) return 'ID:${indices.first}';
    final sorted = List<int>.from(indices)..sort();
    var contiguous = true;
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i] != sorted[i - 1] + 1) {
        contiguous = false;
        break;
      }
    }
    if (contiguous) return 'ID:${sorted.first}–${sorted.last}';
    if (sorted.length <= 3) return sorted.map((i) => 'ID:$i').join(', ');
    return 'ID:${sorted.first} 等 ${sorted.length} 处';
  }
}

String kbSourceDedupeKey(KbMessageSource source) {
  final docId = source.documentId;
  if (docId != null && docId > 0) {
    return 'doc:${source.kbId ?? 0}:$docId';
  }
  final rfId = source.ragflowDocumentId?.trim() ?? '';
  if (rfId.isNotEmpty) return 'rf:$rfId';
  return 'title:${source.title.trim().toLowerCase()}';
}

List<KbMessageSourceGroup> groupKbMessageSources(List<KbMessageSource> sources) {
  if (sources.isEmpty) return const [];
  final grouped = <String, List<KbMessageSource>>{};
  for (final source in sources) {
    grouped.putIfAbsent(kbSourceDedupeKey(source), () => []).add(source);
  }
  final out = grouped.values.map((items) {
    items.sort((a, b) => a.index.compareTo(b.index));
    return KbMessageSourceGroup(
      primary: items.first,
      indices: items.map((s) => s.index).toList(),
    );
  }).toList();
  out.sort((a, b) => a.indices.first.compareTo(b.indices.first));
  return out;
}

class KbMessage {
  const KbMessage({
    required this.role,
    required this.content,
    this.streaming = false,
    this.sources = const [],
    this.attachments = const [],
  });

  final String role;
  final String content;
  final bool streaming;
  final List<KbMessageSource> sources;
  final List<ChatAttachment> attachments;

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  KbMessage copyWith({
    String? content,
    bool? streaming,
    List<KbMessageSource>? sources,
    List<ChatAttachment>? attachments,
  }) =>
      KbMessage(
        role: role,
        content: content ?? this.content,
        streaming: streaming ?? this.streaming,
        sources: sources ?? this.sources,
        attachments: attachments ?? this.attachments,
      );
}

enum KbChatStatus { listening, thinking, responding }

class KbChatConversation {
  const KbChatConversation({
    required this.conversationId,
    required this.title,
    this.updatedAt = '',
  });

  final int conversationId;
  final String title;
  final String updatedAt;

  String get displayTitle => title.trim().isEmpty ? '新对话' : title.trim();

  factory KbChatConversation.fromJson(Map<String, dynamic> j) => KbChatConversation(
        conversationId: (j['conversation_id'] as num?)?.toInt() ?? 0,
        title: j['title'] as String? ?? '',
        updatedAt: j['updated_at'] as String? ?? '',
      );
}
