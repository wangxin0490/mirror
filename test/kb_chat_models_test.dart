import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/models/chat_attachment.dart';
import 'package:mirror_mobile/models/kb_chat_models.dart';

void main() {
  test('groupKbMessageSources deduplicates by document id', () {
    const sources = [
      KbMessageSource(index: 0, title: '2.md', kbId: 1, documentId: 22),
      KbMessageSource(index: 1, title: '2.md', kbId: 1, documentId: 22),
      KbMessageSource(index: 2, title: '2.md', kbId: 1, documentId: 22),
      KbMessageSource(index: 3, title: 'notes.txt', kbId: 1, documentId: 33),
    ];

    final groups = groupKbMessageSources(sources);

    expect(groups.length, 2);
    expect(groups[0].primary.title, '2.md');
    expect(groups[0].indices, [0, 1, 2]);
    expect(groups[0].idLabel, 'ID:0–2');
    expect(groups[1].primary.title, 'notes.txt');
    expect(groups[1].idLabel, 'ID:3');
  });

  test('groupKbMessageSources falls back to ragflow document id', () {
    const sources = [
      KbMessageSource(index: 0, title: 'A.md', ragflowDocumentId: 'rf-1'),
      KbMessageSource(index: 1, title: 'A.md', ragflowDocumentId: 'rf-1'),
      KbMessageSource(index: 2, title: 'B.md', ragflowDocumentId: 'rf-2'),
    ];

    final groups = groupKbMessageSources(sources);

    expect(groups.length, 2);
    expect(groups[0].indices, [0, 1]);
    expect(groups[1].indices, [2]);
  });

  test('KbMessage holds attachments', () {
    const msg = KbMessage(
      role: 'user',
      content: '看图',
      attachments: [
        ChatAttachment(type: 'image', url: 'public/feed/a.jpg', filename: 'a.jpg'),
      ],
    );
    expect(msg.attachments, hasLength(1));
    expect(msg.attachments.first.filename, 'a.jpg');
    final copy = msg.copyWith(content: '更新');
    expect(copy.attachments, msg.attachments);
  });
}
