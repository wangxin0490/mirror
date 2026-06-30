import 'package:file_picker/file_picker.dart';

import 'picked_image_bytes.dart';

/// 非 Web 平台：file_picker。
Future<List<PickedImageBytes>> pickImages({bool allowMultiple = true, int maxCount = 9}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: allowMultiple,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return [];
  final out = <PickedImageBytes>[];
  for (final f in result.files) {
    if (out.length >= maxCount) break;
    final bytes = f.bytes;
    if (bytes == null || bytes.isEmpty) continue;
    out.add(PickedImageBytes(
      name: f.name.isNotEmpty ? f.name : 'image_${out.length + 1}.jpg',
      bytes: bytes,
    ));
  }
  return out;
}
