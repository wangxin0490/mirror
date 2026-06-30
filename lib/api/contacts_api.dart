import '../api/api_client.dart';
import '../models/contacts_models.dart';

/// 通讯录模块接口。
class ContactsApi {
  static Future<ContactListResponse?> fetchUsers({String tab = 'recommend', int limit = 20}) async {
    final data = await ApiClient.get('/api/v1/contacts/users?tab=$tab&limit=$limit');
    if (data == null) return null;
    return ContactListResponse.fromJson(data);
  }

  static Future<ContactUserCard?> fetchUser(int id) async {
    final data = await ApiClient.get('/api/v1/contacts/users/$id');
    if (data == null) return null;
    return ContactUserCard.fromJson(data);
  }

  static Future<ContactUserCard?> lookup(String handle) async {
    final h = Uri.encodeQueryComponent(handle.replaceAll('@', ''));
    final data = await ApiClient.get('/api/v1/contacts/lookup?handle=$h');
    if (data == null) return null;
    return ContactUserCard.fromJson(data);
  }

  static Future<List<ContactUserCard>> search(String q, {int limit = 20}) async {
    final enc = Uri.encodeQueryComponent(q);
    final data = await ApiClient.get('/api/v1/contacts/search?q=$enc&limit=$limit');
    if (data == null) return [];
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => ContactUserCard.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<ContactFollowResult?> follow(int userId) async {
    final data = await ApiClient.post('/api/v1/contacts/users/$userId/follow', {});
    if (data == null) return null;
    return ContactFollowResult.fromJson(data);
  }

  static Future<ContactFollowResult?> unfollow(int userId) async {
    final data = await ApiClient.delete('/api/v1/contacts/users/$userId/follow');
    if (data == null) return null;
    return ContactFollowResult.fromJson(data);
  }

  static Future<ShareTargetsData?> putFavorites(List<Map<String, dynamic>> favorites) async {
    final data = await ApiClient.put('/api/v1/contacts/favorites', {'favorites': favorites});
    if (data == null) return null;
    return ShareTargetsData.fromJson(data);
  }

  static Future<ShareTargetsData?> fetchShareTargets() async {
    final data = await ApiClient.get('/api/v1/contacts/share/targets');
    if (data == null) return null;
    return ShareTargetsData.fromJson(data);
  }

  static Future<String?> createShareLink({required String resourceType, required int resourceId}) async {
    final data = await ApiClient.post('/api/v1/contacts/share/link', {
      'resource_type': resourceType,
      'resource_id': resourceId,
    });
    if (data == null) return null;
    return data['share_url'] as String?;
  }
}
