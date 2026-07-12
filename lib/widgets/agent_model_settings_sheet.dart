import 'package:flutter/material.dart';

import '../models/agent_models.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../utils/model_access_copy.dart';
import 'mirror_pressable.dart';

/// App 风格模型选择 BottomSheet（上拉/下拉关闭）。
Future<void> showAgentModelPickerSheet({
  required BuildContext context,
  required List<AgentModelItem> models,
  required String? selectedModelCode,
  required ValueChanged<AgentModelItem> onModelSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.42,
        minChildSize: 0.28,
        maxChildSize: 0.72,
        expand: false,
        builder: (context, scrollController) {
          return DecoratedBox(
            decoration: const BoxDecoration(
              color: MirrorColors.bgApp,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(color: Color(0x1A000000), blurRadius: 24, offset: Offset(0, -4)),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MirrorColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                  child: Row(
                    children: [
                      Text('选择模型', style: MirrorTheme.sans(fontSize: 17, weight: FontWeight.w600)),
                      const Spacer(),
                      Text(
                        '${models.length} 个',
                        style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text3),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: MirrorColors.borderSoft),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                    itemCount: models.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (_, i) {
                      final m = models[i];
                      return _modelRow(
                        model: m,
                        selected: m.modelCode == selectedModelCode,
                        onTap: () {
                          Navigator.pop(ctx);
                          onModelSelected(m);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _modelRow({
  required AgentModelItem model,
  required bool selected,
  required VoidCallback onTap,
}) {
  return Opacity(
    opacity: model.selectable ? 1 : 0.45,
    child: MirrorPressable(
      key: Key('agent-model-tile-${model.modelCode}'),
      onTap: model.selectable ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? MirrorColors.accentSoft.withValues(alpha: 0.35) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.displayName,
                    style: MirrorTheme.sans(
                      fontSize: 15,
                      weight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: MirrorColors.text,
                    ),
                  ),
                  if (_modelSubtitle(model) != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      _modelSubtitle(model)!,
                      style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text3),
                    ),
                  ],
                ],
              ),
            ),
            _modelCapabilityIcons(model),
            const SizedBox(width: 10),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 22,
              color: selected ? MirrorColors.accent : MirrorColors.border,
            ),
          ],
        ),
      ),
    ),
  );
}

/// 仅锁定模型展示原因；试用/已购及服务端计费文案均不展示（App Store 3.1.1）。
String? _modelSubtitle(AgentModelItem model) => modelLockedSubtitle(
      selectable: model.selectable,
      accessLabel: model.accessLabel,
    );

Widget _modelCapabilityIcons(AgentModelItem model) {
  return _capabilityIcon(
    icon: Icons.image_outlined,
    enabled: model.supportsVision,
    label: model.supportsVision ? '支持图片' : '不支持图片',
  );
}

Widget _capabilityIcon({
  required IconData icon,
  required bool enabled,
  required String label,
}) {
  final color = enabled ? MirrorColors.accentDeep : MirrorColors.text4;
  return Tooltip(
    message: label,
    child: Icon(icon, size: 18, color: color),
  );
}
