import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../api/api_result.dart';
import '../api/meeting_api.dart';
import '../config/api_config.dart';
import '../models/meeting_draft.dart';
import '../state/meeting_session_store.dart';
import 'cos_multipart_uploader.dart';
import 'meeting_background_upload.dart';
import 'meeting_draft_store.dart';

/// 会议草稿上传队列（FIFO，同时只传一条）。
class MeetingUploadWorker extends ChangeNotifier {
  MeetingUploadWorker._();

  static final MeetingUploadWorker instance = MeetingUploadWorker._();

  final _queue = <String>[];
  var _running = false;
  var _busy = false;
  String? _activeLocalId;
  Timer? _retryTimer;

  static const _retryDelays = [
    Duration(seconds: 30),
    Duration(minutes: 2),
    Duration(minutes: 5),
  ];

  String? get activeLocalId => _activeLocalId;

  void start() {
    if (kIsWeb || _running || !ApiConfig.isLoggedIn) return;
    _running = true;
    unawaited(_resumePending());
  }

  void stop() {
    _running = false;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  void enqueue(String localId) {
    if (!_queue.contains(localId)) {
      _queue.add(localId);
    }
    _pump();
  }

  Future<void> retryDraft(String localId) async {
    final store = MeetingDraftStore.instance;
    final d = store.draftById(localId);
    if (d == null) return;
    await store.updateDraft(
      d.copyWith(
        state: DraftUploadState.pending,
        retryCount: 0,
        clearStallReason: true,
        lastProgressAt: DateTime.now(),
      ),
    );
    enqueue(localId);
  }

  Future<void> _resumePending() async {
    final store = MeetingDraftStore.instance;
    for (final d in store.drafts) {
      if (d.state == DraftUploadState.pending || d.state == DraftUploadState.uploading) {
        enqueue(d.localId);
      }
    }
  }

  void _pump() {
    if (!_running || _busy || _queue.isEmpty) return;
    _busy = true;
    final id = _queue.removeAt(0);
    unawaited(_process(id));
  }

  Future<void> _process(String localId) async {
    if (!_running) {
      _finishJob();
      return;
    }
    _activeLocalId = localId;
    notifyListeners();

    final store = MeetingDraftStore.instance;
    var draft = store.draftById(localId);
    if (draft == null) {
      _finishJob();
      return;
    }

    if (!await File(draft.filePath).exists()) {
      await store.removeDraft(localId);
      _finishJob();
      return;
    }

    draft = draft.copyWith(
      state: DraftUploadState.uploading,
      lastProgressAt: DateTime.now(),
    );
    await store.updateDraft(draft);

    final draftTitle = draft.title;
    await MeetingBackgroundUpload.activate(
      title: '正在上传会议录音',
      text: '$draftTitle · 准备中',
    );

    ApiResult<int> r;
    try {
      r = await CosMultipartUploader.instance.uploadDraft(
        draft,
        onProgress: (p) async {
          final cur = store.draftById(localId);
          if (cur == null) return;
          final pct = (p * 100).round();
          await MeetingBackgroundUpload.updateNotification(
            title: '正在上传会议录音',
            text: '$draftTitle · $pct%',
          );
          await store.updateDraft(
            cur.copyWith(
              uploadProgress: p,
              lastProgressAt: DateTime.now(),
              state: DraftUploadState.uploading,
            ),
          );
          notifyListeners();
        },
      );

      if (r.code == -2) {
        r = await _uploadViaBff(draft, localId);
      }
    } finally {
      if (_queue.isEmpty && !_hasScheduledRetry) {
        await MeetingBackgroundUpload.deactivate();
      }
    }

    draft = store.draftById(localId);
    if (draft == null) {
      _finishJob();
      return;
    }

    if (r.ok && r.data != null && r.data! > 0) {
      await store.removeDraft(localId);
      await MeetingSessionStore.instance.refreshList();
      _finishJob();
      return;
    }

    await _handleFailure(localId, draft, r.message);
    _finishJob();
  }

  Future<ApiResult<int>> _uploadViaBff(MeetingDraft draft, String localId) async {
    final store = MeetingDraftStore.instance;
    final filename = draft.filePath.split(Platform.pathSeparator).last;
    return MeetingApi.createSessionFromFile(
      draft.filePath,
      filename,
      title: draft.title,
      durationSec: draft.durationSec,
      onProgress: (p) async {
        final cur = store.draftById(localId);
        if (cur == null) return;
        final pct = (p * 100).round();
        await MeetingBackgroundUpload.updateNotification(
          title: '正在上传会议录音',
          text: '${cur.title} · $pct%',
        );
        await store.updateDraft(
          cur.copyWith(
            uploadProgress: p,
            lastProgressAt: DateTime.now(),
            state: DraftUploadState.uploading,
          ),
        );
        notifyListeners();
      },
    );
  }

  Future<void> _handleFailure(String localId, MeetingDraft draft, String message) async {
    final store = MeetingDraftStore.instance;
    final isOffline = _looksLikeNetworkError(message);
    final nextRetry = draft.retryCount;
    if (nextRetry >= _retryDelays.length) {
      await store.updateDraft(
        draft.copyWith(
          state: isOffline ? DraftUploadState.pending : DraftUploadState.stalled,
          stallReason: isOffline ? null : (message.isNotEmpty ? message : '上传失败'),
          uploadProgress: draft.uploadProgress,
        ),
      );
      return;
    }

    await store.updateDraft(
      draft.copyWith(
        state: DraftUploadState.pending,
        retryCount: nextRetry + 1,
        uploadProgress: draft.uploadProgress,
      ),
    );
    _scheduleRetry(localId, _retryDelays[nextRetry]);
  }

  bool _looksLikeNetworkError(String message) {
    final m = message.toLowerCase();
    return m.contains('连接') ||
        m.contains('connection') ||
        m.contains('socket') ||
        m.contains('network') ||
        m.contains('timeout') ||
        m.contains('中断');
  }

  bool get _hasScheduledRetry => _retryTimer?.isActive ?? false;

  void _scheduleRetry(String localId, Duration delay) {
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      if (!_running) return;
      enqueue(localId);
    });
  }

  void _finishJob() {
    _busy = false;
    _activeLocalId = null;
    notifyListeners();
    _pump();
  }
}
