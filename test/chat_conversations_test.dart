import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/models/chat_models.dart';

void main() {
  test('ChatConversationItem parses flat and nested peer', () {
    final flat = ChatConversationItem.fromJson({
      'conversation_id': 3,
      'peer_user_id': 14,
      'display_name': '林岸',
      'handle': 'linan',
      'avatar_letter': '林',
      'avatar_variant': 'pink',
      'preview': '你好',
      'time_label': '13:20',
      'unread_count': 1,
    });
    expect(flat.threadKey, 'linan');
    expect(flat.unread, isTrue);

    final nested = ChatConversationItem.fromJson({
      'id': 5,
      'peer': {
        'user_id': 2,
        'display_name': '陈墨',
        'handle': 'chenmo',
        'avatar_letter': '陈',
        'avatar_variant': 'accent',
      },
      'last_message': {'preview': 'sync', 'at_me': true},
      'time': '昨天',
    });
    expect(nested.threadKey, 'chenmo');
    expect(nested.atMe, isTrue);
    expect(nested.preview, 'sync');
  });

  test('ChatConversationItem formats feed post preview', () {
    final item = ChatConversationItem.fromJson({
      'conversation_id': 3,
      'preview':
          '[[mirror:feed_post]]{"post_id":70,"title":"你好","author_name":"测试"}',
      'time_label': '11:30',
    });
    expect(item.preview, '[文章] 你好');
  });

  test('ChatConversationItem strips [图片] for non-image file preview', () {
    final item = ChatConversationItem.fromJson({
      'conversation_id': 19,
      'preview': '[图片] HT260512154801784669_17785720827',
      'time_label': '10:51',
    });
    expect(item.preview, 'HT260512154801784669_17785720827');
  });
}
