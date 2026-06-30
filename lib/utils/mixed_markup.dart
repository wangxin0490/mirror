/// 将知识库预览中常见的 HTML 片段转为 Markdown 子集，供 [MirrorMarkdownBody] 渲染。
String normalizeMixedMarkup(String source) {
  var text = source.replaceAll('\r\n', '\n');
  text = _convertHtmlTables(text);
  text = _convertBlockTags(text);
  text = _convertInlineTags(text);
  text = _stripRemainingTags(text);
  text = _decodeBasicEntities(text);
  return text.trim();
}

/// 将 HTML/Markdown 混合内容转为适合摘要展示的纯文本。
String plainTextFromMixedMarkup(String source) {
  if (source.trim().isEmpty) return '';
  final normalized = normalizeMixedMarkup(source);
  return normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _convertHtmlTables(String text) {
  final tableRe = RegExp(r'<table\b[\s\S]*?</table>', caseSensitive: false);
  return text.replaceAllMapped(tableRe, (match) {
    final md = _htmlTableToMarkdown(match.group(0)!);
    return md.isEmpty ? match.group(0)! : '\n$md\n';
  });
}

String _htmlTableToMarkdown(String tableHtml) {
  final rowRe = RegExp(r'<tr\b[\s\S]*?>([\s\S]*?)</tr>', caseSensitive: false);
  final cellRe = RegExp(r'<t[hd]\b[\s\S]*?>([\s\S]*?)</t[hd]>', caseSensitive: false);
  final rows = <List<String>>[];

  for (final rowMatch in rowRe.allMatches(tableHtml)) {
    final cells = <String>[];
    for (final cellMatch in cellRe.allMatches(rowMatch.group(1)!)) {
      final cell = _normalizeCellText(cellMatch.group(1)!);
      if (cell.isNotEmpty) cells.add(cell);
    }
    if (cells.isNotEmpty) rows.add(cells);
  }
  if (rows.isEmpty) return '';

  final width = rows.fold<int>(0, (max, row) => row.length > max ? row.length : max);
  final normalized = rows
      .map((row) => [
            for (var i = 0; i < width; i++) i < row.length ? row[i] : '',
          ])
      .toList();

  final buf = StringBuffer();
  buf.writeln('| ${normalized.first.join(' | ')} |');
  buf.writeln('| ${List.filled(width, '---').join(' | ')} |');
  for (var i = 1; i < normalized.length; i++) {
    buf.writeln('| ${normalized[i].join(' | ')} |');
  }
  return buf.toString().trimRight();
}

String _normalizeCellText(String raw) {
  var text = raw;
  text = _convertInlineTags(text);
  text = _stripRemainingTags(text);
  text = _decodeBasicEntities(text);
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _convertBlockTags(String text) {
  var out = text;
  for (var level = 6; level >= 1; level--) {
    final hashes = '#' * level;
    out = out.replaceAllMapped(
      RegExp('<h$level\\b[^>]*>([\\s\\S]*?)</h$level>', caseSensitive: false),
      (m) => '\n$hashes ${_normalizeCellText(m.group(1)!)} \n',
    );
  }
  out = out.replaceAllMapped(
    RegExp(r'<hr\b[^>]*/?>', caseSensitive: false),
    (_) => '\n---\n',
  );
  out = out.replaceAllMapped(
    RegExp(r'<br\b[^>]*/?>', caseSensitive: false),
    (_) => '\n',
  );
  out = out.replaceAll(RegExp(r'</?(?:p|div|section|article|header|footer|main|span)\b[^>]*>', caseSensitive: false), '\n');
  out = out.replaceAll(RegExp(r'</?(?:thead|tbody|tfoot|colgroup|col)\b[^>]*>', caseSensitive: false), '\n');
  return out;
}

String _convertInlineTags(String text) {
  var out = text;
  out = out.replaceAllMapped(
    RegExp(r'<(?:strong|b)\b[^>]*>([\s\S]*?)</(?:strong|b)>', caseSensitive: false),
    (m) => '**${_normalizeInlineText(m.group(1)!)}**',
  );
  out = out.replaceAllMapped(
    RegExp(r'<(?:em|i)\b[^>]*>([\s\S]*?)</(?:em|i)>', caseSensitive: false),
    (m) => '*${_normalizeInlineText(m.group(1)!)}*',
  );
  out = out.replaceAllMapped(
    RegExp(r'<a\b[^>]*href="([^"]+)"[^>]*>([\s\S]*?)</a>', caseSensitive: false),
    (m) => '[${_normalizeInlineText(m.group(2)!)}](${m.group(1)!})',
  );
  return out;
}

String _normalizeInlineText(String raw) {
  return _decodeBasicEntities(_stripRemainingTags(raw)).replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _stripRemainingTags(String text) {
  return text.replaceAll(RegExp(r'<[^>]+>'), '');
}

String _decodeBasicEntities(String text) {
  return text
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
}
