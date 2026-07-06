import '../api/api_client.dart';
import '../api/api_result.dart';
import '../models/me_models.dart';

/// 「我的」模块接口封装。
class MeApi {
  static Future<MeOverview?> fetchOverview() async {
    final data = await ApiClient.get('/api/v1/me/overview');
    if (data == null) return null;
    return MeOverview.fromJson(data);
  }

  /// 获取当前用户资料（GET /api/v1/me/profile，旧服务回退 overview）。
  static Future<MeProfile?> fetchProfile() async {
    final data = await ApiClient.get('/api/v1/me/profile');
    if (data != null) return MeProfile.fromJson(data);
    final overview = await fetchOverview();
    return overview?.profile;
  }

  /// 更新昵称、简介、头像 URL。
  static Future<MeProfile?> updateProfile(MeProfile profile) async {
    final data = await ApiClient.put(
      '/api/v1/me/profile',
      profile.toUpdateJson(),
    );
    if (data == null) return null;
    return MeProfile.fromJson(data);
  }

  static Future<SoulData?> fetchSoul() async {
    final data = await ApiClient.get('/api/v1/me/soul');
    if (data == null) return null;
    return SoulData.fromJson(data);
  }

  /// 保存灵魂可编辑字段（identity/goal/原则/禁区）。
  static Future<SoulData?> saveSoul(SoulData soul) async {
    final data = await ApiClient.put('/api/v1/me/soul', soul.toJson());
    if (data == null) return null;
    return SoulData.fromJson(data);
  }

  static Future<List<MemoryDoc>> fetchMemoryDocs() async {
    final list = await ApiClient.getList('/api/v1/me/memory/docs');
    if (list == null) return [];
    return list
        .map((e) => MemoryDoc.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<MemoryItemData>> fetchMemoryItems({
    String tab = 'long_term',
    int limit = 4,
  }) async {
    final list = await ApiClient.getList(
      '/api/v1/me/memory/items?tab=$tab&limit=$limit',
    );
    if (list == null) return [];
    return list
        .map((e) => MemoryItemData.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 记忆页合并接口（1 次请求代替 3 次）。
  static Future<
    ({List<MemoryDoc> docs, List<MemoryItemData> items, int longTermCount})?
  >
  fetchMemoryScreen({String tab = 'long_term'}) async {
    final data = await ApiClient.get('/api/v1/me/memory/screen?tab=$tab');
    if (data == null) return null;
    final docs = (data['docs'] as List<dynamic>? ?? [])
        .map((e) => MemoryDoc.fromJson(e as Map<String, dynamic>))
        .toList();
    final items = (data['items'] as List<dynamic>? ?? [])
        .map((e) => MemoryItemData.fromJson(e as Map<String, dynamic>))
        .toList();
    final count = data['long_term_count'] as int? ?? items.length;
    return (docs: docs, items: items, longTermCount: count);
  }

  static Future<List<SkillData>> fetchSkills() async {
    final list = await ApiClient.getList('/api/v1/me/skills?scope=mine');
    if (list == null) return [];
    return list
        .map((e) => SkillData.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<TokenUsageBundle?> fetchTokenUsage({int limit = 20}) async {
    final data = await ApiClient.get('/api/v1/me/token/usage?limit=$limit');
    if (data == null) return null;
    return TokenUsageBundle.fromJson(data);
  }

  /// 兼容旧调用：仅返回近期明细列表。
  static Future<List<TokenUsageEntry>> fetchTokenUsageLog({
    int limit = 20,
  }) async {
    final bundle = await fetchTokenUsage(limit: limit);
    return bundle?.entries ?? [];
  }

  static Future<List<RoutingUsageData>> fetchRoutingUsage() async {
    final data = await ApiClient.get('/api/v1/me/routing');
    if (data == null) return [];
    final usage = data['usage'] as List<dynamic>? ?? [];
    return usage
        .map((e) => RoutingUsageData.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<CronTaskData>> fetchCronTasks() async {
    final list = await ApiClient.getList('/api/v1/me/cron/tasks');
    if (list == null) return [];
    return list
        .map((e) => CronTaskData.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 永久注销当前账号（DELETE /api/v1/me/account）。
  static Future<ApiResult<void>> deleteAccount() async {
    final r = await ApiClient.deleteResult('/api/v1/me/account');
    if (r.ok) return ApiResult(code: 0, message: r.message);
    return ApiResult(code: r.code, message: r.message.isNotEmpty ? r.message : '注销失败');
  }
}
