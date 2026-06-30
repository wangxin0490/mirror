import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/utils/mixed_markup.dart';

void main() {
  test('plainTextFromMixedMarkup strips html table tags', () {
    const html = '<table><thead><tr><th>名词</th><th>定义</th></tr></thead><tbody><tr><td>买家端</td><td>买方视角</td></tr></tbody></table>';
    final plain = plainTextFromMixedMarkup(html);
    expect(plain.contains('<table>'), isFalse);
    expect(plain.contains('买家端'), isTrue);
  });
}
