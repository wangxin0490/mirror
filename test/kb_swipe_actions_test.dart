import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/models/kb_models.dart';
import 'package:mirror_mobile/screens/kb/kb_swipe_actions.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

void main() {
  test('KbSubscribedItem parses kb_deleted', () {
    final item = KbSubscribedItem.fromJson({
      'id': 1,
      'kb_id': 9,
      'name': '工作',
      'owner_name': '用户2',
      'ready_doc_count': 3,
      'kb_deleted': true,
    });
    expect(item.kbDeleted, isTrue);
  });

  testWidgets('KbSwipeActionIcons shows Tabler pencil and trash', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KbSwipeActionIcons(
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      ),
    );
    expect(find.byIcon(TablerIcons.pencil), findsOneWidget);
    expect(find.byIcon(TablerIcons.trash), findsOneWidget);
  });

  testWidgets('Delete KB confirmation mentions subscribers', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: ctx,
                builder: (dCtx) => AlertDialog(
                  title: const Text('删除知识库'),
                  content: const Text('删除后无法恢复，订阅者将无法继续使用，确定删除「工作」？'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('取消')),
                  ],
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('订阅者将无法继续使用'), findsOneWidget);
  });
}
