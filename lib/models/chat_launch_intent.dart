import 'toolbox_agent_models.dart';

/// 从工具箱等元素进入 Mirror 主聊天时的启动参数。
class ChatLaunchIntent {
  const ChatLaunchIntent({
    this.forceNewSession = false,
    this.defaultModelCode,
    this.welcomeMessage,
    this.composerPlaceholder,
  });

  final bool forceNewSession;
  final String? defaultModelCode;
  final String? welcomeMessage;
  final String? composerPlaceholder;

  factory ChatLaunchIntent.fromToolbox(ToolboxAgentItem agent) {
    final ui = agent.uiConfig;
    return ChatLaunchIntent(
      forceNewSession: agent.opensMirrorChat && ui.directNewSession,
      defaultModelCode: _trimOrNull(agent.defaultModel),
      welcomeMessage: _trimOrNull(ui.welcomeMessage),
      composerPlaceholder: _trimOrNull(ui.placeholder),
    );
  }

  static String? _trimOrNull(String? value) {
    final t = value?.trim();
    return t == null || t.isEmpty ? null : t;
  }
}
