import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/kb/kb_ui_helpers.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../utils/external_url.dart';
import '../widgets/mirror_pressable.dart';

const _prefKeyOfficeOpenMode = 'mirror.office_open_mode';
const _modeSave = 'save';
const _modeOpenOnly = 'open';

/// Office 文件全屏引导：大图标 + 打开并存储 / 仅打开（对齐系统文档应用样式）。
class OfficeFileOpenScreen extends StatefulWidget {
  const OfficeFileOpenScreen({
    super.key,
    required this.filename,
    required this.downloadUrl,
    this.openUrl,
  });

  final String filename;
  final String downloadUrl;
  final String? openUrl;

  @override
  State<OfficeFileOpenScreen> createState() => _OfficeFileOpenScreenState();
}

class _OfficeFileOpenScreenState extends State<OfficeFileOpenScreen> {
  var _remember = false;

  String get _openUrl => widget.openUrl?.trim().isNotEmpty == true
      ? widget.openUrl!.trim()
      : widget.downloadUrl.trim();

  @override
  void initState() {
    super.initState();
    _tryAutoOpenFromPreference();
  }

  Future<void> _tryAutoOpenFromPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_prefKeyOfficeOpenMode);
    if (!mounted || mode == null) return;
    if (mode == _modeSave) {
      await _launch(widget.downloadUrl);
      if (mounted) Navigator.of(context).pop();
    } else if (mode == _modeOpenOnly) {
      await _launch(_openUrl);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _persistMode(String mode) async {
    if (!_remember) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyOfficeOpenMode, mode);
  }

  Future<void> _launch(String url) async {
    final ok = await openExternalUrl(url);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('无法打开文件，请检查网络或稍后重试'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onSaveAndOpen() async {
    await _persistMode(_modeSave);
    await _launch(widget.downloadUrl);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _onOpenOnly() async {
    await _persistMode(_modeOpenOnly);
    await _launch(_openUrl);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.filename.trim().isEmpty ? '附件' : widget.filename.trim();
    final (icon, color, _) = KbDocUi.fileTypeForFilename(name);

    return Scaffold(
      backgroundColor: MirrorColors.bgApp,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: MirrorPressable(
                onTap: () => Navigator.of(context).pop(),
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                borderRadius: BorderRadius.circular(8),
                child: const Icon(Icons.chevron_left, size: 28, color: MirrorColors.text),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, size: 44, color: Colors.white),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: MirrorTheme.sans(fontSize: 17, weight: FontWeight.w500, height: 1.35),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton(
                    onPressed: _onSaveAndOpen,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MirrorColors.blue,
                      side: const BorderSide(color: MirrorColors.blue, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: Text(
                      '打开并存储',
                      style: MirrorTheme.sans(fontSize: 16, weight: FontWeight.w500, color: MirrorColors.blue),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _onOpenOnly,
                    style: FilledButton.styleFrom(
                      backgroundColor: MirrorColors.bgCard,
                      foregroundColor: MirrorColors.text,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: Text(
                      '仅打开',
                      style: MirrorTheme.sans(fontSize: 16, weight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Checkbox(
                          value: _remember,
                          onChanged: (v) => setState(() => _remember = v ?? false),
                          activeColor: MirrorColors.blue,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '记住选择，不再询问',
                        style: MirrorTheme.sans(fontSize: 13, color: MirrorColors.text3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 打开 Office 全屏引导页。
Future<void> openOfficeFileGuide(
  BuildContext context, {
  required String filename,
  required String downloadUrl,
  String? openUrl,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => OfficeFileOpenScreen(
        filename: filename,
        downloadUrl: downloadUrl,
        openUrl: openUrl,
      ),
    ),
  );
}
