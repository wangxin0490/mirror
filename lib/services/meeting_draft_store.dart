import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/meeting_draft.dart';
import 'base_voice_session_controller.dart';

/// 会议录音本地草稿持久化（`meeting_drafts/` + `index.json`）。
class MeetingDraftStore extends ChangeNotifier {
  MeetingDraftStore._();

  static final MeetingDraftStore instance = MeetingDraftStore._();

  /// 测试注入目录，跳过 path_provider。
  static String? debugBasePath;

  List<MeetingDraft> drafts = [];

  static const _stallAfter = Duration(hours: 24);
  static const retentionAfter = Duration(days: 7);

  Future<Directory> _draftsDir() async {
    if (kIsWeb) {
      throw UnsupportedError('Meeting drafts require native file storage');
    }
    if (debugBasePath != null) {
      final d = Directory(debugBasePath!);
      await d.create(recursive: true);
      return d;
    }
    final root = await getApplicationDocumentsDirectory();
    final d = Directory('${root.path}/meeting_drafts');
    await d.create(recursive: true);
    return d;
  }

  Future<File> _indexFile() async {
    final dir = await _draftsDir();
    return File('${dir.path}/index.json');
  }

  MeetingDraft? draftById(String localId) {
    for (final d in drafts) {
      if (d.localId == localId) return d;
    }
    return null;
  }

  List<MeetingDraft> get expiredDrafts =>
      drafts.where((d) => DateTime.now().difference(d.createdAt) > retentionAfter).toList();

  bool get hasExpiredDrafts => expiredDrafts.isNotEmpty;

  /// 启动时恢复；将 uploading 重置为 pending 以便续传。
  Future<void> restore() async {
    if (kIsWeb) {
      drafts = [];
      notifyListeners();
      return;
    }
    final idx = await _indexFile();
    if (!await idx.exists()) {
      drafts = [];
      notifyListeners();
      return;
    }
    try {
      final raw = jsonDecode(await idx.readAsString()) as List<dynamic>;
      drafts = raw.map((e) => MeetingDraft.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[MeetingDraftStore] restore failed: $e');
      drafts = [];
    }

    final now = DateTime.now();
    final updated = <MeetingDraft>[];
    for (final d in drafts) {
      var next = d;
      if (d.state == DraftUploadState.uploading) {
        next = d.copyWith(state: DraftUploadState.pending);
      }
      if (now.difference(next.createdAt) > retentionAfter) {
        next = next.copyWith(
          state: DraftUploadState.stalled,
          stallReason: '草稿已超过 7 天，请删除或重新录制',
        );
      } else {
        final last = next.lastProgressAt ?? next.createdAt;
        if (next.state != DraftUploadState.stalled &&
            now.difference(last) > _stallAfter &&
            next.isLocalOnly) {
          next = next.copyWith(
            state: DraftUploadState.stalled,
            stallReason: '长时间未能完成上传',
          );
        }
      }
      if (!await File(next.filePath).exists()) continue;
      final fileSize = await File(next.filePath).length();
      final ext = _extFromFilename(next.filePath);
      final minBps = BaseVoiceSessionController.minBytesPerSecond(
        ext.replaceFirst('.', ''),
      );
      if (next.durationSec >= 1 && fileSize < next.durationSec * minBps) {
        next = next.copyWith(
          state: DraftUploadState.stalled,
          stallReason: '录音文件异常偏小（${fileSize} 字节），请删除后重新录制',
        );
      }
      updated.add(next);
    }
    drafts = updated;
    await _persist();
    notifyListeners();
  }

  /// 录完写入草稿目录。
  Future<MeetingDraft> saveFromRecording({
    required List<int> bytes,
    required String filename,
    required String title,
    required int durationSec,
  }) async {
    final dir = await _draftsDir();
    final localId = '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
    final ext = _extFromFilename(filename);
    final path = '${dir.path}/$localId$ext';
    final minBps = BaseVoiceSessionController.minBytesPerSecond(
      ext.replaceFirst('.', ''),
    );
    if (durationSec >= 1 && bytes.length < durationSec * minBps) {
      throw StateError(
        '录音文件异常偏小（${bytes.length} 字节 / ${durationSec}s），请重新录制',
      );
    }
    await File(path).writeAsBytes(bytes, flush: true);
    if (kDebugMode) {
      debugPrint(
        '[MeetingDraftStore] saved draft duration=${durationSec}s written=${bytes.length} path=$path',
      );
    }

    final draft = MeetingDraft(
      localId: localId,
      filePath: path,
      title: title.trim().isEmpty ? filename.replaceAll(RegExp(r'\.[^.]+$'), '') : title.trim(),
      durationSec: durationSec,
      createdAt: DateTime.now(),
      state: DraftUploadState.pending,
      lastProgressAt: DateTime.now(),
    );
    drafts.insert(0, draft);
    await _persist();
    notifyListeners();
    return draft;
  }

  Future<void> updateDraft(MeetingDraft draft) async {
    final i = drafts.indexWhere((d) => d.localId == draft.localId);
    if (i < 0) return;
    drafts[i] = draft;
    await _persist();
    notifyListeners();
  }

  Future<int> purgeExpiredDrafts() async {
    final ids = expiredDrafts.map((d) => d.localId).toList();
    for (final id in ids) {
      await removeDraft(id);
    }
    return ids.length;
  }

  Future<void> removeDraft(String localId) async {
    final d = draftById(localId);
    if (d != null) {
      try {
        final f = File(d.filePath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    drafts = drafts.where((e) => e.localId != localId).toList();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final idx = await _indexFile();
    final json = jsonEncode(drafts.map((d) => d.toJson()).toList());
    await idx.writeAsString(json, flush: true);
  }

  static String _extFromFilename(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot < 0) return '.m4a';
    return filename.substring(dot).toLowerCase();
  }
}
