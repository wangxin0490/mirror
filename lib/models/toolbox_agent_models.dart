// 工具箱智能体 API 数据模型（与 hylt_go internal/model/productagent 对齐）。

class ToolboxUIConfig {
  const ToolboxUIConfig({
    this.renderer = 'plain',
    this.hubScreen = 'default',
    this.directNewSession = false,
    this.placeholder = '',
    this.welcomeMessage = '',
  });

  final String renderer;
  final String hubScreen;
  final bool directNewSession;
  final String placeholder;
  final String welcomeMessage;

  factory ToolboxUIConfig.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const ToolboxUIConfig();
    return ToolboxUIConfig(
      renderer: j['renderer'] as String? ?? 'plain',
      hubScreen: j['hub_screen'] as String? ?? 'default',
      directNewSession: j['direct_new_session'] as bool? ?? false,
      placeholder: j['placeholder'] as String? ?? '',
      welcomeMessage: j['welcome_message'] as String? ?? '',
    );
  }
}

class ToolboxParserConfig {
  const ToolboxParserConfig({this.structuredBlock = ''});

  final String structuredBlock;

  factory ToolboxParserConfig.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const ToolboxParserConfig();
    return ToolboxParserConfig(
      structuredBlock: j['structured_block'] as String? ?? '',
    );
  }
}

class ToolboxAgentItem {
  const ToolboxAgentItem({
    required this.agentCode,
    required this.displayName,
    required this.description,
    required this.iconKey,
    required this.entryType,
    required this.tokenUsed,
    required this.invokeCount,
    this.enabled = true,
    this.disabledReason = '',
    this.requiredModel = '',
    this.defaultModel = '',
    this.capabilities = const [],
    this.uiConfig = const ToolboxUIConfig(),
    this.parserConfig = const ToolboxParserConfig(),
  });

  final String agentCode;
  final String displayName;
  final String description;
  final String iconKey;
  final String entryType;
  final int tokenUsed;
  final int invokeCount;
  final bool enabled;
  final String disabledReason;
  final String requiredModel;
  final String defaultModel;
  final List<String> capabilities;
  final ToolboxUIConfig uiConfig;
  final ToolboxParserConfig parserConfig;

  bool get isModelUnavailable =>
      !enabled && disabledReason == 'model_unavailable';

  String get hubScreen =>
      uiConfig.hubScreen.isNotEmpty ? uiConfig.hubScreen : 'default';

  bool get opensMirrorChat => hubScreen == 'mirror_chat';

  String get renderer =>
      uiConfig.renderer.isNotEmpty ? uiConfig.renderer : 'plain';

  String get tokenUsedLabel {
    if (tokenUsed <= 0) return '0';
    if (tokenUsed >= 1000000) {
      return '${(tokenUsed / 1000000).toStringAsFixed(1)}M';
    }
    if (tokenUsed >= 1000) return '${(tokenUsed / 1000).round()}k';
    return '$tokenUsed';
  }

  /// 会议纪要助手按会话总次数统计，不消耗 tokens。
  bool get isSessionCountOnly => agentCode == 'meeting-minutes';

  String get usageSubtitle => isSessionCountOnly
      ? '$invokeCount 次'
      : '$tokenUsedLabel tokens · $invokeCount 次调用';

  String get usageTrailing =>
      isSessionCountOnly ? '$invokeCount' : tokenUsedLabel;

  factory ToolboxAgentItem.fromJson(Map<String, dynamic> j) {
    final caps = j['capabilities'];
    return ToolboxAgentItem(
      agentCode: j['agent_code'] as String? ?? '',
      displayName: j['display_name'] as String? ?? '',
      description: j['description'] as String? ?? '',
      iconKey: j['icon_key'] as String? ?? 'default',
      entryType: j['entry_type'] as String? ?? 'chat',
      tokenUsed: (j['token_used'] as num?)?.toInt() ?? 0,
      invokeCount: (j['invoke_count'] as num?)?.toInt() ?? 0,
      enabled: j['enabled'] as bool? ?? true,
      disabledReason: j['disabled_reason'] as String? ?? '',
      requiredModel: j['required_model'] as String? ?? '',
      defaultModel: j['default_model'] as String? ?? '',
      capabilities:
          caps is List ? caps.map((e) => e.toString()).toList() : const [],
      uiConfig: ToolboxUIConfig.fromJson(
        j['ui_config'] as Map<String, dynamic>?,
      ),
      parserConfig: ToolboxParserConfig.fromJson(
        j['parser_config'] as Map<String, dynamic>?,
      ),
    );
  }
}

class ProductAgentConversation {
  const ProductAgentConversation({
    required this.conversationId,
    required this.agentCode,
    required this.modelCode,
    this.title,
  });

  final int conversationId;
  final String agentCode;
  final String modelCode;
  final String? title;

  factory ProductAgentConversation.fromJson(Map<String, dynamic> j) =>
      ProductAgentConversation(
        conversationId: (j['conversation_id'] as num?)?.toInt() ?? 0,
        agentCode: j['agent_code'] as String? ?? '',
        modelCode: j['model_code'] as String? ?? '',
        title: j['title'] as String?,
      );
}

class ProductAgentConversationSummary {
  const ProductAgentConversationSummary({
    required this.conversationId,
    required this.agentCode,
    required this.title,
    required this.modelCode,
    this.lastMessageAt,
    this.createdAt,
  });

  final int conversationId;
  final String agentCode;
  final String title;
  final String modelCode;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;

  String get displayTitle {
    final t = title.trim();
    if (t.isNotEmpty) return t;
    return '新对话';
  }

  DateTime get sortTime =>
      lastMessageAt ?? createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  factory ProductAgentConversationSummary.fromJson(Map<String, dynamic> j) {
    DateTime? lastAt;
    final rawLast = j['last_message_at'];
    if (rawLast is String && rawLast.isNotEmpty) {
      lastAt = DateTime.tryParse(rawLast);
    }
    DateTime? created;
    final rawCreated = j['created_at'];
    if (rawCreated is String && rawCreated.isNotEmpty) {
      created = DateTime.tryParse(rawCreated);
    }
    return ProductAgentConversationSummary(
      conversationId: (j['conversation_id'] as num?)?.toInt() ?? 0,
      agentCode: j['agent_code'] as String? ?? '',
      title: j['title'] as String? ?? '',
      modelCode: j['model_code'] as String? ?? '',
      lastMessageAt: lastAt,
      createdAt: created,
    );
  }
}

class ProductAgentMessage {
  const ProductAgentMessage({
    required this.id,
    required this.role,
    required this.content,
    this.streaming = false,
  });

  final int id;
  final String role;
  final String content;
  final bool streaming;

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  ProductAgentMessage copyWith({String? content, bool? streaming, int? id}) =>
      ProductAgentMessage(
        id: id ?? this.id,
        role: role,
        content: content ?? this.content,
        streaming: streaming ?? this.streaming,
      );

  factory ProductAgentMessage.fromJson(Map<String, dynamic> j) =>
      ProductAgentMessage(
        id: (j['id'] as num?)?.toInt() ?? 0,
        role: j['role'] as String? ?? '',
        content: j['content'] as String? ?? '',
      );
}
