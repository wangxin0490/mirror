import 'package:flutter/material.dart';

import '../theme/mirror_theme.dart';
import 'mirror_icon.dart';

/// Agent / 知识库助手消息身份行：logo + Mirror。
class MirrorAssistantIdentityRow extends StatelessWidget {
  const MirrorAssistantIdentityRow({super.key, this.trailing});

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(7),
          ),
          alignment: Alignment.center,
          child: const MirrorIcon(size: 12),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Mirror', style: MirrorTheme.sans(fontSize: 13, weight: FontWeight.w600)),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Agent 新会话顶栏：logo + Mirror。
class MirrorAssistantHeaderTitle extends StatelessWidget {
  const MirrorAssistantHeaderTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: const MirrorIcon(size: 11),
        ),
        const SizedBox(width: 6),
        Text('Mirror', style: MirrorTheme.sans(fontSize: 14, weight: FontWeight.w500, letterSpacing: -0.01)),
      ],
    );
  }
}
