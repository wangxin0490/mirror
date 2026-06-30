import '../models/me_models.dart';
import 'session_store.dart';

/// 后端 API 根地址（默认远程 8100；可用 --dart-define=API_BASE=... 覆盖）。
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://115.159.46.108:8100',
  );

  /// 公共媒体直链根（与 hylt_go kb.cos.domain 一致）；用于 public/feed/ 等对象键。
  static const String publicMediaBase = String.fromEnvironment(
    'MEDIA_PUBLIC_BASE',
    defaultValue: 'https://docs.einrkv.com',
  );

  static int _userId = 0;
  static String _accessToken = '';
  static String _displayName = '';
  static String _handle = '';
  static String _avatarLetter = '';

  /// access token 变更时回调（用于 WS 等长连接换票重连）。
  static void Function()? onTokenChanged;

  /// 会话清空时回调（用于断开 WS 等长连接）。
  static void Function()? onSessionCleared;

  static int get userId => _userId;
  static String get accessToken => _accessToken;
  static bool get isLoggedIn => _accessToken.isNotEmpty && _userId > 0;

  static bool get hasCachedProfile => _displayName.isNotEmpty;

  /// 登录后缓存的资料，用于「我的」页首屏避免闪动。
  static MeProfile get cachedProfile => MeProfile(
        displayName: _displayName,
        handle: _handle,
        homeUrl: '',
        avatarLetter: _avatarLetter.isNotEmpty ? _avatarLetter : '?',
        following: 0,
        followers: 0,
        notes: 0,
      );

  static void setUserId(int id) {
    if (id > 0) _userId = id;
  }

  static Future<void> loadFromStorage() async {
    final storedBase = await SessionStore.loadApiBase();
    if (storedBase != null && storedBase != baseUrl) {
      await SessionStore.clear();
      return;
    }
    _accessToken = await SessionStore.loadToken() ?? '';
    final uid = await SessionStore.loadUserId();
    _userId = uid ?? 0;
    final profile = await SessionStore.loadProfile();
    if (profile != null) {
      _displayName = profile.displayName;
      _handle = profile.handle;
      _avatarLetter = profile.avatarLetter;
    }
  }

  static Future<void> saveSession({
    required String token,
    required int userId,
    String? displayName,
    String? handle,
    String? avatarLetter,
  }) async {
    final tokenChanged = token != _accessToken;
    _accessToken = token;
    _userId = userId;
    if (displayName != null && displayName.isNotEmpty) {
      _displayName = displayName;
      _handle = handle ?? '';
      _avatarLetter = avatarLetter ?? (displayName.isNotEmpty ? displayName[0].toUpperCase() : '?');
    }
    await SessionStore.save(
      token: token,
      userId: userId,
      apiBase: baseUrl,
      displayName: displayName,
      handle: handle,
      avatarLetter: avatarLetter,
    );
    if (tokenChanged && token.isNotEmpty) {
      onTokenChanged?.call();
    }
  }

  static Future<void> resetSession() async {
    _accessToken = '';
    _userId = 0;
    _displayName = '';
    _handle = '';
    _avatarLetter = '';
    await SessionStore.clear();
    onSessionCleared?.call();
  }
}
