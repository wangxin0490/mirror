import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/widgets/ai_generated_content_label.dart';
import 'package:mirror_mobile/widgets/chat_markdown_body.dart';

void main() {
  test('text label contains required AI and generation elements', () {
    expect(AiGeneratedLabel.textLabel, contains('AI'));
    expect(AiGeneratedLabel.textLabel, contains('生成'));
    expect(AiGeneratedLabel.superscriptLabel, 'AI');
  });

  testWidgets('AiGeneratedContentFrame shows suffix label after content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AiGeneratedContentFrame(
            child: Text('示例正文'),
          ),
        ),
      ),
    );

    expect(find.text('示例正文'), findsOneWidget);
    expect(find.text(AiGeneratedLabel.textLabel), findsOneWidget);
  });

  testWidgets('ChatMarkdownBody can append AI generated label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatMarkdownBody(
            source: '你好，世界。',
            showAiGeneratedLabel: true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text(AiGeneratedLabel.textLabel), findsOneWidget);
  });

  testWidgets('ChatMarkdownBody hides label while streaming content is empty', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatMarkdownBody(
            source: '',
            showAiGeneratedLabel: true,
          ),
        ),
      ),
    );

    expect(find.text(AiGeneratedLabel.textLabel), findsNothing);
  });
}
