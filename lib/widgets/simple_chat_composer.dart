import 'package:flutter/material.dart';

import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import 'chat_voice_keyboard_field.dart';
import 'mirror_pressable.dart';

/// 精简对话输入区（与 Agent 对话同款白卡片 + 圆形发送，无模型/联网/附件）。
class SimpleChatComposer extends StatelessWidget {
  const SimpleChatComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.canSend,
    required this.hintText,
    this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool canSend;
  final String hintText;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      color: MirrorColors.bgApp,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MirrorColors.borderSoft),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F1A1916),
              blurRadius: 16,
              offset: Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ChatVoiceKeyboardField(
              inputKey: const Key('simple-chat-input-field'),
              controller: controller,
              enabled: enabled,
              canSend: canSend,
              hintText: hintText,
              textStyle: MirrorTheme.sans(fontSize: 15, color: MirrorColors.text, height: 1.45),
              onSend: onSend,
            ),
            const SizedBox(height: 10),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              color: MirrorColors.borderSoft.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                MirrorPressable(
                  key: const Key('simple-chat-send-btn'),
                  onTap: canSend ? onSend : null,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: canSend ? MirrorColors.accent : MirrorColors.bgCard,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      size: 16,
                      color: canSend ? Colors.white : MirrorColors.text3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
