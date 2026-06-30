import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/models/agent_models.dart';
import 'package:mirror_mobile/utils/agent_chat_copy.dart';

void main() {
  test('formatAgentConversationMarkdown skips streaming messages', () {
    final md = formatAgentConversationMarkdown(
      title: '武汉天气',
      messages: const [
        AgentMessage(id: 1, role: 'user', content: '今天天气？'),
        AgentMessage(id: 2, role: 'assistant', content: '多云。', streaming: true),
        AgentMessage(id: 3, role: 'assistant', content: '18–26℃。'),
      ],
    );

    expect(md, contains('# 武汉天气'));
    expect(md, contains('**用户**'));
    expect(md, contains('今天天气？'));
    expect(md, contains('18–26℃。'));
    expect(md, isNot(contains('多云。')));
  });

  test('formatAgentMessageForCopy trims content', () {
    const msg = AgentMessage(id: 1, role: 'user', content: '  hello  ');
    expect(formatAgentMessageForCopy(msg), 'hello');
  });
}
