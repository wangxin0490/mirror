import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:network_ninja/network_ninja.dart';

import '../api/api_result.dart';
import '../config/api_config.dart';
import '../config/debug_flags.dart';

/// 鉴权失效时回调（40100/40101/40102）。
typedef AuthErrorCallback = void Function(int code, String message);

/// 统一请求 BFF（响应格式 code/message/data）；Debug 下由 Network Ninja 记录 Dio 请求。
class ApiClient {
  ApiClient._();

  static const Duration _requestTimeout = Duration(seconds: 12);
  static AuthErrorCallback? onAuthError;

  static final Dio _dio = _createDio();

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: _requestTimeout,
        receiveTimeout: _requestTimeout,
        sendTimeout: _requestTimeout,
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        validateStatus: (status) => status != null,
      ),
    );
    if (DebugFlags.networkNinjaEnabled) {
      NetworkNinjaController.addInterceptor(dio);
    }
    return dio;
  }

  static void _log(String msg) {
    if (kDebugMode) {
      debugPrint('[Mirror API] $msg');
    }
  }

  static void _maybeAuthError(int code, String message) {
    if (code == 40100 || code == 40101 || code == 40102) {
      onAuthError?.call(code, message);
    }
  }

  static Map<String, String> _headers() {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (ApiConfig.accessToken.isNotEmpty) {
      h['Authorization'] = 'Bearer ${ApiConfig.accessToken}';
    }
    return h;
  }

  static Options _options() => Options(headers: _headers());

  static String _bodyString(Response<dynamic> res) {
    final data = res.data;
    if (data == null) return '';
    if (data is String) return data;
    return jsonEncode(data);
  }

  static Map<String, dynamic>? _decodeEnvelope(dynamic data, String path) {
    if (data is! Map<String, dynamic>) {
      if (data is Map) {
        return _decodeEnvelope(Map<String, dynamic>.from(data), path);
      }
      return null;
    }
    final code = data['code'] as int? ?? -1;
    final message = data['message'] as String? ?? '';
    if (code != 0) {
      _log('biz code=$code msg=$message path=$path');
      _maybeAuthError(code, message);
      return null;
    }
    final payload = data['data'];
    if (payload is Map<String, dynamic>) return payload;
    return null;
  }

  static Future<ApiResult<Map<String, dynamic>>> getResult(String path) async {
    _log('GET ${ApiConfig.baseUrl}$path');
    try {
      final res = await _dio.get<dynamic>(path, options: _options());
      if (res.statusCode != 200) {
        return ApiResult(code: -1, message: '网络错误 ${res.statusCode}');
      }
      final data = res.data;
      if (data is! Map<String, dynamic> && data is Map) {
        return ApiResult(code: -1, message: '响应解析失败');
      }
      final map = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
      final code = map['code'] as int? ?? -1;
      final message = map['message'] as String? ?? '';
      if (code != 0) {
        _maybeAuthError(code, message);
        return ApiResult(code: code, message: message);
      }
      final payload = map['data'];
      if (payload is Map<String, dynamic>) {
        return ApiResult(code: 0, message: message, data: payload);
      }
      return ApiResult(code: 0, message: message, data: {});
    } on DioException catch (e) {
      _log('GET $path failed: ${e.message}');
      return ApiResult(code: -1, message: '无法连接服务器');
    } catch (e) {
      return ApiResult(code: -1, message: '无法连接服务器');
    }
  }

  static Future<Map<String, dynamic>?> get(String path) async {
    _log('GET ${ApiConfig.baseUrl}$path');
    try {
      final res = await _dio.get<dynamic>(path, options: _options());
      _log('GET $path -> ${res.statusCode}');
      if (res.statusCode != 200) {
        _log('body: ${_bodyString(res)}');
        return null;
      }
      return _decodeEnvelope(res.data, path);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        _log('GET $path timeout');
      } else {
        _log('GET $path failed: ${e.message}');
      }
      return null;
    } catch (e, st) {
      _log('GET $path failed: $e');
      if (kDebugMode) debugPrint('$st');
      return null;
    }
  }

  static Future<List<dynamic>?> getList(String path) async {
    _log('GET ${ApiConfig.baseUrl}$path');
    try {
      final res = await _dio.get<dynamic>(path, options: _options());
      _log('GET $path -> ${res.statusCode}');
      if (res.statusCode != 200) {
        return null;
      }
      final data = res.data;
      if (data is! Map<String, dynamic> && data is Map) {
        return null;
      }
      final map = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
      final code = map['code'] as int? ?? -1;
      final message = map['message'] as String? ?? '';
      if (code != 0) {
        _maybeAuthError(code, message);
        return null;
      }
      final payload = map['data'];
      if (payload is List<dynamic>) return payload;
      return null;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        _log('GET $path timeout');
      } else {
        _log('GET $path failed: ${e.message}');
      }
      return null;
    } catch (e, st) {
      _log('GET $path failed: $e');
      if (kDebugMode) debugPrint('$st');
      return null;
    }
  }

  static Future<ApiResult<Map<String, dynamic>>> patchResult(
    String path,
    Map<String, dynamic> body,
  ) async {
    _log('PATCH ${ApiConfig.baseUrl}$path');
    try {
      final res = await _dio.patch<dynamic>(
        path,
        data: body,
        options: _options(),
      );
      return _decodeResponseMap(res.statusCode, res.data, path);
    } on DioException catch (e) {
      _log('PATCH $path failed: ${e.message}');
      return ApiResult(code: -1, message: '无法连接服务器');
    } catch (e, st) {
      _log('PATCH $path failed: $e');
      if (kDebugMode) debugPrint('$st');
      return ApiResult(code: -1, message: '无法连接服务器');
    }
  }

  static ApiResult<Map<String, dynamic>> _decodeResponseMap(
    int? statusCode,
    dynamic data,
    String path,
  ) {
    try {
      if (data is! Map<String, dynamic> && data is Map) {
        data = Map<String, dynamic>.from(data);
      }
      if (data is! Map<String, dynamic>) {
        return ApiResult(code: -1, message: '响应解析失败');
      }
      final code = data['code'] as int? ?? -1;
      final message = data['message'] as String? ?? '';
      if (statusCode == 200 && code == 0) {
        final payload = data['data'];
        if (payload is Map<String, dynamic>) {
          return ApiResult(code: 0, message: message, data: payload);
        }
        return ApiResult(code: 0, message: message, data: {});
      }
      _log('$path -> $statusCode code=$code msg=$message');
      _maybeAuthError(code, message);
      return ApiResult(code: code, message: message);
    } catch (e) {
      return ApiResult(code: -1, message: '响应解析失败');
    }
  }

  static Future<Map<String, dynamic>?> put(String path, Map<String, dynamic> body) async {
    _log('PUT ${ApiConfig.baseUrl}$path');
    try {
      final res = await _dio.put<dynamic>(path, data: body, options: _options());
      _log('PUT $path -> ${res.statusCode}');
      if (res.statusCode != 200) {
        _log('body: ${_bodyString(res)}');
        return null;
      }
      return _decodeEnvelope(res.data, path);
    } on DioException catch (e) {
      _log('PUT $path failed: ${e.message}');
      if (kDebugMode) debugPrint('${e.stackTrace}');
      return null;
    } catch (e, st) {
      _log('PUT $path failed: $e');
      if (kDebugMode) debugPrint('$st');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> delete(String path) async {
    final r = await deleteResult(path);
    return r.ok ? (r.data ?? <String, dynamic>{}) : null;
  }

  static Future<ApiResult<Map<String, dynamic>>> deleteResult(String path) async {
    _log('DELETE ${ApiConfig.baseUrl}$path');
    try {
      final res = await _dio.delete<dynamic>(path, options: _options());
      final status = res.statusCode ?? 0;
      // Agent 等接口删除成功返回 204 No Content，无 JSON envelope。
      if (status == 204) {
        return ApiResult(code: 0, message: '', data: {});
      }
      return _decodeResponseMap(status, res.data, path);
    } on DioException catch (e) {
      _log('DELETE $path failed: ${e.message}');
      return ApiResult(code: -1, message: '无法连接服务器');
    } catch (e, st) {
      _log('DELETE $path failed: $e');
      if (kDebugMode) debugPrint('$st');
      return ApiResult(code: -1, message: '无法连接服务器');
    }
  }

  static Future<Map<String, dynamic>?> post(String path, Map<String, dynamic> body) async {
    final r = await postResult(path, body);
    return r.ok ? r.data : null;
  }

  /// POST JSON；HTTP 200/202 均视为传输成功（知识库上传/网页导入等异步接口返回 202）。
  static Future<ApiResult<Map<String, dynamic>>> postResult(
    String path,
    Map<String, dynamic> body,
  ) async {
    _log('POST ${ApiConfig.baseUrl}$path');
    try {
      final res = await _dio.post<dynamic>(path, data: body, options: _options());
      final status = res.statusCode ?? 0;
      if (status != 200 && status != 202) {
        return ApiResult(code: -1, message: '网络错误 $status');
      }
      final data = res.data;
      if (data is! Map<String, dynamic> && data is Map) {
        return ApiResult(code: -1, message: '响应解析失败');
      }
      final map = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
      final code = map['code'] as int? ?? -1;
      final message = map['message'] as String? ?? '';
      if (code != 0) {
        _log('biz code=$code msg=$message path=$path');
        _maybeAuthError(code, message);
        return ApiResult(code: code, message: message);
      }
      final payload = map['data'];
      if (payload is Map<String, dynamic>) {
        return ApiResult(code: 0, message: message, data: payload);
      }
      return ApiResult(code: 0, message: message, data: {});
    } on DioException catch (e) {
      _log('POST $path failed: ${e.message}');
      if (kDebugMode) debugPrint('${e.stackTrace}');
      return ApiResult(code: -1, message: '无法连接服务器');
    } catch (e, st) {
      _log('POST $path failed: $e');
      if (kDebugMode) debugPrint('$st');
      return ApiResult(code: -1, message: '无法连接服务器');
    }
  }
}
