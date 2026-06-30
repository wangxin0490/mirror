import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../utils/agent_external_link.dart';
import '../utils/media_url.dart';
import '../utils/mixed_markup.dart';

/// 轻量 Markdown 渲染：标题、段落、列表、表格、加粗、链接、围栏代码块、图片 `![](url)`。
class MirrorMarkdownBody extends StatelessWidget {
  const MirrorMarkdownBody({super.key, required this.source});

  final String source;

  static final _fenceRe = RegExp(r'```([^\n]*)\n([\s\S]*?)```');
  static final _imageRe = RegExp(r'!\[([^\]]*)\]\(([^)]+)\)');
  static final _inlineRe = RegExp(r'(\*\*[^*]+\*\*|\[[^\]]+\]\([^)]+\))');
  static final _tableSepRe = RegExp(r'^\|[\s\-:|]+\|$');
  static final _hrRe = RegExp(r'^(-{3,}|\*{3,}|_{3,})$');

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeMixedMarkup(source);
    final segments = _splitFenced(normalized);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final seg in segments)
          if (seg.isCode)
            _CodeBlock(lang: seg.lang, code: seg.text)
          else
            ..._proseWidgets(context, seg.text),
      ],
    );
  }

  List<_Segment> _splitFenced(String src) {
    final out = <_Segment>[];
    var last = 0;
    for (final m in _fenceRe.allMatches(src)) {
      if (m.start > last) {
        out.add(_Segment.prose(src.substring(last, m.start)));
      }
      out.add(_Segment.code(m.group(1)?.trim() ?? '', m.group(2) ?? ''));
      last = m.end;
    }
    if (last < src.length) {
      out.add(_Segment.prose(src.substring(last)));
    }
    if (out.isEmpty) out.add(_Segment.prose(src));
    return out;
  }

  List<Widget> _proseWidgets(BuildContext context, String text) {
    final lines = text.split('\n');
    final out = <Widget>[];
    final buf = StringBuffer();
    var tableRows = <List<String>>[];

    void flushParagraph() {
      final p = buf.toString().trim();
      buf.clear();
      if (p.isEmpty) return;
      out.add(_paragraph(context, p));
    }

    void flushTable() {
      if (tableRows.isEmpty) return;
      out.add(_MdTable(rows: List.of(tableRows)));
      tableRows = [];
    }

    for (final line in lines) {
      final trimmed = line.trimRight();
      if (_isTableRow(trimmed)) {
        flushParagraph();
        if (_isTableSeparator(trimmed)) continue;
        tableRows.add(_parseTableCells(trimmed));
        continue;
      }
      flushTable();

      if (trimmed.isEmpty) {
        flushParagraph();
        continue;
      }
      if (trimmed.startsWith('### ')) {
        flushParagraph();
        out.add(_heading(context, trimmed.substring(4), 13));
        continue;
      }
      if (trimmed.startsWith('## ')) {
        flushParagraph();
        out.add(_heading(context, trimmed.substring(3), 14));
        continue;
      }
      if (trimmed.startsWith('# ')) {
        flushParagraph();
        out.add(_heading(context, trimmed.substring(2), 15));
        continue;
      }
      if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        flushParagraph();
        out.add(_bullet(context, trimmed.substring(2)));
        continue;
      }
      if (_hrRe.hasMatch(trimmed)) {
        flushParagraph();
        out.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(height: 1, color: MirrorColors.borderSoft),
        ));
        continue;
      }
      if (buf.isNotEmpty) buf.write('\n');
      buf.write(trimmed);
    }
    flushParagraph();
    flushTable();
    return out;
  }

  bool _isTableRow(String line) {
    final t = line.trim();
    return t.startsWith('|') && t.endsWith('|');
  }

  bool _isTableSeparator(String line) => _tableSepRe.hasMatch(line.trim());

  List<String> _parseTableCells(String line) {
    return line
        .trim()
        .split('|')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
  }

  Widget _heading(BuildContext context, String text, double size) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 2),
      child: _richText(context, text.trim(), fontSize: size, weight: FontWeight.w600, height: 1.4),
    );
  }

  Widget _bullet(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: MirrorTheme.sans(fontSize: 13, color: MirrorColors.text2, height: 1.55)),
          Expanded(child: _richText(context, text)),
        ],
      ),
    );
  }

  Widget _paragraph(BuildContext context, String p) {
    final onlyImage = RegExp(r'^!\[([^\]]*)\]\(([^)]+)\)$').firstMatch(p);
    if (onlyImage != null) {
      return _MdImage(url: onlyImage.group(2)!, alt: onlyImage.group(1) ?? '');
    }
    if (!_imageRe.hasMatch(p)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _richText(context, p),
      );
    }
    final parts = <Widget>[];
    var start = 0;
    for (final m in _imageRe.allMatches(p)) {
      if (m.start > start) {
        parts.add(_richText(context, p.substring(start, m.start)));
      }
      parts.add(_MdImage(url: m.group(2)!, alt: m.group(1) ?? ''));
      start = m.end;
    }
    if (start < p.length) {
      parts.add(_richText(context, p.substring(start)));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: parts),
    );
  }

  Widget _richText(
    BuildContext context,
    String text, {
    double fontSize = 13,
    FontWeight? weight,
    double height = 1.7,
  }) {
    return _MdInlineText(
      source: text,
      fontSize: fontSize,
      weight: weight,
      height: height,
    );
  }
}

class _MdInlineText extends StatelessWidget {
  const _MdInlineText({
    required this.source,
    this.fontSize = 13,
    this.weight,
    this.height = 1.7,
  });

  final String source;
  final double fontSize;
  final FontWeight? weight;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(
      TextSpan(children: _inlineSpans(context, source)),
      style: MirrorTheme.sans(
        fontSize: fontSize,
        height: height,
        letterSpacing: -0.003,
        weight: weight ?? MirrorFontWeight.regular,
      ),
    );
  }

  List<InlineSpan> _inlineSpans(BuildContext context, String text) {
    final spans = <InlineSpan>[];
    var start = 0;
    for (final m in MirrorMarkdownBody._inlineRe.allMatches(text)) {
      if (m.start > start) spans.add(TextSpan(text: text.substring(start, m.start)));
      final token = m.group(0)!;
      if (token.startsWith('**') && token.endsWith('**')) {
        spans.add(TextSpan(
          text: token.substring(2, token.length - 2),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ));
      } else {
        final link = RegExp(r'^\[([^\]]+)\]\(([^)]+)\)$').firstMatch(token);
        if (link != null) {
          final label = link.group(1)!;
          final url = link.group(2)!;
          spans.add(TextSpan(
            text: label,
            style: const TextStyle(color: MirrorColors.accentDeep, decoration: TextDecoration.underline),
            recognizer: TapGestureRecognizer()..onTap = () => openAgentExternalLink(context, url),
          ));
        } else {
          spans.add(TextSpan(text: token));
        }
      }
      start = m.end;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
    if (spans.isEmpty) spans.add(const TextSpan(text: ''));
    return spans;
  }
}

class _MdTable extends StatelessWidget {
  const _MdTable({required this.rows});

  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final header = rows.first;
    final body = rows.length > 1 ? rows.sublist(1) : const <List<String>>[];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: MirrorColors.borderSoft),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder(
                horizontalInside: BorderSide(color: MirrorColors.borderSoft.withValues(alpha: 0.7)),
                verticalInside: BorderSide(color: MirrorColors.borderSoft.withValues(alpha: 0.7)),
              ),
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: MirrorColors.bgSoft),
                  children: [
                    for (final cell in header) _tableCell(context, cell, isHeader: true),
                  ],
                ),
                for (final row in body)
                  TableRow(
                    children: [
                      for (var i = 0; i < header.length; i++)
                        _tableCell(context, i < row.length ? row[i] : ''),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tableCell(BuildContext context, String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: _MdInlineText(
        source: text,
        fontSize: isHeader ? 12 : 12,
        weight: isHeader ? FontWeight.w600 : null,
        height: 1.45,
      ),
    );
  }
}

class _Segment {
  _Segment.prose(this.text) : isCode = false, lang = '';
  _Segment.code(this.lang, this.text) : isCode = true;

  final bool isCode;
  final String lang;
  final String text;
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.lang, required this.code});

  final String lang;
  final String code;

  @override
  Widget build(BuildContext context) {
    final label = lang.isEmpty ? 'code' : lang;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: MirrorColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MirrorColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: MirrorTheme.mono(fontSize: 9, color: MirrorColors.text3, letterSpacing: 0.06)),
          const SizedBox(height: 6),
          SelectableText(
            code.trimRight(),
            style: MirrorTheme.mono(fontSize: 11, height: 1.7, color: MirrorColors.text),
          ),
        ],
      ),
    );
  }
}

class _MdImage extends StatelessWidget {
  const _MdImage({required this.url, required this.alt});

  final String url;
  final String alt;

  @override
  Widget build(BuildContext context) {
    final src = resolveMediaUrl(url);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          src,
          fit: BoxFit.cover,
          width: double.infinity,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Container(
              height: 160,
              alignment: Alignment.center,
              color: MirrorColors.bgSoft,
              child: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
          errorBuilder: (_, __, ___) => Container(
            height: 120,
            padding: const EdgeInsets.all(12),
            color: MirrorColors.bgSoft,
            alignment: Alignment.center,
            child: Text(
              alt.isNotEmpty ? alt : '图片加载失败',
              style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text3),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

/// 从 Markdown 正文中提取所有图片 URL（去重保序）。
List<String> allMarkdownImageUrls(String body) {
  final out = <String>[];
  final seen = <String>{};
  for (final m in MirrorMarkdownBody._imageRe.allMatches(body)) {
    final raw = m.group(2)?.trim() ?? '';
    if (raw.isEmpty) continue;
    final resolved = resolveMediaUrl(raw);
    if (seen.add(resolved)) out.add(resolved);
  }
  return out;
}

/// 从 Markdown 正文中提取首张图片 URL（用于轮播封面）。
String? firstMarkdownImageUrl(String body) {
  final all = allMarkdownImageUrls(body);
  return all.isEmpty ? null : all.first;
}
