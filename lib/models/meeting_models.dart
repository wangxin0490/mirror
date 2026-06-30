class MeetingSessionSummary {
  const MeetingSessionSummary({
    required this.id,
    required this.title,
    required this.status,
    required this.durationSec,
    this.minutesPreview = '',
    this.errorMessage = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String title;
  final String status;
  final int durationSec;
  final String minutesPreview;
  final String errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory MeetingSessionSummary.fromJson(Map<String, dynamic> j) {
    return MeetingSessionSummary(
      id: j['id'] as int? ?? 0,
      title: j['title'] as String? ?? '',
      status: j['status'] as String? ?? '',
      durationSec: j['duration_sec'] as int? ?? 0,
      minutesPreview: j['minutes_preview'] as String? ?? '',
      errorMessage: j['error_message'] as String? ?? '',
      createdAt: _parseTime(j['created_at']),
      updatedAt: _parseTime(j['updated_at']),
    );
  }

  bool get isProcessing =>
      status == 'uploading' ||
      status == 'uploaded' ||
      status == 'transcribing' ||
      status == 'generating';

  String get statusLabel => switch (status) {
    'uploading' => '上传中',
    'uploaded' => '已上传',
    'transcribing' => '转写中',
    'generating' => '生成纪要',
    'done' => '已完成',
    'failed' => '失败',
    _ => status,
  };

  /// 用户可见的错误提示（不含状态码、JSON 等技术细节）。
  String get friendlyErrorMessage {
    final msg = errorMessage.trim();
    if (msg.isEmpty) return '';
    if (msg.contains('{') || msg.contains('request id:')) return '处理失败，请稍后重试';
    const prefixes = [
      'meeting api 401: ',
      'meeting api 403: ',
      'meeting api 404: ',
      'meeting api 400: ',
      'meeting api 500: ',
      'meeting api 502: ',
      'login: ',
      'transcribe-file: ',
      'transcribe wait: ',
      'minutes-generation: ',
      'minutes wait: ',
    ];
    for (final p in prefixes) {
      if (msg.startsWith(p)) return '处理失败，请稍后重试';
    }
    return msg;
  }
}

class MeetingSessionDetail extends MeetingSessionSummary {
  const MeetingSessionDetail({
    required super.id,
    required super.title,
    required super.status,
    required super.durationSec,
    super.minutesPreview,
    super.errorMessage,
    required super.createdAt,
    required super.updatedAt,
    this.transcriptText = '',
    this.minutesMarkdown = '',
    this.originalFilename = '',
  });

  final String transcriptText;
  final String minutesMarkdown;
  final String originalFilename;

  factory MeetingSessionDetail.fromJson(Map<String, dynamic> j) {
    return MeetingSessionDetail(
      id: j['id'] as int? ?? 0,
      title: j['title'] as String? ?? '',
      status: j['status'] as String? ?? '',
      durationSec: j['duration_sec'] as int? ?? 0,
      minutesPreview: j['minutes_preview'] as String? ?? '',
      errorMessage: j['error_message'] as String? ?? '',
      createdAt: _parseTime(j['created_at']),
      updatedAt: _parseTime(j['updated_at']),
      transcriptText: j['transcript_text'] as String? ?? '',
      minutesMarkdown: j['minutes_markdown'] as String? ?? '',
      originalFilename: j['original_filename'] as String? ?? '',
    );
  }
}

class MeetingListPage {
  const MeetingListPage({
    required this.items,
    required this.hasMore,
    this.totalCount = 0,
  });

  final List<MeetingSessionSummary> items;
  final bool hasMore;
  final int totalCount;

  factory MeetingListPage.fromJson(Map<String, dynamic> j) {
    final raw = j['items'] as List<dynamic>? ?? [];
    return MeetingListPage(
      items: raw
          .map((e) => MeetingSessionSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasMore: j['has_more'] as bool? ?? false,
      totalCount: j['total_count'] as int? ?? 0,
    );
  }
}

class MeetingStatusEvent {
  const MeetingStatusEvent({
    required this.sessionId,
    required this.status,
    this.title = '',
    this.minutesPreview = '',
    this.errorMessage = '',
  });

  final int sessionId;
  final String status;
  final String title;
  final String minutesPreview;
  final String errorMessage;

  factory MeetingStatusEvent.fromJson(Map<String, dynamic> j) {
    return MeetingStatusEvent(
      sessionId: j['session_id'] as int? ?? 0,
      status: j['status'] as String? ?? '',
      title: j['title'] as String? ?? '',
      minutesPreview: j['minutes_preview'] as String? ?? '',
      errorMessage: j['error_message'] as String? ?? '',
    );
  }
}

DateTime _parseTime(dynamic v) {
  if (v is String && v.isNotEmpty) {
    return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

/// 上传完成后（含转写/纪要失败）服务端可能已有录音，可尝试拉取播放地址。
bool meetingSessionMayHaveAudio(String status) {
  return switch (status) {
    'uploaded' || 'transcribing' || 'generating' || 'done' || 'failed' => true,
    _ => false,
  };
}

String meetingDurationLabel(int sec) {
  if (sec <= 0) return '—';
  final d = Duration(seconds: sec);
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}
