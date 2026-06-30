import 'package:flutter/material.dart';

import '../theme/mirror_colors.dart';
import '../utils/agent_chat_copy.dart';
import 'mirror_pressable.dart';

/// Agent 聊天内统一的复制图标按钮。
class AgentCopyButton extends StatelessWidget {
  const AgentCopyButton({
    super.key,
    required this.text,
    this.onCopied,
    this.iconSize = 16,
    this.padding = const EdgeInsets.all(4),
    this.tooltip = '复制',
    this.assetIcon,
  });

  final String text;
  final VoidCallback? onCopied;
  final double iconSize;
  final EdgeInsetsGeometry padding;
  final String tooltip;
  final String? assetIcon;

  Future<void> _copy() async {
    final ok = await copyTextToClipboard(text);
    if (ok) onCopied?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: MirrorPressable(
        onTap: _copy,
        borderRadius: BorderRadius.circular(6),
        padding: padding,
        child: assetIcon != null
            ? Image.asset(assetIcon!, width: iconSize, height: iconSize)
            : Icon(Icons.content_copy_outlined, size: iconSize, color: MirrorColors.text3),
      ),
    );
  }
}
