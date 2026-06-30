import 'package:flutter/foundation.dart';
import '../screens/post_detail_data.dart';

class SubscribedKbEntry {
  const SubscribedKbEntry({
    required this.name,
    required this.author,
    required this.docCount,
    required this.updated,
  });

  final String name;
  final String author;
  final int docCount;
  final String updated;

  factory SubscribedKbEntry.fromShared(SharedKnowledgeBaseInfo kb) => SubscribedKbEntry(
        name: kb.name,
        author: kb.author,
        docCount: kb.docCount,
        updated: '刚刚订阅',
      );
}

/// 生态文章订阅的知识库（原型内存态，跨 Tab 共享）
class KbSubscriptionStore extends ChangeNotifier {
  KbSubscriptionStore._();

  static final KbSubscriptionStore instance = KbSubscriptionStore._();

  final List<SubscribedKbEntry> _items = [];

  List<SubscribedKbEntry> get items => List.unmodifiable(_items);

  bool contains(String name) => _items.any((e) => e.name == name);

  void subscribe(SharedKnowledgeBaseInfo kb) {
    if (contains(kb.name)) return;
    _items.insert(0, SubscribedKbEntry.fromShared(kb));
    notifyListeners();
  }
}
