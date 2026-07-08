import 'package:flutter/material.dart';

import '../legal/ai_third_party_disclosure.dart';
import '../legal/mirror_legal_documents.dart';
import '../screens/legal_document_screen.dart';
import '../services/ai_consent_store.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../widgets/mirror_pressable.dart';

/// 首次使用 AI 功能前，说明数据共享范围并征得用户同意（App Store 5.1.1/5.1.2）。
class AiDataConsentDialog extends StatelessWidget {
  const AiDataConsentDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AiDataConsentDialog(),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: MirrorColors.bgApp,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        '第三方 AI 数据处理授权',
        style: MirrorTheme.sans(fontSize: 16, weight: FontWeight.w600),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              aiThirdPartyConsentLeadSentence(),
              style: MirrorTheme.sans(
                fontSize: 13,
                height: 1.55,
                weight: FontWeight.w600,
                color: MirrorColors.text,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '接收方与用途：',
              style: MirrorTheme.sans(fontSize: 13, weight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            ...kAiThirdPartyProviders.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: MirrorTheme.sans(fontSize: 13, color: MirrorColors.text2)),
                    Expanded(
                      child: Text(
                        '${p.companyName}：${p.services}',
                        style: MirrorTheme.sans(fontSize: 13, height: 1.45, color: MirrorColors.text2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('可能发送的数据包括：', style: MirrorTheme.sans(fontSize: 13, weight: FontWeight.w600)),
            const SizedBox(height: 6),
            ...[
              '您输入的文字、图片、文件与语音（含实时转写）',
              '所选 AI 模型与会话上下文（用于连续对话）',
              '知识库文档片段（仅在知识库问答时）',
              '会议录音及转写文本（仅在会议纪要功能中）',
            ].map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: MirrorTheme.sans(fontSize: 13, color: MirrorColors.text2)),
                    Expanded(
                      child: Text(t, style: MirrorTheme.sans(fontSize: 13, height: 1.45, color: MirrorColors.text2)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '点击「同意并继续」即表示您明确同意我们将上述数据发送至所列第三方 AI 服务提供商。'
              '您可随时停止使用相关功能；完整说明见《隐私政策》。',
              style: MirrorTheme.sans(fontSize: 12, height: 1.5, color: MirrorColors.text3),
            ),
            const SizedBox(height: 10),
            MirrorPressable(
              onTap: () => LegalDocumentScreen.open(context, MirrorLegalDocument.privacyPolicy),
              child: Text(
                '查看完整隐私政策',
                style: MirrorTheme.sans(fontSize: 13, color: MirrorColors.accentDeep, weight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('暂不使用', style: MirrorTheme.sans(fontSize: 13, color: MirrorColors.text3)),
        ),
        TextButton(
          onPressed: () async {
            await AiConsentStore.setConsented(true);
            if (context.mounted) Navigator.pop(context, true);
          },
          child: Text('同意并继续', style: MirrorTheme.sans(fontSize: 13, weight: FontWeight.w600, color: MirrorColors.accent)),
        ),
      ],
    );
  }
}

/// 在发送 AI 请求前调用；已同意则直接返回 true。
Future<bool> ensureAiDataConsent(BuildContext context) async {
  if (await AiConsentStore.hasConsented()) return true;
  if (!context.mounted) return false;
  return AiDataConsentDialog.show(context);
}
