import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'picked_file_bytes.dart';

/// Web：HTML file input（与 image_picker_service_web 相同策略）。
Future<PickedFileBytes?> pickDocument() async {
  final input = html.FileUploadInputElement()
    ..accept = '.pdf,.doc,.docx,.txt,.md,.markdown,.xls,.xlsx,.ppt,.pptx,.csv,.json,.xml,.html,.htm,image/*'
    ..multiple = false
    ..style.display = 'none';

  final completer = Completer<PickedFileBytes?>();
  var done = false;

  void finish(PickedFileBytes? value) {
    if (done) return;
    done = true;
    input.remove();
    if (!completer.isCompleted) completer.complete(value);
  }

  input.onChange.listen((_) async {
    final files = input.files;
    if (files == null || files.isEmpty) {
      finish(null);
      return;
    }
    final file = files.first;
    final bytes = await _readAsBytes(file);
    if (bytes == null || bytes.isEmpty) {
      finish(null);
      return;
    }
    final name = file.name.isNotEmpty ? file.name : 'document';
    finish(PickedFileBytes(name: name, bytes: bytes));
  });

  html.document.body?.append(input);
  input.click();

  unawaited(Future<void>.delayed(const Duration(seconds: 90), () {
    if (!done) finish(null);
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
