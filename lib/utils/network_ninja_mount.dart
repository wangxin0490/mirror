import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:network_ninja/network_ninja.dart';

import '../app/mirror_app_keys.dart';

bool _bubbleAttached = false;

/// 冷启动时重置，避免热重载后误以为已挂载。
void resetNetworkNinjaBubbleMountState() {
  _bubbleAttached = false;
}

/// 先移除再挂载，避免 network_ninja 内部 `_activeOverlay` 残留导致 attach 静默失败。
void remountNetworkNinjaBubble(BuildContext context) {
  NetworkNinjaController.hideBubble();
  NetworkNinjaController.showBubble(context);
  _bubbleAttached = true;
}

/// 将 Network Ninja 悬浮球挂到根 [Navigator] 的 [Overlay]。
void scheduleNetworkNinjaBubbleMount({VoidCallback? onMounted}) {
  const delaysMs = [0, 150, 400, 800, 1500];
  for (var i = 0; i < delaysMs.length; i++) {
    final delay = delaysMs[i];
    Future<void>.delayed(Duration(milliseconds: delay), () {
      if (_bubbleAttached) return;
      final ok = _tryMountNetworkNinjaBubble(logFailure: i == delaysMs.length - 1);
      if (ok) onMounted?.call();
    });
  }
}

/// 从已 build 的 context 再尝试挂载。
bool tryMountNetworkNinjaBubbleFromContext(BuildContext context) {
  if (_bubbleAttached) return true;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null || !overlay.mounted) return false;
  remountNetworkNinjaBubble(overlay.context);
  if (kDebugMode) {
    debugPrint('[Mirror] Network Ninja 悬浮球已挂载（context 路径）');
  }
  return true;
}

bool _tryMountNetworkNinjaBubble({required bool logFailure}) {
  final overlayState = mirrorRootNavigatorKey.currentState?.overlay;
  if (overlayState == null || !overlayState.mounted) {
    if (logFailure) {
      debugPrint('[Mirror] Network Ninja 悬浮球挂载失败：Navigator 未就绪');
    }
    return false;
  }

  remountNetworkNinjaBubble(overlayState.context);

  if (kDebugMode) {
    debugPrint('[Mirror] Network Ninja 悬浮球已挂载');
    if (kIsWeb) {
      debugPrint('[Mirror] 若仍看不到球，请点左下角黑色「API」按钮');
    }
  }
  return true;
}
