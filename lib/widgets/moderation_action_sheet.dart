import 'package:flutter/material.dart';

import '../api/moderation_api.dart';
import '../config/api_config.dart';
import '../state/block_store.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';

/// 举报原因选项
const kModerationReportReasons = [
  '垃圾广告或欺诈',
  '色情或低俗内容',
  '暴力、仇恨或骚扰',
  '侵犯隐私或版权',
  '其他违规内容',
];

/// 展示举报 / 拉黑操作表。
Future<void> showModerationActionSheet(
  BuildContext context, {
  required String title,
  int? userId,
  String? userName,
  String? targetType,
  String? targetId,
  String? contentPreview,
  VoidCallback? onBlocked,
}) async {
  if (!ApiConfig.isLoggedIn) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('请先登录', style: MirrorTheme.sans(fontSize: 13))),
    );
    return;
  }

  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: MirrorColors.bgApp,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(title, style: MirrorTheme.sans(fontSize: 14, weight: FontWeight.w600)),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined, color: MirrorColors.coral),
            title: Text('举报不当内容', style: MirrorTheme.sans(fontSize: 14)),
            onTap: () => Navigator.pop(ctx, 'report'),
          ),
          if (userId != null && userId > 0 && userId != ApiConfig.userId)
            ListTile(
              leading: const Icon(Icons.block, color: MirrorColors.text2),
              title: Text('拉黑 $userName', style: MirrorTheme.sans(fontSize: 14)),
              subtitle: Text(
                '立即隐藏该用户的内容，并通知我们审核',
                style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text3),
              ),
              onTap: () => Navigator.pop(ctx, 'block'),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (!context.mounted || action == null) return;

  if (action == 'report') {
    await _showReportReasonSheet(
      context,
      targetType: targetType ?? 'user',
      targetId: targetId ?? '${userId ?? 0}',
      reportedUserId: userId,
      contentPreview: contentPreview,
    );
  } else if (action == 'block' && userId != null && userId > 0) {
    await _confirmBlock(context, userId: userId, userName: userName, onBlocked: onBlocked);
  }
}

Future<void> _showReportReasonSheet(
  BuildContext context, {
  required String targetType,
  required String targetId,
  int? reportedUserId,
  String? contentPreview,
}) async {
  final reason = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: MirrorColors.bgApp,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text('选择举报原因', style: MirrorTheme.sans(fontSize: 14, weight: FontWeight.w600)),
          ),
          for (final r in kModerationReportReasons)
            ListTile(
              title: Text(r, style: MirrorTheme.sans(fontSize: 14)),
              onTap: () => Navigator.pop(ctx, r),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (!context.mounted || reason == null) return;

  final detail = contentPreview != null && contentPreview.length > 120
      ? '${contentPreview.substring(0, 120)}…'
      : (contentPreview ?? '');

  final r = await ModerationApi.report(
    targetType: targetType,
    targetId: targetId,
    reason: reason,
    detail: detail,
    reportedUserId: reportedUserId,
  );

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        r.ok ? '已提交举报，我们会尽快处理' : (r.message.isNotEmpty ? r.message : '举报提交失败'),
        style: MirrorTheme.sans(fontSize: 13, color: Colors.white),
      ),
      backgroundColor: MirrorColors.text,
    ),
  );
}

Future<void> _confirmBlock(
  BuildContext context, {
  required int userId,
  String? userName,
  VoidCallback? onBlocked,
}) async {
  final name = (userName ?? '').trim().isEmpty ? '该用户' : userName!.trim();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: MirrorColors.bgApp,
      title: Text('拉黑 $name？', style: MirrorTheme.sans(fontSize: 16, weight: FontWeight.w600)),
      content: Text(
        '拉黑后，您将立即不再看到该用户的帖子、评论和私信。我们会收到通知并进行审核。',
        style: MirrorTheme.sans(fontSize: 13, height: 1.5, color: MirrorColors.text2),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('确认拉黑', style: MirrorTheme.sans(color: MirrorColors.coral, weight: FontWeight.w600)),
        ),
      ],
    ),
  );

  if (ok != true || !context.mounted) return;

  await BlockStore.instance.blockUser(userId, reason: '用户主动拉黑');
  onBlocked?.call();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('已拉黑 $name', style: MirrorTheme.sans(fontSize: 13, color: Colors.white)),
      backgroundColor: MirrorColors.text,
    ),
  );
}
