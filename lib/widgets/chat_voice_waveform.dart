import 'package:flutter/material.dart';

import '../theme/mirror_colors.dart';

/// 按住说话时的波形条（Agent / 知识库输入区共用）。
class ChatVoiceWaveform extends StatelessWidget {
  const ChatVoiceWaveform({
    super.key,
    required this.amplitude,
    required this.active,
    this.canceling = false,
  });

  final double amplitude;
  final bool active;
  final bool canceling;

  @override
  Widget build(BuildContext context) {
    const barCount = 12;
    final baseColor = canceling ? const Color(0xFFE85C5C) : MirrorColors.accentDeep;
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(barCount, (i) {
          final wave = active
              ? (0.25 + amplitude * 0.75) * (0.55 + 0.45 * ((i % 4) + 1) / 4)
              : 0.15;
          final h = 8.0 + 32.0 * wave;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: 4,
              height: h,
              decoration: BoxDecoration(
                color: active
                    ? baseColor.withValues(alpha: 0.4 + amplitude * 0.5)
                    : MirrorColors.borderSoft,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}
