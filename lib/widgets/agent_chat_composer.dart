import 'package:flutter/material.dart';

import '../models/pending_chat_attachment.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import 'chat_composer_attachment_strip.dart';
import 'chat_voice_keyboard_field.dart';
import 'mirror_pressable.dart';

/// Agent 聊天底部输入区（ima 风格：大圆角白卡片，底栏左模型/联网、右上传/发送）。
class AgentChatComposer extends StatelessWidget {
  const AgentChatComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.canSend,
    this.canStop = false,
    required this.modelLabel,
    required this.webSearchEnabled,
    this.webSearchLocked = false,
    required this.previewMode,
    this.onOpenModelPicker,
    this.onSend,
    this.onStop,
    this.onWebSearchToggle,
    this.onMore,
    this.pendingSlots,
    this.onRemovePendingImage,
    this.onRemovePendingDocument,
    this.showVoiceMic = false,
    this.voiceRecording = false,
    this.voiceTranscribing = false,
    this.voiceAmplitude = 0,
    this.onEnterVoiceMode,
    this.onVoiceHoldStart,
    this.onVoiceHoldEnd,
    this.onVoiceHoldCancel,
    this.composerHint,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool canSend;
  final bool canStop;
  final String modelLabel;
  final bool webSearchEnabled;
  final bool webSearchLocked;
  final bool previewMode;
  final VoidCallback? onOpenModelPicker;
  final VoidCallback? onSend;
  final VoidCallback? onStop;
  final VoidCallback? onWebSearchToggle;
  final VoidCallback? onMore;
  final ComposerAttachmentSlots? pendingSlots;
  final VoidCallback? onRemovePendingImage;
  final VoidCallback? onRemovePendingDocument;
  final bool showVoiceMic;
  final bool voiceRecording;
  final bool voiceTranscribing;
  final double voiceAmplitude;
  final Future<bool> Function()? onEnterVoiceMode;
  final VoidCallback? onVoiceHoldStart;
  final VoidCallback? onVoiceHoldEnd;
  final VoidCallback? onVoiceHoldCancel;
  final String? composerHint;

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
            if (pendingSlots != null && pendingSlots!.hasPending)
              ChatComposerAttachmentStrip(
                slots: pendingSlots!,
                onRemoveImage: onRemovePendingImage,
                onRemoveDocument: onRemovePendingDocument,
              ),
            ChatVoiceKeyboardField(
              inputKey: const Key('chat-input-field'),
              controller: controller,
              enabled: enabled,
              canSend: canSend,
              canStop: canStop,
              showVoice: showVoiceMic,
              voiceRecording: voiceRecording,
              voiceTranscribing: voiceTranscribing,
              voiceAmplitude: voiceAmplitude,
              hintText: previewMode
                  ? '预览模式'
                  : (composerHint?.trim().isNotEmpty == true
                      ? composerHint!.trim()
                      : '发消息'),
              textStyle: MirrorTheme.sans(fontSize: 15, color: MirrorColors.text, height: 1.45),
              onSend: onSend,
              onEnterVoiceMode: onEnterVoiceMode,
              onVoiceHoldStart: onVoiceHoldStart,
              onVoiceHoldEnd: onVoiceHoldEnd,
              onVoiceHoldCancel: onVoiceHoldCancel,
            ),
            const SizedBox(height: 10),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              color: MirrorColors.borderSoft.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(child: _modelPill()),
                const SizedBox(width: 6),
                _webSearchToggle(),
                const Spacer(),
                _circleAction(
                  key: const Key('chat-more-btn'),
                  icon: Icons.add,
                  filled: false,
                  onTap: onMore,
                ),
                const SizedBox(width: 8),
                _circleAction(
                  key: Key(canStop ? 'chat-stop-btn' : 'chat-send-btn'),
                  icon: canStop ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                  filled: true,
                  active: canStop || canSend,
                  onTap: canStop ? onStop : (canSend ? onSend : null),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _modelPill() {
    return MirrorPressable(
      key: const Key('chat-model-picker'),
      onTap: onOpenModelPicker,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: MirrorColors.bgSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MirrorColors.borderSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                modelLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text2, weight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: MirrorColors.text3),
          ],
        ),
      ),
    );
  }

  Widget _webSearchToggle() {
    final locked = webSearchLocked;
    final on = !locked && webSearchEnabled;
    final iconColor = locked ? MirrorColors.text4 : (on ? MirrorColors.accentDeep : MirrorColors.text3);
    final textColor = locked ? MirrorColors.text4 : (on ? MirrorColors.accentDeep : MirrorColors.text3);
    final chip = Container(
      key: const Key('chat-web-search-toggle'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: locked ? MirrorColors.bgCard : (on ? MirrorColors.accentSoft : MirrorColors.bgSoft),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: locked ? MirrorColors.borderSoft : (on ? MirrorColors.accentBorder : MirrorColors.borderSoft),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            locked ? Icons.public_off_outlined : Icons.language_rounded,
            size: 13,
            color: iconColor,
          ),
          const SizedBox(width: 3),
          Text(
            locked ? '未联网' : '联网',
            style: MirrorTheme.sans(
              fontSize: 11,
              color: textColor,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    if (locked) {
      return IgnorePointer(child: chip);
    }
    return MirrorPressable(
      onTap: enabled ? onWebSearchToggle : null,
      borderRadius: BorderRadius.circular(16),
      child: chip,
    );
  }

  Widget _circleAction({
    Key? key,
    required IconData icon,
    required bool filled,
    bool active = true,
    VoidCallback? onTap,
  }) {
    final sendStyle = filled;
    final bg = sendStyle
        ? (active ? MirrorColors.accent : MirrorColors.bgCard)
        : MirrorColors.bgSoft;
    final fg = sendStyle
        ? (active ? Colors.white : MirrorColors.text3)
        : MirrorColors.text2;
    return MirrorPressable(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: sendStyle || active ? null : Border.all(color: MirrorColors.borderSoft),
        ),
        child: Icon(icon, size: sendStyle ? 18 : 20, color: fg),
      ),
    );
  }
}
