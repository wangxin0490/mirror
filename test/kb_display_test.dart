import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/models/kb_models.dart';
import 'package:mirror_mobile/utils/kb_display.dart';

void main() {
  test('KbDisplay metaLine shows subscriber count, content count, and handle', () {
    expect(
      KbDisplay.metaLine(
        subscriberCount: 9,
        docCount: 76,
        readyDocCount: 70,
        ownerName: '天天向上',
        ownerHandle: '天天向上',
      ),
      '9人订阅 · 76篇内容 · @天天向上',
    );
  });

  test('KbSubscribedItem parses subscriber_count and doc_count', () {
    final item = KbSubscribedItem.fromJson({
      'id': 1,
      'kb_id': 5,
      'name': '金融',
      'owner_name': 'wx',
      'owner_handle': 'wx',
      'subscriber_count': 4,
      'doc_count': 1,
      'ready_doc_count': 1,
    });
    expect(item.metaLine, '4人订阅 · 1篇内容 · @wx');
  });
}
