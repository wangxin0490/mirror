import 'package:shared_preferences/shared_preferences.dart';

/// 本地持久化登录令牌与用户资料摘要（设备级）。
class SessionStore {
  SessionStore._();

  static const _tokenKey = 'mirror_access_token';
  static const _apiBaseKey = 'mirror_api_base';
  static const _userIdKey = 'mirror_user_id';
  static const _displayNameKey = 'mirror_display_name';
  static const _handleKey = 'mirror_handle';
  static const _avatarLetterKey = 'mirror_avatar_letter';

  static Future<String?> loadToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_tokenKey);
  }

  static Future<String?> loadApiBase() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_apiBaseKey);
  }

  static Future<int?> loadUserId() async {
    final p = await SharedPreferences.getInstance();
    final id = p.getInt(_userIdKey);
    return id != null && id > 0 ? id : null;
  }

  static Future<({String displayName, String handle, String avatarLetter})?> loadProfile() async {
    final p = await SharedPreferences.getInstance();
    final name = p.getString(_displayNameKey);
    if (name == null || name.isEmpty) return null;
    return (
      displayName: name,
      handle: p.getString(_handleKey) ?? '',
      avatarLetter: p.getString(_avatarLetterKey) ?? '?',
    );
  }

  static Future<void> save({
    required String token,
    required int userId,
    required String apiBase,
    String? displayName,
    String? handle,
    String? avatarLetter,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_tokenKey, token);
    await p.setString(_apiBaseKey, apiBase);
    await p.setInt(_userIdKey, userId);
    if (displayName != null && displayName.isNotEmpty) {
      await p.setString(_displayNameKey, displayName);
      await p.setString(_handleKey, handle ?? '');
      final letter = avatarLetter ?? (displayName.isNotEmpty ? displayName[0].toUpperCase() : '?');
      await p.setString(_avatarLetterKey, letter);
    }
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_tokenKey);
    await p.remove(_apiBaseKey);
    await p.remove(_userIdKey);
    await p.remove(_displayNameKey);
    await p.remove(_handleKey);
    await p.remove(_avatarLetterKey);
  }
}
