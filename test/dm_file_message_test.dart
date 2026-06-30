import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/models/chat_models.dart';
import 'package:mirror_mobile/utils/dm_file_message.dart';

void main() {
  test('parseDmFileMessage parses clip filename and url', () {
    const body = '📎 report.pdf\nhttps://docs.example.com/public/feed/14_abc.pdf';
    final parsed = parseDmFileMessage(body);
    expect(parsed, isNotNull);
    expect(parsed!.filename, 'report.pdf');
    expect(parsed.url, 'https://docs.example.com/public/feed/14_abc.pdf');
  });

  test('parseDmFileMessage returns null for plain text', () {
    expect(parseDmFileMessage('hello'), isNull);
    expect(parseDmFileMessage('📎 only-name'), isNull);
  });

  test('fileMessageFromChat reads image type with pdf media_url as file', () {
    final msg = ChatMessage.fromJson({
      'id': 66,
      'conversation_id': 19,
      'sender_id': 14,
      'type': 'image',
      'body': 'report.pdf',
      'media_url': 'https://docs.example.com/public/feed/14_abc.pdf',
      'is_me': true,
    });
    final file = fileMessageFromChat(msg);
    expect(file, isNotNull);
    expect(file!.filename, 'report.pdf');
    expect(file.url, 'https://docs.example.com/public/feed/14_abc.pdf');
    expect(dmMessagePreview(msg), 'report.pdf');
  });

  test('fileMessageFromChat keeps real image messages as non-file', () {
    final msg = ChatMessage.fromJson({
      'id': 2,
      'type': 'image',
      'body': '',
      'media_url': 'https://docs.example.com/public/feed/14_photo.png',
    });
    expect(fileMessageFromChat(msg), isNull);
    expect(dmMessagePreview(msg), '[图片]');
  });

  test('sanitizeConversationPreview strips image tag for file names', () {
    expect(
      sanitizeConversationPreview('[图片] report.pdf'),
      'report.pdf',
    );
    expect(
      sanitizeConversationPreview('[图片] HT260512154801784669_17785720827'),
      'HT260512154801784669_17785720827',
    );
    expect(sanitizeConversationPreview('[图片]'), '[图片]');
    expect(sanitizeConversationPreview('[图片] photo.png'), '[图片] photo.png');
    expect(sanitizeConversationPreview('你好'), '你好');
  });

  test('normalizeConversationPreview formats feed post share', () {
    expect(
      normalizeConversationPreview(
        '[[mirror:feed_post]]{"post_id":70,"title":"你好","author_name":"测试"}',
      ),
      '[文章] 你好',
    );
    expect(
      normalizeConversationPreview(
        '[[mirror:feed_post]]{"post_id":70,"title":"你好",',
      ),
      '[文章] 你好',
    );
    expect(
      normalizeConversationPreview(
        '[[mirror:feed_post]]{"post_id":2,"title":"让你的 ...',
      ),
      '[文章] 让你的',
    );
  });

  test('dmMessagePreview formats truncated feed post body', () {
    final msg = ChatMessage.fromJson({
      'id': 1,
      'type': 'text',
      'body': '[[mirror:feed_post]]{"post_id":2,"title":"让你的 ...',
    });
    expect(dmMessagePreview(msg), '[文章] 让你的');
  });

  test('resolveConversationPreview prefers last_message fields', () {
    expect(
      resolveConversationPreview(
        apiPreview: '[图片] wrong.pdf',
        lastMessage: {
          'type': 'image',
          'body': 'report.pdf',
          'media_url': 'https://docs.example.com/public/feed/14_abc.pdf',
        },
      ),
      'report.pdf',
    );
  });

  test('fileMessageFromChat falls back to legacy body format', () {
    final msg = ChatMessage.fromJson({
      'id': 1,
      'type': 'text',
      'body': '📎 old.pdf\nhttps://docs.example.com/public/feed/old.pdf',
    });
    final file = fileMessageFromChat(msg);
    expect(file?.filename, 'old.pdf');
    expect(file?.url, 'https://docs.example.com/public/feed/old.pdf');
  });
}
