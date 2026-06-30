import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../api/kb_api.dart';
import '../../models/kb_models.dart';
import '../../theme/mirror_colors.dart';
import '../../theme/mirror_theme.dart';
import '../../widgets/kb_audio_player.dart';
import '../../widgets/mirror_markdown_body.dart';
import '../../widgets/mirror_network_image.dart';
import '../../utils/external_url.dart';
import '../../widgets/mirror_pressable.dart';
import '../../widgets/phone_components.dart';
import '../screens/kb/kb_ui_helpers.dart';

/// 文档预览层（解析正文 / 原图 / 原文件）。
class KbDocumentViewer extends StatefulWidget {
  const KbDocumentViewer({
    super.key,
    required this.kbId,
    required this.doc,
    required this.onClose,
    this.sourceLabel,
  });

  final int kbId;
  final KbDocumentItem doc;
  final VoidCallback onClose;
  final String? sourceLabel;

  @override
  State<KbDocumentViewer> createState() => _KbDocumentViewerState();
}

class _KbDocumentViewerState extends State<KbDocumentViewer> {
  String? _preview;
  String? _fileUrl;
  Uint8List? _fileBytes;
  var _loading = true;
  String? _error;

  bool get _isImage => KbDocUi.isImage(widget.doc);
  bool get _isAudio => KbDocUi.isAudio(widget.doc);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.doc.isReady) {
        final file = await KbApi.getFile(widget.kbId, widget.doc.id);
        if (file != null) {
          if (!file.isDirectBytes && file.url.isNotEmpty) {
            _fileUrl = file.url;
          }
          if (file.isDirectBytes && file.bytes != null) {
            _fileBytes = Uint8List.fromList(file.bytes!);
          }
        }
        if (!_isImage || (_preview == null || _preview!.trim().isEmpty)) {
          _preview = await KbApi.previewText(widget.kbId, widget.doc.id);
        }
        if ((_preview == null || _preview!.trim().isEmpty) &&
            _fileBytes != null &&
            KbDocUi.isTextPreviewable(widget.doc)) {
          _preview = utf8.decode(_fileBytes!, allowMalformed: true);
        }
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  bool _isParseErrorContent(String text) {
    final lower = text.toLowerCase();
    if (lower.startsWith('**error**:') || lower.startsWith('[error]')) return true;
    if (lower.contains('code:') &&
        (lower.contains('api 调用参数有误') ||
            lower.contains('no audio segment found') ||
            lower.contains('no valid audio') ||
            lower.contains('no speech detected'))) {
      return true;
    }
    return false;
  }

  String? get _displayPreview {
    final text = _preview?.trim() ?? '';
    if (text.isEmpty || text == '暂无解析正文' || _isParseErrorContent(text)) return null;
    return text;
  }

  String? get _ocrText => _displayPreview;

  Widget _textBody(String text) {
    if (KbDocUi.isRichTextPreview(widget.doc.originalFilename)) {
      return MirrorMarkdownBody(source: text);
    }
    return SelectableText(text, style: MirrorTheme.sans(fontSize: 14, color: MirrorColors.text2, height: 1.65));
  }

  Widget _imagePreview() {
    if (_fileUrl != null && _fileUrl!.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: MirrorColors.bgSoft,
          child: SizedBox(
            width: double.infinity,
            height: 360,
            child: MirrorNetworkImage(url: _fileUrl!, fit: BoxFit.contain),
          ),
        ),
      );
    }
    if (_fileBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: MirrorColors.bgSoft,
          child: Image.memory(
            _fileBytes!,
            fit: BoxFit.contain,
            width: double.infinity,
            height: 360,
            errorBuilder: (context, error, stackTrace) => Center(
              child: Text('图片加载失败', style: MirrorTheme.sans(fontSize: 13, color: MirrorColors.text3)),
            ),
          ),
        ),
      );
    }
    return Text('无法加载原图', style: MirrorTheme.sans(fontSize: 14, color: MirrorColors.text3, height: 1.65));
  }

  String get _audioMimeType {
    final n = widget.doc.originalFilename.toLowerCase();
    if (n.endsWith('.mp3')) return 'audio/mpeg';
    if (n.endsWith('.wav')) return 'audio/wav';
    if (n.endsWith('.webm')) return 'audio/webm';
    if (n.endsWith('.ogg')) return 'audio/ogg';
    if (widget.doc.mimeType.isNotEmpty) return widget.doc.mimeType;
    return 'audio/mp4';
  }

  Widget _audioSection() {
    return KbAudioPlayer(
      url: _fileUrl,
      bytes: _fileBytes,
      mimeType: _audioMimeType,
      filename: widget.doc.originalFilename,
    );
  }

  Widget _bodyContent() {
    if (_isAudio) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _audioSection(),
          if (_ocrText != null) ...[
            const SizedBox(height: 20),
            Text('正文', style: MirrorTheme.mono(fontSize: 10, color: MirrorColors.text3, letterSpacing: 0.04)),
            const SizedBox(height: 10),
            _textBody(_ocrText!),
          ],
        ],
      );
    }
    if (_isImage) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _imagePreview(),
          if (_ocrText != null) ...[
            const SizedBox(height: 20),
            Text('识别文字', style: MirrorTheme.mono(fontSize: 10, color: MirrorColors.text3, letterSpacing: 0.04)),
            const SizedBox(height: 10),
            _textBody(_ocrText!),
          ],
        ],
      );
    }

    final text = _displayPreview ?? '暂无解析正文';
    if (text == '暂无解析正文') {
      return Text(text, style: MirrorTheme.sans(fontSize: 14, color: MirrorColors.text3, height: 1.65));
    }
    return _textBody(text);
  }

  @override
  Widget build(BuildContext context) {
    final (icon, bg, fg) = KbDocUi.iconFor(widget.doc);
    return Material(
      color: MirrorColors.bgApp,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 14, 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: MirrorColors.borderSoft))),
              child: Row(
                children: [
                  MirrorBackButton(onTap: widget.onClose),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.doc.originalFilename,
                      style: MirrorTheme.sans(fontSize: 15, weight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
                        child: Icon(icon, size: 20, color: fg),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${KbDocUi.sizeLabel(widget.doc)} · ${KbDocUi.statusLabel(widget.doc.parseStatus)}',
                              style: MirrorTheme.mono(fontSize: 10.5, color: MirrorColors.text3),
                            ),
                            if (widget.sourceLabel != null)
                              Text(widget.sourceLabel!, style: MirrorTheme.sans(fontSize: 11, color: MirrorColors.blue)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (widget.doc.isWebImport) ...[
                    const SizedBox(height: 16),
                    Text('原链接', style: MirrorTheme.mono(fontSize: 10, color: MirrorColors.text3, letterSpacing: 0.04)),
                    const SizedBox(height: 8),
                    MirrorPressable(
                      onTap: () async {
                        final ok = await openExternalUrl(widget.doc.sourceUrl);
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('无法打开链接'), behavior: SnackBarBehavior.floating),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Text(
                        widget.doc.sourceUrl,
                        style: MirrorTheme.sans(
                          fontSize: 13,
                          color: MirrorColors.accent,
                          height: 1.45,
                        ).copyWith(
                          decoration: TextDecoration.underline,
                          decorationColor: MirrorColors.accent,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (!widget.doc.isReady)
                    Text(
                      '文档${KbDocUi.statusLabel(widget.doc.parseStatus)}，解析完成后可阅读。',
                      style: MirrorTheme.sans(fontSize: 14, color: MirrorColors.text3, height: 1.6),
                    )
                  else if (_loading)
                    const Padding(padding: EdgeInsets.only(top: 24), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                  else ...[
                    if (_error != null)
                      Text(_error!, style: MirrorTheme.sans(fontSize: 13, color: MirrorColors.amber)),
                    if (!_isImage && !_isAudio) ...[
                      Text('正文', style: MirrorTheme.mono(fontSize: 10, color: MirrorColors.text3, letterSpacing: 0.04)),
                      const SizedBox(height: 10),
                    ],
                    if (_isAudio) ...[
                      Text('音频', style: MirrorTheme.mono(fontSize: 10, color: MirrorColors.text3, letterSpacing: 0.04)),
                      const SizedBox(height: 10),
                    ],
                    _bodyContent(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
