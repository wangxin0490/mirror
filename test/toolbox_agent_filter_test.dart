import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/models/toolbox_agent_models.dart';
import 'package:mirror_mobile/utils/toolbox_agent_filter.dart';

void main() {
  test('filterVisibleToolboxAgents keeps meeting-minutes, yijing-bazi, 12306, kuaidi100, dg-coupon-chat', () {
    const agents = [
      ToolboxAgentItem(
        agentCode: 'smart-assistant',
        displayName: '智能助手',
        description: '',
        iconKey: 'smart_toy',
        entryType: 'chat',
        tokenUsed: 0,
        invokeCount: 0,
      ),
      ToolboxAgentItem(
        agentCode: 'meeting-minutes',
        displayName: '会议纪要助手',
        description: '',
        iconKey: 'mic',
        entryType: 'workflow',
        tokenUsed: 0,
        invokeCount: 0,
      ),
      ToolboxAgentItem(
        agentCode: 'yijing-bazi',
        displayName: '易经八字',
        description: '',
        iconKey: 'auto_awesome',
        entryType: 'chat',
        tokenUsed: 0,
        invokeCount: 0,
      ),
      ToolboxAgentItem(
        agentCode: '12306',
        displayName: '12306 查票',
        description: '',
        iconKey: 'train',
        entryType: 'chat',
        tokenUsed: 0,
        invokeCount: 0,
      ),
      ToolboxAgentItem(
        agentCode: 'kuaidi100',
        displayName: '快递100',
        description: '',
        iconKey: 'local_shipping',
        entryType: 'chat',
        tokenUsed: 0,
        invokeCount: 0,
      ),
      ToolboxAgentItem(
        agentCode: 'weekly-report',
        displayName: '周报生成',
        description: '',
        iconKey: 'description',
        entryType: 'workflow',
        tokenUsed: 0,
        invokeCount: 0,
      ),
      ToolboxAgentItem(
        agentCode: 'dg-coupon',
        displayName: '石化优惠券',
        description: '',
        iconKey: 'local_gas_station',
        entryType: 'chat',
        tokenUsed: 131,
        invokeCount: 1,
      ),
      ToolboxAgentItem(
        agentCode: 'dg-coupon-chat',
        displayName: '主聊天 · 石化券',
        description: '',
        iconKey: 'local_gas_station',
        entryType: 'chat',
        tokenUsed: 0,
        invokeCount: 0,
      ),
    ];

    final filtered = filterVisibleToolboxAgents(agents);

    expect(filtered, hasLength(5));
    expect(filtered.map((a) => a.agentCode).toList(), [
      'meeting-minutes',
      'yijing-bazi',
      '12306',
      'kuaidi100',
      'dg-coupon-chat',
    ]);
    expect(filtered.first.uiConfig.hubScreen, 'meeting');
    expect(filtered[1].opensMirrorChat, isTrue);
    expect(filtered[1].uiConfig.directNewSession, isTrue);
    expect(filtered[2].opensMirrorChat, isTrue);
    expect(filtered[2].uiConfig.directNewSession, isTrue);
    expect(filtered[2].defaultModel, 'deepseek-v4-flash-none');
    expect(filtered[3].opensMirrorChat, isTrue);
    expect(filtered[3].uiConfig.directNewSession, isTrue);
    expect(filtered[3].defaultModel, 'deepseek-v4-flash-none');
    expect(filtered[3].uiConfig.placeholder, contains('SF1234567890'));
    expect(filtered[4].displayName, '石化优惠券');
    expect(filtered[4].opensMirrorChat, isTrue);
    expect(filtered[4].uiConfig.directNewSession, isTrue);
    expect(filtered[4].defaultModel, 'deepseek-v4-flash-none');
  });
}
