import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/moderation_api.dart';
import '../config/api_config.dart';

/// 本地拉黑列表：立即从 Feed / 私信中隐藏，并同步通知服务端。
class BlockStore extends ChangeNotifier {
  BlockStore._();

  static final BlockStore instance = BlockStore._();

  static const _prefsKey = 'mirror_blocked_user_ids';

  final Set<int> _blocked = {};
  bool _loaded = false;

  Set<int> get blockedUserIds => Set.unmodifiable(_blocked);

  bool isBlocked(int userId) => userId > 0 && _blocked.contains(userId);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_prefsKey) ?? const [];
    _blocked
      ..clear()
      ..addAll(raw.map(int.tryParse).whereType<int>().where((id) => id > 0));
    if (ApiConfig.isLoggedIn) {
      final remote = await ModerationApi.fetchBlockedUserIds();
      if (remote.isNotEmpty) {
        _blocked.addAll(remote);
        await _persist();
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> blockUser(int userId, {String? reason}) async {
    if (userId <= 0 || userId == ApiConfig.userId) return;
    await ensureLoaded();
    if (_blocked.contains(userId)) return;
    _blocked.add(userId);
    notifyListeners();
    await _persist();
    if (ApiConfig.isLoggedIn) {
      final r = await ModerationApi.blockUser(userId);
      if (!r.ok && kDebugMode) {
        debugPrint('[BlockStore] block API failed: ${r.message}');
      }
      if (reason != null && reason.isNotEmpty) {
        await ModerationApi.report(
          targetType: 'user',
          targetId: '$userId',
          reason: reason,
          reportedUserId: userId,
        );
      }
    }
  }

  Future<void> unblockUser(int userId) async {
    if (userId <= 0) return;
    await ensureLoaded();
    if (!_blocked.remove(userId)) return;
    notifyListeners();
    await _persist();
    if (ApiConfig.isLoggedIn) {
      await ModerationApi.unblockUser(userId);
    }
  }

  Future<void> clear() async {
    _blocked.clear();
    _loaded = false;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.remove(_prefsKey);
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
      _prefsKey,
      _blocked.map((e) => e.toString()).toList(),
    );
  }

  /// 调试：导出当前列表
  String exportJson() => jsonEncode(_blocked.toList());
}
