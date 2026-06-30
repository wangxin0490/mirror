import 'package:flutter/material.dart';

import '../models/pending_chat_attachment.dart';
import '../theme/mirror_colors.dart';
import 'chat_composer_attachment_strip.dart';
import 'chat_voice_keyboard_field.dart';
import 'mirror_pressable.dart';

/// 知识库问答底部输入区（白底输入框 + 附件 + 按住说话 + 发送/停止）。
class KbChatComposer extends StatelessWidget {
  const KbChatComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.canSend,
    this.canStop = false,
    this.onSend,
    this.onStop,
    this.onAttach,
    this.showVoiceMic = false,
    this.voiceRecording = false,
    this.voiceTranscribing = false,
    this.voiceAmplitude = 0,
    this.onEnterVoiceMode,
    this.onVoiceHoldStart,
    this.onVoiceHoldEnd,
    this.onVoiceHoldCancel,
    this.pendingSlots,
    this.onRemovePendingImage,
    this.onRemovePendingDocument,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool canSend;
  final bool canStop;
  final VoidCallback? onSend;
  final VoidCallback? onStop;
  final VoidCallback? onAttach;
  /// 是否展示语音切换（系统 ASR 开启时）。
  final bool showVoiceMic;
  /// 是否正在录音。
  final bool voiceRecording;
  /// 是否正在转写。
  final bool voiceTranscribing;
  /// 录音音量（0–1），用于波形展示。
  final double voiceAmplitude;
  /// 切换到语音模式前请求麦克风权限。
  final Future<bool> Function()? onEnterVoiceMode;
  /// 按下麦克风指针时开始录音。
  final VoidCallback? onVoiceHoldStart;
  /// 松开指针时结束录音并转写进输入框。
  final VoidCallback? onVoiceHoldEnd;
  /// 指针取消时放弃本次录音。
  final VoidCallback? onVoiceHoldCancel;
  final ComposerAttachmentSlots? pendingSlots;
  final VoidCallback? onRemovePendingImage;
  final VoidCallback? onRemovePendingDocument;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      decoration: const BoxDecoration(
        color: MirrorColors.bgApp,
        border: Border(top: BorderSide(color: MirrorColors.borderSoft)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (onAttach != null)
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 4),
              child: MirrorPressable(
                onTap: enabled ? onAttach : null,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: MirrorColors.borderSoft),
                  ),
                  child: const Icon(Icons.add, size: 20, color: MirrorColors.text2),
                ),
              ),
            ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: MirrorColors.borderSoft),
              ),
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
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
                    controller: controller,
                    enabled: enabled,
                    canSend: canSend,
                    canStop: canStop,
                    showVoice: showVoiceMic,
                    voiceRecording: voiceRecording,
                    voiceTranscribing: voiceTranscribing,
                    voiceAmplitude: voiceAmplitude,
                    hintText: '输入问题，基于当前知识库问答',
                    onSend: onSend,
                    onEnterVoiceMode: onEnterVoiceMode,
                    onVoiceHoldStart: onVoiceHoldStart,
                    onVoiceHoldEnd: onVoiceHoldEnd,
                    onVoiceHoldCancel: onVoiceHoldCancel,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          MirrorPressable(
            key: Key(canStop ? 'kb-chat-stop-btn' : 'kb-chat-send-btn'),
            onTap: canStop ? onStop : (canSend ? onSend : null),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (canStop || canSend) ? MirrorColors.text : MirrorColors.border,
                shape: BoxShape.circle,
              ),
              child: Icon(
                canStop ? Icons.stop_rounded : Icons.arrow_upward,
                size: canStop ? 20 : 18,
                color: (canStop || canSend) ? Colors.white : MirrorColors.text3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
