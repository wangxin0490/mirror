import 'package:flutter/foundation.dart';

/// 编译期调试开关（通过 `--dart-define` 注入，Release 包也可用）。
class DebugFlags {
  DebugFlags._();

  static const bool _networkNinjaDefine = bool.fromEnvironment(
    'NETWORK_NINJA',
    defaultValue: false,
  );

  /// Network Ninja 抓包悬浮球。
  ///
  /// - Debug 运行（`flutter run`）：默认开启
  /// - Release 打包调试：`--dart-define=NETWORK_NINJA=true`
  static bool get networkNinjaEnabled => kDebugMode || _networkNinjaDefine;
}
