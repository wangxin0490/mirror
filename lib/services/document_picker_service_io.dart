import 'package:file_picker/file_picker.dart';

import 'document_path_reader.dart';
import 'picked_file_bytes.dart';

/// 桌面 / 移动端：file_picker + 路径回退。
Future<PickedFileBytes?> pickDocument() async {
  final result = await FilePicker.platform.pickFiles(withData: true);
  if (result == null || result.files.isEmpty) return null;
  final f = result.files.first;
  var bytes = f.bytes;
  if (bytes == null || bytes.isEmpty) {
    final path = f.path;
    if (path != null && path.isNotEmpty) {
      bytes = await readFileBytesFromPath(path);
    }
  }
  if (bytes == null || bytes.isEmpty) return null;
  final name = f.name.isNotEmpty ? f.name : 'document';
  return PickedFileBytes(name: name, bytes: bytes);
}
