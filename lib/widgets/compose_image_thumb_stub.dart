import 'dart:typed_data';

import 'package:flutter/material.dart';

/// 非 Web 平台占位（由条件导入指向 web 实现；此文件仅满足分析器）。
class ComposeImageThumbWeb extends StatelessWidget {
  const ComposeImageThumbWeb({super.key, required this.bytes, required this.size});

  final Uint8List bytes;
  final double size;

  @override
  Widget build(BuildContext context) => Image.memory(bytes, width: size, height: size, fit: BoxFit.cover);
}
