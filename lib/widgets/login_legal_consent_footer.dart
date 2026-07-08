import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../legal/mirror_legal_documents.dart';
import '../screens/legal_document_screen.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import 'mirror_pressable.dart';

/// 登录/注册前法律告知：空白复选框 + 协议链接，需用户自愿明确勾选。
class LoginLegalConsentFooter extends StatelessWidget {
  const LoginLegalConsentFooter({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final base = MirrorTheme.sans(fontSize: 12, color: MirrorColors.text3, height: 1.55);
    final link = base.copyWith(color: MirrorColors.accentDeep);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ConsentCheckbox(
            key: const Key('login-legal-consent-checkbox'),
            value: value,
            onChanged: onChanged,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(!value),
              child: RichText(
                text: TextSpan(
                  style: base,
                  children: [
                    const TextSpan(text: '我已阅读并同意'),
                    TextSpan(
                      text: '《用户协议》',
                      style: link,
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => LegalDocumentScreen.open(
                              context,
                              MirrorLegalDocument.userAgreement,
                            ),
                    ),
                    const TextSpan(text: '和'),
                    TextSpan(
                      text: '《隐私政策》',
                      style: link,
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => LegalDocumentScreen.open(
                              context,
                              MirrorLegalDocument.privacyPolicy,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsentCheckbox extends StatelessWidget {
  const _ConsentCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  static const _size = 16.0;
  static const _radius = 3.0;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final size = _snapToDevicePixel(_size, dpr);
    final radius = _snapToDevicePixel(_radius, dpr);

    return MirrorPressable(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _ConsentCheckboxPainter(
            checked: value,
            borderRadius: radius,
            devicePixelRatio: dpr,
            fillColor: value ? MirrorColors.text : MirrorColors.bgApp,
            borderColor: value ? MirrorColors.text : MirrorColors.border,
          ),
        ),
      ),
    );
  }

  static double _snapToDevicePixel(double value, double devicePixelRatio) {
    return (value * devicePixelRatio).round() / devicePixelRatio;
  }
}

class _ConsentCheckboxPainter extends CustomPainter {
  const _ConsentCheckboxPainter({
    required this.checked,
    required this.borderRadius,
    required this.devicePixelRatio,
    required this.fillColor,
    required this.borderColor,
  });

  final bool checked;
  final double borderRadius;
  final double devicePixelRatio;
  final Color fillColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 1 / devicePixelRatio;
    final inset = stroke / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - stroke,
      size.height - stroke,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    canvas.drawRRect(rrect, Paint()..color = fillColor);

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    if (!checked) return;

    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.28, h * 0.52)
      ..lineTo(w * 0.44, h * 0.68)
      ..lineTo(w * 0.74, h * 0.34);
    canvas.drawPath(path, checkPaint);
  }

  @override
  bool shouldRepaint(covariant _ConsentCheckboxPainter oldDelegate) {
    return oldDelegate.checked != checked ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.devicePixelRatio != devicePixelRatio;
  }
}

/// 未勾选协议时弹窗确认；提供明确的拒绝选项。
class LoginLegalConsentDialog extends StatelessWidget {
  const LoginLegalConsentDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoginLegalConsentDialog(),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final body = MirrorTheme.sans(fontSize: 13, height: 1.55, color: MirrorColors.text2);
    return AlertDialog(
      key: const Key('login-legal-consent-dialog'),
      backgroundColor: MirrorColors.bgApp,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        '用户协议与隐私政策',
        style: MirrorTheme.sans(fontSize: 16, weight: FontWeight.w600),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '继续使用 MirrorX 前，请您阅读并自愿同意《用户协议》和《隐私政策》。',
              style: body,
            ),
            const SizedBox(height: 12),
            MirrorPressable(
              onTap: () => LegalDocumentScreen.open(context, MirrorLegalDocument.userAgreement),
              child: Text(
                '查看《用户协议》',
                style: MirrorTheme.sans(fontSize: 13, color: MirrorColors.accentDeep, weight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 6),
            MirrorPressable(
              onTap: () => LegalDocumentScreen.open(context, MirrorLegalDocument.privacyPolicy),
              child: Text(
                '查看《隐私政策》',
                style: MirrorTheme.sans(fontSize: 13, color: MirrorColors.accentDeep, weight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '若您不同意，将无法登录或使用本应用。',
              style: body,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('login-legal-consent-decline'),
          onPressed: () => Navigator.pop(context, false),
          child: Text('不同意', style: MirrorTheme.sans(fontSize: 13, color: MirrorColors.text3)),
        ),
        TextButton(
          key: const Key('login-legal-consent-accept'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            '同意并继续',
            style: MirrorTheme.sans(fontSize: 13, weight: FontWeight.w600, color: MirrorColors.accent),
          ),
        ),
      ],
    );
  }
}

/// 若已勾选则直接通过；否则弹出含「不同意」选项的确认弹窗。
Future<bool> ensureLoginLegalConsent(
  BuildContext context, {
  required bool accepted,
}) async {
  if (accepted) return true;
  if (!context.mounted) return false;
  return LoginLegalConsentDialog.show(context);
}
