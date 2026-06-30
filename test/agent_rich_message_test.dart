import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/models/agent_models.dart';
import 'package:mirror_mobile/widgets/agent_rich_message.dart';

void main() {
  testWidgets('AgentAssistantMessage shows citation summary', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgentAssistantMessage(
            message: AgentMessage(
              id: 1,
              role: 'assistant',
              content: '武汉雨天适合逛博物馆[1]',
              sources: const [
                AgentMessageSource(index: 1, title: '武汉室内活动', url: 'https://example.com/a'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('引用 1 篇资料作为参考'), findsOneWidget);
    expect(find.textContaining('武汉雨天适合逛博物馆'), findsOneWidget);
    expect(find.byIcon(Icons.content_copy_outlined), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    await tester.tap(find.textContaining('引用 1 篇资料作为参考'));
    await tester.pumpAndSettle();

    expect(find.text('引用来源'), findsOneWidget);
    expect(find.textContaining('1. 武汉室内活动'), findsOneWidget);
  });

  testWidgets('AgentAssistantMessage renders [ID:N] citation marker', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgentAssistantMessage(
            message: AgentMessage(
              id: 1,
              role: 'assistant',
              content: '参考说明[ID:0]',
              sources: const [
                AgentMessageSource(index: 0, title: '参考页', url: 'https://example.com/ref'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('[ID:0]'), findsOneWidget);
  });

  testWidgets('AgentAssistantMessage renders dg-coupon product cards', (tester) async {
    const source = '''
以下是可用优惠券：

```dg-coupon
{"type":"product_list","items":[{"product_no":"P001","name":"测试券","face_value":"10元"}]}
```
''';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgentAssistantMessage(
            message: AgentMessage(
              id: 1,
              role: 'assistant',
              content: source,
            ),
            onDgCouponQueryStock: (_) {},
            onCopyFeedback: () {},
          ),
        ),
      ),
    );

    expect(find.text('测试券'), findsOneWidget);
    expect(find.text('P001 · 10元'), findsOneWidget);
    expect(find.text('查库存'), findsOneWidget);
    expect(find.text('复制产品码'), findsOneWidget);
    expect(find.textContaining('```dg-coupon'), findsNothing);
  });
}
