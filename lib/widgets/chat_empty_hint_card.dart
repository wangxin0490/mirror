import 'package:flutter/material.dart';

import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';

/// 知识库空答案 / 无结果提示（区别于 Markdown 正文气泡）。
class ChatEmptyHintCard extends StatelessWidget {
  const ChatEmptyHintCard({super.key, required this.message});

  final String message;

  /// 是否为 KB 空答案模板文案（含 SSE `empty` 与本地 fallback）。
  static bool isKbEmptyHintContent(String content) {
    final t = content.trim();
    if (t.isEmpty) return false;
    return t.contains('未在知识库中检索到') ||
        t.contains('未在知识库中找到') ||
        t.contains('未收到回答，请确认知识库文档已解析完成');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: MirrorColors.bgSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MirrorColors.borderSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 36,
            margin: const EdgeInsets.only(right: 10, top: 2),
            decoration: BoxDecoration(
              color: MirrorColors.text3.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Icon(Icons.info_outline, size: 16, color: MirrorColors.text3),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.trim(),
              style: MirrorTheme.sans(fontSize: 13, height: 1.55, color: MirrorColors.text2),
            ),
          ),
        ],
      ),
    );
  }
}
