import 'dart:convert';

import '../models/personal_kb.dart';
import '../models/post_blocks_codec.dart';
import '../screens/post_detail_data.dart';

/// 帖子正文信封：个人 KB 元数据 + 样式块 + markdown 尾部。
class PostBodyEnvelopeCodec {
  PostBodyEnvelopeCodec._();

  static const sharedKbOpen = '<!-- mirror:shared_kb -->';
  static const sharedKbClose = '<!-- /mirror:shared_kb -->';
  static const coverGalleryOpen = '<!-- mirror:cover_gallery -->';
  static const coverGalleryClose = '<!-- /mirror:cover_gallery -->';

  static String encode({
    SharedKbAttachment? sharedKb,
    List<String> coverImageUrls = const [],
    required List<PostBodyBlock> blocks,
    String markdownTail = '',
  }) {
    final buf = StringBuffer();
    if (coverImageUrls.isNotEmpty) {
      buf.writeln(coverGalleryOpen);
      buf.writeln(jsonEncode(coverImageUrls));
      buf.writeln(coverGalleryClose);
      buf.writeln();
    }
    if (sharedKb != null && sharedKb.kbId.isNotEmpty) {
      buf.writeln(sharedKbOpen);
      final meta = <String, dynamic>{'kb_id': sharedKb.kbId, 'name': sharedKb.name};
      if (sharedKb.readyDocCount > 0) meta['ready_doc_count'] = sharedKb.readyDocCount;
      buf.writeln(jsonEncode(meta));
      buf.writeln(sharedKbClose);
      buf.writeln();
    }
    buf.write(PostBlocksCodec.encode(blocks, markdownTail: markdownTail));
    return buf.toString().trim();
  }

  static PostBodyEnvelope parse(String body) {
    var rest = body.trim();
    SharedKbAttachment? sharedKb;
    var coverImageUrls = const <String>[];

    if (rest.contains(coverGalleryOpen)) {
      final start = rest.indexOf(coverGalleryOpen) + coverGalleryOpen.length;
      final end = rest.indexOf(coverGalleryClose, start);
      if (end > start) {
        coverImageUrls = _parseCoverGallery(rest.substring(start, end).trim());
        final before = rest.substring(0, rest.indexOf(coverGalleryOpen)).trim();
        final after = rest.substring(end + coverGalleryClose.length).trim();
        rest = [before, after].where((s) => s.isNotEmpty).join('\n\n');
      }
    }

    if (rest.contains(sharedKbOpen)) {
      final start = rest.indexOf(sharedKbOpen) + sharedKbOpen.length;
      final end = rest.indexOf(sharedKbClose, start);
      if (end > start) {
        final jsonPart = rest.substring(start, end).trim();
        sharedKb = _parseSharedKb(jsonPart);
        final before = rest.substring(0, rest.indexOf(sharedKbOpen)).trim();
        final after = rest.substring(end + sharedKbClose.length).trim();
        rest = [before, after].where((s) => s.isNotEmpty).join('\n\n');
      }
    }

    if (sharedKb == null) {
      sharedKb = _parseLegacyKbFootnote(rest);
    }

    final blocksParsed = PostBlocksCodec.parse(rest);
    return PostBodyEnvelope(
      sharedKb: sharedKb,
      coverImageUrls: coverImageUrls,
      blocks: blocksParsed.blocks,
      markdownTail: blocksParsed.markdownTail,
    );
  }

  static List<String> _parseCoverGallery(String jsonPart) {
    try {
      final decoded = jsonDecode(jsonPart);
      if (decoded is! List) return const [];
      return decoded.map((e) => '$e'.trim()).where((u) => u.isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }

  static SharedKbAttachment? _parseSharedKb(String jsonPart) {
    try {
      final j = jsonDecode(jsonPart) as Map<String, dynamic>;
      final id = (j['kb_id'] ?? j['id'] ?? '').toString();
      final name = (j['name'] ?? j['label'] ?? '').toString();
      if (id.isEmpty) return null;
      final ready = j['ready_doc_count'];
      final readyDocCount = ready is int ? ready : int.tryParse('$ready') ?? 0;
      return SharedKbAttachment(
        kbId: id,
        name: name.isNotEmpty ? name : id,
        readyDocCount: readyDocCount,
      );
    } catch (_) {
      return null;
    }
  }

  static SharedKbAttachment? _parseLegacyKbFootnote(String text) {
    final re = RegExp(r'^>\s*分享知识库[：:]\s*(.+)$', multiLine: true);
    final m = re.firstMatch(text);
    if (m == null) return null;
    final name = m.group(1)?.trim() ?? '';
    if (name.isEmpty) return null;
    return SharedKbAttachment(kbId: 'legacy', name: name);
  }
}

class PostBodyEnvelope {
  const PostBodyEnvelope({
    this.sharedKb,
    this.coverImageUrls = const [],
    required this.blocks,
    required this.markdownTail,
  });

  final SharedKbAttachment? sharedKb;
  final List<String> coverImageUrls;
  final List<PostBodyBlock> blocks;
  final String markdownTail;
}
