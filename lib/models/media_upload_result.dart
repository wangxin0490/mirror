/// 媒体类上传统一响应（Feed 图、头像、知识库封面）。
class MediaUploadResult {
  const MediaUploadResult({
    required this.objectKey,
    required this.url,
    required this.storage,
  });

  final String objectKey;
  final String url;
  final String storage;

  factory MediaUploadResult.fromJson(Map<String, dynamic> j) => MediaUploadResult(
        objectKey: j['object_key'] as String? ?? '',
        url: j['url'] as String? ?? '',
        storage: j['storage'] as String? ?? '',
      );
}
