import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/models/post_blocks_codec.dart';
import 'package:mirror_mobile/screens/post_detail_data.dart';

void main() {
  test('encode and parse stats + callout blocks', () {
    final blocks = [
      const PostBodyBlock.paragraph('我们组每月要交 50 篇内部周报。'),
      const PostBodyBlock.stats([
        (v: '92', k: 'CLAUDE'),
        (v: '87', k: 'GPT-4o'),
        (v: '24×', k: 'ROI'),
      ]),
      const PostBodyBlock.callout(
        icon: Icons.check,
        variant: CalloutVariant.green,
        body: '简单结论',
      ),
    ];
    final body = PostBlocksCodec.encode(blocks, markdownTail: '![](/static/a.png)');
    expect(body, contains(PostBlocksCodec.openTag));
    expect(body, contains('"type":"stats"'));

    final parsed = PostBlocksCodec.parse(body);
    expect(parsed.blocks, hasLength(3));
    expect(parsed.blocks[1].type, PostBodyBlockType.stats);
    expect(parsed.blocks[2].callout?.body, '简单结论');
    expect(parsed.markdownTail, contains('![](/static/a.png)'));
  });

  test('plain body without fence returns markdown tail only', () {
    final parsed = PostBlocksCodec.parse('hello world');
    expect(parsed.blocks, isEmpty);
    expect(parsed.markdownTail, 'hello world');
  });
}
