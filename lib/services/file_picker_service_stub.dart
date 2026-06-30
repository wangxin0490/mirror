import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'picked_image_bytes.dart';

Future<List<PickedImageBytes>> pickFiles({bool allowMultiple = false, int maxCount = 1}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.any,
    allowMultiple: allowMultiple,
    // 大文件（mp3 等）在真机上 withData:true 常拿不到 bytes，需用 path 流式上传。
    withData: false,
  );
  if (result == null || result.files.isEmpty) return [];

  final out = <PickedImageBytes>[];
  for (final f in result.files) {
    if (out.length >= maxCount) break;
    final name = f.name.isNotEmpty ? f.name : 'file_${out.length + 1}';
    final path = f.path;

    Uint8List bytes = f.bytes ?? Uint8List(0);
    if (bytes.isEmpty && path != null && path.isNotEmpty) {
      try {
        final file = File(path);
        if (await file.exists()) {
          final len = await file.length();
          // 大文件只保留 path，由 MeetingApi.createSessionFromFile 流式上传。
          if (len > 0 && len <= 1024 * 1024) {
            bytes = await file.readAsBytes();
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[FilePicker] read path failed: $e');
      }
    }

    if (bytes.isEmpty && (path == null || path.isEmpty)) continue;

    out.add(PickedImageBytes(name: name, bytes: bytes, path: path));
  }
  return out;
}
