import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'native_shell.dart';
import 'prototype_shell.dart';

/// Web 保留画廊手机框；Android / iOS 使用全屏原生壳。
Widget platformShell({required Widget child}) {
  if (kIsWeb) {
    return PrototypeShell(child: child);
  }
  return NativeShell(child: child);
}

bool get useNativeLayout => !kIsWeb;
