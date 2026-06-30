import '../models/agent_models.dart';

/// 默认 Hermes relay 模型名（与 new-api 配置一致）。
const kHermesAgentModelCode = 'hermes-agent';

/// model_code 以 hermes 为前缀即视为 Hermes 模型。
bool isHermesAgentModel(String? modelCode) {
  final c = modelCode?.trim().toLowerCase() ?? '';
  return c.startsWith('hermes');
}

bool isHermesAgentItem(AgentModelItem? item) {
  if (item == null) return false;
  if (isHermesAgentModel(item.modelCode)) return true;
  final dn = item.displayName.trim().toLowerCase();
  return dn.startsWith('hermes');
}

/// model_code / display_name 命中即视为 GLM 模型（Agent 聊天列表中隐藏）。
bool isGlmAgentModel(String? modelCode) {
  final c = modelCode?.trim().toLowerCase() ?? '';
  if (c.isEmpty) return false;
  return c.startsWith('glm') || c.contains('/glm') || c.contains('-glm');
}

bool isGlmAgentItem(AgentModelItem? item) {
  if (item == null) return false;
  if (isGlmAgentModel(item.modelCode)) return true;
  final dn = item.displayName.trim().toLowerCase();
  return dn.contains('glm');
}

/// Agent 聊天模型选择器可见列表（排除 GLM）。
List<AgentModelItem> filterAgentChatModels(List<AgentModelItem> models) =>
    models.where((m) => !isGlmAgentItem(m)).toList(growable: false);
