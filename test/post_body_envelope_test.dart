import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/models/personal_kb.dart';
import 'package:mirror_mobile/models/post_body_envelope.dart';
import 'package:mirror_mobile/models/post_blocks_codec.dart';
import 'package:mirror_mobile/screens/post_detail_data.dart';

void main() {
  test('envelope encodes shared kb and blocks', () {
    final body = PostBodyEnvelopeCodec.encode(
      sharedKb: const SharedKbAttachment(kbId: 'work', name: '工作'),
      blocks: const [
        PostBodyBlock.stats([(v: '92', k: 'A')]),
      ],
      markdownTail: '![](/a.png)',
    );
    expect(body, contains('mirror:shared_kb'));
    expect(body, contains('mirror:blocks'));

    final parsed = PostBodyEnvelopeCodec.parse(body);
    expect(parsed.sharedKb?.kbId, 'work');
    expect(parsed.blocks, hasLength(1));
    expect(parsed.markdownTail, contains('/a.png'));
  });

  test('envelope encodes cover gallery urls', () {
    final body = PostBodyEnvelopeCodec.encode(
      coverImageUrls: const ['/c1.png', '/c2.png'],
      blocks: const [PostBodyBlock.paragraph('hi')],
    );
    expect(body, contains('mirror:cover_gallery'));
    final parsed = PostBodyEnvelopeCodec.parse(body);
    expect(parsed.coverImageUrls, ['/c1.png', '/c2.png']);
  });

  test('envelope parses ready_doc_count on shared kb', () {
    final body = PostBodyEnvelopeCodec.encode(
      sharedKb: const SharedKbAttachment(kbId: '12', name: '工作', readyDocCount: 5),
      blocks: const [PostBodyBlock.paragraph('x')],
    );
    expect(PostBodyEnvelopeCodec.parse(body).sharedKb?.readyDocCount, 5);
  });

  test('kb id from cover label', () {
    expect(PostBodyEnvelopeCodec.parse('').sharedKb, isNull);
    final legacy = PostBodyEnvelopeCodec.parse('> 分享知识库：工作\n\nhello');
    expect(legacy.sharedKb?.name, '工作');
  });
}
