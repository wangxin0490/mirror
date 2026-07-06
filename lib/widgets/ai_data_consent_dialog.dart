import 'package:flutter/material.dart';

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
        '第三方 AI 数据处理说明',
        style: MirrorTheme.sans(fontSize: 16, weight: FontWeight.w600),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'MirrorX 的 AI 对话、知识库问答、会议纪要等功能，会将您输入的内容发送至第三方大语言模型与语音识别服务以生成回复。',
              style: MirrorTheme.sans(fontSize: 13, height: 1.55, color: MirrorColors.text2),
            ),
            const SizedBox(height: 14),
            Text('可能发送的数据包括：', style: MirrorTheme.sans(fontSize: 13, weight: FontWeight.w600)),
            const SizedBox(height: 6),
            ...[
              '您输入的文字、图片、文件与语音转写文本',
              '所选 AI 模型与会话上下文（用于连续对话）',
              '知识库文档片段（仅在知识库问答时）',
              '会议录音转写文本（仅在会议纪要功能中）',
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
            Text('数据接收方：', style: MirrorTheme.sans(fontSize: 13, weight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              '经我们甄选并签订数据处理协议的第三方 AI 服务提供商（包括但不限于大语言模型推理与语音识别服务商）。具体名单与用途详见《隐私政策》。',
              style: MirrorTheme.sans(fontSize: 13, height: 1.5, color: MirrorColors.text2),
            ),
            const SizedBox(height: 12),
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
