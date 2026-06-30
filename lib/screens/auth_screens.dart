import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/auth_api.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../widgets/mirror_icon.dart';
import '../widgets/mirror_pressable.dart';
import '../widgets/phone_components.dart';

const _kResendCooldownSeconds = 60;

/// 两步登录：手机号 → 6 格验证码（填完自动登录/注册）
class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({
    super.key,
    this.onBack,
    this.onLoggedIn,
    this.onNeedsRegister,
  });

  final VoidCallback? onBack;
  final void Function(int userId)? onLoggedIn;
  final void Function(String phone, String registerToken)? onNeedsRegister;

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

enum _LoginStep { phone, code }

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  _LoginStep _step = _LoginStep.phone;
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _otpFocus = FocusNode();
  String _otp = '';
  String _phone = '';
  bool _submitting = false;
  String? _error;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _phoneCtrl.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneCtrl.removeListener(_onPhoneChanged);
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = _kResendCooldownSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  void _stopResendCountdown() {
    _resendTimer?.cancel();
    _resendTimer = null;
    if (_resendSeconds != 0) {
      setState(() => _resendSeconds = 0);
    }
  }

  Future<void> _resendSms() async {
    if (_resendSeconds > 0 || _submitting) return;
    setState(() {
      _error = null;
      _otp = '';
      _otpCtrl.clear();
    });
    await AuthApi.sendSms(_phone);
    if (!mounted) return;
    _startResendCountdown();
    _otpFocus.requestFocus();
  }

  void _onPhoneChanged() {
    final t = _phoneCtrl.text;
    if (t.length == 11 && _step == _LoginStep.phone) {
      _goToCode(t);
    }
  }

  void _goToCode(String phone) {
    setState(() {
      _phone = phone;
      _step = _LoginStep.code;
      _otp = '';
      _otpCtrl.clear();
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _otpFocus.requestFocus();
    });
    AuthApi.sendSms(phone);
    _startResendCountdown();
  }

  void _back() {
    if (_step == _LoginStep.code) {
      _stopResendCountdown();
      setState(() {
        _step = _LoginStep.phone;
        _otp = '';
        _otpCtrl.clear();
        _error = null;
      });
      return;
    }
    widget.onBack?.call();
  }

  void _onOtpChanged(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final next = digits.length > 6 ? digits.substring(0, 6) : digits;
    if (next == _otp) return;
    setState(() {
      _otp = next;
      _error = null;
    });
    if (next.length == 6) _submitLogin(next);
  }

  Future<void> _submitLogin(String code) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final res = await AuthApi.phoneLogin(_phone, code);
    if (!mounted) return;
    if (!res.ok || res.data == null) {
      setState(() {
        _submitting = false;
        _otp = '';
        _otpCtrl.clear();
        _error = res.message.isNotEmpty ? res.message : '验证失败';
      });
      _otpFocus.requestFocus();
      return;
    }
    final data = res.data!;
    if (data.needsRegister) {
      setState(() => _submitting = false);
      widget.onNeedsRegister?.call(_phone, data.registerToken ?? '');
      return;
    }
    if (data.loggedIn && data.userId != null) {
      widget.onLoggedIn?.call(data.userId!);
      return;
    }
    setState(() {
      _submitting = false;
      _otp = '';
      _otpCtrl.clear();
      _error = '登录异常，请重试';
    });
  }

  String get _maskedPhone {
    if (_phone.length < 11) return _phone;
    return '${_phone.substring(0, 3)} ${_phone.substring(3, 7)} ${_phone.substring(7)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _minimalTopBar(),
        const _AuthLogoHeader(),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _step == _LoginStep.phone
                ? _buildPhoneStep()
                : _buildCodeStep(),
          ),
        ),
      ],
    );
  }

  Widget _minimalTopBar() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
    child: Row(
      children: [
        MirrorBackButton(onTap: _back),
        const Spacer(),
        if (_step == _LoginStep.code)
          _resendSeconds > 0
              ? Text(
                  '${_resendSeconds}s',
                  key: const Key('login-resend-countdown'),
                  style: MirrorTheme.mono(
                    fontSize: 13,
                    color: MirrorColors.text4,
                  ),
                )
              : MirrorPressable(
                  onTap: _submitting ? null : _resendSms,
                  child: Text(
                    '重新发送',
                    key: const Key('login-resend-button'),
                    style: MirrorTheme.sans(
                      fontSize: 13,
                      color: _submitting
                          ? MirrorColors.text4
                          : MirrorColors.accent,
                    ),
                  ),
                ),
      ],
    ),
  );

  Widget _buildPhoneStep() {
    return Padding(
      key: const ValueKey('phone'),
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '登录',
            style: MirrorTheme.sans(
              fontSize: 22,
              weight: FontWeight.w500,
              letterSpacing: -0.02,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '输入手机号',
            style: MirrorTheme.sans(fontSize: 13, color: MirrorColors.text3),
          ),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12, right: 12),
                child: Text(
                  '+86',
                  style: MirrorTheme.mono(
                    fontSize: 15,
                    color: MirrorColors.text2,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  key: const Key('login-phone-field'),
                  controller: _phoneCtrl,
                  autofocus: true,
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: MirrorTheme.sans(
                    fontSize: 26,
                    weight: FontWeight.w400,
                    letterSpacing: 2,
                  ),
                  decoration: InputDecoration(
                    hintText: '手机号',
                    hintStyle: MirrorTheme.sans(
                      fontSize: 26,
                      color: MirrorColors.text4,
                      letterSpacing: 0,
                    ),
                    border: const UnderlineInputBorder(
                      borderSide: BorderSide(color: MirrorColors.border),
                    ),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: MirrorColors.border),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: MirrorColors.text,
                        width: 1.5,
                      ),
                    ),
                    counterText: '',
                    contentPadding: const EdgeInsets.only(bottom: 10),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.coral),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCodeStep() {
    return Padding(
      key: const Key('login-code-step'),
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '输入验证码',
            style: MirrorTheme.sans(
              fontSize: 22,
              weight: FontWeight.w500,
              letterSpacing: -0.02,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '已发送至 $_maskedPhone',
            style: MirrorTheme.sans(fontSize: 13, color: MirrorColors.text3),
          ),
          const SizedBox(height: 36),
          _OtpBoxes(
            value: _otp,
            controller: _otpCtrl,
            focusNode: _otpFocus,
            enabled: !_submitting,
            onChanged: _onOtpChanged,
          ),
          const SizedBox(height: 20),
          if (_submitting)
            Center(
              child: Text(
                '验证中…',
                style: MirrorTheme.mono(
                  fontSize: 11,
                  color: MirrorColors.text3,
                ),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.coral),
            ),
          ],
        ],
      ),
    );
  }
}

/// 登录/注册页顶部 Mirror Logo（与欢迎页一致风格）
class _AuthLogoHeader extends StatelessWidget {
  const _AuthLogoHeader({this.showSlogan = true});

  final bool showSlogan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  border: Border.all(color: MirrorColors.border),
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: MirrorColors.text,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: const MirrorIcon(size: 40),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '魔镜',
            style: MirrorTheme.sans(
              fontSize: 28,
              weight: FontWeight.w500,
              letterSpacing: -0.025,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Mirror',
            style: MirrorTheme.mono(
              fontSize: 11,
              color: MirrorColors.text3,
              letterSpacing: 0.06,
            ),
          ),
          if (showSlogan) ...[
            const SizedBox(height: 6),
            Text(
              '照见知识、映射能力',
              style: MirrorTheme.sans(
                fontSize: 12,
                color: MirrorColors.text3,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 6 格 OTP 输入（隐藏 TextField 承接键盘）
class _OtpBoxes extends StatelessWidget {
  const _OtpBoxes({
    required this.value,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.enabled = true,
  });

  final String value;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              final ch = i < value.length ? value[i] : '';
              final active = i == value.length;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: i == 0 ? 0 : 6,
                    right: i == 5 ? 0 : 6,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ch.isNotEmpty || active
                          ? MirrorColors.bgApp
                          : MirrorColors.bgSoft,
                      border: Border.all(
                        color: active
                            ? MirrorColors.accent
                            : (ch.isNotEmpty
                                  ? MirrorColors.text
                                  : MirrorColors.border),
                        width: active ? 1.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      ch,
                      style: MirrorTheme.mono(
                        fontSize: 20,
                        weight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        Opacity(
          opacity: 0.01,
          child: SizedBox(
            height: 52,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: onChanged,
              style: const TextStyle(fontSize: 1),
              decoration: const InputDecoration(
                border: InputBorder.none,
                counterText: '',
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 新用户注册（手机号已验证）
class PhoneRegisterScreen extends StatefulWidget {
  const PhoneRegisterScreen({
    super.key,
    required this.phone,
    required this.registerToken,
    this.onBack,
    this.onRegistered,
  });

  final String phone;
  final String registerToken;
  final VoidCallback? onBack;
  final void Function(int userId)? onRegistered;

  @override
  State<PhoneRegisterScreen> createState() => _PhoneRegisterScreenState();
}

class _PhoneRegisterScreenState extends State<PhoneRegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '请填写昵称');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final res = await AuthApi.register(
      phone: widget.phone,
      registerToken: widget.registerToken,
      displayName: name,
      bio: _bioCtrl.text.trim(),
    );
    if (!mounted) return;
    if (!res.ok || res.data == null) {
      setState(() {
        _submitting = false;
        _error = res.message.isNotEmpty ? res.message : '注册失败';
      });
      return;
    }
    widget.onRegistered?.call(res.data!.userId);
  }

  String get _maskedPhone {
    final p = widget.phone;
    if (p.length < 11) return p;
    return '${p.substring(0, 3)} **** ${p.substring(7)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
          child: Row(children: [MirrorBackButton(onTap: widget.onBack)]),
        ),
        const _AuthLogoHeader(showSlogan: false),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 4, 28, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '完善资料',
                  style: MirrorTheme.sans(
                    fontSize: 22,
                    weight: FontWeight.w500,
                    letterSpacing: -0.02,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '最后一步，设置你的 Mirror 身份',
                  style: MirrorTheme.sans(
                    fontSize: 13,
                    color: MirrorColors.text3,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: MirrorColors.accentSoft,
                    border: Border.all(color: MirrorColors.accentBorder),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: MirrorColors.bgApp,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: MirrorColors.accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '手机号已验证',
                              style: MirrorTheme.sans(
                                fontSize: 13,
                                weight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _maskedPhone,
                              style: MirrorTheme.mono(
                                fontSize: 11,
                                color: MirrorColors.text2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _RegisterField(
                  label: '昵称',
                  controller: _nameCtrl,
                  hint: '如 林岸 · Lin Yan',
                ),
                const SizedBox(height: 16),
                _RegisterField(
                  label: '简介',
                  controller: _bioCtrl,
                  hint: '一句话介绍你和你的 Agent（可选）',
                  maxLines: 3,
                  optional: true,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: MirrorColors.coralSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _error!,
                      style: MirrorTheme.sans(
                        fontSize: 12,
                        color: MirrorColors.coral,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 44),
          child: MirrorPressable(
            onTap: _submitting ? null : _submit,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _submitting ? MirrorColors.text3 : MirrorColors.text,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _submitting ? '创建中…' : '进入 Mirror',
                textAlign: TextAlign.center,
                style: MirrorTheme.sans(
                  fontSize: 14,
                  weight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 注册表单字段（与灵魂页/发布页一致的圆角输入框）
class _RegisterField extends StatelessWidget {
  const _RegisterField({
    required this.label,
    required this.controller,
    required this.hint,
    this.prefix,
    this.helper,
    this.maxLines = 1,
    this.optional = false,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final String? prefix;
  final String? helper;
  final int maxLines;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: MirrorTheme.mono(
                fontSize: 10,
                color: MirrorColors.text3,
                letterSpacing: 0.06,
              ),
            ),
            if (optional) ...[
              const SizedBox(width: 6),
              Text(
                '可选',
                style: MirrorTheme.mono(
                  fontSize: 9,
                  color: MirrorColors.text4,
                  letterSpacing: 0.04,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: MirrorColors.bgSoft,
            border: Border.all(color: MirrorColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            crossAxisAlignment: maxLines > 1
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              if (prefix != null) ...[
                Padding(
                  padding: EdgeInsets.only(top: maxLines > 1 ? 12 : 0),
                  child: Text(
                    prefix!,
                    style: MirrorTheme.mono(
                      fontSize: 14,
                      color: MirrorColors.text2,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: maxLines > 1 ? 20 : 18,
                  margin: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: maxLines > 1 ? 14 : 0,
                  ),
                  color: MirrorColors.border,
                ),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: maxLines,
                  style: MirrorTheme.sans(
                    fontSize: 15,
                    height: maxLines > 1 ? 1.55 : 1.2,
                  ),
                  cursorColor: MirrorColors.accent,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: MirrorTheme.sans(
                      fontSize: 14,
                      color: MirrorColors.text3,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: maxLines > 1 ? 12 : 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(
            helper!,
            style: MirrorTheme.sans(
              fontSize: 11,
              color: MirrorColors.text4,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}
