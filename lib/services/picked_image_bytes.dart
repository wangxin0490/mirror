import 'dart:typed_data';

/// 本地选中的文件（名称 + 字节，原生平台可选磁盘路径）。
class PickedImageBytes {
  PickedImageBytes({
    required this.name,
    required this.bytes,
    this.path,
  });

  final String name;
  final Uint8List bytes;

  /// 原生 file_picker 返回的绝对路径（大文件 mp3 等应优先走路径上传）。
  final String? path;

  bool get hasBytes => bytes.isNotEmpty;
  bool get hasPath => path != null && path!.isNotEmpty;
}
