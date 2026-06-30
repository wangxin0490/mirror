import 'meeting_draft.dart';
import 'meeting_models.dart';

/// Hub 列表联合项：本地草稿或服务端 session。
sealed class MeetingHubItem {
  const MeetingHubItem();

  DateTime get sortTime;
  String get title;
}

class MeetingHubDraftItem extends MeetingHubItem {
  const MeetingHubDraftItem(this.draft);

  final MeetingDraft draft;

  @override
  DateTime get sortTime => draft.createdAt;

  @override
  String get title => draft.title;
}

class MeetingHubSessionItem extends MeetingHubItem {
  const MeetingHubSessionItem(this.session);

  final MeetingSessionSummary session;

  @override
  DateTime get sortTime => session.createdAt;

  @override
  String get title => session.title;
}

String _sessionDedupKey(MeetingSessionSummary s) => '${s.title}|${s.durationSec}';

/// 合并草稿与服务端列表；隐藏已关联 session，并折叠上传中的孤儿/重复记录。
List<MeetingHubItem> mergeMeetingHubItems({
  required List<MeetingDraft> drafts,
  required List<MeetingSessionSummary> sessions,
}) {
  final hiddenSessionIds = <int>{};
  for (final d in drafts) {
    final sid = d.serverSessionId;
    if (sid != null && sid > 0) hiddenSessionIds.add(sid);
  }

  final draftKeys = drafts.map((d) => '${d.title}|${d.durationSec}').toSet();

  // 同标题+时长多条 uploading：仅保留 id 最大（最新）的一条。
  final newestUploadingByKey = <String, int>{};
  for (final s in sessions) {
    if (s.status != 'uploading') continue;
    final key = _sessionDedupKey(s);
    final prev = newestUploadingByKey[key];
    if (prev == null || s.id > prev) newestUploadingByKey[key] = s.id;
  }

  final visibleSessions = sessions.where((s) {
    if (hiddenSessionIds.contains(s.id)) return false;
    if (s.status == 'uploading') {
      if (draftKeys.contains(_sessionDedupKey(s))) return false;
      final keeper = newestUploadingByKey[_sessionDedupKey(s)];
      if (keeper != null && s.id != keeper) return false;
    }
    return true;
  });

  final merged = <MeetingHubItem>[
    ...drafts.map(MeetingHubDraftItem.new),
    ...visibleSessions.map(MeetingHubSessionItem.new),
  ];
  merged.sort((a, b) => b.sortTime.compareTo(a.sortTime));
  return merged;
}
