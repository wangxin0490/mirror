import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api/api_result.dart';
import '../api/meeting_api.dart';
import '../models/meeting_draft.dart';
import '../models/meeting_upload_models.dart';
import 'base_voice_session_controller.dart';
import 'meeting_draft_store.dart';

/// 会议录音 COS 分片直传（单片静默重试 + 断点续传）。
class CosMultipartUploader {
  CosMultipartUploader._();

  static final CosMultipartUploader instance = CosMultipartUploader._();

  static const _partRetryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 3),
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(seconds: 30),
  ];

  static final Dio _putDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(minutes: 2),
      sendTimeout: const Duration(minutes: 30),
      receiveTimeout: const Duration(minutes: 5),
      validateStatus: (s) => s != null && s >= 200 && s < 300,
    ),
  );

  /// 上传草稿；`storage=local` 时返回 `code=-2` 供 Worker 走 BFF fallback。
  Future<ApiResult<int>> uploadDraft(
    MeetingDraft draft, {
    required void Function(double progress) onProgress,
  }) async {
    final store = MeetingDraftStore.instance;
    final file = File(draft.filePath);
    if (!await file.exists()) {
      return ApiResult(code: -1, message: '本地文件不存在');
    }
    final fileSize = await file.length();
    if (fileSize <= 0) {
      return ApiResult(code: -1, message: '文件为空');
    }
    final minBps = BaseVoiceSessionController.minBytesPerSecond(
      _fileExt(draft.filePath).replaceFirst('.', ''),
    );
    if (draft.durationSec >= 1 && fileSize < draft.durationSec * minBps) {
      if (kDebugMode) {
        debugPrint(
          '[CosMultipart] suspicious file size: duration=${draft.durationSec}s bytes=$fileSize path=${draft.filePath}',
        );
      }
      return ApiResult(code: -1, message: '录音文件异常偏小，请重新录制后再上传');
    }

    final header = await _readHeader(file);
    _logLocalAudioDiag(draft, fileSize, header);
    if (kDebugMode) {
      debugPrint(
        '[MeetingAudioDiag] detected_format=${_detectFormat(header)} '
        'pathExt=${_fileExt(draft.filePath)} uploadExt=${_fileExt(_filenameFor(draft))}',
      );
    }

    var current = draft;

    // 始终 sync upload-init，避免断点续传时 uploadId 已变但本地仍跳过旧分片。
    final initR = await MeetingApi.uploadInit(
      filename: _filenameFor(draft),
      fileSize: fileSize,
      title: draft.title,
      durationSec: draft.durationSec,
      clientDraftId: draft.localId,
    );
    if (!initR.ok || initR.data == null) {
      return ApiResult(code: initR.code, message: initR.message);
    }
    final init = initR.data!;
    if (!init.isCos) {
      return ApiResult(code: -2, message: 'local');
    }

    final uploadIdChanged =
        (current.cosUploadId ?? '').isNotEmpty && current.cosUploadId != init.uploadId;
    current = current.copyWith(
      uploadToken: init.uploadToken,
      cosKey: init.cosKey,
      cosUploadId: init.uploadId,
      partSize: init.partSize,
      serverSessionId: init.sessionId,
      state: DraftUploadState.uploading,
      lastProgressAt: DateTime.now(),
      completedParts: uploadIdChanged ? const [] : current.completedParts,
      partEtags: uploadIdChanged ? const {} : current.partEtags,
      uploadProgress: uploadIdChanged ? 0 : current.uploadProgress,
    );
    await store.updateDraft(current);

    final partSize = max(1, current.partSize);
    final totalParts = (fileSize / partSize).ceil();
    final completed = Set<int>.from(current.completedParts);
    final etags = Map<int, String>.from(current.partEtags);

    for (var partNumber = 1; partNumber <= totalParts; partNumber++) {
      if (completed.contains(partNumber)) continue;

      final start = (partNumber - 1) * partSize;
      final end = min(start + partSize, fileSize);
      final length = end - start;
      final bytes = await _readRange(file, start, length);

      final etag = await _putPartWithRetry(
        uploadToken: init.uploadToken,
        partNumber: partNumber,
        bytes: bytes,
      );
      if (etag == null) {
        return ApiResult(code: -1, message: '网络中断');
      }

      completed.add(partNumber);
      etags[partNumber] = etag;
      final progress = completed.length / totalParts;
      current = current.copyWith(
        completedParts: completed.toList()..sort(),
        partEtags: etags,
        uploadProgress: progress,
        lastProgressAt: DateTime.now(),
        state: DraftUploadState.uploading,
      );
      await store.updateDraft(current);
      onProgress(progress);
    }

    final parts = etags.entries
        .map((e) => MeetingUploadPart(partNumber: e.key, etag: e.value))
        .toList()
      ..sort((a, b) => a.partNumber.compareTo(b.partNumber));

    final completeR = await MeetingApi.uploadComplete(
      uploadToken: init.uploadToken,
      parts: parts,
    );
    if (!completeR.ok || completeR.data == null) {
      return ApiResult(code: completeR.code, message: completeR.message);
    }
    return ApiResult(code: 0, message: '', data: completeR.data);
  }

  Future<String?> _putPartWithRetry({
    required String uploadToken,
    required int partNumber,
    required List<int> bytes,
  }) async {
    for (var attempt = 0; attempt < _partRetryDelays.length; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(_partRetryDelays[attempt]);
      }
      try {
        final urlR = await MeetingApi.uploadPartUrl(
          uploadToken: uploadToken,
          partNumber: partNumber,
        );
        if (!urlR.ok || urlR.data == null || urlR.data!.isEmpty) {
          continue;
        }
        final resp = await _putDio.put<Response<dynamic>>(
          urlR.data!,
          data: bytes,
          options: Options(
            headers: {'Content-Type': 'application/octet-stream'},
            responseType: ResponseType.plain,
          ),
        );
        final etag = resp.headers.value('etag') ?? resp.headers.value('ETag');
        if (etag != null && etag.isNotEmpty) {
          return etag;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[CosMultipart] part $partNumber attempt ${attempt + 1}: $e');
        }
      }
    }
    return null;
  }

  Future<List<int>> _readRange(File file, int start, int length) async {
    final raf = await file.open();
    try {
      await raf.setPosition(start);
      final chunk = await raf.read(length);
      return chunk;
    } finally {
      await raf.close();
    }
  }

  String _filenameFor(MeetingDraft draft) {
    final base = draft.filePath.split(Platform.pathSeparator).last;
    if (base.contains('.')) return base;
    return '${draft.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}.wav';
  }

  void _logLocalAudioDiag(MeetingDraft draft, int fileSize, List<int> header) {
    if (!kDebugMode) return;
    final pathExt = _fileExt(draft.filePath);
    final uploadName = _filenameFor(draft);
    final uploadExt = _fileExt(uploadName);
    final hex = header.isEmpty
        ? ''
        : header.take(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    debugPrint(
      '[MeetingAudioDiag] stage=before_cos_upload '
      'localId=${draft.localId} '
      'filePath=${draft.filePath} '
      'pathExt=$pathExt '
      'uploadFilename=$uploadName '
      'uploadExt=$uploadExt '
      'bytes=$fileSize '
      'durationSec=${draft.durationSec} '
      'headerHex=$hex',
    );
  }

  String _fileExt(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return '';
    return path.substring(dot).toLowerCase();
  }

  String _detectFormat(List<int> header) {
    if (header.length >= 4 &&
        header[0] == 0x1A &&
        header[1] == 0x45 &&
        header[2] == 0xDF &&
        header[3] == 0xA3) {
      return 'webm/matroska';
    }
    if (header.length >= 8 && String.fromCharCodes(header.sublist(4, 8)) == 'ftyp') {
      return 'mp4/m4a';
    }
    if (header.length >= 4 && String.fromCharCodes(header.sublist(0, 4)) == 'RIFF') {
      return 'wav';
    }
    if (header.length >= 3 && String.fromCharCodes(header.sublist(0, 3)) == 'ID3') {
      return 'mp3';
    }
    return header.isEmpty ? 'empty' : 'unknown';
  }

  Future<List<int>> _readHeader(File file, {int n = 16}) async {
    final raf = await file.open();
    try {
      final chunk = await raf.read(n);
      return chunk;
    } finally {
      await raf.close();
    }
  }
}
