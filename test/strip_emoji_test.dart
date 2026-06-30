import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/utils/strip_emoji.dart';
import 'package:mirror_mobile/widgets/chat_markdown_body.dart';

void main() {
  test('stripEmoji removes common model emoji markers', () {
    const raw = '📋 目前共有 2 款\n- ✅ **面值**：3 元\n## 📌 说明';
    final out = stripEmoji(raw);
    expect(out, isNot(contains('📋')));
    expect(out, isNot(contains('✅')));
    expect(out, isNot(contains('📌')));
    expect(out, contains('目前共有 2 款'));
    expect(out, contains('**面值**'));
    expect(out, contains('##  说明'));
  });

  test('ChatMarkdownBody.preprocessEmoji is wired', () {
    expect(
      ChatMarkdownBody.preprocessEmoji('📊 库存充足'),
      ' 库存充足',
    );
  });

  test('stripEmoji normalizes arrow glyphs for train schedules', () {
    expect(
      stripEmoji('武汉站 → 上海虹桥站'),
      '武汉站 至 上海虹桥站',
    );
    expect(
      stripEmoji('07:55 → 11:31'),
      '07:55-11:31',
    );
    expect(
      stripEmoji('G458 ➡ 推荐'),
      'G458 至 推荐',
    );
  });
}
