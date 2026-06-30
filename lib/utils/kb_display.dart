/// 知识库列表副标题（订阅人数 · 内容数 · 作者昵称）。
abstract final class KbDisplay {
  static String metaLine({
    required int subscriberCount,
    required int docCount,
    required int readyDocCount,
    required String ownerName,
    String ownerHandle = '',
  }) {
    final contentCount = docCount > 0 ? docCount : readyDocCount;
    final author = _authorLabel(ownerName, ownerHandle);
    return '$subscriberCount人订阅 · $contentCount篇内容 · $author';
  }

  static String _authorLabel(String ownerName, String ownerHandle) {
    final handle = ownerHandle.trim();
    if (handle.isNotEmpty) return handle.startsWith('@') ? handle : '@$handle';
    final name = ownerName.trim();
    return name.isNotEmpty ? name : '未知作者';
  }
}
