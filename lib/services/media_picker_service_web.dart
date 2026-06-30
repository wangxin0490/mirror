import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'picked_image_bytes.dart';

Future<List<PickedImageBytes>> pickFromCamera() async {
  final completer = Completer<List<PickedImageBytes>>();
  final input = html.FileUploadInputElement()..accept = 'image/*';
  input.setAttribute('capture', 'environment');
  input.onChange.listen((_) async {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete([]);
      return;
    }
    final file = files.first;
    final bytes = await _readAsBytes(file);
    if (bytes == null || bytes.isEmpty) {
      completer.complete([]);
      return;
    }
    completer.complete([
      PickedImageBytes(name: file.name.isNotEmpty ? file.name : 'photo.jpg', bytes: bytes),
    ]);
  });
  input.click();
  return completer.future.timeout(const Duration(minutes: 2), onTimeout: () => []);
}

Future<Uint8List?> _readAsBytes(html.File file) {
  final reader = html.FileReader();
  final c = Completer<Uint8List?>();
  reader.onError.listen((_) {
    if (!c.isCompleted) c.complete(null);
  });
  reader.onLoadEnd.listen((_) {
    final result = reader.result;
    if (result is ByteBuffer) {
      c.complete(Uint8List.view(result));
    } else if (result is Uint8List) {
      c.complete(result);
    } else {
      c.complete(null);
    }
  });
  reader.readAsArrayBuffer(file);
  return c.future;
}
