import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/api_config.dart';
import '../models/document_preview.dart';
import '../screens/office_file_open_screen.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../utils/external_url.dart';
import '../utils/media_url.dart';
import '../utils/office_file.dart';
import '../widgets/mirror_pressable.dart';

/// 按后端 preview kind 路由到对应渲染器。
class DocumentPreviewScreen extends StatefulWidget {
  const DocumentPreviewScreen({
    super.key,
    required this.preview,
    this.headers,
  });

  final DocumentPreviewResult preview;
  final Map<String, String>? headers;

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  var _sheetIndex = 0;

  DocumentPreviewResult get preview => widget.preview;

  Map<String, String>? get _authHeaders {
    if (widget.headers != null && widget.headers!.isNotEmpty) return widget.headers;
    if (ApiConfig.accessToken.isEmpty) return null;
    final src = preview.inlineUrl ?? preview.downloadUrl;
    if (!src.contains('/api/v1/')) return null;
    return {'Authorization': 'Bearer ${ApiConfig.accessToken}'};
  }

  Future<void> _downloadOriginal() async {
    final url = resolveMediaUrl(fileDownloadUrl(preview.downloadUrl));
    if (url.isEmpty) return;
    final ok = await openExternalUrl(url);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法下载文件'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = preview.kind.trim().toLowerCase();
    if (kind == 'binary') {
      return OfficeFileOpenScreen(
        filename: preview.filename,
        downloadUrl: resolveMediaUrl(fileDownloadUrl(preview.downloadUrl)),
        openUrl: resolveMediaUrl(preview.downloadUrl),
      );
    }

    return Scaffold(
      backgroundColor: MirrorColors.bgApp,
      appBar: AppBar(
        backgroundColor: MirrorColors.bgApp,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: MirrorPressable(
          onTap: () => Navigator.of(context).pop(),
          padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
          borderRadius: BorderRadius.circular(8),
          child: const Icon(Icons.chevron_left, size: 22, color: MirrorColors.text),
        ),
        title: Text(
          preview.filename,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MirrorTheme.sans(fontSize: 15, weight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: '下载原文件',
            onPressed: _downloadOriginal,
            icon: const Icon(Icons.download_outlined, color: MirrorColors.text2),
          ),
        ],
      ),
      body: switch (kind) {
        'image' => _ImageBody(preview: preview, headers: _authHeaders),
        'pdf' => _PdfBody(preview: preview, headers: _authHeaders),
        'text' => _TextBody(preview: preview),
        'table' => _TableBody(
            preview: preview,
            sheetIndex: _sheetIndex,
            onSheetChanged: (i) => setState(() => _sheetIndex = i),
          ),
        _ => _BinaryHint(preview: preview, onDownload: _downloadOriginal),
      },
    );
  }
}

class _ImageBody extends StatelessWidget {
  const _ImageBody({required this.preview, this.headers});

  final DocumentPreviewResult preview;
  final Map<String, String>? headers;

  @override
  Widget build(BuildContext context) {
    final url = resolveMediaUrl(preview.inlineUrl ?? preview.downloadUrl);
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4,
      child: Center(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          headers: headers,
          errorBuilder: (_, __, ___) => const Center(child: Text('图片加载失败')),
        ),
      ),
    );
  }
}

class _PdfBody extends StatefulWidget {
  const _PdfBody({required this.preview, this.headers});

  final DocumentPreviewResult preview;
  final Map<String, String>? headers;

  @override
  State<_PdfBody> createState() => _PdfBodyState();
}

class _PdfBodyState extends State<_PdfBody> {
  late final WebViewController _controller;
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    if (!kIsWeb) {
      _controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (mounted) setState(() => _loading = false);
            },
            onWebResourceError: (e) {
              if (mounted) {
                setState(() {
                  _loading = false;
                  _error = e.description;
                });
              }
            },
          ),
        );
    }
    _load();
  }

  Future<void> _load() async {
    final url = resolveMediaUrl(widget.preview.inlineUrl ?? widget.preview.downloadUrl);
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (mounted) setState(() { _loading = false; _error = '无效链接'; });
      return;
    }
    try {
      await _controller.loadRequest(uri, headers: widget.headers ?? const {});
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = '$e'; });
      return;
    }
    if (kIsWeb && mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text(_error!, style: MirrorTheme.sans(fontSize: 14, color: MirrorColors.text3)));
    }
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_loading)
          const Center(
            child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      ],
    );
  }
}

class _TextBody extends StatelessWidget {
  const _TextBody({required this.preview});

  final DocumentPreviewResult preview;

  @override
  Widget build(BuildContext context) {
    final text = preview.text;
    if (text == null || text.content.isEmpty) {
      return const Center(child: Text('暂无文本内容'));
    }
    final lang = text.language.toLowerCase();
    final isMarkdown = lang == 'markdown';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (text.truncated)
          const _TruncationBanner(message: '文本内容已截断，请下载原文件查看完整内容'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: isMarkdown
                ? GptMarkdown(text.content)
                : SelectableText(
                    text.content,
                    style: MirrorTheme.mono(fontSize: 13, height: 1.5),
                  ),
          ),
        ),
      ],
    );
  }
}

class _TableBody extends StatelessWidget {
  const _TableBody({
    required this.preview,
    required this.sheetIndex,
    required this.onSheetChanged,
  });

  final DocumentPreviewResult preview;
  final int sheetIndex;
  final ValueChanged<int> onSheetChanged;

  @override
  Widget build(BuildContext context) {
    final table = preview.table;
    final sheets = table?.sheets ?? const [];
    if (sheets.isEmpty) {
      return const Center(child: Text('表格为空'));
    }
    final idx = sheetIndex.clamp(0, sheets.length - 1);
    final sheet = sheets[idx];
    final columns = sheet.columns;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sheet.truncatedRows || sheet.truncatedColumns || sheet.truncatedSheets)
          _TruncationBanner(message: _tableTruncationMessage(sheet)),
        if (sheets.length > 1)
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: sheets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final selected = i == idx;
                return ChoiceChip(
                  label: Text(sheets[i].name),
                  selected: selected,
                  onSelected: (_) => onSheetChanged(i),
                );
              },
            ),
          ),
        Expanded(
          child: Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Scrollbar(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(MirrorColors.bgCard),
                    columns: [
                      for (final col in columns)
                        DataColumn(
                          label: Text(
                            col,
                            style: MirrorTheme.sans(fontSize: 12, weight: FontWeight.w600),
                          ),
                        ),
                    ],
                    rows: [
                      for (final row in sheet.rows)
                        DataRow(
                          cells: [
                            for (var i = 0; i < columns.length; i++)
                              DataCell(Text(row.length > i ? row[i] : '')),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _tableTruncationMessage(DocumentTableSheet sheet) {
    final parts = <String>[];
    if (sheet.truncatedSheets) parts.add('工作表');
    if (sheet.truncatedRows) parts.add('行');
    if (sheet.truncatedColumns) parts.add('列');
    return '${parts.join('、')}已截断，请下载原文件查看完整表格';
  }
}

class _TruncationBanner extends StatelessWidget {
  const _TruncationBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: MirrorColors.accentSoft,
      child: Text(
        message,
        style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text2),
      ),
    );
  }
}

class _BinaryHint extends StatelessWidget {
  const _BinaryHint({required this.preview, required this.onDownload});

  final DocumentPreviewResult preview;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file_outlined, size: 48, color: MirrorColors.text2),
            const SizedBox(height: 12),
            Text('此格式暂不支持在线预览', style: MirrorTheme.sans(fontSize: 14)),
            const SizedBox(height: 16),
            FilledButton(onPressed: onDownload, child: const Text('下载原文件')),
          ],
        ),
      ),
    );
  }
}

/// 若 preview metadata 可用且非 binary，则打开 [DocumentPreviewScreen]。
Future<bool> openDocumentPreviewScreen(
  BuildContext context, {
  required DocumentPreviewResult preview,
  Map<String, String>? headers,
}) async {
  if (!context.mounted) return false;
  if (!preview.hasInlinePreview || preview.downloadUrl.trim().isEmpty) {
    return false;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => DocumentPreviewScreen(preview: preview, headers: headers),
    ),
  );
  return true;
}
