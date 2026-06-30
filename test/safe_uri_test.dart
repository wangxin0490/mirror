import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/utils/safe_uri.dart';

void main() {
  test('sanitizePercentEncoding fixes lone percent', () {
    expect(sanitizePercentEncoding('a%b.md'), 'a%25b.md');
    expect(sanitizePercentEncoding('ok%20x'), 'ok%20x');
  });

  test('safeFilenameFromUrl does not throw on illegal encoding', () {
    expect(safeFilenameFromUrl('/api/v1/agent/hermes-files/2/bad%file.md'), 'bad%file.md');
    expect(
      safeFilenameFromUrl('/api/v1/agent/hermes-files/2/%E6%B1%87%E6%89%BF.md'),
      '汇承.md',
    );
  });

  test('safeParseHermesGrantId', () {
    expect(
      safeParseHermesGrantId('/api/v1/agent/hermes-files/42/report%25.md?download=1'),
      42,
    );
  });

  test('safeFileDownloadUrl appends download', () {
    expect(
      safeFileDownloadUrl('https://x.com/f?st=ab'),
      'https://x.com/f?st=ab&download=1',
    );
  });
}
