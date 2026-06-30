import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../api/meeting_api.dart';
import '../app/meeting_navigation.dart';
import '../app/mirror_app_keys.dart';
import '../config/api_config.dart';
import '../models/meeting_models.dart';
import '../services/meeting_notification_service.dart';
import '../services/meeting_sse_client.dart';
import '../theme/mirror_theme.dart';

/// 全局会议任务状态：SSE 订阅、列表缓存、完成通知。
class MeetingSessionStore extends ChangeNotifier with WidgetsBindingObserver {
  MeetingSessionStore._();

  static final MeetingSessionStore instance = MeetingSessionStore._();

  List<MeetingSessionSummary> items = [];
  final Map<int, MeetingSessionSummary> _byId = {};
  final Set<int> _notifiedDoneIds = {};

  bool _running = false;
  var _sseActive = false;
  Timer? _pollTimer;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  /// 由 [MirrorPrototype] 注入，用于在 App 内栈导航打开详情。
  void Function(int sessionId)? openMeetingDetail;

  bool get isRunning => _running;

  bool get isForeground =>
      _lifecycle == AppLifecycleState.resumed || _lifecycle == AppLifecycleState.inactive;

  void start() {
    if (_running || !ApiConfig.isLoggedIn) return;
    _running = true;
    WidgetsBinding.instance.addObserver(this);
    unawaited(refreshList());
    unawaited(_sseLoop());
  }

  void stop() {
    if (!_running) return;
    _running = false;
    _sseActive = false;
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _pollTimer = null;
    items = [];
    _byId.clear();
    _notifiedDoneIds.clear();
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state == AppLifecycleState.resumed) {
      _pollTimer?.cancel();
      _pollTimer = null;
      unawaited(refreshList());
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _startBackgroundPoll();
    }
  }

  void _startBackgroundPoll() {
    if (!_running) return;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_running) return;
      unawaited(refreshList(notifyOnNewlyDone: true));
    });
  }

  Future<void> refreshList({bool notifyOnNewlyDone = false}) async {
    // Hub 进入时会主动 refresh；Web 不启动 SSE store，但仍需拉历史列表。
    if (!ApiConfig.isLoggedIn) return;
    final page = await MeetingApi.listSessions();
    if (page == null) return;

    if (notifyOnNewlyDone) {
      for (final item in page.items) {
        if (item.status != 'done') continue;
        if (_notifiedDoneIds.contains(item.id)) continue;
        final prev = _byId[item.id];
        if (prev != null && prev.isProcessing) {
          _notifyDone(
            MeetingStatusEvent(
              sessionId: item.id,
              status: 'done',
              title: item.title,
              minutesPreview: item.minutesPreview,
            ),
          );
        }
      }
    }

    items = page.items;
    _byId
      ..clear()
      ..addEntries(items.map((e) => MapEntry(e.id, e)));
    for (final id in items.where((e) => e.status == 'done').map((e) => e.id)) {
      _notifiedDoneIds.add(id);
    }
    notifyListeners();
  }

  MeetingSessionSummary? summaryFor(int id) => _byId[id];

  void removeSession(int id) {
    items = items.where((e) => e.id != id).toList();
    _byId.remove(id);
    _notifiedDoneIds.remove(id);
    notifyListeners();
  }

  Future<void> _sseLoop() async {
    if (!_running) return;
    _sseActive = true;
    while (_sseActive && _running) {
      await MeetingSseClient.stream(
        onEvent: _handleSseEvent,
        onError: (_) {},
        onDisconnected: () {},
      );
      if (!_sseActive || !_running) return;
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  void _handleSseEvent(MeetingStatusEvent ev, String name) {
    if (!_running) return;
    final idx = items.indexWhere((e) => e.id == ev.sessionId);
    if (idx >= 0) {
      final old = items[idx];
      items[idx] = MeetingSessionSummary(
        id: old.id,
        title: ev.title.isNotEmpty ? ev.title : old.title,
        status: ev.status,
        durationSec: old.durationSec,
        minutesPreview: ev.minutesPreview.isNotEmpty ? ev.minutesPreview : old.minutesPreview,
        errorMessage: ev.errorMessage,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
      );
      _byId[ev.sessionId] = items[idx];
    } else if (name == 'done' || name == 'update') {
      unawaited(refreshList());
    }

    if (name == 'done') {
      _notifyDone(ev);
    }
    notifyListeners();
  }

  void _notifyDone(MeetingStatusEvent ev) {
    if (_notifiedDoneIds.contains(ev.sessionId)) return;
    _notifiedDoneIds.add(ev.sessionId);

    final title = ev.title.isNotEmpty ? ev.title : '会议 #${ev.sessionId}';
    if (isForeground) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        mirrorScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('《$title》纪要已生成', style: MirrorTheme.sans(fontSize: 13, color: Colors.white)),
            action: SnackBarAction(
              label: '查看',
              textColor: Colors.white70,
              onPressed: () => _openDetail(ev.sessionId),
            ),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
          ),
        );
      });
    } else {
      unawaited(MeetingNotificationService.showDone(sessionId: ev.sessionId, title: title));
    }
  }

  void _openDetail(int sessionId) {
    if (openMeetingDetail != null) {
      openMeetingDetail!(sessionId);
      return;
    }
    openMeetingDetailScreen(sessionId);
  }
}
