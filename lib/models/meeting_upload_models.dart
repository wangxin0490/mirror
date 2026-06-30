/// COS 分片直传 API 模型。
class MeetingUploadInit {
  const MeetingUploadInit({
    required this.uploadToken,
    required this.sessionId,
    required this.cosKey,
    required this.uploadId,
    required this.partSize,
    required this.storage,
  });

  final String uploadToken;
  final int sessionId;
  final String cosKey;
  final String uploadId;
  final int partSize;
  final String storage;

  bool get isCos => storage == 'cos';

  factory MeetingUploadInit.fromJson(Map<String, dynamic> j) {
    return MeetingUploadInit(
      uploadToken: j['upload_token'] as String? ?? '',
      sessionId: j['session_id'] as int? ?? 0,
      cosKey: j['cos_key'] as String? ?? '',
      uploadId: j['upload_id'] as String? ?? '',
      partSize: j['part_size'] as int? ?? 5 * 1024 * 1024,
      storage: j['storage'] as String? ?? 'cos',
    );
  }
}

class MeetingUploadPart {
  const MeetingUploadPart({required this.partNumber, required this.etag});

  final int partNumber;
  final String etag;

  Map<String, dynamic> toJson() => {
        'part_number': partNumber,
        'etag': etag,
      };
}
