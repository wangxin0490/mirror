import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/layout/adaptive_layout.dart';
import 'package:mirror_mobile/models/chat_attachment.dart';
import 'package:mirror_mobile/widgets/chat_message_attachments.dart';

void main() {
  testWidgets('ChatMessageAttachments shows document filename', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatMessageAttachments(
            attachments: [
              ChatAttachment(
                type: 'document',
                url: 'public/feed/u1/notes.txt',
                filename: 'notes.txt',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('notes.txt'), findsOneWidget);
    expect(find.byIcon(Icons.notes_outlined), findsOneWidget);
  });

  testWidgets('ChatMessageAttachments renders image thumb region', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatMessageAttachments(
            attachments: [
              ChatAttachment(
                type: 'image',
                url: 'https://example.com/a.jpg',
                filename: 'a.jpg',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(ChatMessageAttachments), findsOneWidget);
    expect(find.text('a.jpg'), findsNothing);
  });

  testWidgets('image thumb scales on tablet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1024, 768)),
          child: const Scaffold(
            body: ChatMessageAttachments(
              attachments: [
                ChatAttachment(
                  type: 'image',
                  url: 'https://example.com/a.jpg',
                  filename: 'a.jpg',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final box = tester.getSize(
      find.descendant(
        of: find.byType(ChatMessageAttachments),
        matching: find.byType(ConstrainedBox),
      ),
    );
    expect(box.width, kChatImageMaxSize);
  });

  testWidgets('document chip opens preview sheet on tap', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageAttachments(
            attachments: const [
              ChatAttachment(
                type: 'document',
                url: 'https://example.com/notes.md',
                filename: 'notes.md',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('notes.md'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('notes.md'), findsWidgets);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('KbMessage-style user bubble shows attachment and text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.all(12),
              color: Colors.black87,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const ChatMessageAttachments(
                    attachments: [
                      ChatAttachment(type: 'image', url: 'https://example.com/x.png', filename: 'x.png'),
                    ],
                    onDarkBackground: true,
                  ),
                  const SizedBox(height: 8),
                  const Text('请分析这张图', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('请分析这张图'), findsOneWidget);
  });
}
