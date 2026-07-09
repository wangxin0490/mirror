import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/utils/relay_error_messages.dart';

void main() {
  test('quota and 402 messages do not mention recharge or Token purchase', () {
    final quota = RelayErrorMessages.userMessage(
      upstream: 'insufficient_quota exceeded your current quota 余额不足',
    );
    final status402 = RelayErrorMessages.userMessage(code: '402');

    for (final msg in [quota, status402]) {
      expect(msg, isNot(contains('充值')));
      expect(msg, isNot(contains('购买')));
      expect(msg, isNot(contains('Token')));
      expect(msg, contains('换一个模型'));
    }
  });
}
