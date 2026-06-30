import '../utils/kb_display.dart';

class KbListItem {
  KbListItem({
    required this.id,
    required this.name,
    this.description,
    this.coverUrl,
    this.docCount = 0,
    this.readyDocCount = 0,
    this.parsingCount = 0,
    this.updatedAt = '',
  });

  final int id;
  final String name;
  final String? description;
  final String? coverUrl;
  final int docCount;
  final int readyDocCount;
  final int parsingCount;
  final String updatedAt;

  factory KbListItem.fromJson(Map<String, dynamic> j) => KbListItem(
        id: j['id'] as int? ?? 0,
        name: j['name'] as String? ?? '',
        description: j['description'] as String?,
        coverUrl: j['cover_url'] as String?,
        docCount: j['doc_count'] as int? ?? 0,
        readyDocCount: j['ready_doc_count'] as int? ?? 0,
        parsingCount: j['parsing_count'] as int? ?? 0,
        updatedAt: j['updated_at'] as String? ?? '',
      );
}

class KbMineList {
  KbMineList({required this.items, this.kbCount = 0, this.docCount = 0, this.storageUsed = ''});

  final List<KbListItem> items;
  final int kbCount;
  final int docCount;
  final String storageUsed;

  factory KbMineList.fromJson(Map<String, dynamic> j) => KbMineList(
        items: (j['items'] as List<dynamic>? ?? [])
            .map((e) => KbListItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        kbCount: j['kb_count'] as int? ?? 0,
        docCount: j['doc_count'] as int? ?? 0,
        storageUsed: j['storage_used'] as String? ?? '',
      );
}

class KbDocumentItem {
  KbDocumentItem({
    required this.id,
    required this.originalFilename,
    this.fileSize = 0,
    this.mimeType = '',
    this.parseStatus = 'uploading',
    this.chunkNum = 0,
    this.parseError,
    this.folderId = 0,
    this.sourceType = '',
    this.sourceUrl = '',
  });

  final int id;
  final int folderId;
  final String originalFilename;
  final int fileSize;
  final String mimeType;
  final String parseStatus;
  final int chunkNum;
  final String? parseError;
  final String sourceType;
  final String sourceUrl;

  bool get isReady => parseStatus == 'ready';
  bool get isWebImport => sourceType == 'web' && sourceUrl.trim().isNotEmpty;

  factory KbDocumentItem.fromJson(Map<String, dynamic> j) => KbDocumentItem(
        id: j['id'] as int? ?? 0,
        folderId: j['folder_id'] as int? ?? 0,
        originalFilename: j['original_filename'] as String? ?? '',
        fileSize: (j['file_size'] as num?)?.toInt() ?? 0,
        mimeType: j['mime_type'] as String? ?? '',
        parseStatus: j['parse_status'] as String? ?? 'uploading',
        chunkNum: j['chunk_num'] as int? ?? 0,
        parseError: j['parse_error'] as String?,
        sourceType: j['source_type'] as String? ?? '',
        sourceUrl: j['source_url'] as String? ?? '',
      );
}

class KbFolderItem {
  KbFolderItem({required this.id, required this.name, this.docCount = 0});

  final int id;
  final String name;
  final int docCount;

  factory KbFolderItem.fromJson(Map<String, dynamic> j) => KbFolderItem(
        id: j['id'] as int? ?? 0,
        name: j['name'] as String? ?? '',
        docCount: j['doc_count'] as int? ?? 0,
      );
}

class KbDetail {
  KbDetail({
    required this.id,
    required this.name,
    this.folders = const [],
    this.documents = const [],
    this.readyDocCount = 0,
    this.isOwner = false,
  });

  final int id;
  final String name;
  final List<KbFolderItem> folders;
  final List<KbDocumentItem> documents;
  final int readyDocCount;
  final bool isOwner;

  factory KbDetail.fromJson(Map<String, dynamic> j) => KbDetail(
        id: j['id'] as int? ?? 0,
        name: j['name'] as String? ?? '',
        readyDocCount: j['ready_doc_count'] as int? ?? 0,
        isOwner: j['is_owner'] as bool? ?? false,
        folders: (j['folders'] as List<dynamic>? ?? [])
            .map((e) => KbFolderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        documents: (j['documents'] as List<dynamic>? ?? [])
            .map((e) => KbDocumentItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class KbSubscribedItem {
  KbSubscribedItem({
    required this.id,
    required this.kbId,
    required this.name,
    this.ownerName = '',
    this.ownerHandle = '',
    this.subscriberCount = 0,
    this.docCount = 0,
    this.readyDocCount = 0,
    this.kbDeleted = false,
  });

  final int id;
  final int kbId;
  final String name;
  final String ownerName;
  final String ownerHandle;
  final int subscriberCount;
  final int docCount;
  final int readyDocCount;
  final bool kbDeleted;

  String get metaLine => KbDisplay.metaLine(
        subscriberCount: subscriberCount,
        docCount: docCount,
        readyDocCount: readyDocCount,
        ownerName: ownerName,
        ownerHandle: ownerHandle,
      );

  factory KbSubscribedItem.fromJson(Map<String, dynamic> j) => KbSubscribedItem(
        id: j['id'] as int? ?? 0,
        kbId: j['kb_id'] as int? ?? 0,
        name: j['name'] as String? ?? '',
        ownerName: j['owner_name'] as String? ?? '',
        ownerHandle: j['owner_handle'] as String? ?? '',
        subscriberCount: j['subscriber_count'] as int? ?? 0,
        docCount: j['doc_count'] as int? ?? 0,
        readyDocCount: j['ready_doc_count'] as int? ?? 0,
        kbDeleted: j['kb_deleted'] as bool? ?? false,
      );
}

class KbExploreItem {
  KbExploreItem({
    required this.id,
    required this.name,
    this.ownerName = '',
    this.ownerHandle = '',
    this.subscriberCount = 0,
    this.docCount = 0,
    this.readyDocCount = 0,
    this.subscribed = false,
  });

  final int id;
  final String name;
  final String ownerName;
  final String ownerHandle;
  final int subscriberCount;
  final int docCount;
  final int readyDocCount;
  final bool subscribed;

  String get metaLine => KbDisplay.metaLine(
        subscriberCount: subscriberCount,
        docCount: docCount,
        readyDocCount: readyDocCount,
        ownerName: ownerName,
        ownerHandle: ownerHandle,
      );

  factory KbExploreItem.fromJson(Map<String, dynamic> j) => KbExploreItem(
        id: j['id'] as int? ?? 0,
        name: j['name'] as String? ?? '',
        ownerName: j['owner_name'] as String? ?? '',
        ownerHandle: j['owner_handle'] as String? ?? '',
        subscriberCount: j['subscriber_count'] as int? ?? 0,
        docCount: j['doc_count'] as int? ?? 0,
        readyDocCount: j['ready_doc_count'] as int? ?? 0,
        subscribed: j['subscribed'] as bool? ?? false,
      );
}

class KbPaginatedMineResponse {
  const KbPaginatedMineResponse({required this.items, this.nextCursor = '', this.hasMore = false});
  final List<KbListItem> items;
  final String nextCursor;
  final bool hasMore;

  factory KbPaginatedMineResponse.fromJson(Map<String, dynamic> j) => KbPaginatedMineResponse(
        items: (j['items'] as List<dynamic>? ?? [])
            .map((e) => KbListItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextCursor: j['next_cursor'] as String? ?? '',
        hasMore: j['has_more'] as bool? ?? false,
      );
}

class KbPaginatedSubscribedResponse {
  const KbPaginatedSubscribedResponse({required this.items, this.nextCursor = '', this.hasMore = false});
  final List<KbSubscribedItem> items;
  final String nextCursor;
  final bool hasMore;

  factory KbPaginatedSubscribedResponse.fromJson(Map<String, dynamic> j) => KbPaginatedSubscribedResponse(
        items: (j['items'] as List<dynamic>? ?? [])
            .map((e) => KbSubscribedItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextCursor: j['next_cursor'] as String? ?? '',
        hasMore: j['has_more'] as bool? ?? false,
      );
}

class KbPaginatedExploreResponse {
  const KbPaginatedExploreResponse({required this.items, this.nextCursor = '', this.hasMore = false});
  final List<KbExploreItem> items;
  final String nextCursor;
  final bool hasMore;

  factory KbPaginatedExploreResponse.fromJson(Map<String, dynamic> j) => KbPaginatedExploreResponse(
        items: (j['items'] as List<dynamic>? ?? [])
            .map((e) => KbExploreItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextCursor: j['next_cursor'] as String? ?? '',
        hasMore: j['has_more'] as bool? ?? false,
      );
}

class KbUploadResult {
  KbUploadResult({required this.documentId, required this.parseStatus});

  final int documentId;
  final String parseStatus;

  factory KbUploadResult.fromJson(Map<String, dynamic> j) => KbUploadResult(
        documentId: (j['document_id'] as num?)?.toInt() ?? 0,
        parseStatus: j['parse_status'] as String? ?? 'uploaded',
      );
}

class KbDocStatusItem {
  KbDocStatusItem({
    required this.id,
    required this.parseStatus,
    this.chunkNum = 0,
    this.parseError,
  });

  final int id;
  final String parseStatus;
  final int chunkNum;
  final String? parseError;

  factory KbDocStatusItem.fromJson(Map<String, dynamic> j) => KbDocStatusItem(
        id: j['id'] as int? ?? 0,
        parseStatus: j['parse_status'] as String? ?? 'uploading',
        chunkNum: j['chunk_num'] as int? ?? 0,
        parseError: j['parse_error'] as String?,
      );
}

class KbDocSyncSnapshot {
  KbDocSyncSnapshot({
    required this.readyDocCount,
    required this.pending,
    required this.items,
  });

  final int readyDocCount;
  final bool pending;
  final List<KbDocStatusItem> items;

  factory KbDocSyncSnapshot.fromJson(Map<String, dynamic> j) => KbDocSyncSnapshot(
        readyDocCount: j['ready_doc_count'] as int? ?? 0,
        pending: j['pending'] as bool? ?? false,
        items: (j['items'] as List<dynamic>? ?? [])
            .map((e) => KbDocStatusItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class KbDocSyncUpdate {
  KbDocSyncUpdate({required this.readyDocCount, required this.document});

  final int readyDocCount;
  final KbDocStatusItem document;

  factory KbDocSyncUpdate.fromJson(Map<String, dynamic> j) => KbDocSyncUpdate(
        readyDocCount: j['ready_doc_count'] as int? ?? 0,
        document: KbDocStatusItem.fromJson(j['document'] as Map<String, dynamic>? ?? {}),
      );
}

/// KB 语音/文档上传限制（来自 GET /api/v1/kb/upload-limits）。
class KbUploadLimits {
  const KbUploadLimits({required this.maxVoiceSeconds, required this.maxVoiceMb});

  final int maxVoiceSeconds;
  final int maxVoiceMb;

  static const defaults = KbUploadLimits(maxVoiceSeconds: 1800, maxVoiceMb: 60);

  factory KbUploadLimits.fromJson(Map<String, dynamic> j) => KbUploadLimits(
        maxVoiceSeconds: j['max_voice_seconds'] as int? ?? 1800,
        maxVoiceMb: j['max_voice_mb'] as int? ?? 60,
      );
}
