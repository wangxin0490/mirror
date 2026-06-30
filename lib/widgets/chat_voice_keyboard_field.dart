import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import 'chat_voice_waveform.dart';
import 'mirror_pressable.dart';

/// 豆包式语音/键盘切换输入区：文本框 ⇄ 按住说话（松手发送，上滑取消）。
class ChatVoiceKeyboardField extends StatefulWidget {
  const ChatVoiceKeyboardField({
    super.key,
    required this.controller,
    required this.enabled,
    required this.canSend,
    this.canStop = false,
    this.showVoice = false,
    this.voiceRecording = false,
    this.voiceTranscribing = false,
    this.voiceAmplitude = 0,
    this.hintText = '发消息',
    this.textStyle,
    this.onSend,
    this.onEnterVoiceMode,
    this.onVoiceHoldStart,
    this.onVoiceHoldEnd,
    this.onVoiceHoldCancel,
    this.inputKey,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool canSend;
  final bool canStop;
  final bool showVoice;
  final bool voiceRecording;
  final bool voiceTranscribing;
  final double voiceAmplitude;
  final String hintText;
  final TextStyle? textStyle;
  final VoidCallback? onSend;
  /// 切换到语音模式前请求麦克风权限，返回 false 则保持键盘模式。
  final Future<bool> Function()? onEnterVoiceMode;
  final VoidCallback? onVoiceHoldStart;
  final VoidCallback? onVoiceHoldEnd;
  final VoidCallback? onVoiceHoldCancel;
  final Key? inputKey;

  @override
  State<ChatVoiceKeyboardField> createState() => _ChatVoiceKeyboardFieldState();
}

class _ChatVoiceKeyboardFieldState extends State<ChatVoiceKeyboardField> {
  var _voiceMode = false;
  var _enteringVoice = false;
  var _slideCancel = false;
  double? _holdStartDy;

  static const _slideCancelThreshold = 48.0;

  TextStyle get _fieldStyle =>
      widget.textStyle ??
      MirrorTheme.sans(fontSize: 14, color: MirrorColors.text, height: 1.45);

  Future<void> _enterVoiceMode() async {
    if (!widget.showVoice || !widget.enabled || widget.canStop || _enteringVoice) return;
    final request = widget.onEnterVoiceMode;
    if (request != null) {
      setState(() => _enteringVoice = true);
      final granted = await request();
      if (!mounted) return;
      setState(() => _enteringVoice = false);
      if (!granted) return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _voiceMode = true);
  }

  void _enterTextMode() {
    if (widget.voiceRecording) widget.onVoiceHoldCancel?.call();
    setState(() {
      _voiceMode = false;
      _slideCancel = false;
      _holdStartDy = null;
    });
  }

  void _resetHoldState() {
    setState(() {
      _slideCancel = false;
      _holdStartDy = null;
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.enabled || widget.canStop || widget.voiceTranscribing) return;
    setState(() {
      _holdStartDy = event.position.dy;
      _slideCancel = false;
    });
    widget.onVoiceHoldStart?.call();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_holdStartDy == null) return;
    final canceling = _holdStartDy! - event.position.dy >= _slideCancelThreshold;
    if (canceling != _slideCancel) {
      setState(() => _slideCancel = canceling);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_holdStartDy == null) return;
    final canceling = _slideCancel;
    _resetHoldState();
    if (canceling) {
      widget.onVoiceHoldCancel?.call();
    } else {
      widget.onVoiceHoldEnd?.call();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _resetHoldState();
    widget.onVoiceHoldCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showVoice) return _textField(showToggle: false);
    if (_voiceMode) return _holdToSpeakPanel();
    return _textField(showToggle: true);
  }

  Widget _textField({required bool showToggle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Focus(
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey != LogicalKeyboardKey.enter) return KeyEventResult.ignored;
              if (HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored;
              if (!widget.canSend) return KeyEventResult.handled;
              widget.onSend?.call();
              return KeyEventResult.handled;
            },
            child: TextField(
              key: widget.inputKey,
              controller: widget.controller,
              enabled: widget.enabled,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              style: _fieldStyle,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: widget.hintText,
                hintStyle: MirrorTheme.sans(fontSize: _fieldStyle.fontSize ?? 14, color: MirrorColors.text3),
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: widget.canSend ? (_) => widget.onSend?.call() : null,
            ),
          ),
        ),
        if (showToggle) ...[
          const SizedBox(width: 4),
          _modeToggleIcon(
            icon: Icons.mic_none_outlined,
            onTap: _enterVoiceMode,
          ),
        ],
      ],
    );
  }

  static const _voicePanelRadius = 14.0;

  BoxDecoration _voicePanelDecoration({required bool holding, required bool canceling, required bool transcribing}) {
    if (transcribing) {
      return BoxDecoration(
        color: MirrorColors.accentSoft.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(_voicePanelRadius),
      );
    }
    if (holding) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(_voicePanelRadius),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: canceling
              ? [const Color(0xFFFFF5F5), const Color(0xFFFFE8E8)]
              : [MirrorColors.accentSoft.withValues(alpha: 0.25), MirrorColors.accentSoft.withValues(alpha: 0.55)],
        ),
        border: Border.all(
          color: canceling ? const Color(0xFFF5C4C4) : MirrorColors.accentBorder.withValues(alpha: 0.5),
        ),
      );
    }
    return BoxDecoration(
      color: MirrorColors.bgSoft,
      borderRadius: BorderRadius.circular(_voicePanelRadius),
      border: Border.all(color: MirrorColors.borderSoft),
    );
  }

  Widget _holdToSpeakPanel() {
    final holding = _holdStartDy != null || widget.voiceRecording;
    final transcribing = widget.voiceTranscribing;
    final canHold = widget.enabled && !widget.canStop && !transcribing;
    final canceling = holding && _slideCancel;
    final activePanel = holding || transcribing;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: canHold ? _onPointerDown : null,
          onPointerMove: canHold ? _onPointerMove : null,
          onPointerUp: canHold ? _onPointerUp : null,
          onPointerCancel: canHold ? _onPointerCancel : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(14, activePanel ? 14 : 0, 48, activePanel ? 12 : 0),
            constraints: BoxConstraints(minHeight: activePanel ? 0 : 44),
            decoration: _voicePanelDecoration(
              holding: holding,
              canceling: canceling,
              transcribing: transcribing,
            ),
            child: transcribing
                ? const SizedBox(
                    height: 36,
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: MirrorColors.accentDeep,
                        ),
                      ),
                    ),
                  )
                : holding
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            canceling ? '松手取消' : '松手发送，上滑取消',
                            style: MirrorTheme.sans(
                              fontSize: 14,
                              color: canceling ? const Color(0xFFD64545) : MirrorColors.text2,
                              weight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ChatVoiceWaveform(
                            amplitude: widget.voiceRecording ? widget.voiceAmplitude : 0.2,
                            active: widget.voiceRecording,
                            canceling: canceling,
                          ),
                        ],
                      )
                    : SizedBox(
                        height: 44,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.mic_none_outlined, size: 18, color: MirrorColors.text3),
                            const SizedBox(width: 6),
                            Text(
                              '按住说话',
                              style: MirrorTheme.sans(
                                fontSize: 15,
                                color: MirrorColors.text2,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ),
        Positioned(
          right: 2,
          bottom: activePanel ? 10 : 8,
          child: _modeToggleIcon(
            icon: Icons.keyboard_outlined,
            onTap: _enterTextMode,
            elevated: activePanel,
          ),
        ),
      ],
    );
  }

  Widget _modeToggleIcon({
    required IconData icon,
    required VoidCallback onTap,
    bool elevated = false,
  }) {
    return MirrorPressable(
      onTap: widget.enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: elevated
            ? BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 1)),
                ],
              )
            : null,
        child: Icon(icon, size: 20, color: MirrorColors.text2),
      ),
    );
  }
}
