import 'chat_attachment.dart';

/// Agent 聊天 API 数据模型（与 hylt_go internal/model/agent 对齐）。
class AgentModelItem {
  const AgentModelItem({
    required this.modelCode,
    required this.displayName,
    required this.accessMode,
    required this.accessLabel,
    required this.selectable,
    this.supportsVision = false,
    this.lockReason,
    this.balanceTokens,
    this.trialRemaining,
  });

  final String modelCode;
  final String displayName;
  final String accessMode;
  final String accessLabel;
  final bool selectable;
  final bool supportsVision;
  final String? lockReason;
  final int? balanceTokens;
  final int? trialRemaining;

  factory AgentModelItem.fromJson(Map<String, dynamic> j) => AgentModelItem(
        modelCode: j['model_code'] as String? ?? '',
        displayName: j['display_name'] as String? ?? '',
        accessMode: j['access_mode'] as String? ?? '',
        accessLabel: j['access_label'] as String? ?? '',
        selectable: j['selectable'] as bool? ?? false,
        supportsVision: j['supports_vision'] as bool? ?? false,
        lockReason: j['lock_reason'] as String?,
        balanceTokens: (j['balance_tokens'] as num?)?.toInt(),
        trialRemaining: (j['trial_remaining'] as num?)?.toInt(),
      );
}

class AgentModelList {
  const AgentModelList({required this.items});

  final List<AgentModelItem> items;

  factory AgentModelList.fromJson(Map<String, dynamic> j) {
    final raw = j['items'];
    if (raw is! List) return const AgentModelList(items: []);
    return AgentModelList(
      items: raw.map((e) => AgentModelItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class AgentConversation {
  const AgentConversation({
    required this.conversationId,
    required this.modelCode,
    this.title,
  });

  final int conversationId;
  final String modelCode;
  final String? title;

  factory AgentConversation.fromJson(Map<String, dynamic> j) => AgentConversation(
        conversationId: (j['conversation_id'] as num?)?.toInt() ?? 0,
        modelCode: j['model_code'] as String? ?? '',
        title: j['title'] as String?,
      );
}

class AgentConversationSummary {
  const AgentConversationSummary({
    required this.conversationId,
    required this.modelCode,
    this.title,
    this.lastMessageAt,
    this.createdAt,
  });

  final int conversationId;
  final String modelCode;
  final String? title;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;

  String get displayTitle {
    final t = title?.trim();
    if (t != null && t.isNotEmpty) return t;
    return '新对话';
  }

  DateTime get sortTime => lastMessageAt ?? createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  factory AgentConversationSummary.fromJson(Map<String, dynamic> j) {
    DateTime? parseAt(String? key) {
      final raw = j[key];
      if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
      return null;
    }

    return AgentConversationSummary(
      conversationId: (j['conversation_id'] as num?)?.toInt() ?? 0,
      modelCode: j['model_code'] as String? ?? '',
      title: j['title'] as String?,
      lastMessageAt: parseAt('last_message_at'),
      createdAt: parseAt('created_at'),
    );
  }
}

class AgentConversationList {
  const AgentConversationList({required this.items, required this.hasMore});

  final List<AgentConversationSummary> items;
  final bool hasMore;

  factory AgentConversationList.fromJson(Map<String, dynamic> j) {
    final raw = j['items'];
    final items = raw is List
        ? raw.map((e) => AgentConversationSummary.fromJson(e as Map<String, dynamic>)).toList()
        : <AgentConversationSummary>[];
    return AgentConversationList(
      items: items,
      hasMore: j['has_more'] as bool? ?? false,
    );
  }
}

class AgentMessageSource {
  const AgentMessageSource({
    required this.index,
    required this.title,
    this.url,
    this.snippet,
  });

  final int index;
  final String title;
  final String? url;
  final String? snippet;

  bool get hasUrl {
    final u = url?.trim() ?? '';
    return u.startsWith('http://') || u.startsWith('https://');
  }

  factory AgentMessageSource.fromJson(Map<String, dynamic> j) => AgentMessageSource(
        index: (j['index'] as num?)?.toInt() ?? 0,
        title: j['title'] as String? ?? '',
        url: j['url'] as String?,
        snippet: j['snippet'] as String?,
      );

  static List<AgentMessageSource> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => AgentMessageSource.fromJson(e as Map<String, dynamic>)).toList();
  }
}

/// 同一网页/标题的多处引用角标（资料列表去重展示）。
class AgentMessageSourceGroup {
  const AgentMessageSourceGroup({
    required this.primary,
    required this.indices,
  });

  final AgentMessageSource primary;
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

String agentSourceDedupeKey(AgentMessageSource source) {
  final url = source.url?.trim() ?? '';
  if (url.isNotEmpty) return 'url:$url';
  return 'title:${source.title.trim().toLowerCase()}';
}

List<AgentMessageSourceGroup> groupAgentMessageSources(List<AgentMessageSource> sources) {
  if (sources.isEmpty) return const [];
  final grouped = <String, List<AgentMessageSource>>{};
  for (final source in sources) {
    grouped.putIfAbsent(agentSourceDedupeKey(source), () => []).add(source);
  }
  final out = grouped.values.map((items) {
    items.sort((a, b) => a.index.compareTo(b.index));
    return AgentMessageSourceGroup(
      primary: items.first,
      indices: items.map((s) => s.index).toList(),
    );
  }).toList();
  out.sort((a, b) => a.indices.first.compareTo(b.indices.first));
  return out;
}

class AgentMessage {
  const AgentMessage({
    required this.id,
    required this.role,
    required this.content,
    this.attachments = const [],
    this.createdAt,
    this.streaming = false,
    this.searching = false,
    this.sources = const [],
  });

  final int id;
  final String role;
  final String content;
  final List<ChatAttachment> attachments;
  final DateTime? createdAt;
  final bool streaming;
  final bool searching;
  final List<AgentMessageSource> sources;

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  AgentMessage copyWith({
    String? content,
    bool? streaming,
    bool? searching,
    int? id,
    List<AgentMessageSource>? sources,
    List<ChatAttachment>? attachments,
  }) =>
      AgentMessage(
        id: id ?? this.id,
        role: role,
        content: content ?? this.content,
        attachments: attachments ?? this.attachments,
        createdAt: createdAt,
        streaming: streaming ?? this.streaming,
        searching: searching ?? this.searching,
        sources: sources ?? this.sources,
      );

  factory AgentMessage.fromJson(Map<String, dynamic> j) {
    DateTime? at;
    final raw = j['created_at'];
    if (raw is String && raw.isNotEmpty) {
      at = DateTime.tryParse(raw);
    }
    final attRaw = j['attachments'];
    final attachments = attRaw is List
        ? attRaw.map((e) => ChatAttachment.fromJson(e as Map<String, dynamic>)).toList()
        : <ChatAttachment>[];
    return AgentMessage(
      id: (j['id'] as num?)?.toInt() ?? 0,
      role: j['role'] as String? ?? '',
      content: j['content'] as String? ?? '',
      attachments: attachments,
      createdAt: at,
      sources: AgentMessageSource.listFromJson(j['sources']),
    );
  }
}

class AgentMessageList {
  const AgentMessageList({required this.items, required this.hasMore});

  final List<AgentMessage> items;
  final bool hasMore;

  factory AgentMessageList.fromJson(Map<String, dynamic> j) {
    final raw = j['items'];
    final items = raw is List
        ? raw.map((e) => AgentMessage.fromJson(e as Map<String, dynamic>)).toList()
        : <AgentMessage>[];
    return AgentMessageList(
      items: items,
      hasMore: j['has_more'] as bool? ?? false,
    );
  }
}

class AgentStreamDone {
  const AgentStreamDone({
    required this.messageId,
    required this.tokensIn,
    required this.tokensOut,
    required this.accessMode,
    this.content = '',
    this.lockReason,
    this.sources = const [],
  });

  final int messageId;
  final int tokensIn;
  final int tokensOut;
  final String accessMode;
  final String content;
  final String? lockReason;
  final List<AgentMessageSource> sources;

  factory AgentStreamDone.fromJson(Map<String, dynamic> j) => AgentStreamDone(
        messageId: (j['message_id'] as num?)?.toInt() ?? 0,
        tokensIn: (j['tokens_in'] as num?)?.toInt() ?? 0,
        tokensOut: (j['tokens_out'] as num?)?.toInt() ?? 0,
        accessMode: j['access_mode'] as String? ?? '',
        content: j['content'] as String? ?? '',
        lockReason: j['lock_reason'] as String?,
        sources: AgentMessageSource.listFromJson(j['sources']),
      );
}

class AgentToolEvent {
  const AgentToolEvent({
    required this.name,
    required this.phase,
    this.query,
    this.sourceCount,
    this.message,
    this.sources = const [],
  });

  final String name;
  final String phase;
  final String? query;
  final int? sourceCount;
  final String? message;
  final List<AgentMessageSource> sources;

  factory AgentToolEvent.fromJson(Map<String, dynamic> j) => AgentToolEvent(
        name: j['name'] as String? ?? '',
        phase: j['phase'] as String? ?? '',
        query: j['query'] as String?,
        sourceCount: (j['source_count'] as num?)?.toInt(),
        message: j['message'] as String?,
        sources: AgentMessageSource.listFromJson(j['sources']),
      );
}
