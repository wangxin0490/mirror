import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/utils/mixed_markup.dart';
import 'package:mirror_mobile/widgets/mirror_markdown_body.dart';

void main() {
  test('normalizeMixedMarkup converts html tables to markdown', () {
    const html = '''
# 名词与角色
<table>
<thead><tr><th>名词</th><th>含义（依据系统约定）</th></tr></thead>
<tbody><tr><td><strong>拼单活动</strong></td><td>多人一起下单</td></tr></tbody>
</table>
''';

    final normalized = normalizeMixedMarkup(html);

    expect(normalized, contains('# 名词与角色'));
    expect(normalized, contains('| 名词 | 含义（依据系统约定） |'));
    expect(normalized, contains('| **拼单活动** | 多人一起下单 |'));
    expect(normalized, isNot(contains('<table>')));
  });

  testWidgets('MirrorMarkdownBody renders html tables in markdown files', (tester) async {
    const source = '''
# 名词与角色
<table>
<thead><tr><th>名词</th><th>含义</th></tr></thead>
<tbody><tr><td><strong>Agent</strong></td><td>智能体</td></tr></tbody>
</table>
''';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MirrorMarkdownBody(source: source),
          ),
        ),
      ),
    );

    expect(find.text('名词与角色'), findsOneWidget);
    expect(find.textContaining('Agent'), findsWidgets);
    expect(find.text('智能体'), findsOneWidget);
    expect(find.textContaining('<table>'), findsNothing);
    expect(find.textContaining('<strong>'), findsNothing);
  });
}
