import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/models/chat_attachment.dart';
import 'package:mirror_mobile/services/picked_file_bytes.dart';
import 'package:mirror_mobile/services/picked_image_bytes.dart';
import 'package:mirror_mobile/widgets/chat_message_attachments.dart';

void main() {
  group('picker result models', () {
    test('PickedImageBytes stores name and bytes', () {
      final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF]);
      final picked = PickedImageBytes(name: 'photo.jpg', bytes: bytes);
      expect(picked.name, 'photo.jpg');
      expect(picked.bytes, same(bytes));
    });

    test('PickedFileBytes stores name and bytes', () {
      const picked = PickedFileBytes(name: 'notes.txt', bytes: [72, 101, 108, 108, 111]);
      expect(picked.name, 'notes.txt');
      expect(picked.bytes, [72, 101, 108, 108, 111]);
    });
  });

  group('ChatAttachment from picker upload payload', () {
    test('image attachment round-trips JSON', () {
      const att = ChatAttachment(
        type: 'image',
        url: 'public/feed/u1/abc.jpg',
        filename: 'photo.jpg',
        mime: 'image/jpeg',
        size: 1024,
      );
      final restored = ChatAttachment.fromJson(att.toJson());
      expect(restored.type, 'image');
      expect(restored.url, att.url);
      expect(restored.filename, 'photo.jpg');
      expect(attachmentIsImage(restored), isTrue);
    });

    test('document attachment is not treated as image', () {
      const att = ChatAttachment(
        type: 'document',
        url: 'public/feed/u1/notes.txt',
        filename: 'notes.txt',
        mime: 'text/plain',
      );
      expect(attachmentIsImage(att), isFalse);
    });
  });
}
