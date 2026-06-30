import 'dart:io';
import 'dart:typed_data';

Future<Uint8List?> readFileBytesFromPath(String path) async {
  try {
    return await File(path).readAsBytes();
  } catch (_) {
    return null;
  }
}
