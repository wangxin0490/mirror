import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';

import '../api/api_client.dart';
import '../api/api_result.dart';
import '../config/api_config.dart';
import '../models/meeting_models.dart';
import '../models/meeting_upload_models.dart';
import '../services/voice_recorder_service.dart';
import '../utils/meeting_audio_mime.dart';

class MeetingApi {
  static const String _legacyCreatePath = '/api/v1/meeting-sessions';

  static Dio _uploadDio() {
    final headers = <String, String>{};
    if (ApiConfig.accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${ApiConfig.accessToken}';
    }
    return Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(minutes: 10),
        sendTimeout: const Duration(minutes: 10),
        headers: headers,
        validateStatus: (status) => status != null,
      ),
    );
  }

  static String _uploadErrorMessage(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return '上传超时，请检查网络后重试';
        case DioExceptionType.connectionError:
          return '无法连接服务器，请确认网络或文件是否超过服务端限制（>4MB 需升级服务端）';
        case DioExceptionType.badResponse:
          final status = e.response?.statusCode;
          if (status == 413) return '文件过大，请压缩后重试';
          final data = e.response?.data;
          if (data is Map<String, dynamic>) {
            final msg = data['message'] as String? ?? '';
            if (msg.isNotEmpty) return msg;
          }
          if (status != null) return '上传失败（HTTP $status）';
          break;
        default:
          break;
      }
      final status = e.response?.statusCode;
      if (status == 413) return '文件过大，请压缩后重试';
      final msg = e.message;
      if (msg != null && msg.isNotEmpty) return msg;
    }
    return '无法连接服务器';
  }

  static ApiResult<int>? _parseUploadJson(
    Map<String, dynamic>? j, {
    required int httpStatus,
  }) {
    if (j == null) {
      return ApiResult(code: -1, message: '服务器响应异常（HTTP $httpStatus）');
    }
    final code = j['code'] as int? ?? -1;
    final message = j['message'] as String? ?? '';
    if (code != 0) {
      return ApiResult(
        code: code,
        message: message.isNotEmpty ? message : '上传失败',
      );
    }
    final data = j['data'] as Map<String, dynamic>?;
    return ApiResult(
      code: 0,
      message: message,
      data: data?['session_id'] as int? ?? 0,
    );
  }

  static MultipartFile _multipartFromBytes(RecordedVoice recorded) {
    final mime = meetingAudioMimeType(recorded.filename);
    return MultipartFile.fromBytes(
      recorded.bytes,
      filename: recorded.filename,
      contentType: mime != null ? MediaType.parse(mime) : null,
    );
  }

  static Future<MultipartFile> _multipartFromPath(
    String filePath,
    String filename,
  ) async {
    final mime = meetingAudioMimeType(filename);
    return MultipartFile.fromFile(
      filePath,
      filename: filename,
      contentType: mime != null ? MediaType.parse(mime) : null,
    );
  }

  static Future<MeetingListPage?> listSessions({
    int limit = 30,
    int beforeId = 0,
  }) async {
    final q = <String>['limit=$limit'];
    if (beforeId > 0) q.add('before_id=$beforeId');
    final data = await ApiClient.get('/api/v1/meeting-sessions?${q.join('&')}');
    if (data == null) return null;
    return MeetingListPage.fromJson(data);
  }

  static Future<MeetingSessionDetail?> getSession(int id) async {
    final data = await ApiClient.get('/api/v1/meeting-sessions/$id');
    if (data == null) return null;
    return MeetingSessionDetail.fromJson(data);
  }

  static Future<String?> getAudioUrl(int id) async {
    final data = await ApiClient.get('/api/v1/meeting-sessions/$id/audio-url');
    if (data == null) return null;
    return data['url'] as String?;
  }

  static Future<ApiResult<MeetingUploadInit>> uploadInit({
    required String filename,
    required int fileSize,
    required String title,
    int durationSec = 0,
    String? clientDraftId,
  }) async {
    final r =
        await ApiClient.postResult('/api/v1/meeting-sessions/upload-init', {
          'filename': filename,
          'file_size': fileSize,
          'title': title,
          if (durationSec > 0) 'duration_sec': durationSec,
          if (clientDraftId != null && clientDraftId.isNotEmpty)
            'client_draft_id': clientDraftId,
        });
    if (!r.ok || r.data == null) {
      return ApiResult(code: r.code, message: r.message);
    }
    return ApiResult(
      code: 0,
      message: r.message,
      data: MeetingUploadInit.fromJson(r.data!),
    );
  }

  static Future<ApiResult<String>> uploadPartUrl({
    required String uploadToken,
    required int partNumber,
  }) async {
    final r = await ApiClient.postResult(
      '/api/v1/meeting-sessions/upload-part-url',
      {'upload_token': uploadToken, 'part_number': partNumber},
    );
    if (!r.ok || r.data == null) {
      return ApiResult(code: r.code, message: r.message);
    }
    final url = r.data!['presigned_url'] as String? ?? '';
    if (url.isEmpty) {
      return ApiResult(code: -1, message: '预签名 URL 为空');
    }
    return ApiResult(code: 0, message: r.message, data: url);
  }

  static Future<ApiResult<int>> uploadComplete({
    required String uploadToken,
    required List<MeetingUploadPart> parts,
  }) async {
    final r = await ApiClient.postResult(
      '/api/v1/meeting-sessions/upload-complete',
      {
        'upload_token': uploadToken,
        'parts': parts.map((p) => p.toJson()).toList(),
      },
    );
    if (!r.ok || r.data == null) {
      return ApiResult(code: r.code, message: r.message);
    }
    return ApiResult(
      code: 0,
      message: r.message,
      data: r.data!['session_id'] as int? ?? 0,
    );
  }

  /// 从本地文件 multipart 上传（真机大文件 mp3 等推荐）。
  static Future<ApiResult<int>> createSessionFromFile(
    String filePath,
    String filename, {
    String? title,
    int durationSec = 0,
    void Function(double progress)? onProgress,
  }) async {
    final fields = <String, String>{};
    if (title != null && title.trim().isNotEmpty) {
      fields['title'] = title.trim();
    }
    if (durationSec > 0) {
      fields['duration_sec'] = '$durationSec';
    }
    try {
      final dio = _uploadDio();
      onProgress?.call(0);
      final form = FormData.fromMap({
        ...fields,
        'file': await _multipartFromPath(filePath, filename),
      });
      if (kDebugMode) {
        debugPrint('[MeetingApi] upload file=$filename path=$filePath');
      }
      final resp = await dio.post<Map<String, dynamic>>(
        _legacyCreatePath,
        data: form,
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call((sent / total).clamp(0.0, 1.0));
        },
      );
      final status = resp.statusCode ?? 0;
      if (status != 200 && status != 202) {
        return ApiResult(code: -1, message: '上传失败（HTTP $status）');
      }
      final parsed = _parseUploadJson(resp.data, httpStatus: status);
      if (parsed == null) {
        return ApiResult(code: -1, message: '上传响应格式错误');
      }
      if (parsed.code != 0) return parsed;
      onProgress?.call(1);
      return parsed;
    } catch (e, st) {
      if (kDebugMode) debugPrint('[MeetingApi] createFromFile failed: $e\n$st');
      return ApiResult(code: -1, message: _uploadErrorMessage(e));
    }
  }

  static Future<ApiResult<int>> createSession(
    RecordedVoice recorded, {
    String? title,
    void Function(double progress)? onProgress,
  }) async {
    final fields = <String, String>{};
    if (title != null && title.trim().isNotEmpty) {
      fields['title'] = title.trim();
    }
    if (recorded.duration.inSeconds > 0) {
      fields['duration_sec'] = '${recorded.duration.inSeconds}';
    }

    if (recorded.bytes.isEmpty) {
      return ApiResult(code: -1, message: '音频文件为空，请重新选择');
    }

    return _createWithProgress(recorded, fields, onProgress ?? (_) {});
  }

  static Future<ApiResult<int>> _createWithProgress(
    RecordedVoice recorded,
    Map<String, String> fields,
    void Function(double progress) onProgress,
  ) async {
    try {
      final dio = _uploadDio();
      onProgress(0);
      final form = FormData.fromMap({
        ...fields,
        'file': _multipartFromBytes(recorded),
      });
      final resp = await dio.post<Map<String, dynamic>>(
        _legacyCreatePath,
        data: form,
        onSendProgress: (sent, total) {
          if (total > 0) onProgress((sent / total).clamp(0.0, 1.0));
        },
      );
      final status = resp.statusCode ?? 0;
      if (status != 200 && status != 202) {
        return ApiResult(code: -1, message: '上传失败（HTTP $status）');
      }
      final parsed = _parseUploadJson(resp.data, httpStatus: status);
      if (parsed == null) {
        return ApiResult(code: -1, message: '上传响应格式错误');
      }
      if (parsed.code != 0) return parsed;
      onProgress(1);
      return parsed;
    } catch (e, st) {
      if (kDebugMode) debugPrint('[MeetingApi] create failed: $e\n$st');
      return ApiResult(code: -1, message: _uploadErrorMessage(e));
    }
  }

  static Future<ApiResult<void>> retrySession(
    int id, {
    String stage = 'transcribe',
  }) async {
    final r = await ApiClient.postResult(
      '/api/v1/meeting-sessions/$id/retry?stage=$stage',
      {},
    );
    return ApiResult(code: r.code, message: r.message);
  }

  static Future<ApiResult<void>> deleteSession(int id) async {
    final r = await ApiClient.deleteResult('/api/v1/meeting-sessions/$id');
    return ApiResult(code: r.code, message: r.message);
  }
}
