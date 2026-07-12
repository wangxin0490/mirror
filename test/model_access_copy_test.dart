import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/utils/model_access_copy.dart';

void main() {
  test('locked model subtitle is always 暂不可用', () {
    expect(
      modelLockedSubtitle(selectable: false, accessLabel: '需购买后使用'),
      '暂不可用',
    );
    expect(
      modelLockedSubtitle(selectable: false, accessLabel: '余额不足，请充值'),
      '暂不可用',
    );
    expect(
      modelLockedSubtitle(selectable: false, accessLabel: '随便什么原因'),
      '暂不可用',
    );
    expect(modelLockedSubtitle(selectable: true, accessLabel: '已购'), isNull);
  });

  test('lock toast ignores lockReason and avoids billing words', () {
    for (final reason in [
      'trial_exhausted',
      'balance_exhausted',
      'not_purchased',
      null,
      'other',
    ]) {
      final msg = modelLockToastMessage(reason);
      expect(msg, kModelUnavailableMessage);
      expect(msg, isNot(contains('额度')));
      expect(msg, isNot(contains('余额')));
      expect(msg, isNot(contains('购买')));
      expect(msg, isNot(contains('充值')));
    }
  });

  test('server message with billing words is replaced', () {
    final sanitized = sanitizeModelAccessServerMessage(
      '余额不足，请充值后再试',
      lockReason: 'balance_exhausted',
    );
    expect(sanitized, kModelUnavailableMessage);
  });

  test('non-billing server message is kept', () {
    expect(
      sanitizeModelAccessServerMessage('会话不存在'),
      '会话不存在',
    );
  });

  test('empty server message falls back to lock toast', () {
    expect(
      sanitizeModelAccessServerMessage('  ', lockReason: 'not_purchased'),
      kModelUnavailableMessage,
    );
  });

  test('toolbox disabled copy has no 权限 wording', () {
    expect(kToolboxUnavailableMessage, '该工具暂不可用');
    expect(kToolboxUnavailableMessage, isNot(contains('权限')));
  });
}
