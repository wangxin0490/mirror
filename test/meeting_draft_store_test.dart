import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/models/meeting_draft.dart';
import 'package:mirror_mobile/services/meeting_draft_store.dart';

List<int> _fakeAudioBytes(int durationSec, {String ext = 'wav'}) {
  final minBps = ext == 'wav' ? 16000 : 4096;
  return List<int>.filled(durationSec * minBps, 1);
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meeting_draft_test_');
    MeetingDraftStore.debugBasePath = tempDir.path;
    MeetingDraftStore.instance.drafts = [];
  });

  tearDown(() async {
    MeetingDraftStore.debugBasePath = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('saveFromRecording persists and restore reloads draft', () async {
    final store = MeetingDraftStore.instance;
    final draft = await store.saveFromRecording(
      bytes: _fakeAudioBytes(120, ext: 'm4a'),
      filename: 'test.m4a',
      title: '测试会议',
      durationSec: 120,
    );
    expect(draft.localId, isNotEmpty);
    expect(await File(draft.filePath).exists(), isTrue);

    store.drafts = [];
    await store.restore();

    expect(store.drafts, hasLength(1));
    expect(store.drafts.first.title, '测试会议');
    expect(store.drafts.first.durationSec, 120);
    expect(store.drafts.first.state, DraftUploadState.pending);
  });

  test('restore resets uploading to pending', () async {
    final store = MeetingDraftStore.instance;
    final draft = await store.saveFromRecording(
      bytes: _fakeAudioBytes(1),
      filename: 'a.wav',
      title: 'A',
      durationSec: 1,
    );
    await store.updateDraft(draft.copyWith(state: DraftUploadState.uploading));

    store.drafts = [];
    await store.restore();

    expect(store.drafts.single.state, DraftUploadState.pending);
  });

  test('restore marks drafts older than 7 days as stalled', () async {
    final store = MeetingDraftStore.instance;
    final draft = await store.saveFromRecording(
      bytes: _fakeAudioBytes(3),
      filename: 'old.wav',
      title: '旧草稿',
      durationSec: 3,
    );
    await store.updateDraft(
      draft.copyWith(createdAt: DateTime.now().subtract(const Duration(days: 8))),
    );

    store.drafts = [];
    await store.restore();

    expect(store.drafts.single.state, DraftUploadState.stalled);
    expect(store.drafts.single.stallReason, contains('7 天'));
  });

  test('restore marks suspiciously small audio as stalled', () async {
    final store = MeetingDraftStore.instance;
    final localId = 'small_draft_1';
    final path = '${tempDir.path}/$localId.wav';
    await File(path).writeAsBytes(List<int>.filled(5461, 0));

    final idx = File('${tempDir.path}/index.json');
    await idx.writeAsString(
      jsonEncode([
        {
          'local_id': localId,
          'file_path': path,
          'title': '坏录音',
          'duration_sec': 60,
          'created_at': DateTime.now().toIso8601String(),
          'state': 'pending',
        },
      ]),
    );

    store.drafts = [];
    await store.restore();

    expect(store.drafts.single.state, DraftUploadState.stalled);
    expect(store.drafts.single.stallReason, contains('异常偏小'));
  });

  test('removeDraft deletes file and index entry', () async {
    final store = MeetingDraftStore.instance;
    final draft = await store.saveFromRecording(
      bytes: _fakeAudioBytes(2),
      filename: 'b.wav',
      title: 'B',
      durationSec: 2,
    );
    final path = draft.filePath;
    await store.removeDraft(draft.localId);

    expect(store.drafts, isEmpty);
    expect(await File(path).exists(), isFalse);
  });
}
