import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/models/document_preview.dart';

void main() {
  test('DocumentPreviewResult parses table preview', () {
    final preview = DocumentPreviewResult.fromJson({
      'kind': 'table',
      'filename': 'data.csv',
      'download_url': 'https://example.com/dl',
      'table': {
        'sheets': [
          {
            'name': 'Sheet1',
            'columns': ['a', 'b'],
            'rows': [
              ['1', '2'],
            ],
          },
        ],
      },
    });
    expect(preview.kind, 'table');
    expect(preview.hasInlinePreview, isTrue);
    expect(preview.downloadUrl, isNotEmpty);
    expect(preview.table?.sheets.single.columns, ['a', 'b']);
  });

  test('binary kind is not inline previewable', () {
    final preview = DocumentPreviewResult.fromJson({
      'kind': 'binary',
      'filename': 'deck.pptx',
      'download_url': 'https://example.com/dl',
    });
    expect(preview.hasInlinePreview, isFalse);
  });

  test('CSV table routing kind', () {
    const preview = DocumentPreviewResult(
      kind: 'table',
      filename: 'report.csv',
      downloadUrl: 'https://example.com/dl',
    );
    expect(preview.kind, 'table');
    expect(preview.downloadUrl.isNotEmpty, isTrue);
  });
}
