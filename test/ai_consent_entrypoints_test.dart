import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('critical AI screens reference ensureAiDataConsent', () {
    const files = [
      'lib/screens/mirror_screens.dart',
      'lib/screens/kb/knowledge_base_screen.dart',
      'lib/screens/meeting/meeting_hub_screen.dart',
      'lib/screens/product_agent_screens.dart',
      'lib/screens/dg_coupon_chat_screen.dart',
    ];
    for (final path in files) {
      final src = File(path).readAsStringSync();
      expect(src.contains('ensureAiDataConsent'), isTrue, reason: path);
    }
  });
}
