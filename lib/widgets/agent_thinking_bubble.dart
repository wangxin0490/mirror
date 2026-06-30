import 'package:flutter/material.dart';

import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';

class AgentThinkingBubble extends StatefulWidget {
  const AgentThinkingBubble({
    super.key,
    this.label = '正在思考',
  });

  final String label;

  @override
  State<AgentThinkingBubble> createState() => _AgentThinkingBubbleState();
}

class _AgentThinkingBubbleState extends State<AgentThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasLabel = widget.label.trim().isNotEmpty;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: MirrorColors.bgApp,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MirrorColors.borderSoft),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasLabel) ...[
              Text(
                widget.label,
                style: MirrorTheme.sans(
                  fontSize: 13,
                  color: MirrorColors.text2,
                ),
              ),
              const SizedBox(width: 8),
            ],
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => Row(
                children: List.generate(3, (index) {
                  final phase = (_controller.value * 3 - index).clamp(0.0, 1.0);
                  final opacity = 0.35 + 0.65 * (1 - (phase - 0.5).abs() * 2);
                  final offset = -3.0 * (1 - (phase - 0.5).abs() * 2);
                  return Transform.translate(
                    offset: Offset(0, offset),
                    child: Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: MirrorColors.accent.withValues(alpha: opacity),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
