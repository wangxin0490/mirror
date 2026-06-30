import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/models/meeting_draft.dart';
import 'package:mirror_mobile/models/meeting_hub_item.dart';
import 'package:mirror_mobile/models/meeting_models.dart';

void main() {
  test('merge hides server session when draft references serverSessionId', () {
    final draft = MeetingDraft(
      localId: 'd1',
      filePath: '/x.m4a',
      title: 'Draft',
      durationSec: 60,
      createdAt: DateTime(2026, 6, 9, 14),
      serverSessionId: 42,
    );
    final session = MeetingSessionSummary(
      id: 42,
      title: 'Server',
      status: 'uploading',
      durationSec: 60,
      createdAt: DateTime(2026, 6, 9, 13),
      updatedAt: DateTime(2026, 6, 9, 13),
    );
    final merged = mergeMeetingHubItems(drafts: [draft], sessions: [session]);
    expect(merged, hasLength(1));
    expect(merged.first, isA<MeetingHubDraftItem>());
  });

  test('merge hides orphan uploading session when matching draft exists', () {
    final draft = MeetingDraft(
      localId: 'd1',
      filePath: '/x.m4a',
      title: '会议录音_20260610172759',
      durationSec: 7,
      createdAt: DateTime(2026, 6, 10, 17, 28),
      state: DraftUploadState.pending,
    );
    final orphan = MeetingSessionSummary(
      id: 99,
      title: '会议录音_20260610172759',
      status: 'uploading',
      durationSec: 7,
      createdAt: DateTime(2026, 6, 10, 17, 27),
      updatedAt: DateTime(2026, 6, 10, 17, 27),
    );
    final merged = mergeMeetingHubItems(drafts: [draft], sessions: [orphan]);
    expect(merged, hasLength(1));
    expect(merged.first, isA<MeetingHubDraftItem>());
  });

  test('merge dedupes multiple orphan uploading sessions with same title', () {
    final older = MeetingSessionSummary(
      id: 10,
      title: '会议录音_20260610172759',
      status: 'uploading',
      durationSec: 7,
      createdAt: DateTime(2026, 6, 10, 17, 27),
      updatedAt: DateTime(2026, 6, 10, 17, 27),
    );
    final newer = MeetingSessionSummary(
      id: 12,
      title: '会议录音_20260610172759',
      status: 'uploading',
      durationSec: 7,
      createdAt: DateTime(2026, 6, 10, 17, 28),
      updatedAt: DateTime(2026, 6, 10, 17, 28),
    );
    final merged = mergeMeetingHubItems(drafts: [], sessions: [older, newer]);
    expect(merged, hasLength(1));
    final item = merged.first as MeetingHubSessionItem;
    expect(item.session.id, 12);
  });
}
