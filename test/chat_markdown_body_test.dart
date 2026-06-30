import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/widgets/chat_empty_hint_card.dart';
import 'package:mirror_mobile/widgets/chat_markdown_body.dart';

void main() {
  test('preprocessAutolinks wraps bare http and hermes-files paths', () {
    const raw = '下载 http://115.159.46.108:8010/v1/files/1/a.xlsx 或 /api/v1/agent/hermes-files/2/a.xlsx';
    final out = ChatMarkdownBody.preprocessAutolinks(raw);
    expect(out, contains('[a.xlsx](http://115.159.46.108:8010/v1/files/1/a.xlsx)'));
    expect(out, contains('[a.xlsx](/api/v1/agent/hermes-files/2/a.xlsx)'));
  });

  test('preprocessCitations converts ID and numeric markers', () {
    const raw = '结论 [ID:1] 与 [2] 结束';
    final out = ChatMarkdownBody.preprocessCitations(raw);
    expect(out, contains('[ID:1](mirror-citation://1)'));
    expect(out, contains('[2](mirror-citation://2)'));
  });

  test('isKbEmptyHintContent detects empty template', () {
    expect(
      ChatEmptyHintCard.isKbEmptyHintContent('未在知识库中检索到与问题相关的内容。'),
      isTrue,
    );
    expect(ChatEmptyHintCard.isKbEmptyHintContent('**保修 12 个月**'), isFalse);
  });

  test('preprocessAutolinks tolerates illegal percent in hermes path', () {
    const raw = '见 /api/v1/agent/hermes-files/3/report%bad.md';
    expect(() => ChatMarkdownBody.preprocessAutolinks(raw), returnsNormally);
    final out = ChatMarkdownBody.preprocessAutolinks(raw);
    expect(out, contains('hermes-files/3'));
  });

  testWidgets('ChatMarkdownBody renders hermes link without throwing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMarkdownBody(
            source: '[报告.md](/api/v1/agent/hermes-files/9/report%20(1).md?download=1)',
            onLinkTap: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('报告'), findsWidgets);
  });

  testWidgets('ChatMarkdownBody renders heading', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatMarkdownBody(source: '## 标题\n\n- 列表项'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('标题'), findsOneWidget);
    expect(find.text('列表项'), findsOneWidget);
  });

  testWidgets('ChatEmptyHintCard shows message', (tester) async {
    const msg = '未在知识库中检索到与问题相关的内容。';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ChatEmptyHintCard(message: msg)),
      ),
    );
    expect(find.text(msg), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
  });
}
