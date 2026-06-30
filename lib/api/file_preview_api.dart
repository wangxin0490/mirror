import '../api/api_client.dart';
import '../models/document_preview.dart';

/// 文档在线预览 metadata API。
class FilePreviewApi {
  static Future<DocumentPreviewResult?> fetchHermesPreview({
    required int grantId,
    Map<String, String>? signQuery,
  }) async {
    final q = <String, String>{};
    final st = signQuery?['st']?.trim() ?? '';
    final exp = signQuery?['exp']?.trim() ?? '';
    if (st.isNotEmpty) q['st'] = st;
    if (exp.isNotEmpty) q['exp'] = exp;
    final query = q.entries
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final path = query.isEmpty
        ? '/api/v1/agent/hermes-files/$grantId/preview'
        : '/api/v1/agent/hermes-files/$grantId/preview?$query';
    final data = await ApiClient.get(path);
    if (data == null) return null;
    return DocumentPreviewResult.fromJson(data);
  }

  static Future<DocumentPreviewResult?> fetchChatAttachmentPreview({
    required String objectKey,
    String? filename,
  }) async {
    final q = <String, String>{'object_key': objectKey};
    final fn = filename?.trim() ?? '';
    if (fn.isNotEmpty) q['filename'] = fn;
    final query = q.entries
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final data = await ApiClient.get('/api/v1/chat/attachments/preview?$query');
    if (data == null) return null;
    return DocumentPreviewResult.fromJson(data);
  }
}
