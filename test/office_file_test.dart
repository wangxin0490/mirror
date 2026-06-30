import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/utils/office_file.dart';

void main() {
  test('isOfficeFilename detects docx', () {
    expect(isOfficeFilename('合同.docx'), isTrue);
    expect(isOfficeFilename('readme.md'), isFalse);
  });

  test('shouldUseFileOpenGuide for documents on all platforms', () {
    expect(shouldUseFileOpenGuide(filename: 'a.md', kind: 'text'), isTrue);
    expect(shouldUseFileOpenGuide(filename: 'a.pdf', kind: 'pdf'), isTrue);
    expect(shouldUseFileOpenGuide(filename: 'a.docx', kind: 'office'), isTrue);
    expect(shouldUseFileOpenGuide(filename: 'a.png', kind: 'image'), isFalse);
    expect(shouldUseFileOpenGuide(filename: 'photo.jpeg'), isFalse);
  });

  test('fileDownloadUrl adds download query', () {
    expect(
      fileDownloadUrl('https://cos.example.com/f.pdf?foo=1'),
      'https://cos.example.com/f.pdf?foo=1&download=1',
    );
  });
}
