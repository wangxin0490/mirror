import 'package:flutter/material.dart';

import '../api/chat_api.dart';
import '../data/mirror_authors.dart';
import '../models/chat_models.dart';
import '../utils/dm_file_message.dart';
import '../screens/mirror_feed_data.dart';

class DmThread {
  DmThread({
    required this.key,
    required this.name,
    required this.av,
    required this.colors,
    required this.preview,
    required this.time,
    this.unread = false,
    this.atMe = false,
    this.userId = 0,
    this.conversationId = 0,
    this.handle = '',
    this.avatarVariant = 'accent',
    this.avatarUrl = '',
  });

  final String key;
  String name;
  String av;
  List<Color> colors;
  String preview;
  String time;
  bool unread;
  bool atMe;
  int userId;
  int conversationId;
  String handle;
  String avatarVariant;
  String avatarUrl;
}

/// 私信会话（对话 Tab 与私信页共享；列表来自 /api/v1/chat/conversations）。
class DmThreadStore extends ChangeNotifier {
  DmThreadStore._();

  static final DmThreadStore instance = DmThreadStore._();

  final List<DmThread> _threads = [];
  bool _loading = false;
  bool _loadFailed = false;
  String _lastTab = 'all';

  List<DmThread> get threads => List.unmodifiable(_threads);
  bool get loading => _loading;
  bool get loadFailed => _loadFailed;
  String get lastTab => _lastTab;

  DmThread? byKey(String key) {
    for (final t in _threads) {
      if (t.key == key) return t;
    }
    return null;
  }

  MirrorAuthor? authorForKey(String key) {
    final t = byKey(key);
    if (t == null) return MirrorAuthor.byKey(key);
    return MirrorAuthor(
      key: t.key,
      name: t.name,
      av: t.av,
      variant: variantEnum(t.avatarVariant),
      handle: t.handle.isNotEmpty ? t.handle : t.key,
      bio: '',
      avatarUrl: t.avatarUrl,
    );
  }

  /// 从后端拉取会话列表；返回是否请求成功（含空列表）。
  Future<bool> refreshFromApi({required String tab, String? q}) async {
    _loading = true;
    _loadFailed = false;
    _lastTab = tab;
    notifyListeners();

    final res = await ChatApi.fetchConversations(tab: tab, q: q);
    if (res == null) {
      _loading = false;
      _loadFailed = true;
      notifyListeners();
      return false;
    }

    _threads
      ..clear()
      ..addAll(res.items.map(_threadFromItem));
    _loading = false;
    _loadFailed = false;
    notifyListeners();
    return true;
  }

  DmThread _threadFromItem(ChatConversationItem item) => DmThread(
        key: item.threadKey,
        name: item.displayName,
        av: item.avatarLetter,
        colors: item.avatarColors,
        preview: normalizeConversationPreview(item.preview),
        time: item.timeLabel,
        unread: item.unread,
        atMe: item.atMe,
        userId: item.peerUserId,
        conversationId: item.conversationId,
        handle: item.handle,
        avatarVariant: item.avatarVariant,
        avatarUrl: item.avatarUrl,
      );

  DmThread ensureThread(MirrorAuthor author) {
    final existing = byKey(author.key);
    if (existing != null) {
      if (author.userId > 0 && existing.userId <= 0) {
        existing.userId = author.userId;
      }
      if (author.handle.isNotEmpty && existing.handle.isEmpty) {
        existing.handle = author.handle;
      }
      if (author.avatarUrl.isNotEmpty && existing.avatarUrl.isEmpty) {
        existing.avatarUrl = author.avatarUrl;
      }
      return existing;
    }
    final t = DmThread(
      key: author.key,
      name: author.name,
      av: author.av,
      colors: author.avatarColors,
      preview: '点击开始聊天',
      time: '刚刚',
      unread: false,
      userId: author.userId,
      handle: author.handle,
      avatarUrl: author.avatarUrl,
      avatarVariant: switch (author.variant) {
        FeedAvatarVariant.green => 'green',
        FeedAvatarVariant.pink => 'pink',
        FeedAvatarVariant.blue => 'blue',
        FeedAvatarVariant.amber => 'amber',
        _ => 'accent',
      },
    );
    _threads.insert(0, t);
    notifyListeners();
    return t;
  }

  DmThread? _findThread({String? key, int conversationId = 0, int userId = 0}) {
    if (key != null && key.isNotEmpty) {
      final t = byKey(key);
      if (t != null) return t;
    }
    for (final t in _threads) {
      if (conversationId > 0 && t.conversationId == conversationId) return t;
      if (userId > 0 && t.userId == userId) return t;
    }
    return null;
  }

  void bumpThread(
    String key, {
    required String preview,
    bool unread = true,
    int conversationId = 0,
  }) {
    final t = _findThread(key: key, conversationId: conversationId);
    if (t == null) return;
    t.preview = normalizeConversationPreview(preview);
    t.time = '刚刚';
    t.unread = unread;
    if (conversationId > 0) t.conversationId = conversationId;
    _threads.remove(t);
    _threads.insert(0, t);
    notifyListeners();
  }

  /// WS 新消息兜底：按 conversation_id 更新列表预览（收件箱 push 失败时仍可用）。
  void applyIncomingMessage(ChatMessage msg) {
    if (msg.conversationId <= 0) return;
    final preview = normalizeConversationPreview(dmMessagePreview(msg));
    final t = _findThread(conversationId: msg.conversationId);
    if (t == null) return;
    t.preview = preview;
    t.time = '刚刚';
    if (!msg.isMe) t.unread = true;
    _threads.remove(t);
    _threads.insert(0, t);
    notifyListeners();
  }

  void markRead(String key) {
    final t = byKey(key);
    if (t == null || !t.unread) return;
    t.unread = false;
    notifyListeners();
  }

  /// WS 推送的会话更新：合并 preview / 未读并置顶。
  void applyConversationUpdate(ChatConversationItem item) {
    final match = (DmThread t) =>
        (item.conversationId > 0 && t.conversationId == item.conversationId) ||
        (item.peerUserId > 0 && t.userId == item.peerUserId) ||
        (item.handle.isNotEmpty && t.handle == item.handle);

    if (_lastTab == 'unread' && !item.unread) {
      if (_threads.any(match)) {
        _threads.removeWhere(match);
        notifyListeners();
      }
      return;
    }
    if (_lastTab == 'contacts' && !_threads.any(match)) {
      return;
    }

    DmThread? existing;
    for (final t in _threads) {
      if (match(t)) {
        existing = t;
        break;
      }
    }

    if (existing != null) {
      existing.preview = item.preview.isNotEmpty
          ? normalizeConversationPreview(item.preview)
          : existing.preview;
      existing.time = item.timeLabel.isNotEmpty ? item.timeLabel : '刚刚';
      existing.unread = item.unread;
      existing.atMe = item.atMe;
      if (item.conversationId > 0) existing.conversationId = item.conversationId;
      if (item.peerUserId > 0) existing.userId = item.peerUserId;
      if (item.handle.isNotEmpty) existing.handle = item.handle;
      if (item.displayName.isNotEmpty) existing.name = item.displayName;
      if (item.avatarLetter.isNotEmpty) existing.av = item.avatarLetter;
      if (item.avatarUrl.isNotEmpty) existing.avatarUrl = item.avatarUrl;
      existing.avatarVariant = item.avatarVariant;
      existing.colors = item.avatarColors;
      _threads.remove(existing);
      _threads.insert(0, existing);
    } else {
      _threads.insert(0, _threadFromItem(item));
    }
    notifyListeners();
  }

  void clear() {
    _threads.clear();
    _loading = false;
    _loadFailed = false;
    notifyListeners();
  }

  /// 删除会话：请求后端成功后从列表移除。失败时 [message] 为接口或本地提示。
  Future<({bool ok, String message})> deleteConversation(int conversationId) async {
    if (conversationId <= 0) {
      return (ok: false, message: '无效会话');
    }
    final r = await ChatApi.deleteConversation(conversationId);
    if (!r.ok) {
      return (ok: false, message: r.message.isNotEmpty ? r.message : '删除失败');
    }
    _threads.removeWhere((t) => t.conversationId == conversationId);
    notifyListeners();
    return (ok: true, message: '');
  }
}
