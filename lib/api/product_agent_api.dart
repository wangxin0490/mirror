import '../api/api_client.dart';
import '../models/toolbox_agent_models.dart';
import '../utils/toolbox_agent_filter.dart';

/// 工具箱智能体 REST（/api/v1/me/agents/*）。
class ProductAgentApi {
  static Future<List<ToolboxAgentItem>> fetchAgents({
    String scope = 'all',
    int? limit,
  }) async {
    final q = StringBuffer('/api/v1/me/agents?scope=$scope');
    final effectiveLimit = limit ?? (scope == 'toolbox' ? 32 : null);
    if (effectiveLimit != null && effectiveLimit > 0) {
      q.write('&limit=$effectiveLimit');
    }
    final data = await ApiClient.get(q.toString());
    if (data == null) return [];
    final items = data['items'];
    if (items is! List) return [];
    final agents = items
        .map((e) => ToolboxAgentItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return filterVisibleToolboxAgents(agents);
  }

  static Future<List<ProductAgentConversationSummary>> fetchConversations(
    String agentCode, {
    int limit = 50,
    int beforeId = 0,
  }) async {
    final q = StringBuffer(
      '/api/v1/me/agents/$agentCode/conversations?limit=$limit',
    );
    if (beforeId > 0) q.write('&before_id=$beforeId');
    final data = await ApiClient.get(q.toString());
    if (data == null) return [];
    final items = data['items'];
    if (items is! List) return [];
    return items
        .map(
          (e) => ProductAgentConversationSummary.fromJson(
            e as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  static Future<ProductAgentConversation?> createConversation(
    String agentCode,
  ) async {
    final data = await ApiClient.post(
      '/api/v1/me/agents/$agentCode/conversations',
      {},
    );
    if (data == null) return null;
    return ProductAgentConversation.fromJson(data);
  }

  static Future<ProductAgentConversation?> patchConversationTitle(
    String agentCode,
    int conversationId,
    String title,
  ) async {
    final r = await ApiClient.patchResult(
      '/api/v1/me/agents/$agentCode/conversations/$conversationId',
      {'title': title},
    );
    if (!r.ok || r.data == null) return null;
    return ProductAgentConversation.fromJson(r.data!);
  }

  static Future<bool> deleteConversation(
    String agentCode,
    int conversationId,
  ) async {
    final r = await ApiClient.deleteResult(
      '/api/v1/me/agents/$agentCode/conversations/$conversationId',
    );
    return r.ok;
  }

  static Future<List<ProductAgentMessage>> fetchMessages(
    String agentCode,
    int conversationId, {
    int limit = 50,
  }) async {
    final data = await ApiClient.get(
      '/api/v1/me/agents/$agentCode/conversations/$conversationId/messages?limit=$limit',
    );
    if (data == null) return [];
    final items = data['items'];
    if (items is! List) return [];
    return items
        .map((e) => ProductAgentMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
