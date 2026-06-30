import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/utils/dg_coupon_parser.dart';

void main() {
  test('parseDgCouponMessage extracts product_list', () {
    const source = '''
为您找到以下优惠券：

```dg-coupon
{"type":"product_list","items":[{"product_no":"PROD_001","name":"满100减20","stock":128,"face_value":"20元"}]}
```

点击卡片可查库存。
''';
    final parsed = parseDgCouponMessage(source);
    expect(parsed.markdownText, contains('为您找到'));
    expect(parsed.markdownText, isNot(contains('```')));
    expect(parsed.products, hasLength(1));
    expect(parsed.products.first.productNo, 'PROD_001');
    expect(parsed.products.first.stock, 128);
  });

  test('parseDgCouponMessage ignores unclosed fence while streaming', () {
    const partial = '摘要\n```dg-coupon\n{"type":"product_list"';
    final parsed = parseDgCouponMessage(partial);
    expect(parsed.products, isEmpty);
  });

  test('parseDgCouponMessage extracts hermes-app-data dg_coupon_products', () {
    const source = '''
当前可买的优惠券：

```hermes-app-data
{"type":"dg_coupon_products","version":1,"products":[{"productCode":"MIRROR_3YCSQ","productName":"3元测试券","faceValue":300,"validDays":10,"endDate":"2026-10-01 23:59:59"},{"productCode":"MIRROR_3YCSQ2","productName":"3元测试券2","faceValue":300,"validDays":10,"endDate":"2026-10-01 23:59:59"}]}
```
''';
    final parsed = parseDgCouponMessage(source);
    expect(parsed.markdownText, contains('当前可买的优惠券'));
    expect(parsed.markdownText, isNot(contains('```')));
    expect(parsed.products, hasLength(2));
    expect(parsed.products.first.productNo, 'MIRROR_3YCSQ');
    expect(parsed.products.first.name, '3元测试券');
    expect(parsed.products.first.faceValue, '3元');
    expect(parsed.products.first.validDays, 10);
    expect(parsed.products.first.description, '2026-10-01 23:59:59');
  });

  test('parseDgCouponMessage handles multiple dg-coupon blocks', () {
    const source = '''
以下是可用优惠券：

```dg-coupon
{"type":"product_list","items":[{"product_no":"P001","name":"券A","face_value":"10元"}]}
```

```dg-coupon
{"type":"product_list","items":[{"product_no":"P002","name":"券B","face_value":"20元"}]}
```
''';
    final parsed = parseDgCouponMessage(source);
    expect(parsed.products, hasLength(2));
    expect(parsed.products[0].productNo, 'P001');
    expect(parsed.products[1].productNo, 'P002');
    expect(parsed.markdownText, isNot(contains('```')));
  });

  test('parseDgCouponMessage strips markdown table when products present', () {
    const source = '''
目前共有 2 款优惠券：

## 优惠券列表

| 产品名称 | 面值 | 有效天数 |
| --- | --- | --- |
| 3元测试券 | 3元 | 10天 |
| 3元测试券2 | 3元 | 10天 |

两款均为测试券。

```dg-coupon
{"type":"product_list","items":[{"product_no":"P001","name":"3元测试券","face_value":"3元","valid_days":10}]}
```
''';
    final parsed = parseDgCouponMessage(source);
    expect(parsed.products, hasLength(1));
    expect(parsed.markdownText, isNot(contains('| 产品名称')));
    expect(parsed.markdownText, isNot(contains('优惠券列表')));
    expect(parsed.markdownText, contains('目前共有'));
    expect(parsed.markdownText, contains('两款均为测试券'));
  });
}
