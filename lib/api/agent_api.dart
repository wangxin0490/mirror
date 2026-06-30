import '../api/api_client.dart';
import '../api/api_result.dart';
import '../models/agent_models.dart';
import '../utils/agent_model.dart';

/// Agent 聊天 REST（非 SSE）。
class AgentApi {
  static Future<List<AgentModelItem>> listModels() async {
    final data = await ApiClient.get('/api/v1/agent/models');
    if (data == null) return [];
    return filterAgentChatModels(AgentModelList.fromJson(data).items);
  }

  static Future<AgentConversation?> getConversation() async {
    final data = await ApiClient.get('/api/v1/agent/conversation');
    if (data == null) return null;
    return AgentConversation.fromJson(data);
  }

  static Future<AgentConversationList?> listConversations({int limit = 50, int beforeId = 0}) async {
    final q = StringBuffer('/api/v1/agent/conversations?limit=$limit');
    if (beforeId > 0) q.write('&before_id=$beforeId');
    final data = await ApiClient.get(q.toString());
    if (data == null) return null;
    return AgentConversationList.fromJson(data);
  }

  static Future<AgentConversation?> createConversation({String? modelCode}) async {
    final body = <String, dynamic>{};
    if (modelCode != null && modelCode.isNotEmpty) {
      body['model_code'] = modelCode;
    }
    final data = await ApiClient.post('/api/v1/agent/conversations', body);
    if (data == null) return null;
    return AgentConversation.fromJson(data);
  }

  static Future<bool> deleteConversation(int conversationId) async {
    final r = await ApiClient.deleteResult(
      '/api/v1/agent/conversations/$conversationId',
    );
    return r.ok;
  }

  static Future<AgentMessageList?> listMessages(int conversationId, {int limit = 50}) async {
    final data = await ApiClient.get('/api/v1/agent/conversations/$conversationId/messages?limit=$limit');
    if (data == null) return null;
    return AgentMessageList.fromJson(data);
  }

  /// 切换模型；402 时 [ApiResult.code] 为 40201/40202/40203。
  static Future<ApiResult<AgentConversation>> patchModel(int conversationId, String modelCode) async {
    final r = await ApiClient.patchResult(
      '/api/v1/agent/conversations/$conversationId',
      {'model_code': modelCode},
    );
    if (!r.ok || r.data == null) {
      return ApiResult(code: r.code, message: r.message);
    }
    return ApiResult(code: 0, message: r.message, data: AgentConversation.fromJson(r.data!));
  }

  /// 重命名会话。
  static Future<ApiResult<AgentConversation>> patchTitle(int conversationId, String title) async {
    final r = await ApiClient.patchResult(
      '/api/v1/agent/conversations/$conversationId',
      {'title': title},
    );
    if (!r.ok || r.data == null) {
      return ApiResult(code: r.code, message: r.message);
    }
    return ApiResult(code: 0, message: r.message, data: AgentConversation.fromJson(r.data!));
  }

  /// Hermes grant 文件 WebView 短签名 URL（相对路径，需拼 ApiConfig.baseUrl）。
  static Future<HermesFileSignResult?> signHermesFileAccess(int grantId) async {
    final data = await ApiClient.get('/api/v1/agent/hermes-files/$grantId/sign');
    if (data == null) return null;
    return HermesFileSignResult.fromJson(data);
  }
}

class HermesFileSignResult {
  const HermesFileSignResult({required this.url, required this.expiresIn});
  final String url;
  final int expiresIn;

  factory HermesFileSignResult.fromJson(Map<String, dynamic> j) => HermesFileSignResult(
        url: j['url'] as String? ?? '',
        expiresIn: (j['expires_in'] as num?)?.toInt() ?? 0,
      );
}
