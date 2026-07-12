/// App Store 3.1.1：模型/工具不可用提示统一为中性文案（不改锁定逻辑）。

const kModelUnavailableMessage = '该模型暂时不可用，请换一个模型试试';
const kModelUnavailableShortLabel = '暂不可用';
const kToolboxUnavailableMessage = '该工具暂不可用';

/// 不可选模型副标题：不透传服务端 accessLabel。
String? modelLockedSubtitle({
  required bool selectable,
  required String accessLabel,
}) {
  if (selectable) return null;
  return kModelUnavailableShortLabel;
}

/// 锁定 Toast：各类 lockReason 统一文案。
String modelLockToastMessage(String? lockReason) => kModelUnavailableMessage;

/// 切模型等 API 失败文案：含计费/购买语义时替换，其它保留。
String sanitizeModelAccessServerMessage(
  String message, {
  String? lockReason,
}) {
  final trimmed = message.trim();
  if (trimmed.isEmpty) return modelLockToastMessage(lockReason);
  if (looksLikeBillingOrPurchaseCopy(trimmed)) {
    return modelLockToastMessage(lockReason);
  }
  return trimmed;
}

bool looksLikeBillingOrPurchaseCopy(String text) {
  final lower = text.toLowerCase();
  const needles = [
    '购买',
    '充值',
    '余额',
    '额度',
    '已购',
    '付费',
    '套餐',
    '会员',
    'vip',
    'token',
    'wallet',
    'purchase',
    'recharge',
    'billing',
    'quota',
  ];
  for (final n in needles) {
    if (lower.contains(n.toLowerCase())) return true;
  }
  return false;
}
