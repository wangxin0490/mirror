import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/utils/agent_external_link.dart';

void main() {
  test('agentSourceHostLabel extracts host', () {
    expect(agentSourceHostLabel('https://news.example.com/path'), 'news.example.com');
    expect(agentSourceHostLabel(''), '');
  });

  test('hermesFilePreviewUrl keeps inline preview mode', () {
    const raw = 'http://127.0.0.1:8100/api/v1/agent/hermes-files/9/report.xlsx';
    expect(hermesFilePreviewUrl(raw), raw);
    expect(
      hermesFilePreviewUrl('$raw?st=abc&exp=1'),
      '$raw?st=abc&exp=1',
    );
    expect(
      hermesFilePreviewUrl('$raw?download=1&st=abc&exp=1'),
      '$raw?st=abc&exp=1',
    );
  });
}
