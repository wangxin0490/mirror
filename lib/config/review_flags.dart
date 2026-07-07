/// 计费/余额展示开关（通过 `--dart-define` 注入，可显式关闭）。
class ReviewFlags {
  ReviewFlags._();

  /// 隐藏「我的」页账户余额、金额计费、用量卡片及工具箱消耗数字。
  ///
  /// 默认开启；恢复展示：`--dart-define=HIDE_BILLING=false`
  static const bool hideBilling = bool.fromEnvironment(
    'HIDE_BILLING',
    defaultValue: true,
  );
}
