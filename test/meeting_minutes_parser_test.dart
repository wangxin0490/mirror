import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/utils/meeting_minutes_parser.dart';

void main() {
  test('parseMeetingMinutes splits agenda resolutions and todos table', () {
    const md = '''
# 会议纪要

本次会议讨论了结算规则变更。

## 议题
1. 支付服务规则变更
2. 灯塔系统同步

## 决议
- **任务触发机制:** 规则变更后触发
- **生效时间设计:** 2026-06-15 生效

## 待办
| 事项 | 负责人 | 截止时间 | 状态 |
| --- | --- | --- | --- |
| 整理接口文档 | 张三 | 06-15 | 待处理 |
| 联调验证 | 李四 | 06-18 | 进行中 |
''';

    final parsed = parseMeetingMinutes(md);
    expect(parsed.summary, contains('结算规则'));
    expect(parsed.agenda, contains('支付服务'));
    expect(parsed.resolutions, contains('任务触发机制'));
    expect(parsed.todos.length, 2);
    expect(parsed.todos.first.owner, '张三');
    expect(parsed.todos.first.status, '待处理');
    expect(parsed.hasStructure, isTrue);
  });

  test('parseMeetingMinutes returns empty for blank input', () {
    final parsed = parseMeetingMinutes('');
    expect(parsed.hasStructure, isFalse);
  });
}
