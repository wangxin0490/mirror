import 'package:shared_preferences/shared_preferences.dart';

/// 用户是否已同意将数据发送至第三方 AI 服务。
class AiConsentStore {
  AiConsentStore._();

  static const _prefsKey = 'mirror_ai_third_party_consent_v1';

  static Future<bool> hasConsented() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_prefsKey) ?? false;
  }

  static Future<void> setConsented(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_prefsKey, value);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_prefsKey);
  }
}
