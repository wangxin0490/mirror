import 'package:flutter/material.dart';

import '../../api/api_result.dart';
import '../../theme/mirror_colors.dart';
import '../../theme/mirror_theme.dart';
import '../../widgets/mirror_pressable.dart';

/// 弹出网页链接导入底部表单。
///
/// [onImport] 提交 URL 与可选标题，由调用方调用 API。
/// 返回 true 表示导入请求已成功提交（202）。
Future<bool> showKbWebImportSheet(
  BuildContext context, {
  required Future<ApiResult<dynamic>> Function(String url, String? title) onImport,
}) async {
  final urlCtrl = TextEditingController();
  final titleCtrl = TextEditingController();
  var submitting = false;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: MirrorColors.bgApp,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheet) {
          final keyboardBottom = MediaQuery.viewInsetsOf(ctx).bottom;
          return Padding(
            padding: EdgeInsets.only(bottom: keyboardBottom),
            child: SingleChildScrollView(
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('导入网页链接', style: MirrorTheme.sans(fontSize: 17, weight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: urlCtrl,
                        decoration: InputDecoration(
                          hintText: 'https://example.com/article',
                          hintStyle: MirrorTheme.sans(fontSize: 14, color: MirrorColors.text3),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: TextInputType.url,
                        autofocus: true,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          hintText: '标题（可选）',
                          hintStyle: MirrorTheme.sans(fontSize: 14, color: MirrorColors.text3),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      MirrorPressable(
                        onTap: submitting
                            ? null
                            : () async {
                                final url = urlCtrl.text.trim();
                                if (url.isEmpty) return;
                                setSheet(() => submitting = true);
                                final title = titleCtrl.text.trim();
                                final r = await onImport(url, title.isEmpty ? null : title);
                                if (!ctx.mounted) return;
                                if (r.ok) {
                                  Navigator.pop(ctx, true);
                                } else {
                                  setSheet(() => submitting = false);
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text(r.message.isNotEmpty ? r.message : '导入失败')),
                                  );
                                }
                              },
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: MirrorColors.text,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            submitting ? '提交中…' : '开始导入',
                            style: MirrorTheme.sans(fontSize: 15, color: Colors.white, weight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
  urlCtrl.dispose();
  titleCtrl.dispose();
  return ok == true;
}
