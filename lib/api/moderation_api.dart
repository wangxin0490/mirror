import '../api/api_client.dart';
import '../api/api_result.dart';

/// 内容 moderation：举报与拉黑。
class ModerationApi {
  static Future<ApiResult<Map<String, dynamic>>> report({
    required String targetType,
    required String targetId,
    required String reason,
    String detail = '',
    int? reportedUserId,
  }) async {
    final body = <String, dynamic>{
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason,
      if (detail.isNotEmpty) 'detail': detail,
      if (reportedUserId != null && reportedUserId > 0) 'reported_user_id': reportedUserId,
    };
    return ApiClient.postResult('/api/v1/moderation/reports', body);
  }

  static Future<ApiResult<Map<String, dynamic>>> blockUser(int userId) async {
    return ApiClient.postResult('/api/v1/contacts/users/$userId/block', {});
  }

  static Future<ApiResult<Map<String, dynamic>>> unblockUser(int userId) async {
    return ApiClient.deleteResult('/api/v1/contacts/users/$userId/block');
  }

  static Future<List<int>> fetchBlockedUserIds() async {
    final data = await ApiClient.get('/api/v1/contacts/blocks');
    if (data == null) return [];
    final items = data['items'] as List<dynamic>? ?? data['user_ids'] as List<dynamic>? ?? [];
    return items
        .map((e) {
          if (e is int) return e;
          if (e is Map) return e['user_id'] as int? ?? 0;
          return int.tryParse('$e') ?? 0;
        })
        .where((id) => id > 0)
        .toList();
  }
}
