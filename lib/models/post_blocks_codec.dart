import 'dart:convert';

import 'package:flutter/material.dart';

import '../screens/post_detail_data.dart';

/// 样式块在 `body` 中的存储格式（后端只持久化 body 字符串）。
class PostBlocksCodec {
  PostBlocksCodec._();

  static const openTag = '<!-- mirror:blocks -->';
  static const closeTag = '<!-- /mirror:blocks -->';

  static String encode(List<PostBodyBlock> blocks, {String markdownTail = ''}) {
    final payload = blocks.map(_blockToJson).where((e) => e != null).cast<Map<String, dynamic>>().toList();
    final buf = StringBuffer();
    if (payload.isNotEmpty) {
      buf.writeln(openTag);
      buf.writeln(jsonEncode(payload));
      buf.writeln(closeTag);
      buf.writeln();
    }
    final tail = markdownTail.trim();
    if (tail.isNotEmpty) buf.write(tail);
    return buf.toString().trim();
  }

  static PostBlocksParseResult parse(String body) {
    final src = body.trim();
    if (!src.contains(openTag)) {
      return PostBlocksParseResult(blocks: const [], markdownTail: src);
    }
    final start = src.indexOf(openTag) + openTag.length;
    final end = src.indexOf(closeTag, start);
    if (end < 0) {
      return PostBlocksParseResult(blocks: const [], markdownTail: src);
    }
    final jsonPart = src.substring(start, end).trim();
    final tail = src.substring(end + closeTag.length).trim();
    return PostBlocksParseResult(blocks: _parseJsonList(jsonPart), markdownTail: tail);
  }

  static List<PostBodyBlock> _parseJsonList(String jsonPart) {
    if (jsonPart.isEmpty) return [];
    try {
      final decoded = jsonDecode(jsonPart);
      if (decoded is! List) return [];
      return decoded.map((e) => _blockFromJson(e as Map<String, dynamic>)).whereType<PostBodyBlock>().toList();
    } catch (_) {
      return [];
    }
  }

  static Map<String, dynamic>? _blockToJson(PostBodyBlock b) {
    switch (b.type) {
      case PostBodyBlockType.paragraph:
        final t = b.text.trim();
        if (t.isEmpty) return null;
        return {'type': 'paragraph', 'text': t};
      case PostBodyBlockType.stats:
        final items = b.stats;
        if (items == null || items.isEmpty) return null;
        return {
          'type': 'stats',
          'items': [for (final s in items) {'v': s.v, 'k': s.k}],
        };
      case PostBodyBlockType.callout:
        final c = b.callout;
        if (c == null || c.body.trim().isEmpty) return null;
        return {
          'type': 'callout',
          'variant': c.variant.name,
          'icon': _iconKey(c.icon),
          'body': c.body,
        };
      case PostBodyBlockType.compare:
        final c = b.compare;
        if (c == null) return null;
        return {
          'type': 'compare',
          'bad_title': c.badTitle,
          'bad': c.bad,
          'good_title': c.goodTitle,
          'good': c.good,
        };
      case PostBodyBlockType.code:
        final code = b.code?.trim() ?? '';
        if (code.isEmpty) return null;
        return {'type': 'code', 'text': code};
    }
  }

  static PostBodyBlock? _blockFromJson(Map<String, dynamic> j) {
    final type = (j['type'] ?? '').toString();
    switch (type) {
      case 'paragraph':
        return PostBodyBlock.paragraph((j['text'] ?? '').toString());
      case 'stats':
        final raw = j['items'] as List<dynamic>? ?? [];
        final items = <({String v, String k})>[];
        for (final e in raw) {
          if (e is! Map) continue;
          final v = (e['v'] ?? '').toString();
          final k = (e['k'] ?? '').toString();
          if (v.isEmpty && k.isEmpty) continue;
          items.add((v: v, k: k));
        }
        if (items.isEmpty) return null;
        return PostBodyBlock.stats(items);
      case 'callout':
        return PostBodyBlock.callout(
          icon: _iconFromKey((j['icon'] ?? 'check').toString()),
          variant: _variantFromString((j['variant'] ?? 'accent').toString()),
          body: (j['body'] ?? '').toString(),
        );
      case 'compare':
        return PostBodyBlock.compare(
          badTitle: (j['bad_title'] ?? 'before').toString(),
          bad: (j['bad'] ?? '').toString(),
          goodTitle: (j['good_title'] ?? 'after').toString(),
          good: (j['good'] ?? '').toString(),
        );
      case 'code':
        return PostBodyBlock.code((j['text'] ?? j['code'] ?? '').toString());
      default:
        return null;
    }
  }

  static String _iconKey(IconData icon) => switch (icon) {
        Icons.lightbulb_outline => 'lightbulb',
        Icons.bolt => 'bolt',
        Icons.nightlight_round => 'nightlight',
        Icons.check => 'check',
        _ => 'check',
      };

  static IconData _iconFromKey(String key) => switch (key) {
        'lightbulb' => Icons.lightbulb_outline,
        'bolt' => Icons.bolt,
        'nightlight' => Icons.nightlight_round,
        _ => Icons.check,
      };

  static CalloutVariant _variantFromString(String s) => switch (s) {
        'amber' => CalloutVariant.amber,
        'green' => CalloutVariant.green,
        _ => CalloutVariant.accent,
      };
}

class PostBlocksParseResult {
  const PostBlocksParseResult({required this.blocks, required this.markdownTail});

  final List<PostBodyBlock> blocks;
  final String markdownTail;
}
