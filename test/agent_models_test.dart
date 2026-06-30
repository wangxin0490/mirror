import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/models/agent_models.dart';

void main() {
  test('AgentConversationSummary parses list fields', () {
    final item = AgentConversationSummary.fromJson({
      'conversation_id': 12,
      'title': '武汉天气',
      'model_code': 'gpt-4o',
      'last_message_at': '2026-05-28T10:00:00Z',
      'created_at': '2026-05-27T08:00:00Z',
    });
    expect(item.conversationId, 12);
    expect(item.displayTitle, '武汉天气');
    expect(item.modelCode, 'gpt-4o');
    expect(item.lastMessageAt, isNotNull);
  });

  test('AgentConversationList parses items', () {
    final list = AgentConversationList.fromJson({
      'items': [
        {'conversation_id': 1, 'title': '', 'model_code': 'm1', 'created_at': '2026-05-28T10:00:00Z'},
      ],
      'has_more': false,
    });
    expect(list.items.length, 1);
    expect(list.items.first.displayTitle, '新对话');
  });

  test('AgentMessage parses sources', () {
    final msg = AgentMessage.fromJson({
      'id': 9,
      'role': 'assistant',
      'content': '武汉今日多云[1]',
      'sources': [
        {'index': 1, 'title': '武汉天气', 'url': 'https://example.com/w', 'snippet': '摘要'},
      ],
    });
    expect(msg.sources.length, 1);
    expect(msg.sources.first.hasUrl, isTrue);
    expect(msg.sources.first.title, '武汉天气');
  });

  test('AgentToolEvent parses sources', () {
    final tool = AgentToolEvent.fromJson({
      'name': 'web.search',
      'phase': 'done',
      'source_count': 1,
      'sources': [
        {'index': 1, 'title': '新闻', 'url': 'https://example.com/a'},
      ],
    });
    expect(tool.sources.length, 1);
    expect(tool.sourceCount, 1);
  });

  test('AgentStreamDone parses sources', () {
    final done = AgentStreamDone.fromJson({
      'message_id': 3,
      'tokens_in': 1,
      'tokens_out': 2,
      'access_mode': 'trial',
      'sources': [
        {'index': 1, 'title': '资料', 'url': 'https://example.com'},
      ],
    });
    expect(done.sources.single.url, 'https://example.com');
  });

  test('AgentStreamDone parses final content', () {
    final done = AgentStreamDone.fromJson({
      'message_id': 4,
      'tokens_in': 1,
      'tokens_out': 2,
      'access_mode': 'trial',
      'content': '[report.xlsx](/api/v1/agent/hermes-files/9/report.xlsx)',
    });
    expect(done.content, '[report.xlsx](/api/v1/agent/hermes-files/9/report.xlsx)');
  });
}
