import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../legal/mirror_legal_documents.dart';
import '../screens/legal_document_screen.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';

/// 登录前法律告知：登录/注册即表示同意用户协议与隐私政策。
class LoginLegalConsentFooter extends StatelessWidget {
  const LoginLegalConsentFooter({super.key, this.actionPrefix = '登录'});

  final String actionPrefix;

  @override
  Widget build(BuildContext context) {
    final base = MirrorTheme.sans(fontSize: 12, color: MirrorColors.text3, height: 1.55);
    final link = base.copyWith(color: MirrorColors.accentDeep);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: base,
          children: [
            TextSpan(text: '$actionPrefix即表示同意'),
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
    );
  }
}
