import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../api/api_result.dart';
import '../api/kb_api.dart';
import '../models/kb_models.dart';
import '../services/kb_doc_sync_client.dart';

/// 文档是否仍处于上传/解析流程中。
bool kbHasPendingDocs(Iterable<KbDocumentItem> docs) => docs.any(
      (d) =>
          d.parseStatus == 'uploading' ||
          d.parseStatus == 'uploaded' ||
          d.parseStatus == 'parsing',
    );

/// 比较两次详情中各文档解析状态是否变化。
bool kbDocsStatusChanged(KbDetail? before, KbDetail? after) {
  if (identical(before, after)) return false;
  if (before == null || after == null) return before != after;
  if (before.readyDocCount != after.readyDocCount) return true;
  final prev = {for (final d in before.documents) d.id: d.parseStatus};
  final next = {for (final d in after.documents) d.id: d.parseStatus};
  if (prev.length != next.length) return true;
  for (final e in prev.entries) {
    if (next[e.key] != e.value) return true;
  }
  return false;
}

/// 将轻量状态合并进详情；文档集合不一致时返回 null（需全量 reload）。
KbDetail? kbMergeSyncItems(KbDetail? detail, List<KbDocStatusItem> items, int readyDocCount) {
  if (detail == null) return null;
  if (items.length != detail.documents.length) return null;
  final byId = {for (final i in items) i.id: i};
  var changed = detail.readyDocCount != readyDocCount;
  final nextDocs = <KbDocumentItem>[];
  for (final d in detail.documents) {
    final u = byId[d.id];
    if (u == null) return null;
    if (u.parseStatus != d.parseStatus || u.chunkNum != d.chunkNum || u.parseError != d.parseError) {
      changed = true;
      nextDocs.add(KbDocumentItem(
        id: d.id,
        folderId: d.folderId,
        originalFilename: d.originalFilename,
        fileSize: d.fileSize,
        mimeType: d.mimeType,
        parseStatus: u.parseStatus,
        chunkNum: u.chunkNum,
        parseError: u.parseError,
        sourceType: d.sourceType,
        sourceUrl: d.sourceUrl,
      ));
    } else {
      nextDocs.add(d);
    }
  }
  if (!changed) return detail;
  return KbDetail(
    id: detail.id,
    name: detail.name,
    folders: detail.folders,
    documents: nextDocs,
    readyDocCount: readyDocCount,
    isOwner: detail.isOwner,
  );
}

/// 知识库 API 状态。
class KbStore extends ChangeNotifier {
  KbStore._();

  static final KbStore instance = KbStore._();

  static const _fallbackIntervalsSec = [5, 8, 12, 15];

  bool loading = false;
  String? error;
  KbMineList? mine;
  List<KbSubscribedItem> subscribed = [];

  bool scopeSearchLoading = false;
  bool scopeSearchLoadingMore = false;
  String scopeSearchQuery = '';
  String scopeSearchType = 'personal';
  List<KbListItem> scopeSearchMine = [];
  List<KbSubscribedItem> scopeSearchSubscribed = [];
  String? scopeSearchCursor;
  bool scopeSearchHasMore = false;

  KbDetail? detail;
  int? detailKbId;
  List<int> activeKbIds = [];
  String activeScopeLabel = '个人知识库';
  String activeScopeType = 'personal';

  Timer? _fallbackTimer;
  bool _syncActive = false;
  int _syncGeneration = 0;
  int _fallbackAttempt = 0;
  bool _usingFallback = false;

  KbUploadLimits? _uploadLimits;

  KbUploadLimits get uploadLimits => _uploadLimits ?? KbUploadLimits.defaults;

  Future<KbUploadLimits> ensureUploadLimits() async {
    if (_uploadLimits != null) return _uploadLimits!;
    try {
      _uploadLimits = await KbApi.fetchUploadLimits();
    } catch (_) {
      _uploadLimits = KbUploadLimits.defaults;
    }
    return _uploadLimits!;
  }

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      mine = await KbApi.listMine();
      subscribed = await KbApi.listSubscribed();
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> searchLibraries(String scopeType, String q, {bool loadMore = false}) async {
    if (loadMore) {
      if (!scopeSearchHasMore || scopeSearchLoadingMore || scopeSearchLoading) return;
      scopeSearchLoadingMore = true;
    } else {
      scopeSearchLoading = true;
      scopeSearchQuery = q.trim();
      scopeSearchType = scopeType;
      scopeSearchCursor = null;
      scopeSearchMine = [];
      scopeSearchSubscribed = [];
      scopeSearchHasMore = false;
    }
    error = null;
    notifyListeners();
    try {
      if (scopeType == 'subscribed') {
        final page = await KbApi.searchSubscribed(
          q: loadMore ? scopeSearchQuery : q.trim(),
          cursor: loadMore ? scopeSearchCursor : null,
        );
        if (page != null) {
          scopeSearchSubscribed = loadMore ? [...scopeSearchSubscribed, ...page.items] : page.items;
          scopeSearchCursor = page.nextCursor.isEmpty ? null : page.nextCursor;
          scopeSearchHasMore = page.hasMore;
        }
      } else {
        final page = await KbApi.searchMine(
          q: loadMore ? scopeSearchQuery : q.trim(),
          cursor: loadMore ? scopeSearchCursor : null,
        );
        if (page != null) {
          scopeSearchMine = loadMore ? [...scopeSearchMine, ...page.items] : page.items;
          scopeSearchCursor = page.nextCursor.isEmpty ? null : page.nextCursor;
          scopeSearchHasMore = page.hasMore;
        }
      }
    } catch (e) {
      if (!loadMore) {
        scopeSearchMine = [];
        scopeSearchSubscribed = [];
      }
      error = e.toString();
    }
    scopeSearchLoading = false;
    scopeSearchLoadingMore = false;
    notifyListeners();
  }

  void clearScopeSearch() {
    scopeSearchLoading = false;
    scopeSearchLoadingMore = false;
    scopeSearchQuery = '';
    scopeSearchMine = [];
    scopeSearchSubscribed = [];
    scopeSearchCursor = null;
    scopeSearchHasMore = false;
    notifyListeners();
  }

  Future<KbListItem?> createKb(String name, {String coverUrl = ''}) async {
    final item = await KbApi.createKb(name, coverUrl: coverUrl);
    await refresh();
    return item;
  }

  Future<KbListItem?> updateKb(int kbId, {required String name, String? coverUrl}) async {
    final item = await KbApi.patchKb(kbId, name: name, coverUrl: coverUrl);
    await refresh();
    if (detailKbId == kbId) {
      await loadDetail(kbId, silent: true);
    }
    return item;
  }

  Future<bool> deleteKb(int kbId) async {
    final ok = await KbApi.deleteKb(kbId);
    if (ok) {
      if (detailKbId == kbId) {
        detail = null;
        detailKbId = null;
        stopDetailPoll();
      }
      await refresh();
    }
    return ok;
  }

  Future<({bool ok, String? message})> subscribe(int kbId) async {
    final r = await KbApi.subscribe(kbId);
    if (r.ok) {
      await refresh();
      return (ok: true, message: null);
    }
    return (ok: false, message: r.message);
  }

  Future<({bool ok, String? message})> cancelSubscription(int subId) async {
    final r = await KbApi.cancelSubscription(subId);
    if (r.ok) {
      await refresh();
      return (ok: true, message: null);
    }
    return (ok: false, message: r.message);
  }

  Future<({bool ok, String? message})> deleteDocument(int kbId, int docId) async {
    final r = await KbApi.deleteDocument(kbId, docId);
    if (r.ok) {
      if (detailKbId == kbId) {
        await loadDetail(kbId, silent: true);
      }
      await refresh();
      return (ok: true, message: null);
    }
    return (ok: false, message: r.message);
  }

  void setActiveScope({required List<int> kbIds, required String label, required String scopeType}) {
    activeKbIds = kbIds;
    activeScopeLabel = label;
    activeScopeType = scopeType;
  }

  Future<KbDetail?> loadDetail(int kbId, {bool silent = false}) async {
    if (!silent) {
      loading = true;
      notifyListeners();
    }
    detailKbId = kbId;
    try {
      detail = await KbApi.getDetail(kbId);
      if (_syncActive) _ensureSync();
    } catch (e) {
      if (!silent) error = e.toString();
    }
    if (!silent) loading = false;
    notifyListeners();
    return detail;
  }

  /// 进入知识库详情页时订阅解析状态 SSE。
  void startDetailPoll() {
    stopDetailPoll();
    _syncActive = true;
    _fallbackAttempt = 0;
    _usingFallback = false;
    _ensureSync();
  }

  /// 离开详情页时断开 SSE / 降级轮询。
  void stopDetailPoll() {
    _syncActive = false;
    _syncGeneration++;
    _fallbackAttempt = 0;
    _usingFallback = false;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
  }

  void _ensureSync() {
    if (!_syncActive || detailKbId == null) return;
    final docs = detail?.documents ?? [];
    if (!kbHasPendingDocs(docs)) return;
    if (_usingFallback) {
      _scheduleFallbackPoll();
      return;
    }
    final gen = _syncGeneration;
    unawaited(_openSyncStream(gen));
  }

  Future<void> _openSyncStream(int gen) async {
    final kbId = detailKbId;
    if (!_syncActive || gen != _syncGeneration || kbId == null) return;
    try {
      await KbDocSyncClient.stream(
        kbId: kbId,
        onSnapshot: (snap) {
          if (!_syncActive || gen != _syncGeneration) return;
          unawaited(_applySyncSnapshot(snap));
        },
        onUpdate: (update) {
          if (!_syncActive || gen != _syncGeneration) return;
          _applySyncUpdate(update);
        },
        onDone: (_) {
          if (!_syncActive || gen != _syncGeneration) return;
          unawaited(_onSyncComplete());
        },
        onError: (_) {
          if (!_syncActive || gen != _syncGeneration) return;
          _startFallbackPoll(gen);
        },
      );
    } catch (_) {
      if (_syncActive && gen == _syncGeneration) {
        _startFallbackPoll(gen);
      }
      return;
    }
    if (_syncActive &&
        gen == _syncGeneration &&
        kbHasPendingDocs(detail?.documents ?? [])) {
      _startFallbackPoll(gen);
    }
  }

  void _startFallbackPoll(int gen) {
    if (!_syncActive || gen != _syncGeneration) return;
    _usingFallback = true;
    _fallbackAttempt = 0;
    _scheduleFallbackPoll();
  }

  void _scheduleFallbackPoll() {
    _fallbackTimer?.cancel();
    if (!_syncActive || detailKbId == null) return;
    final idx = math.min(_fallbackAttempt, _fallbackIntervalsSec.length - 1);
    _fallbackTimer = Timer(Duration(seconds: _fallbackIntervalsSec[idx]), _fallbackTick);
  }

  Future<void> _fallbackTick() async {
    if (!_syncActive || detailKbId == null) return;
    final kbId = detailKbId!;
    final previous = detail;
    try {
      final snap = await KbApi.getDocumentSyncStatus(kbId);
      if (!_syncActive || detailKbId != kbId || snap == null) return;
      await _applySyncSnapshot(snap);
      if (snap.pending) {
        _fallbackAttempt++;
        _scheduleFallbackPoll();
        return;
      }
      await _onSyncComplete();
    } catch (_) {
      if (_syncActive && detailKbId == kbId && kbHasPendingDocs(previous?.documents ?? [])) {
        _fallbackAttempt++;
        _scheduleFallbackPoll();
      }
    }
  }

  Future<void> _applySyncSnapshot(KbDocSyncSnapshot snap) async {
    final merged = kbMergeSyncItems(detail, snap.items, snap.readyDocCount);
    if (merged == null && detailKbId != null) {
      await loadDetail(detailKbId!, silent: true);
      return;
    }
    if (merged != null && !identical(merged, detail)) {
      detail = merged;
      notifyListeners();
    }
    if (!snap.pending) {
      await _onSyncComplete();
    }
  }

  void _applySyncUpdate(KbDocSyncUpdate update) {
    final d = detail;
    if (d == null) return;
    final u = update.document;
    var changed = d.readyDocCount != update.readyDocCount;
    final nextDocs = <KbDocumentItem>[];
    var found = false;
    for (final doc in d.documents) {
      if (doc.id != u.id) {
        nextDocs.add(doc);
        continue;
      }
      found = true;
      if (doc.parseStatus != u.parseStatus || doc.chunkNum != u.chunkNum || doc.parseError != u.parseError) {
        changed = true;
        nextDocs.add(KbDocumentItem(
          id: doc.id,
          folderId: doc.folderId,
          originalFilename: doc.originalFilename,
          fileSize: doc.fileSize,
          mimeType: doc.mimeType,
          parseStatus: u.parseStatus,
          chunkNum: u.chunkNum,
          parseError: u.parseError,
          sourceType: doc.sourceType,
          sourceUrl: doc.sourceUrl,
        ));
      } else {
        nextDocs.add(doc);
      }
    }
    if (!found) {
      if (detailKbId != null) unawaited(loadDetail(detailKbId!, silent: true));
      return;
    }
    if (!changed) return;
    detail = KbDetail(
      id: d.id,
      name: d.name,
      folders: d.folders,
      documents: nextDocs,
      readyDocCount: update.readyDocCount,
      isOwner: d.isOwner,
    );
    notifyListeners();
  }

  Future<void> _onSyncComplete() async {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _fallbackAttempt = 0;
    _usingFallback = false;
    await refresh();
  }

  Future<KbFolderItem?> createFolder(int kbId, String name) async {
    final f = await KbApi.createFolder(kbId, name);
    await loadDetail(kbId, silent: true);
    return f;
  }

  Future<ApiResult<KbUploadResult>> uploadDocument(
    int kbId,
    List<int> bytes,
    String filename, {
    int? folderId,
    void Function(double progress)? onProgress,
  }) async {
    final r = await KbApi.uploadDocument(kbId, bytes, filename, folderId: folderId, onProgress: onProgress);
    if (r.ok) {
      await loadDetail(kbId, silent: true);
      await refresh();
      if (_syncActive) _ensureSync();
    }
    return r;
  }

  /// 导入网页到指定知识库；成功后刷新详情与列表并维持文档 SSE。
  Future<ApiResult<void>> importWebDocument(
    int kbId,
    String url, {
    String? name,
    int? folderId,
  }) async {
    final r = await KbApi.importWebDocument(kbId, url, name: name, folderId: folderId);
    if (r.ok) {
      await loadDetail(kbId, silent: true);
      await refresh();
      if (_syncActive) _ensureSync();
    }
    return r;
  }

  @override
  void dispose() {
    stopDetailPoll();
    super.dispose();
  }
}
