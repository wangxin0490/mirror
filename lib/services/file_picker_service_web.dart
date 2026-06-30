import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'picked_image_bytes.dart';

Future<List<PickedImageBytes>> pickFiles({bool allowMultiple = false, int maxCount = 1}) async {
  final input = html.FileUploadInputElement()
    ..accept = '*/*'
    ..multiple = allowMultiple
    ..style.display = 'none';

  final completer = Completer<List<PickedImageBytes>>();
  var done = false;

  void finish(List<PickedImageBytes> value) {
    if (done) return;
    done = true;
    input.remove();
    if (!completer.isCompleted) completer.complete(value);
  }

  input.onChange.listen((_) async {
    final files = input.files;
    if (files == null || files.isEmpty) {
      finish([]);
      return;
    }
    final out = <PickedImageBytes>[];
    for (var i = 0; i < files.length && out.length < maxCount; i++) {
      final file = files[i];
      final bytes = await _readAsBytes(file);
      if (bytes == null || bytes.isEmpty) continue;
      final name = file.name.isNotEmpty ? file.name : 'file_${out.length + 1}';
      out.add(PickedImageBytes(name: name, bytes: bytes));
    }
    finish(out);
  });

  html.document.body?.append(input);
  input.click();

  unawaited(Future<void>.delayed(const Duration(seconds: 90), () {
    if (!done) finish([]);
  }));

  return completer.future;
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
