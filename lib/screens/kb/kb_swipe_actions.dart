import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../theme/mirror_colors.dart';

/// 个人知识库列表左滑圆形 Tabler 图标按钮。
class KbCircularSwipeAction extends StatelessWidget {
  const KbCircularSwipeAction({
    super.key,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: iconColor),
          ),
        ),
      ),
    );
  }
}

/// 编辑 / 删除滑出动作（Tabler pencil + trash）。
class KbSwipeActionIcons extends StatelessWidget {
  const KbSwipeActionIcons({
    super.key,
    required this.onEdit,
    required this.onDelete,
  });

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          KbCircularSwipeAction(
            icon: TablerIcons.pencil,
            backgroundColor: MirrorColors.accentSoft,
            iconColor: MirrorColors.accentDeep,
            onTap: onEdit,
          ),
          KbCircularSwipeAction(
            icon: TablerIcons.trash,
            backgroundColor: MirrorColors.coralSoft,
            iconColor: MirrorColors.coral,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}
