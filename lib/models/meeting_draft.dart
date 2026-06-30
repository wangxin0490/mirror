/// 会议录音本地草稿（上传前/上传中）。
enum DraftUploadState {
  pending,
  uploading,
  stalled;

  static DraftUploadState fromJson(String? v) => switch (v) {
        'uploading' => DraftUploadState.uploading,
        'stalled' => DraftUploadState.stalled,
        _ => DraftUploadState.pending,
      };

  String toJson() => name;
}

class MeetingDraft {
  const MeetingDraft({
    required this.localId,
    required this.filePath,
    required this.title,
    required this.durationSec,
    required this.createdAt,
    this.state = DraftUploadState.pending,
    this.uploadToken,
    this.cosKey,
    this.cosUploadId,
    this.partSize = 5 * 1024 * 1024,
    this.completedParts = const [],
    this.partEtags = const {},
    this.serverSessionId,
    this.stallReason,
    this.uploadProgress = 0,
    this.lastProgressAt,
    this.retryCount = 0,
  });

  final String localId;
  final String filePath;
  final String title;
  final int durationSec;
  final DateTime createdAt;
  final DraftUploadState state;
  final String? uploadToken;
  final String? cosKey;
  final String? cosUploadId;
  final int partSize;
  final List<int> completedParts;
  final Map<int, String> partEtags;
  final int? serverSessionId;
  final String? stallReason;
  final double uploadProgress;
  final DateTime? lastProgressAt;
  final int retryCount;

  bool get isLocalOnly => serverSessionId == null || serverSessionId! <= 0;

  String get statusLabel => switch (state) {
        DraftUploadState.uploading when uploadProgress > 0 =>
          '上传中 · ${(uploadProgress * 100).round()}%',
        DraftUploadState.uploading => '上传中',
        DraftUploadState.stalled => '上传受阻',
        DraftUploadState.pending => '等待网络',
      };

  MeetingDraft copyWith({
    String? filePath,
    String? title,
    int? durationSec,
    DateTime? createdAt,
    DraftUploadState? state,
    String? uploadToken,
    String? cosKey,
    String? cosUploadId,
    int? partSize,
    List<int>? completedParts,
    Map<int, String>? partEtags,
    int? serverSessionId,
    String? stallReason,
    double? uploadProgress,
    DateTime? lastProgressAt,
    int? retryCount,
    bool clearStallReason = false,
    bool clearServerSessionId = false,
  }) {
    return MeetingDraft(
      localId: localId,
      filePath: filePath ?? this.filePath,
      title: title ?? this.title,
      durationSec: durationSec ?? this.durationSec,
      createdAt: createdAt ?? this.createdAt,
      state: state ?? this.state,
      uploadToken: uploadToken ?? this.uploadToken,
      cosKey: cosKey ?? this.cosKey,
      cosUploadId: cosUploadId ?? this.cosUploadId,
      partSize: partSize ?? this.partSize,
      completedParts: completedParts ?? this.completedParts,
      partEtags: partEtags ?? this.partEtags,
      serverSessionId: clearServerSessionId ? null : (serverSessionId ?? this.serverSessionId),
      stallReason: clearStallReason ? null : (stallReason ?? this.stallReason),
      uploadProgress: uploadProgress ?? this.uploadProgress,
      lastProgressAt: lastProgressAt ?? this.lastProgressAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'local_id': localId,
        'file_path': filePath,
        'title': title,
        'duration_sec': durationSec,
        'created_at': createdAt.toIso8601String(),
        'state': state.toJson(),
        if (uploadToken != null) 'upload_token': uploadToken,
        if (cosKey != null) 'cos_key': cosKey,
        if (cosUploadId != null) 'cos_upload_id': cosUploadId,
        'part_size': partSize,
        'completed_parts': completedParts,
        'part_etags': partEtags.map((k, v) => MapEntry('$k', v)),
        if (serverSessionId != null) 'server_session_id': serverSessionId,
        if (stallReason != null) 'stall_reason': stallReason,
        'upload_progress': uploadProgress,
        if (lastProgressAt != null) 'last_progress_at': lastProgressAt!.toIso8601String(),
        'retry_count': retryCount,
      };

  factory MeetingDraft.fromJson(Map<String, dynamic> j) {
    final etagsRaw = j['part_etags'] as Map<String, dynamic>? ?? {};
    final etags = <int, String>{};
    for (final e in etagsRaw.entries) {
      final n = int.tryParse(e.key);
      if (n != null) etags[n] = e.value as String? ?? '';
    }
    return MeetingDraft(
      localId: j['local_id'] as String? ?? '',
      filePath: j['file_path'] as String? ?? '',
      title: j['title'] as String? ?? '',
      durationSec: j['duration_sec'] as int? ?? 0,
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      state: DraftUploadState.fromJson(j['state'] as String?),
      uploadToken: j['upload_token'] as String?,
      cosKey: j['cos_key'] as String?,
      cosUploadId: j['cos_upload_id'] as String?,
      partSize: j['part_size'] as int? ?? 5 * 1024 * 1024,
      completedParts: (j['completed_parts'] as List<dynamic>? ?? []).map((e) => e as int).toList(),
      partEtags: etags,
      serverSessionId: j['server_session_id'] as int?,
      stallReason: j['stall_reason'] as String?,
      uploadProgress: (j['upload_progress'] as num?)?.toDouble() ?? 0,
      lastProgressAt: DateTime.tryParse(j['last_progress_at'] as String? ?? ''),
      retryCount: j['retry_count'] as int? ?? 0,
    );
  }
}
