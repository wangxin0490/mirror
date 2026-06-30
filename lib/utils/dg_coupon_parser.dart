import 'dart:convert';

/// 解析 Hermes dg-coupon fenced JSON block。

class DgCouponProduct {
  const DgCouponProduct({
    required this.productNo,
    required this.name,
    this.stock,
    this.faceValue = '',
    this.validDays,
    this.description = '',
  });

  final String productNo;
  final String name;
  final int? stock;
  final String faceValue;
  final int? validDays;
  final String description;

  factory DgCouponProduct.fromJson(Map<String, dynamic> j) => DgCouponProduct(
        productNo:
            j['product_no'] as String? ?? j['productCode'] as String? ?? '',
        name: j['name'] as String? ?? j['productName'] as String? ?? '',
        stock: (j['stock'] as num?)?.toInt(),
        faceValue: _faceValueFromJson(j['face_value'] ?? j['faceValue']),
        validDays: (j['valid_days'] as num?)?.toInt() ??
            (j['validDays'] as num?)?.toInt(),
        description: j['description'] as String? ??
            j['endDate']?.toString() ??
            '',
      );
}

class DgCouponParsedMessage {
  const DgCouponParsedMessage({
    required this.markdownText,
    this.products = const [],
    this.stockInfo,
    this.couponStatus,
  });

  final String markdownText;
  final List<DgCouponProduct> products;
  final Map<String, dynamic>? stockInfo;
  final Map<String, dynamic>? couponStatus;
}

const _hermesAppDataBlock = 'hermes-app-data';

final _fenceRe = RegExp(
  r'```([a-zA-Z0-9_-]+)\s*\n([\s\S]*?)```',
  multiLine: true,
);

/// [structuredBlock] 通常为 `dg-coupon`；同时兼容 Hermes `hermes-app-data`。
DgCouponParsedMessage parseDgCouponMessage(
  String source, {
  String structuredBlock = 'dg-coupon',
}) {
  final block = structuredBlock.trim().isEmpty ? 'dg-coupon' : structuredBlock;
  final products = <DgCouponProduct>[];
  Map<String, dynamic>? stockInfo;
  Map<String, dynamic>? couponStatus;
  final fenceMatches = <RegExpMatch>[];

  for (final m in _fenceRe.allMatches(source)) {
    final tag = m.group(1) ?? '';
    if (tag != block && tag != _hermesAppDataBlock) continue;
    fenceMatches.add(m);
    final raw = m.group(2)?.trim() ?? '';
    if (raw.isEmpty) continue;
    try {
      final decoded = _decodeJson(raw);
      if (decoded == null) continue;
      _applyDecodedPayload(
        decoded,
        products: products,
        onStockInfo: (v) => stockInfo = v,
        onCouponStatus: (v) => couponStatus = v,
      );
    } catch (_) {
      // 保留 markdown 文本，忽略坏 JSON
    }
  }

  var text = source;
  for (final m in fenceMatches.reversed) {
    text = text.replaceRange(m.start, m.end, '');
  }

  return DgCouponParsedMessage(
    markdownText: _finalizeMarkdown(text, hasProducts: products.isNotEmpty),
    products: products,
    stockInfo: stockInfo,
    couponStatus: couponStatus,
  );
}

/// 有产品卡片时去掉 Markdown 表格及重复的小标题，避免与卡片重复展示。
String _finalizeMarkdown(String text, {required bool hasProducts}) {
  var out = _collapseBlankLines(text);
  if (!hasProducts) return out;
  out = stripMarkdownTables(out);
  out = out.replaceAll(
    RegExp(r'^#{1,3}\s*优惠券列表\s*$', multiLine: true, caseSensitive: false),
    '',
  );
  return _collapseBlankLines(out);
}

/// 去掉 GFM Markdown 表格（移动端渲染差且与卡片重复）。
String stripMarkdownTables(String text) {
  final tableRe = RegExp(
    r'^\|.+\|\s*\r?\n\|[-:\s|]+\|\s*\r?\n(?:\|.+\|\s*\r?\n?)+',
    multiLine: true,
  );
  return _collapseBlankLines(text.replaceAll(tableRe, ''));
}

void _applyDecodedPayload(
  Map<String, dynamic> decoded, {
  required List<DgCouponProduct> products,
  required void Function(Map<String, dynamic>) onStockInfo,
  required void Function(Map<String, dynamic>) onCouponStatus,
}) {
  switch (decoded['type']) {
    case 'product_list':
      _appendProducts(products, decoded['items']);
    case 'dg_coupon_products':
      _appendProducts(products, decoded['products']);
    case 'stock_info':
      onStockInfo(decoded);
    case 'coupon_status':
      onCouponStatus(decoded);
  }
}

void _appendProducts(List<DgCouponProduct> out, dynamic items) {
  if (items is! List) return;
  for (final item in items) {
    if (item is Map<String, dynamic>) {
      out.add(DgCouponProduct.fromJson(item));
    } else if (item is Map) {
      out.add(DgCouponProduct.fromJson(Map<String, dynamic>.from(item)));
    }
  }
}

Map<String, dynamic>? _decodeJson(String raw) {
  final dynamic decoded = jsonDecode(raw);
  if (decoded is Map<String, dynamic>) return decoded;
  if (decoded is Map) return Map<String, dynamic>.from(decoded);
  return null;
}

String _faceValueFromJson(dynamic v) {
  if (v == null) return '';
  if (v is String) return v;
  if (v is num) {
    final yuan = v / 100;
    if (yuan == yuan.roundToDouble()) {
      return '${yuan.toInt()}元';
    }
    return '$yuan元';
  }
  return '$v';
}

String _collapseBlankLines(String s) {
  return s.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}
