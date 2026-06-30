import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/models/kb_chat_models.dart';
import 'package:mirror_mobile/widgets/kb_assistant_message.dart';

void main() {
  testWidgets('KbAssistantMessage citation tap opens preview callback', (tester) async {
    KbMessageSource? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KbAssistantMessage(
            message: const KbMessage(
              role: 'assistant',
              content: '定义如下[ID:0]',
              sources: [
                KbMessageSource(index: 0, title: 'doc.md', kbId: 1, documentId: 2),
              ],
            ),
            onOpenSource: (s) => tapped = s,
          ),
        ),
      ),
    );

    expect(find.text('[ID:0]'), findsOneWidget);
    await tester.tap(find.text('[ID:0]'));
    await tester.pump();
    expect(tapped?.index, 0);
    expect(tapped?.documentId, 2);
  });
}
