import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/models/kb_chat_models.dart';
import 'package:mirror_mobile/widgets/kb_assistant_message.dart';

void main() {
  testWidgets('KbAssistantMessage opens draggable source sheet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KbAssistantMessage(
            message: KbMessage(
              role: 'assistant',
              content: '答案内容',
              sources: const [
                KbMessageSource(index: 0, title: '2.md', kbId: 1, documentId: 2, snippet: '名词与角色'),
                KbMessageSource(index: 1, title: '2.md', kbId: 1, documentId: 2, snippet: '拼单活动'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('引用 1 篇资料作为参考'), findsOneWidget);
    await tester.tap(find.textContaining('引用 1 篇资料作为参考'));
    await tester.pumpAndSettle();

    expect(find.text('引用来源'), findsOneWidget);
    expect(find.textContaining('1. 2.md'), findsOneWidget);
    expect(find.text('Markdown'), findsOneWidget);
  });
}
