class DocumentPreviewResult {
  const DocumentPreviewResult({
    required this.kind,
    required this.filename,
    required this.downloadUrl,
    this.mime = '',
    this.inlineUrl,
    this.text,
    this.table,
  });

  final String kind;
  final String filename;
  final String mime;
  final String downloadUrl;
  final String? inlineUrl;
  final DocumentTextPreview? text;
  final DocumentTablePreview? table;

  bool get hasInlinePreview => kind != 'binary';

  factory DocumentPreviewResult.fromJson(Map<String, dynamic> j) => DocumentPreviewResult(
        kind: j['kind'] as String? ?? 'binary',
        filename: j['filename'] as String? ?? 'file',
        mime: j['mime'] as String? ?? '',
        downloadUrl: j['download_url'] as String? ?? '',
        inlineUrl: j['inline_url'] as String?,
        text: j['text'] is Map<String, dynamic>
            ? DocumentTextPreview.fromJson(j['text'] as Map<String, dynamic>)
            : null,
        table: j['table'] is Map<String, dynamic>
            ? DocumentTablePreview.fromJson(j['table'] as Map<String, dynamic>)
            : null,
      );
}

class DocumentTextPreview {
  const DocumentTextPreview({
    required this.content,
    required this.language,
    this.truncated = false,
  });

  final String content;
  final String language;
  final bool truncated;

  factory DocumentTextPreview.fromJson(Map<String, dynamic> j) => DocumentTextPreview(
        content: j['content'] as String? ?? '',
        language: j['language'] as String? ?? 'plain',
        truncated: j['truncated'] == true,
      );
}

class DocumentTablePreview {
  const DocumentTablePreview({required this.sheets});

  final List<DocumentTableSheet> sheets;

  factory DocumentTablePreview.fromJson(Map<String, dynamic> j) => DocumentTablePreview(
        sheets: (j['sheets'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(DocumentTableSheet.fromJson)
            .toList(),
      );
}

class DocumentTableSheet {
  const DocumentTableSheet({
    required this.name,
    required this.columns,
    required this.rows,
    this.truncatedRows = false,
    this.truncatedColumns = false,
    this.truncatedSheets = false,
  });

  final String name;
  final List<String> columns;
  final List<List<String>> rows;
  final bool truncatedRows;
  final bool truncatedColumns;
  final bool truncatedSheets;

  factory DocumentTableSheet.fromJson(Map<String, dynamic> j) => DocumentTableSheet(
        name: j['name'] as String? ?? 'Sheet1',
        columns: (j['columns'] as List<dynamic>? ?? []).map((e) => '$e').toList(),
        rows: (j['rows'] as List<dynamic>? ?? [])
            .whereType<List<dynamic>>()
            .map((row) => row.map((cell) => '$cell').toList())
            .toList(),
        truncatedRows: j['truncated_rows'] == true,
        truncatedColumns: j['truncated_columns'] == true,
        truncatedSheets: j['truncated_sheets'] == true,
      );
}
