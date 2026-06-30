/// 11 位手机号中间四位脱敏，如 138****5678。
String maskPhoneNickname(String phone) {
  final p = phone.trim();
  if (p.length != 11) return p;
  return '${p.substring(0, 3)}****${p.substring(7)}';
}
