import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/models/chat_models.dart';

void main() {
  test('ChatMessage parses text and image', () {
    final text = ChatMessage.fromJson({
      'id': 1,
      'conversation_id': 10,
      'sender_id': 2,
      'type': 'text',
      'body': 'hello',
      'created_at': '2026-05-28T17:13:55+08:00',
      'is_me': true,
    });
    expect(text.isText, isTrue);
    expect(text.body, 'hello');
    expect(text.isMe, isTrue);

    final image = ChatMessage.fromJson({
      'id': 2,
      'type': 'image',
      'media_url': '/static/feed/a.png',
      'is_me': false,
    });
    expect(image.isImage, isTrue);
    expect(image.mediaUrl, '/static/feed/a.png');
  });

  test('ChatMessageListResponse parses items and has_more', () {
    final res = ChatMessageListResponse.fromJson({
      'items': [
        {'id': 1, 'type': 'text', 'body': 'a', 'is_me': false},
      ],
      'has_more': true,
    });
    expect(res.items, hasLength(1));
    expect(res.hasMore, isTrue);
  });
}
