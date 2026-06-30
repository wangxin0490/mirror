import 'package:shared_preferences/shared_preferences.dart';

/// 生态圈搜索历史（本地，最近 6 条）。
class FeedSearchHistory {
  FeedSearchHistory._();

  static const _key = 'mirror_feed_search_history';
  static const maxItems = 6;

  static Future<List<String>> load() async {
    final p = await SharedPreferences.getInstance();
    return p.getStringList(_key) ?? [];
  }

  static Future<void> add(String query) async {
    final q = query.trim();
    if (q.length < 2) return;
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_key) ?? [];
    final next = [q, ...list.where((e) => e != q)].take(maxItems).toList();
    await p.setStringList(_key, next);
  }

  static Future<void> remove(String query) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_key) ?? [];
    final next = list.where((e) => e != query).toList();
    await p.setStringList(_key, next);
  }
}
