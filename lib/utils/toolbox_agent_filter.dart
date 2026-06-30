import '../models/toolbox_agent_models.dart';

/// 「我的」工具箱仅展示的智能体（其余数据库条目不展示）。
const kVisibleToolboxAgentCodes = {
  'meeting-minutes',
  'yijing-bazi',
  '12306',
  'kuaidi100',
  'dg-coupon-chat',
};

/// 客户端补全 API 未下发的 UI / 模型配置。
ToolboxAgentItem enrichToolboxAgent(ToolboxAgentItem agent) {
  switch (agent.agentCode) {
    case 'meeting-minutes':
      if (agent.uiConfig.hubScreen == 'meeting') return agent;
      return ToolboxAgentItem(
        agentCode: agent.agentCode,
        displayName: agent.displayName,
        description: agent.description,
        iconKey: agent.iconKey,
        entryType: agent.entryType,
        tokenUsed: agent.tokenUsed,
        invokeCount: agent.invokeCount,
        enabled: agent.enabled,
        disabledReason: agent.disabledReason,
        requiredModel: agent.requiredModel,
        defaultModel: agent.defaultModel,
        capabilities: agent.capabilities,
        uiConfig: const ToolboxUIConfig(hubScreen: 'meeting'),
        parserConfig: agent.parserConfig,
      );
    case 'yijing-bazi':
      if (agent.opensMirrorChat && agent.uiConfig.directNewSession) {
        return agent;
      }
      return ToolboxAgentItem(
        agentCode: agent.agentCode,
        displayName: agent.displayName,
        description: agent.description,
        iconKey: agent.iconKey.isNotEmpty ? agent.iconKey : 'auto_awesome',
        entryType: agent.entryType,
        tokenUsed: agent.tokenUsed,
        invokeCount: agent.invokeCount,
        enabled: agent.enabled,
        disabledReason: agent.disabledReason,
        requiredModel: agent.requiredModel,
        defaultModel: agent.defaultModel.isNotEmpty
            ? agent.defaultModel
            : 'deepseek-v4-flash-none',
        capabilities: agent.capabilities,
        uiConfig: const ToolboxUIConfig(
          hubScreen: 'mirror_chat',
          directNewSession: true,
          placeholder: '例如：1990年5月15日10点半，男',
          welcomeMessage: '你好，我可以帮你排八字、起卦、看运势。请告诉我出生时间，或直接说你的问题。',
        ),
        parserConfig: agent.parserConfig,
      );
    case '12306':
      if (agent.opensMirrorChat && agent.uiConfig.directNewSession) {
        return agent;
      }
      return ToolboxAgentItem(
        agentCode: agent.agentCode,
        displayName: agent.displayName,
        description: agent.description,
        iconKey: agent.iconKey.isNotEmpty ? agent.iconKey : 'train',
        entryType: agent.entryType,
        tokenUsed: agent.tokenUsed,
        invokeCount: agent.invokeCount,
        enabled: agent.enabled,
        disabledReason: agent.disabledReason,
        requiredModel: agent.requiredModel,
        defaultModel: agent.defaultModel.isNotEmpty
            ? agent.defaultModel
            : 'deepseek-v4-flash-none',
        capabilities: agent.capabilities,
        uiConfig: const ToolboxUIConfig(
          hubScreen: 'mirror_chat',
          directNewSession: true,
          placeholder: '例如：后天北京到上海的高铁',
          welcomeMessage: '你好，我可以帮你查火车票、经停站和中转方案。请告诉我出发地、目的地和日期。',
        ),
        parserConfig: agent.parserConfig,
      );
    case 'kuaidi100':
      if (agent.opensMirrorChat && agent.uiConfig.directNewSession) {
        return agent;
      }
      return ToolboxAgentItem(
        agentCode: agent.agentCode,
        displayName: agent.displayName,
        description: agent.description,
        iconKey: agent.iconKey.isNotEmpty ? agent.iconKey : 'local_shipping',
        entryType: agent.entryType,
        tokenUsed: agent.tokenUsed,
        invokeCount: agent.invokeCount,
        enabled: agent.enabled,
        disabledReason: agent.disabledReason,
        requiredModel: agent.requiredModel,
        defaultModel: agent.defaultModel.isNotEmpty
            ? agent.defaultModel
            : 'deepseek-v4-flash-none',
        capabilities: agent.capabilities,
        uiConfig: const ToolboxUIConfig(
          hubScreen: 'mirror_chat',
          directNewSession: true,
          placeholder: '例如：查一下 SF1234567890 到哪了',
          welcomeMessage: '你好，我可以帮你查快递轨迹、估运费和送达时效。请告诉我快递单号，或说明寄件/收件地址。',
        ),
        parserConfig: agent.parserConfig,
      );
    case 'dg-coupon-chat':
      if (agent.opensMirrorChat &&
          agent.uiConfig.directNewSession &&
          agent.displayName == '石化优惠券') {
        return agent;
      }
      return ToolboxAgentItem(
        agentCode: agent.agentCode,
        displayName: '石化优惠券',
        description: agent.description,
        iconKey: agent.iconKey.isNotEmpty ? agent.iconKey : 'local_gas_station',
        entryType: agent.entryType,
        tokenUsed: agent.tokenUsed,
        invokeCount: agent.invokeCount,
        enabled: agent.enabled,
        disabledReason: agent.disabledReason,
        requiredModel: agent.requiredModel,
        defaultModel: agent.defaultModel.isNotEmpty
            ? agent.defaultModel
            : 'deepseek-v4-flash-none',
        capabilities: agent.capabilities,
        uiConfig: const ToolboxUIConfig(
          hubScreen: 'mirror_chat',
          directNewSession: true,
          placeholder: '问问有哪些优惠券、查库存…',
          welcomeMessage: '你好，我可以帮你查石化优惠券、库存和券状态。',
        ),
        parserConfig: agent.parserConfig,
      );
    default:
      return agent;
  }
}

List<ToolboxAgentItem> filterVisibleToolboxAgents(List<ToolboxAgentItem> agents) {
  final out = <ToolboxAgentItem>[];
  for (final code in kVisibleToolboxAgentCodes) {
    for (final agent in agents) {
      if (agent.agentCode == code) {
        out.add(enrichToolboxAgent(agent));
        break;
      }
    }
  }
  return out;
}
