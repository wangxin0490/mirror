import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../api/api_client.dart';
import '../api/api_result.dart';
import '../config/api_config.dart';
import '../models/auth_models.dart';

/// 登录 / 注册 / 演示账号接口。
class AuthApi {
  static Future<void> _persistSession(Map<String, dynamic> data) async {
    final token = data['access_token'] as String? ?? '';
    final uid = data['user_id'] as int? ?? 0;
    if (token.isEmpty || uid <= 0) return;
    final name = data['display_name'] as String? ?? '';
    final handle = data['handle'] as String? ?? '';
    await ApiConfig.saveSession(
      token: token,
      userId: uid,
      displayName: name.isNotEmpty ? name : null,
      handle: handle.isNotEmpty ? handle : null,
    );
  }

  static Future<List<DemoUser>> fetchDemoUsers() async {
    final data = await ApiClient.get('/api/v1/auth/demo-users');
    if (data == null) return [];
    final users = data['users'] as List<dynamic>? ?? [];
    return users.map((e) => DemoUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<DemoUser?> demoLogin(int userId) async {
    final data = await _postPublic('/api/v1/auth/demo-login', {'user_id': userId});
    if (!data.ok || data.data == null) return null;
    await _persistSession(data.data!);
    final j = data.data!;
    return DemoUser(
      userId: j['user_id'] as int? ?? userId,
      displayName: j['display_name'] as String? ?? '',
      handle: j['handle'] as String? ?? '',
      homeUrl: '',
      avatarLetter: '',
      planCode: '',
    );
  }

  static Future<ApiResult<SendSmsResult>> sendSms(String phone) async {
    final r = await _postPublic('/api/v1/auth/sms/send', {'phone': phone});
    if (!r.ok || r.data == null) return ApiResult(code: r.code, message: r.message);
    return ApiResult(code: 0, message: r.message, data: SendSmsResult.fromJson(r.data!));
  }

  static Future<ApiResult<PhoneLoginResult>> phoneLogin(String phone, String code) async {
    final r = await _postPublic('/api/v1/auth/phone-login', {'phone': phone, 'code': code});
    if (!r.ok || r.data == null) return ApiResult(code: r.code, message: r.message);
    final result = PhoneLoginResult.fromJson(r.data!);
    if (result.loggedIn && result.accessToken != null && result.userId != null) {
      await ApiConfig.saveSession(
        token: result.accessToken!,
        userId: result.userId!,
        displayName: result.displayName,
        handle: result.handle,
      );
    }
    return ApiResult(code: 0, message: r.message, data: result);
  }

  static Future<ApiResult<RegisterResult>> register({
    required String phone,
    required String registerToken,
    required String displayName,
    String bio = '',
  }) async {
    final r = await _postPublic('/api/v1/auth/register', {
      'phone': phone,
      'register_token': registerToken,
      'display_name': displayName,
      'bio': bio,
    });
    if (!r.ok || r.data == null) return ApiResult(code: r.code, message: r.message);
    final result = RegisterResult.fromJson(r.data!);
    if (result.accessToken != null && result.accessToken!.isNotEmpty) {
      await ApiConfig.saveSession(
        token: result.accessToken!,
        userId: result.userId,
        displayName: result.displayName,
        handle: result.handle,
      );
    }
    return ApiResult(code: 0, message: r.message, data: result);
  }

  /// 校验本地令牌是否仍有效。
  static Future<ApiResult<SessionInfo>> fetchSession() async {
    final r = await ApiClient.getResult('/api/v1/auth/session');
    if (!r.ok || r.data == null) return ApiResult(code: r.code, message: r.message);
    final info = SessionInfo.fromJson(r.data!);
    if (info.userId > 0) {
      await ApiConfig.saveSession(
        token: ApiConfig.accessToken,
        userId: info.userId,
        displayName: info.displayName,
        handle: info.handle,
      );
    }
    return ApiResult(code: 0, message: r.message, data: info);
  }

  static Future<void> logout() async {
    await ApiClient.post('/api/v1/auth/logout', {});
    await ApiConfig.resetSession();
  }

  static Future<ApiResult<Map<String, dynamic>>> _postPublic(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    try {
      final res = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (res.statusCode != 200) {
        return ApiResult(code: -1, message: '网络错误 ${res.statusCode}');
      }
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final code = decoded['code'] as int? ?? -1;
      final message = decoded['message'] as String? ?? '';
      final data = decoded['data'];
      if (code != 0) {
        if (kDebugMode) debugPrint('[AuthApi] $path code=$code $message');
        return ApiResult(code: code, message: message);
      }
      if (data is Map<String, dynamic>) {
        return ApiResult(code: 0, message: message, data: data);
      }
      return ApiResult(code: 0, message: message, data: {});
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthApi] $path failed: $e');
      return ApiResult(code: -1, message: '无法连接服务器');
    }
  }
}
