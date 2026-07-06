import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/models/pending_chat_attachment.dart';
import 'package:mirror_mobile/widgets/agent_chat_composer.dart';
import 'package:mirror_mobile/widgets/chat_composer_attachment_strip.dart';
import 'package:mirror_mobile/widgets/compose_image_thumb.dart';

void main() {
  testWidgets('ChatComposerAttachmentStrip shows image and file with remove', (tester) async {
    final slots = ComposerAttachmentSlots(
      image: PendingChatAttachment(
        name: 'a.jpg',
        bytes: Uint8List.fromList([0xFF, 0xD8]),
        isImage: true,
      ),
      document: PendingChatAttachment(
        name: 'notes.md',
        bytes: Uint8List.fromList([35, 32, 116]),
        isImage: false,
      ),
    );
    var removedImage = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatComposerAttachmentStrip(
            slots: slots,
            onRemoveImage: () => removedImage = true,
          ),
        ),
      ),
    );

    expect(find.text('notes.md'), findsOneWidget);
    expect(find.byType(ComposeImageThumb), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close).first);
    expect(removedImage, isTrue);
  });

  testWidgets('AgentChatComposer canSend with pending only (no text)', (tester) async {
    final ctrl = TextEditingController();
    final slots = ComposerAttachmentSlots(
      image: PendingChatAttachment(
        name: 'a.png',
        bytes: Uint8List(1),
        isImage: true,
      ),
    );
    var sent = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgentChatComposer(
            controller: ctrl,
            enabled: true,
            canSend: slots.hasPending,
            modelLabel: 'gpt-4o',
            webSearchEnabled: false,
            previewMode: false,
            pendingSlots: slots,
            onSend: () => sent = true,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('chat-send-btn')), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat-send-btn')));
    expect(sent, isTrue);
  });

  testWidgets('AgentChatComposer toolbar adapts to narrow width with long model label', (tester) async {
    final ctrl = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(320, 640)),
          child: Scaffold(
            body: AgentChatComposer(
              controller: ctrl,
              enabled: true,
              canSend: false,
              modelLabel: 'deepseek-v4-flash-none-extra-long-name',
              webSearchEnabled: true,
              previewMode: false,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('chat-model-picker')), findsOneWidget);
    expect(find.byKey(const Key('chat-web-search-toggle')), findsOneWidget);
    expect(find.byKey(const Key('chat-more-btn')), findsOneWidget);
    expect(find.byKey(const Key('chat-send-btn')), findsOneWidget);
    expect(find.text('联网'), findsOneWidget);
  });

  test('ComposerAttachmentSlots hasPending when staged', () {
    final slots = ComposerAttachmentSlots();
    expect(slots.hasPending, isFalse);
    slots.image = PendingChatAttachment(
      name: 'x.png',
      bytes: Uint8List(0),
      isImage: true,
    );
    expect(slots.hasPending, isTrue);
    expect(slots.ordered, hasLength(1));
  });
}
