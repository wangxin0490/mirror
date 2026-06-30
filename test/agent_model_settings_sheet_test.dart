import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/screens/mirror_screens.dart';

void main() {
  testWidgets('Chat model picker sheet switches model', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ChatScreen(previewMode: true))));

    expect(find.text('claude-4'), findsOneWidget);

    await tester.tap(find.byKey(const Key('chat-model-picker')));
    await tester.pumpAndSettle();

    expect(find.text('选择模型'), findsOneWidget);
    expect(find.text('联网搜索'), findsNothing);
    expect(find.text('模型设置'), findsNothing);

    await tester.tap(find.byKey(const Key('agent-model-tile-gpt-4o')));
    await tester.pumpAndSettle();

    expect(find.text('gpt-4o'), findsWidgets);
  });

  testWidgets('AgentChatComposer keeps web search toggle', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ChatScreen(previewMode: true))));

    expect(find.byKey(const Key('chat-model-picker')), findsOneWidget);
    expect(find.byKey(const Key('chat-web-search-toggle')), findsOneWidget);
    expect(find.byKey(const Key('chat-more-btn')), findsOneWidget);
    expect(find.text('联网'), findsOneWidget);
  });

  testWidgets('Session history groups conversations by date', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ChatScreen(previewMode: true))));

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    expect(find.text('今天'), findsOneWidget);
    expect(find.text('昨天'), findsOneWidget);
    expect(find.text('周报提纲'), findsOneWidget);
    expect(find.text('武汉天气'), findsWidgets);
  });
}
