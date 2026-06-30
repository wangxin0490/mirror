import 'package:flutter/material.dart';

import '../legal/mirror_legal_documents.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';

/// 应用内展示用户协议 / 隐私政策全文。
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final MirrorLegalDocument document;

  static Future<void> open(BuildContext context, MirrorLegalDocument doc) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => LegalDocumentScreen(document: doc)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MirrorColors.bgApp,
      appBar: AppBar(
        backgroundColor: MirrorColors.bgApp,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: MirrorColors.text2),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          document.title,
          style: MirrorTheme.sans(fontSize: 16, weight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            '更新日期：${document.updatedAt}',
            style: MirrorTheme.mono(fontSize: 11, color: MirrorColors.text3),
          ),
          const SizedBox(height: 20),
          for (final section in document.sections) ...[
            Text(
              section.heading,
              style: MirrorTheme.sans(
                fontSize: 15,
                weight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              section.body,
              style: MirrorTheme.sans(
                fontSize: 14,
                color: MirrorColors.text2,
                height: 1.75,
              ),
            ),
            const SizedBox(height: 22),
          ],
        ],
      ),
    );
  }
}
