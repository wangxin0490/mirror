import 'package:flutter/material.dart';

import '../api/me_api.dart';
import '../legal/mirror_legal_documents.dart';
import '../screens/legal_document_screen.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../widgets/mirror_pressable.dart';
import '../widgets/phone_components.dart';

/// 账号与隐私设置：法律文档、注销账号。
class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({
    super.key,
    this.onBack,
    this.onAccountDeleted,
  });

  final VoidCallback? onBack;
  final VoidCallback? onAccountDeleted;

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool _deleting = false;

  Future<void> _confirmDeleteAccount() async {
    final step1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MirrorColors.bgApp,
        title: Text('注销账号', style: MirrorTheme.sans(fontSize: 16, weight: FontWeight.w600)),
        content: Text(
          '注销后，您的账号资料、帖子、对话记录等个人数据将被永久删除且无法恢复。确定要继续吗？',
          style: MirrorTheme.sans(fontSize: 13, height: 1.55, color: MirrorColors.text2),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('继续', style: MirrorTheme.sans(color: MirrorColors.coral)),
          ),
        ],
      ),
    );
    if (step1 != true || !mounted) return;

    final step2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MirrorColors.bgApp,
        title: Text('最后确认', style: MirrorTheme.sans(fontSize: 16, weight: FontWeight.w600)),
        content: Text(
          '此操作不可撤销。您的账号及所有相关数据将被永久删除。',
          style: MirrorTheme.sans(fontSize: 13, height: 1.55, color: MirrorColors.text2),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '永久注销账号',
              style: MirrorTheme.sans(color: MirrorColors.coral, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (step2 != true || !mounted) return;

    setState(() => _deleting = true);
    final r = await MeApi.deleteAccount();
    if (!mounted) return;
    setState(() => _deleting = false);

    if (!r.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            r.message.isNotEmpty ? r.message : '注销失败，请稍后重试',
            style: MirrorTheme.sans(fontSize: 13, color: Colors.white),
          ),
        ),
      );
      return;
    }

    widget.onAccountDeleted?.call();
  }

  Widget _row({
    required IconData icon,
    required String label,
    String? sub,
    VoidCallback? onTap,
    Color? labelColor,
  }) {
    return MirrorPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: MirrorColors.borderSoft)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: labelColor ?? MirrorColors.text2),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: MirrorTheme.sans(
                      fontSize: 13,
                      weight: FontWeight.w500,
                      color: labelColor,
                    ),
                  ),
                  if (sub != null)
                    Text(sub, style: MirrorTheme.mono(fontSize: 10, color: MirrorColors.text3)),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, size: 16, color: MirrorColors.text3),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
          child: SizedBox(
            height: 40,
            child: Row(
              children: [
                MirrorBackButton(onTap: widget.onBack),
                const SizedBox(width: 8),
                Text('账号与隐私', style: MirrorTheme.sans(fontSize: 16, weight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
            children: [
              const SectionLabel('法律文档'),
              Container(
                decoration: BoxDecoration(
                  color: MirrorColors.bgApp,
                  border: Border.all(color: MirrorColors.borderSoft),
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _row(
                      icon: Icons.description_outlined,
                      label: '用户协议',
                      onTap: () => LegalDocumentScreen.open(context, MirrorLegalDocument.userAgreement),
                    ),
                    _row(
                      icon: Icons.privacy_tip_outlined,
                      label: '隐私政策',
                      onTap: () => LegalDocumentScreen.open(context, MirrorLegalDocument.privacyPolicy),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionLabel('账号管理'),
              Container(
                decoration: BoxDecoration(
                  color: MirrorColors.bgApp,
                  border: Border.all(color: MirrorColors.borderSoft),
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: _row(
                  icon: Icons.delete_outline,
                  label: _deleting ? '正在注销…' : '注销账号',
                  sub: '永久删除账号及全部个人数据',
                  labelColor: MirrorColors.coral,
                  onTap: _deleting ? null : _confirmDeleteAccount,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '注销账号后，您将无法再使用该手机号登录，所有数据将被永久删除。',
                style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text3, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
