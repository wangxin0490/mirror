import '../screens/post_detail_data.dart';

/// 用户个人知识库分类（与发布页「分享个人知识库」选项一致）。
class PersonalKbCategory {
  const PersonalKbCategory({required this.id, required this.label});

  final String id;
  final String label;
}

/// 发帖页从 API 拉取的可分享知识库。
class ShareablePersonalKb {
  const ShareablePersonalKb({
    required this.kbId,
    required this.name,
    this.readyDocCount = 0,
  });

  final int kbId;
  final String name;
  final int readyDocCount;

  String get id => '$kbId';

  factory ShareablePersonalKb.fromJson(Map<String, dynamic> j) => ShareablePersonalKb(
        kbId: j['kb_id'] is int ? j['kb_id'] as int : int.tryParse('${j['kb_id']}') ?? 0,
        name: j['name'] as String? ?? '',
        readyDocCount: j['ready_doc_count'] as int? ?? 0,
      );
}

abstract final class PersonalKbCatalog {
  static const categories = [
    PersonalKbCategory(id: 'work', label: '工作'),
    PersonalKbCategory(id: 'study', label: '学习'),
    PersonalKbCategory(id: 'audio', label: '录音'),
    PersonalKbCategory(id: 'finance', label: '金融'),
    PersonalKbCategory(id: 'images', label: '图片'),
  ];

  static PersonalKbCategory? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  static String? labelFor(String? id) => byId(id)?.label;

  /// 列表 `cover_label` 携带 KB：`kb:work`
  static const coverLabelPrefix = 'kb:';

  static String coverLabelFor(String kbId) => '$coverLabelPrefix$kbId';

  static String? kbIdFromCoverLabel(String? coverLabel) {
    final v = coverLabel?.trim() ?? '';
    if (!v.startsWith(coverLabelPrefix)) return null;
    final id = v.substring(coverLabelPrefix.length).trim();
    if (id.isEmpty) return null;
    if (byId(id) != null) return id;
    return id;
  }

  static String listDisplayName({required String authorName, required String kbLabel}) {
    final a = authorName.trim();
    if (a.isEmpty) return kbLabel;
    return '$a · $kbLabel';
  }

  /// 解析发帖/详情中的 kb_id；仅正整数视为可调用订阅 API 的库 ID。
  static int? parseApiKbId(Object? kbId) {
    if (kbId == null) return null;
    if (kbId is int) return kbId > 0 ? kbId : null;
    final n = int.tryParse(kbId.toString().trim());
    return n != null && n > 0 ? n : null;
  }

  static SharedKnowledgeBaseInfo toSharedInfo({
    required Object kbId,
    required String kbLabel,
    required String authorName,
    int docCount = 0,
    bool isOwnKb = false,
  }) {
    return SharedKnowledgeBaseInfo(
      name: listDisplayName(authorName: authorName, kbLabel: kbLabel),
      author: authorName,
      docCount: docCount,
      summary: isOwnKb
          ? '这是你分享的知识库「$kbLabel」，可在「知识库」→「个人知识库」中查看与管理。'
          : '博主在发布本文时同步分享了个人知识库「$kbLabel」，订阅后可加入你的「订阅知识库」。',
      apiKbId: parseApiKbId(kbId),
      isOwnKb: isOwnKb,
    );
  }
}

/// 帖子附带的个人知识库引用。
class SharedKbAttachment {
  const SharedKbAttachment({
    required this.kbId,
    required this.name,
    this.readyDocCount = 0,
  });

  final String kbId;
  final String name;
  final int readyDocCount;
}
