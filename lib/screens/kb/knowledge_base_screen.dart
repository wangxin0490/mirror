import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../api/kb_api.dart';
import '../../models/chat_attachment.dart';
import '../../models/pending_chat_attachment.dart';
import '../../utils/chat_pending_upload.dart';
import '../../widgets/chat_message_attachments.dart';
import '../../widgets/ai_data_consent_dialog.dart';
import '../../models/kb_chat_models.dart';
import '../../models/kb_models.dart';
import '../../services/document_picker_service.dart';
import '../../services/file_picker_service.dart';
import '../../services/image_picker_service.dart';
import '../../services/asr_client.dart';
import '../../services/chat_stream_handle.dart';
import '../../services/kb_sse_client.dart';
import '../../services/voice_input_controller.dart';
import '../../services/media_picker_service.dart';
import '../../state/kb_store.dart';
import '../../utils/kb_voice_upload.dart';
import '../../theme/mirror_colors.dart';
import '../../theme/mirror_theme.dart';
import '../../widgets/compose_image_thumb.dart';
import '../../widgets/kb_chat_composer.dart';
import '../../widgets/kb_assistant_message.dart';
import '../../widgets/kb_document_viewer.dart';
import '../../widgets/mirror_network_image.dart';
import '../../widgets/mirror_pressable.dart';
import '../../widgets/phone_components.dart';
import 'kb_swipe_actions.dart';
import 'kb_ui_helpers.dart';
import 'kb_voice_record_screen.dart';
import 'kb_web_import_sheet.dart';

// ─── S9 知识库（API 驱动）────────────────────────────────────────

enum _KbScope { personal, subscribed }

class KnowledgeBaseScreen extends StatefulWidget {
  const KnowledgeBaseScreen({
    super.key,
    this.onAsk,
    this.registerSystemBackHandler,
  });

  final VoidCallback? onAsk;
  final void Function(bool Function()? handler)? registerSystemBackHandler;

  @override
  State<KnowledgeBaseScreen> createState() => _KnowledgeBaseScreenState();
}

class _KnowledgeBaseScreenState extends State<KnowledgeBaseScreen> {
  _KbScope _scope = _KbScope.personal;
  int? _openedKbId;
  String _openedKbName = '';
  bool _openedIsSubscribed = false;
  int? _folderFilterId;
  KbDocumentItem? _openedDoc;

  bool _importMenuOpen = false;
  bool _uploading = false;
  bool _createFolderOpen = false;
  bool _createKbOpen = false;
  bool _searchOpen = false;
  final _createFolderCtrl = TextEditingController();
  final _createFolderFocus = FocusNode();
  final _createKbNameCtrl = TextEditingController();
  final _createKbNameFocus = FocusNode();
  final _searchCtrl = TextEditingController();
  final _searchScrollCtrl = ScrollController();
  Timer? _searchDebounce;
  _KbScope? _searchScope;
  PickedImageBytes? _createKbCover;
  String? _createKbCoverKey;
  String? _createKbCoverPreviewUrl;
  bool _createKbCoverUploading = false;
  KbListItem? _editingKb;
  bool _createKbCoverCleared = false;

  @override
  void initState() {
    super.initState();
    widget.registerSystemBackHandler?.call(_consumeSystemBack);
    KbStore.instance.addListener(_onStore);
    KbStore.instance.refresh();
    _searchScrollCtrl.addListener(_onSearchScroll);
  }

  @override
  void dispose() {
    widget.registerSystemBackHandler?.call(null);
    KbStore.instance.removeListener(_onStore);
    _createFolderCtrl.dispose();
    _createFolderFocus.dispose();
    _createKbNameCtrl.dispose();
    _createKbNameFocus.dispose();
    _searchDebounce?.cancel();
    _searchScrollCtrl.removeListener(_onSearchScroll);
    _searchScrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onStore() => setState(() {});

  void _onSearchScroll() {
    if (!_searchOpen ||
        !KbStore.instance.scopeSearchHasMore ||
        KbStore.instance.scopeSearchLoadingMore)
      return;
    if (!_searchScrollCtrl.hasClients) return;
    if (_searchScrollCtrl.position.pixels >=
        _searchScrollCtrl.position.maxScrollExtent - 120) {
      final scope = _searchScope ?? _scope;
      KbStore.instance.searchLibraries(
        scope == _KbScope.personal ? 'personal' : 'subscribed',
        _searchCtrl.text.trim(),
        loadMore: true,
      );
    }
  }

  void _runScopeSearch(String q) {
    _searchDebounce?.cancel();
    final scope = _searchScope ?? _scope;
    KbStore.instance.searchLibraries(
      scope == _KbScope.personal ? 'personal' : 'subscribed',
      q.trim(),
    );
  }

  void _scheduleScopeSearch(String q) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _runScopeSearch(q),
    );
  }

  void _openSearch() {
    final scope = _scope;
    setState(() {
      _searchOpen = true;
      _searchScope = scope;
    });
    _runScopeSearch('');
  }

  void _closeSearch() {
    _searchDebounce?.cancel();
    KbStore.instance.clearScopeSearch();
    setState(() {
      _searchOpen = false;
      _searchScope = null;
      _searchCtrl.clear();
    });
  }

  bool get _inDetail => _openedKbId != null;

  KbDetail? get _detail => KbStore.instance.detail;

  List<KbDocumentItem> get _visibleDocs {
    final d = _detail;
    if (d == null) return [];
    if (_folderFilterId == null) {
      return d.documents.where((doc) => doc.folderId == 0).toList();
    }
    return d.documents.where((doc) => doc.folderId == _folderFilterId).toList();
  }

  Future<void> _openKb(
    int kbId,
    String name, {
    required bool subscribed,
  }) async {
    await KbStore.instance.loadDetail(kbId);
    KbStore.instance.startDetailPoll();
    if (!mounted) return;
    setState(() {
      _openedKbId = kbId;
      _openedKbName = name;
      _openedIsSubscribed = subscribed;
      _folderFilterId = null;
    });
  }

  void _closeDetail() {
    KbStore.instance.stopDetailPoll();
    setState(() {
      _openedKbId = null;
      _folderFilterId = null;
      _openedDoc = null;
    });
  }

  void _prepareAskScope() {
    if (_openedKbId != null) {
      KbStore.instance.setActiveScope(
        kbIds: [_openedKbId!],
        label: _openedKbName,
        scopeType: _openedIsSubscribed ? 'subscribed' : 'personal',
      );
    } else if (_scope == _KbScope.personal) {
      final ids = (KbStore.instance.mine?.items ?? [])
          .map((e) => e.id)
          .toList();
      KbStore.instance.setActiveScope(
        kbIds: ids,
        label: '个人知识库',
        scopeType: 'personal',
      );
    } else {
      final ids = KbStore.instance.subscribed
          .where((s) => !s.kbDeleted)
          .map((s) => s.kbId)
          .toList();
      KbStore.instance.setActiveScope(
        kbIds: ids,
        label: '订阅知识库',
        scopeType: 'subscribed',
      );
    }
  }

  bool get _shouldConsumeSystemBack =>
      _createKbOpen ||
      _createFolderOpen ||
      _importMenuOpen ||
      _openedDoc != null ||
      _searchOpen ||
      _folderFilterId != null ||
      _inDetail;

  void _handleSystemBack() {
    if (_createKbOpen) {
      _closeCreateKbDialog();
      return;
    }
    if (_createFolderOpen) {
      _closeCreateFolderSheet();
      return;
    }
    if (_importMenuOpen) {
      _closeImportMenu();
      return;
    }
    if (_openedDoc != null) {
      setState(() => _openedDoc = null);
      return;
    }
    if (_searchOpen) {
      _closeSearch();
      return;
    }
    if (_folderFilterId != null) {
      setState(() => _folderFilterId = null);
      return;
    }
    if (_inDetail) {
      _closeDetail();
    }
  }

  /// 供根导航优先消费系统返回（详情/文档/弹层等）。
  bool _consumeSystemBack() {
    if (!_shouldConsumeSystemBack) return false;
    _handleSystemBack();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final body = _inDetail
        ? _wrapOverlays(_buildDetail())
        : _wrapOverlays(
            Column(
              children: [
                _header(),
                Expanded(
                  child: _scope == _KbScope.personal
                      ? _personalBody()
                      : _subscribedBody(),
                ),
                _askBar(onImport: () => _openImportMenu()),
              ],
            ),
          );
    return PopScope(
      canPop: !_shouldConsumeSystemBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleSystemBack();
      },
      child: body,
    );
  }

  Widget _buildDetail() {
    final d = _detail;
    final folders = d?.folders ?? [];
    return Column(
      children: [
        _detailHeader(),
        if (folders.isNotEmpty && _folderFilterId == null)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                for (final f in folders)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: MirrorPressable(
                      onTap: () => setState(() => _folderFilterId = f.id),
                      child: Chip(
                        label: Text(
                          f.name,
                          style: MirrorTheme.sans(fontSize: 12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (_folderFilterId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: Row(
              children: [
                MirrorPressable(
                  onTap: () => setState(() => _folderFilterId = null),
                  child: Text(
                    '← 全部',
                    style: MirrorTheme.sans(
                      fontSize: 12,
                      color: MirrorColors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
            children: [
              Text(
                '${d?.readyDocCount ?? 0} 篇可用 · ${_visibleDocs.length} 篇当前列表',
                style: MirrorTheme.mono(
                  fontSize: 10.5,
                  color: MirrorColors.text3,
                ),
              ),
              const SizedBox(height: 10),
              if (_visibleDocs.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Center(
                    child: Text(
                      _openedIsSubscribed ? '暂无文档' : '暂无内容\n点击 + 导入文件',
                      textAlign: TextAlign.center,
                      style: MirrorTheme.sans(
                        fontSize: 13,
                        color: MirrorColors.text3,
                        height: 1.5,
                      ),
                    ),
                  ),
                )
              else
                for (final doc in _visibleDocs) _docRow(doc),
            ],
          ),
        ),
        _askBar(
          onImport: _openedIsSubscribed ? null : () => _openImportMenu(),
          scopeLabel: _folderFilterId != null ? _openedKbName : _openedKbName,
        ),
      ],
    );
  }

  Widget _docRow(KbDocumentItem doc) {
    final (icon, bg, fg) = KbDocUi.iconFor(doc);
    final sub =
        '${KbDocUi.sizeLabel(doc)} · ${KbDocUi.statusLabel(doc.parseStatus)}';
    final canDelete = !_openedIsSubscribed && _openedKbId != null;
    return MirrorPressable(
      onTap: () {
        if (!doc.isReady) {
          _toast('文档${KbDocUi.statusLabel(doc.parseStatus)}，请稍候');
          return;
        }
        setState(() => _openedDoc = doc);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          border: Border.all(color: MirrorColors.borderSoft),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.originalFilename,
                    style: MirrorTheme.sans(
                      fontSize: 13.5,
                      weight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    sub,
                    style: MirrorTheme.mono(
                      fontSize: 10,
                      color: MirrorColors.text3,
                    ),
                  ),
                ],
              ),
            ),
            if (canDelete)
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: MirrorColors.text3,
                ),
                onPressed: () => _confirmDeleteDocument(doc),
                tooltip: '删除',
              ),
            if (doc.isReady)
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: MirrorColors.text3,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteDocument(KbDocumentItem doc) async {
    final kbId = _openedKbId;
    if (kbId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除文档'),
        content: Text('确定删除「${doc.originalFilename}」？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final result = await KbStore.instance.deleteDocument(kbId, doc.id);
    if (!mounted) return;
    if (result.ok) {
      if (_openedDoc?.id == doc.id) setState(() => _openedDoc = null);
      _toast('已删除');
    } else {
      _toast(result.message ?? '删除失败');
    }
  }

  Future<void> _confirmCancelSubscription(KbSubscribedItem sub) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('取消订阅'),
        content: Text('确定取消订阅「${sub.name}」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('保留'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('取消订阅'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final result = await KbStore.instance.cancelSubscription(sub.id);
    if (!mounted) return;
    if (result.ok) {
      _toast('已取消订阅');
    } else {
      _toast(result.message ?? '取消失败');
    }
  }

  Widget _header() => Container(
    padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: MirrorColors.borderSoft)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '知识库',
              style: MirrorTheme.sans(
                fontSize: 20,
                weight: FontWeight.w700,
                letterSpacing: -0.02,
              ),
            ),
            const Spacer(),
            MirrorPressable(
              onTap: _openSearch,
              child: const Icon(
                Icons.search,
                size: 20,
                color: MirrorColors.text2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: MirrorColors.bgSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              _scopeTab('个人知识库', _KbScope.personal),
              _scopeTab('订阅知识库', _KbScope.subscribed),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _scopeTab(String label, _KbScope scope) {
    final on = _scope == scope;
    return Expanded(
      child: MirrorPressable(
        onTap: () => setState(() => _scope = scope),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? MirrorColors.bgApp : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: on ? const [MirrorShadows.tabOn] : null,
          ),
          child: Text(
            label,
            style: MirrorTheme.sans(
              fontSize: 12,
              weight: FontWeight.w600,
              color: on ? MirrorColors.text : MirrorColors.text3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _personalBody() {
    final mine = KbStore.instance.mine;
    final items = mine?.items ?? [];
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      children: [
        MirrorPressable(
          key: const Key('kb-personal-create-folder'),
          onTap: _openCreateKbDialog,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: MirrorColors.bgSoft,
              border: Border.all(color: MirrorColors.borderSoft),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: MirrorColors.accentSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 18,
                    color: MirrorColors.accentDeep,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '创建个人知识库',
                        style: MirrorTheme.sans(
                          fontSize: 13.5,
                          weight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '新建一个分类并设置封面',
                        style: MirrorTheme.sans(
                          fontSize: 11.5,
                          color: MirrorColors.text3,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: MirrorColors.text3,
                ),
              ],
            ),
          ),
        ),
        Text(
          _personalStatsLine(mine),
          style: MirrorTheme.mono(fontSize: 10.5, color: MirrorColors.text3),
        ),
        const SizedBox(height: 12),
        if (KbStore.instance.loading && items.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (items.isEmpty)
          Text(
            '暂无分类，点击上方创建',
            style: MirrorTheme.sans(fontSize: 13, color: MirrorColors.text3),
          )
        else
          for (final k in items)
            Slidable(
              key: ValueKey('kb-personal-slidable-${k.id}'),
              endActionPane: ActionPane(
                motion: const DrawerMotion(),
                extentRatio: 0.24,
                children: [
                  CustomSlidableAction(
                    onPressed: (_) => _openEditKbDialog(k),
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.transparent,
                    padding: const EdgeInsets.only(left: 8, right: 2),
                    flex: 1,
                    child: KbCircularSwipeAction(
                      icon: TablerIcons.pencil,
                      backgroundColor: MirrorColors.accentSoft,
                      iconColor: MirrorColors.accentDeep,
                      onTap: () => _openEditKbDialog(k),
                    ),
                  ),
                  CustomSlidableAction(
                    onPressed: (_) => _confirmDeleteKb(k),
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.transparent,
                    padding: const EdgeInsets.only(left: 2, right: 8),
                    flex: 1,
                    child: KbCircularSwipeAction(
                      icon: TablerIcons.trash,
                      backgroundColor: MirrorColors.coralSoft,
                      iconColor: MirrorColors.coral,
                      onTap: () => _confirmDeleteKb(k),
                    ),
                  ),
                ],
              ),
              child: MirrorPressable(
                onTap: () => _openKb(k.id, k.name, subscribed: false),
                child: _kbCard(
                  k.name,
                  '${k.docCount} 篇${KbDocUi.relativeUpdated(k.updatedAt).isNotEmpty ? ' · ${KbDocUi.relativeUpdated(k.updatedAt)}' : ''}',
                  coverUrl: k.coverUrl,
                ),
              ),
            ),
      ],
    );
  }

  Widget _subscribedBody() {
    final items = KbStore.instance.subscribed;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      children: [
        Text(
          '在知识库内搜索并订阅',
          style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text3),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Center(
              child: Text(
                '暂无订阅\n点击右上角搜索可订阅的知识库',
                textAlign: TextAlign.center,
                style: MirrorTheme.sans(
                  fontSize: 13,
                  color: MirrorColors.text3,
                  height: 1.5,
                ),
              ),
            ),
          )
        else
          for (final s in items)
            Opacity(
              opacity: s.kbDeleted ? 0.45 : 1,
              child: _subscribedKbListTile(s),
            ),
      ],
    );
  }

  Widget _subscribedKbListTile(KbSubscribedItem s) {
    final card = MirrorPressable(
      onTap: s.kbDeleted
          ? () => _toast('知识库已被作者删除')
          : () => _openKb(s.kbId, s.name, subscribed: true),
      child: _kbCard(
        s.name,
        s.kbDeleted ? '知识库已被作者删除' : s.metaLine,
      ),
    );
    if (s.kbDeleted) return card;
    return Slidable(
      key: ValueKey('kb-subscribed-slidable-${s.id}'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.14,
        children: [
          CustomSlidableAction(
            onPressed: (_) => _confirmCancelSubscription(s),
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.transparent,
            padding: const EdgeInsets.only(left: 8, right: 8),
            flex: 1,
            child: KbCircularSwipeAction(
              icon: Icons.link_off,
              backgroundColor: MirrorColors.coralSoft,
              iconColor: MirrorColors.coral,
              onTap: () => _confirmCancelSubscription(s),
            ),
          ),
        ],
      ),
      child: card,
    );
  }

  String _personalStatsLine(KbMineList? mine) {
    final count = mine?.items.length ?? 0;
    final docs = mine?.docCount ?? 0;
    final storage = mine?.storageUsed ?? '';
    if (storage.isNotEmpty) return '$count 个分类 · $docs 条 · $storage';
    return '$count 个分类 · $docs 条';
  }

  Widget _kbCard(String title, String sub, {String? coverUrl}) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      border: Border.all(color: MirrorColors.borderSoft),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: coverUrl != null && coverUrl.isNotEmpty
              ? SizedBox(
                  width: 44,
                  height: 44,
                  child: MirrorNetworkImage(url: coverUrl),
                )
              : Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: MirrorColors.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.folder_outlined,
                    color: MirrorColors.accentDeep,
                    size: 22,
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: MirrorTheme.sans(fontSize: 14, weight: FontWeight.w600),
              ),
              Text(
                sub,
                style: MirrorTheme.sans(
                  fontSize: 11,
                  color: MirrorColors.text3,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: MirrorColors.text3, size: 18),
      ],
    ),
  );

  Widget _detailHeader() => Container(
    padding: const EdgeInsets.fromLTRB(8, 8, 14, 10),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: MirrorColors.borderSoft)),
    ),
    child: Row(
      children: [
        MirrorBackButton(onTap: _closeDetail),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            _openedKbName,
            style: MirrorTheme.sans(fontSize: 16, weight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );

  Widget _askBar({VoidCallback? onImport, String? scopeLabel}) => Container(
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
    decoration: const BoxDecoration(
      color: MirrorColors.bgApp,
      border: Border(top: BorderSide(color: MirrorColors.borderSoft)),
    ),
    child: Row(
      children: [
        Expanded(
          child: MirrorPressable(
            onTap: () {
              _prepareAskScope();
              widget.onAsk?.call();
            },
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: MirrorColors.bgSoft,
                border: Border.all(color: MirrorColors.border),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.mic_none,
                    size: 18,
                    color: MirrorColors.text3,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      scopeLabel != null
                          ? '基于「$scopeLabel」提问…'
                          : (_scope == _KbScope.personal
                                ? '基于个人知识库提问…'
                                : '基于订阅知识库提问…'),
                      style: MirrorTheme.sans(
                        fontSize: 13,
                        color: MirrorColors.text3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (onImport != null) ...[
          const SizedBox(width: 10),
          MirrorPressable(
            onTap: onImport,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: MirrorColors.bgSoft,
                border: Border.all(color: MirrorColors.border),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, size: 20, color: MirrorColors.text2),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _wrapOverlays(Widget body) {
    return Stack(
      fit: StackFit.expand,
      children: [
        body,
        if (_importMenuOpen) ..._importLayers(),
        if (_createFolderOpen) ..._createFolderLayers(),
        if (_createKbOpen) ..._createKbLayers(),
        if (_searchOpen) ..._searchLayers(),
        if (_uploading)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x66FFFFFF),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
        if (_openedDoc != null && _openedKbId != null)
          Positioned.fill(
            child: KbDocumentViewer(
              kbId: _openedKbId!,
              doc: _openedDoc!,
              onClose: () => setState(() => _openedDoc = null),
              sourceLabel: _openedIsSubscribed ? '订阅库' : null,
            ),
          ),
      ],
    );
  }

  void _openImportMenu() {
    if (_openedKbId == null) {
      _toast('请先打开一个知识库');
      return;
    }
    if (_uploading) return;
    setState(() => _importMenuOpen = true);
  }

  void _closeImportMenu() => setState(() => _importMenuOpen = false);

  List<Widget> _importLayers() => [
    Positioned.fill(
      child: GestureDetector(
        onTap: _closeImportMenu,
        behavior: HitTestBehavior.opaque,
        child: ColoredBox(color: Colors.black.withValues(alpha: 0.28)),
      ),
    ),
    Positioned(
      left: 16,
      right: 16,
      bottom: 58,
      child: Material(
        color: MirrorColors.bgApp,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _importRow('拍照', Icons.camera_alt_outlined, _beginCameraUpload),
            _importRow('图片', Icons.image_outlined, _beginImageUpload),
            _importRow('本地文件', Icons.folder_outlined, _beginLocalFileUpload),
            _importRow('网页链接', Icons.link_outlined, _beginWebImport),
            _importRow('语音导入', Icons.mic_none_rounded, _beginVoiceImport),
            _importRow('新建文件夹', Icons.create_new_folder_outlined, () {
              _closeImportMenu();
              _openCreateFolderSheet();
            }, isLast: true),
          ],
        ),
      ),
    ),
  ];

  Widget _importRow(
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool isLast = false,
  }) => MirrorPressable(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: isLast
          ? null
          : const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: MirrorColors.borderSoft),
              ),
            ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: MirrorTheme.sans(fontSize: 15))),
          Icon(icon, size: 20, color: MirrorColors.text2),
        ],
      ),
    ),
  );

  void _beginCameraUpload() {
    final kbId = _openedKbId;
    if (kbId == null) return;
    final future = pickFromCamera();
    _closeImportMenu();
    future.then((picked) {
      if (!mounted) return;
      if (picked.isEmpty) {
        _toast('未选择图片');
        return;
      }
      _doUpload(kbId, picked.first.bytes, picked.first.name);
    });
  }

  void _beginImageUpload() {
    final kbId = _openedKbId;
    if (kbId == null) return;
    final future = pickFromGallery(allowMultiple: false, maxCount: 1);
    _closeImportMenu();
    future.then((picked) {
      if (!mounted) return;
      if (picked.isEmpty) {
        _toast('未选择图片');
        return;
      }
      final img = picked.first;
      _doUpload(kbId, img.bytes, img.name);
    });
  }

  /// 库详情「导入」菜单：打开网页链接导入表单。
  void _beginWebImport() {
    final kbId = _openedKbId;
    if (kbId == null) return;
    _closeImportMenu();
    showKbWebImportSheet(
      context,
      onImport: (url, title) =>
          KbStore.instance.importWebDocument(kbId, url, name: title),
    ).then((ok) {
      if (!mounted) return;
      if (ok) _toast('已提交，后台解析中');
    });
  }

  /// 库详情「导入」菜单：打开全屏语音录制页（可暂停，单文件上传）。
  void _beginVoiceImport() {
    final kbId = _openedKbId;
    if (kbId == null) return;
    _closeImportMenu();
    unawaited(_beginVoiceImportWithConsent(kbId));
  }

  Future<void> _beginVoiceImportWithConsent(int kbId) async {
    final consented = await ensureAiDataConsent(context);
    if (!consented || !mounted) return;
    final ok = await openKbVoiceRecordScreen(
      context,
      onUpload: (recorded, {onProgress}) => KbStore.instance.uploadDocument(
        kbId,
        recorded.bytes,
        recorded.filename,
        folderId: _folderFilterId,
        onProgress: onProgress,
      ),
    );
    if (!mounted) return;
    if (ok) _toast('已加入知识库，后台解析中');
  }

  void _beginLocalFileUpload() {
    final kbId = _openedKbId;
    if (kbId == null) return;
    final future = pickDocument();
    _closeImportMenu();
    future.then((file) async {
      if (!mounted) return;
      if (file == null) {
        _toast('未选择文件');
        return;
      }
      final limits = await KbStore.instance.ensureUploadLimits();
      if (!mounted) return;
      if (isKbVoiceFilename(file.name) && !isKbVoiceWithinSizeLimit(file.bytes.length, limits.maxVoiceMb)) {
        _toast(kbVoiceSizeLimitMessage(limits.maxVoiceMb));
        return;
      }
      _doUpload(kbId, file.bytes, file.name);
    });
  }

  Future<void> _doUpload(int kbId, List<int> bytes, String filename) async {
    if (_uploading) return;
    setState(() => _uploading = true);
    _toast('上传中…');
    try {
      final r = await KbStore.instance.uploadDocument(
        kbId,
        bytes,
        filename,
        folderId: _folderFilterId,
      );
      if (!mounted) return;
      if (r.ok) {
        _toast('已上传，后台解析中');
      } else {
        _toast(r.message.isNotEmpty ? r.message : '上传失败');
      }
    } catch (e) {
      if (mounted) _toast('上传失败：$e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _openCreateFolderSheet() {
    _createFolderCtrl.clear();
    setState(() => _createFolderOpen = true);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted && _createFolderOpen) _createFolderFocus.requestFocus();
    });
  }

  void _closeCreateFolderSheet() => setState(() => _createFolderOpen = false);

  Future<void> _confirmCreateFolder() async {
    final name = _createFolderCtrl.text.trim();
    final kbId = _openedKbId;
    if (name.isEmpty || kbId == null) return;
    _closeCreateFolderSheet();
    await KbStore.instance.createFolder(kbId, name);
    _toast('已创建文件夹「$name」');
  }

  List<Widget> _createFolderLayers() => [
    Positioned.fill(
      child: GestureDetector(
        onTap: _closeCreateFolderSheet,
        behavior: HitTestBehavior.opaque,
        child: ColoredBox(color: Colors.black.withValues(alpha: 0.28)),
      ),
    ),
    Positioned(
      left: 16,
      right: 16,
      bottom: 58,
      child: Material(
        color: MirrorColors.bgApp,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '新建文件夹',
                style: MirrorTheme.sans(fontSize: 16, weight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _createFolderCtrl,
                focusNode: _createFolderFocus,
                decoration: InputDecoration(
                  hintText: '分类名称',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onSubmitted: (_) => _confirmCreateFolder(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _closeCreateFolderSheet,
                      child: const Text('取消'),
                    ),
                  ),
                  Expanded(
                    child: FilledButton(
                      onPressed: _confirmCreateFolder,
                      child: const Text('创建'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  ];

  void _openCreateKbDialog() {
    _editingKb = null;
    _createKbNameCtrl.clear();
    _createKbCover = null;
    _createKbCoverKey = null;
    _createKbCoverPreviewUrl = null;
    _createKbCoverUploading = false;
    _createKbCoverCleared = false;
    setState(() => _createKbOpen = true);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted && _createKbOpen) _createKbNameFocus.requestFocus();
    });
  }

  void _openEditKbDialog(KbListItem item) {
    _editingKb = item;
    _createKbNameCtrl.text = item.name;
    _createKbCover = null;
    _createKbCoverKey = null;
    _createKbCoverPreviewUrl = null;
    _createKbCoverUploading = false;
    _createKbCoverCleared = false;
    setState(() => _createKbOpen = true);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted && _createKbOpen) _createKbNameFocus.requestFocus();
    });
  }

  void _closeCreateKbDialog() => setState(() {
    _createKbOpen = false;
    _createKbCover = null;
    _createKbCoverKey = null;
    _createKbCoverPreviewUrl = null;
    _createKbCoverUploading = false;
    _editingKb = null;
    _createKbCoverCleared = false;
  });

  Future<void> _pickCreateKbCover() async {
    final picked = await pickImages(allowMultiple: false, maxCount: 1);
    if (!mounted || picked.isEmpty) return;
    final img = picked.first;
    setState(() {
      _createKbCover = img;
      _createKbCoverKey = null;
      _createKbCoverPreviewUrl = null;
      _createKbCoverCleared = false;
      _createKbCoverUploading = true;
    });
    final uploaded = await KbApi.uploadCover(img.bytes, img.name);
    if (!mounted) return;
    if (uploaded == null) {
      setState(() {
        _createKbCover = null;
        _createKbCoverKey = null;
        _createKbCoverPreviewUrl = null;
        _createKbCoverUploading = false;
      });
      _toast('封面上传失败，请重试');
      return;
    }
    setState(() {
      _createKbCoverKey = uploaded.objectKey;
      _createKbCoverPreviewUrl = uploaded.url;
      _createKbCoverUploading = false;
    });
  }

  void _clearCreateKbCover() => setState(() {
    _createKbCover = null;
    _createKbCoverKey = null;
    _createKbCoverPreviewUrl = null;
    _createKbCoverUploading = false;
    _createKbCoverCleared = true;
  });

  Widget _createKbCoverPreview() {
    if (_createKbCover != null) {
      return ComposeImageThumb(bytes: _createKbCover!.bytes, size: 48);
    }
    final uploaded = _createKbCoverPreviewUrl;
    if (uploaded != null && uploaded.isNotEmpty) {
      return SizedBox(
        width: 48,
        height: 48,
        child: MirrorNetworkImage(url: uploaded),
      );
    }
    final existing = _editingKb?.coverUrl;
    if (!_createKbCoverCleared && existing != null && existing.isNotEmpty) {
      return SizedBox(
        width: 48,
        height: 48,
        child: MirrorNetworkImage(url: existing),
      );
    }
    return Container(
      width: 48,
      height: 48,
      color: MirrorColors.bgCard,
      child: const Icon(
        Icons.image_outlined,
        size: 22,
        color: MirrorColors.text4,
      ),
    );
  }

  Future<void> _confirmCreateKb() async {
    final name = _createKbNameCtrl.text.trim();
    if (name.isEmpty) {
      _toast('请输入知识库名称');
      return;
    }
    if (_createKbCoverUploading) {
      _toast('封面上传中，请稍候');
      return;
    }
    final editing = _editingKb;
    final coverKey = _createKbCoverKey;
    final coverCleared = _createKbCoverCleared;
    _closeCreateKbDialog();
    setState(() => _uploading = true);
    String? coverUrl;
    if (coverKey != null && coverKey.isNotEmpty) {
      coverUrl = coverKey;
    } else if (coverCleared) {
      coverUrl = '';
    } else if (editing != null) {
      coverUrl = null;
    } else {
      coverUrl = '';
    }

    if (editing != null) {
      final updated = await KbStore.instance.updateKb(
        editing.id,
        name: name,
        coverUrl: coverUrl,
      );
      if (!mounted) return;
      setState(() => _uploading = false);
      if (updated != null) {
        _toast('已保存「$name」');
        if (_openedKbId == editing.id) {
          setState(() => _openedKbName = name);
        }
      } else {
        _toast('保存失败');
      }
      return;
    }

    final created = await KbStore.instance.createKb(
      name,
      coverUrl: coverUrl ?? '',
    );
    if (!mounted) return;
    setState(() => _uploading = false);
    if (created != null) {
      _toast('已创建「$name」');
      await _openKb(created.id, created.name, subscribed: false);
    } else {
      _toast('创建失败');
    }
  }

  Future<void> _confirmDeleteKb(KbListItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '删除知识库',
          style: MirrorTheme.sans(fontSize: 16, weight: FontWeight.w600),
        ),
        content: Text(
          '删除后无法恢复，订阅者将无法继续使用，确定删除「${item.name}」？',
          style: MirrorTheme.sans(fontSize: 14, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '删除',
              style: MirrorTheme.sans(color: MirrorColors.coral),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _uploading = true);
    final deleted = await KbStore.instance.deleteKb(item.id);
    if (!mounted) return;
    setState(() => _uploading = false);
    if (deleted) {
      if (_openedKbId == item.id) _closeDetail();
      _toast('已删除「${item.name}」');
    } else {
      _toast('删除失败');
    }
  }

  List<Widget> _createKbLayers() => [
    Positioned.fill(
      child: GestureDetector(
        onTap: _closeCreateKbDialog,
        behavior: HitTestBehavior.opaque,
        child: ColoredBox(color: Colors.black.withValues(alpha: 0.28)),
      ),
    ),
    Center(
      child: Material(
        color: MirrorColors.bgApp,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _editingKb == null ? '创建个人知识库' : '编辑个人知识库',
                  style: MirrorTheme.sans(
                    fontSize: 17,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '设置名称与封面，之后再导入知识',
                  style: MirrorTheme.sans(
                    fontSize: 12.5,
                    color: MirrorColors.text3,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _createKbNameCtrl,
                  focusNode: _createKbNameFocus,
                  style: MirrorTheme.sans(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '知识库名称，如 工作、学习',
                    hintStyle: MirrorTheme.sans(
                      fontSize: 14,
                      color: MirrorColors.text4,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: MirrorColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: MirrorColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: MirrorColors.accent,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _confirmCreateKb(),
                ),
                const SizedBox(height: 12),
                MirrorPressable(
                  onTap: _createKbCoverUploading ? null : _pickCreateKbCover,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: MirrorColors.bgSoft,
                      border: Border.all(color: MirrorColors.borderSoft),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _createKbCoverPreview(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '上传封面',
                                style: MirrorTheme.sans(
                                  fontSize: 13.5,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _createKbCoverUploading
                                    ? '正在上传到云端…'
                                    : (_createKbCoverKey != null
                                          ? '已上传，保存后生效'
                                          : '可选，用一张图代表这个知识库'),
                                style: MirrorTheme.sans(
                                  fontSize: 11.5,
                                  color: MirrorColors.text3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_createKbCoverUploading)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          const Icon(
                            Icons.file_upload_outlined,
                            size: 20,
                            color: MirrorColors.text3,
                          ),
                      ],
                    ),
                  ),
                ),
                if (_editingKb != null &&
                    (_createKbCover != null ||
                        (_editingKb!.coverUrl?.isNotEmpty ?? false)) &&
                    !_createKbCoverCleared)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _clearCreateKbCover,
                        child: Text(
                          '移除封面',
                          style: MirrorTheme.sans(
                            fontSize: 12,
                            color: MirrorColors.text3,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _closeCreateKbDialog,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: MirrorColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          '取消',
                          style: MirrorTheme.sans(
                            fontSize: 14,
                            weight: FontWeight.w600,
                            color: MirrorColors.text2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _createKbCoverUploading
                            ? null
                            : _confirmCreateKb,
                        style: FilledButton.styleFrom(
                          backgroundColor: MirrorColors.accent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _editingKb == null ? '创建' : '保存',
                          style: MirrorTheme.sans(
                            fontSize: 14,
                            weight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ];

  List<Widget> _searchLayers() {
    final isPersonal = (_searchScope ?? _scope) == _KbScope.personal;
    final hint = isPersonal ? '搜索我的知识库' : '搜索订阅的知识库';
    return [
      Positioned.fill(
        child: Material(
          color: MirrorColors.bgApp,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
                child: Row(
                  children: [
                    MirrorBackButton(onTap: _closeSearch),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        autofocus: true,
                        style: MirrorTheme.sans(
                          fontSize: 15,
                          color: MirrorColors.text,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: hint,
                          hintStyle: MirrorTheme.sans(
                            fontSize: 15,
                            color: MirrorColors.text3,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                        onChanged: _scheduleScopeSearch,
                        onSubmitted: _runScopeSearch,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _runScopeSearch(_searchCtrl.text),
                      icon: const Icon(Icons.search),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final store = KbStore.instance;
                    final items = isPersonal
                        ? store.scopeSearchMine
                        : store.scopeSearchSubscribed;
                    if (store.scopeSearchLoading && items.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    if (items.isEmpty) {
                      final q = _searchCtrl.text.trim();
                      final emptyHint = q.isEmpty
                          ? (isPersonal ? '暂无个人知识库' : '暂无订阅知识库')
                          : '未找到匹配的知识库';
                      return Center(
                        child: Text(
                          emptyHint,
                          textAlign: TextAlign.center,
                          style: MirrorTheme.sans(
                            fontSize: 13,
                            color: MirrorColors.text3,
                            height: 1.5,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: _searchScrollCtrl,
                      padding: const EdgeInsets.all(14),
                      itemCount:
                          items.length + (store.scopeSearchLoadingMore ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i >= items.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        }
                        if (isPersonal) {
                          final k = store.scopeSearchMine[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: MirrorPressable(
                              onTap: () async {
                                await _openKb(k.id, k.name, subscribed: false);
                                if (mounted) _closeSearch();
                              },
                              child: _kbCard(
                                k.name,
                                '${k.readyDocCount} 篇就绪',
                                coverUrl: k.coverUrl,
                              ),
                            ),
                          );
                        }
                        final s = store.scopeSearchSubscribed[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: MirrorPressable(
                            onTap: s.kbDeleted
                                ? null
                                : () async {
                                    await _openKb(
                                      s.kbId,
                                      s.name,
                                      subscribed: true,
                                    );
                                    if (mounted) _closeSearch();
                                  },
                            child: _kbCard(
                              s.name,
                              s.kbDeleted
                                  ? '知识库已删除'
                                  : s.metaLine,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: MirrorTheme.sans(fontSize: 13, color: Colors.white),
        ),
        backgroundColor: MirrorColors.text,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      ),
    );
  }
}

typedef DriveScreen = KnowledgeBaseScreen;

// ─── 知识库问答 ───────────────────────────────────────

class KbChatScreen extends StatefulWidget {
  const KbChatScreen({
    super.key,
    this.onBack,
    this.scopeLabel,
    this.kbIds,
    this.scopeType,
  });

  final VoidCallback? onBack;
  final String? scopeLabel;
  final List<int>? kbIds;
  final String? scopeType;

  @override
  State<KbChatScreen> createState() => _KbChatScreenState();
}

class _KbChatScreenState extends State<KbChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <KbMessage>[];
  var _sending = false;
  ChatStreamHandle? _activeStream;
  var _uploading = false;
  final _pendingSlots = ComposerAttachmentSlots();
  var _historyOpen = false;
  var _loadingHistory = false;
  var _settlingHistoryScroll = true;
  var _historyLoadError = '';
  var _conversationId = 0;
  final _conversations = <KbChatConversation>[];
  KbDocumentItem? _previewDoc;
  int? _previewKbId;
  var _scrollSettleGeneration = 0;
  final _voiceInput = VoiceInputController();
  var _asrAvailable = false;

  bool get _showVoiceMic => _kbIds.isNotEmpty && _asrAvailable;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onInputChanged);
    _voiceInput.addListener(_onVoiceInputChanged);
    _voiceInput.onAutoEnd = _onVoiceAutoEnd;
    KbStore.instance.addListener(_onStore);
    _ensureKbDetail();
    _bootstrapConversation();
    unawaited(_loadAsrStatus());
  }

  Future<void> _loadAsrStatus() async {
    final asr = await AsrClient.fetchStatus(refresh: true);
    if (!mounted) return;
    setState(() {
      _asrAvailable = asr.enabled;
      _voiceInput.maxDuration = Duration(seconds: asr.maxSegmentSeconds);
    });
  }

  void _onVoiceInputChanged() {
    if (mounted) setState(() {});
  }

  void _onInputChanged() {
    if (mounted) setState(() {});
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  Future<void> _ensureKbDetail() async {
    final ids = _kbIds;
    if (ids.length != 1) return;
    if (KbStore.instance.detailKbId == ids.first &&
        KbStore.instance.detail != null)
      return;
    await KbStore.instance.loadDetail(ids.first, silent: true);
    if (mounted) setState(() {});
  }

  Future<void> _bootstrapConversation() async {
    if (_kbIds.isEmpty) {
      if (mounted) setState(() => _settlingHistoryScroll = false);
      return;
    }
    final list = await KbApi.listChatConversations(
      kbIds: _kbIds,
      scopeType: _scopeType,
    );
    if (!mounted) return;
    if (list.isNotEmpty) {
      setState(() {
        _conversations
          ..clear()
          ..addAll(list);
        _conversationId = list.first.conversationId;
        _settlingHistoryScroll = true;
      });
      await _loadConversationMessages(_conversationId);
      return;
    }
    final id = await KbApi.createChatConversation(
      kbIds: _kbIds,
      scopeType: _scopeType,
    );
    if (!mounted) return;
    setState(() {
      if (id != null && id > 0) _conversationId = id;
      _settlingHistoryScroll = false;
    });
  }

  @override
  void dispose() {
    _activeStream?.cancel();
    _voiceInput.removeListener(_onVoiceInputChanged);
    _voiceInput.dispose();
    KbStore.instance.removeListener(_onStore);
    _ctrl.removeListener(_onInputChanged);
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _stopGeneration() {
    if (!_sending && _activeStream == null) return;
    _activeStream?.cancel();
    if (!mounted) return;
    setState(() {
      _sending = false;
      for (var i = 0; i < _messages.length; i++) {
        final m = _messages[i];
        if (m.streaming) {
          _messages[i] = m.copyWith(streaming: false);
        }
      }
    });
  }

  List<int> get _kbIds => widget.kbIds ?? KbStore.instance.activeKbIds;

  String get _scopeType => widget.scopeType ?? KbStore.instance.activeScopeType;

  void _animateToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _jumpToEndAfterLayout({bool closeHistoryAfter = false}) async {
    final generation = ++_scrollSettleGeneration;
    double? lastExtent;
    var stableFrames = 0;
    for (var i = 0; i < 12; i++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || generation != _scrollSettleGeneration) return;
      if (!_scroll.hasClients) {
        stableFrames = 0;
        lastExtent = null;
        continue;
      }
      final max = _scroll.position.maxScrollExtent;
      _scroll.jumpTo(max);
      if (lastExtent != null && (max - lastExtent).abs() < 1) {
        stableFrames++;
        if (stableFrames >= 2) break;
      } else {
        stableFrames = 0;
      }
      lastExtent = max;
    }
    if (!mounted || generation != _scrollSettleGeneration) return;
    if (_scroll.hasClients) {
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    }
    setState(() {
      _settlingHistoryScroll = false;
      if (closeHistoryAfter) _historyOpen = false;
    });
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loadingHistory = true;
        _historyLoadError = '';
      });
    }
    final list = await KbApi.listChatConversations(
      kbIds: _kbIds,
      scopeType: _scopeType,
    );
    if (!mounted) return;
    final merged = List<KbChatConversation>.from(list);
    if (_conversationId > 0 &&
        !merged.any((c) => c.conversationId == _conversationId)) {
      merged.insert(
        0,
        KbChatConversation(conversationId: _conversationId, title: '当前对话'),
      );
    }
    setState(() {
      _loadingHistory = false;
      _historyLoadError = list.isEmpty && _conversationId <= 0 ? '' : '';
      _conversations
        ..clear()
        ..addAll(merged);
    });
  }

  Future<void> _loadConversationMessages(
    int conversationId, {
    bool closeHistoryAfter = false,
  }) async {
    if (conversationId <= 0) return;
    if (!_settlingHistoryScroll) {
      setState(() => _settlingHistoryScroll = true);
    }
    final items = await KbApi.listChatMessages(conversationId);
    if (!mounted) return;
    setState(() {
      _conversationId = conversationId;
      _messages
        ..clear()
        ..addAll(items);
    });
    if (items.isEmpty) {
      setState(() {
        _settlingHistoryScroll = false;
        if (closeHistoryAfter) _historyOpen = false;
      });
      return;
    }
    await _jumpToEndAfterLayout(closeHistoryAfter: closeHistoryAfter);
  }

  Future<void> _openHistory() async {
    setState(() => _historyOpen = true);
    await _loadConversations();
  }

  void _closeHistory() => setState(() => _historyOpen = false);

  Future<void> _switchConversation(KbChatConversation item) async {
    if (item.conversationId == _conversationId) {
      if (_messages.isEmpty) {
        _closeHistory();
        return;
      }
      setState(() => _settlingHistoryScroll = true);
      await _jumpToEndAfterLayout(closeHistoryAfter: true);
      return;
    }
    setState(() {
      _settlingHistoryScroll = true;
      _messages.clear();
    });
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
    await _loadConversationMessages(
      item.conversationId,
      closeHistoryAfter: true,
    );
  }

  Future<void> _createNewConversation() async {
    if (_sending || _kbIds.isEmpty) return;
    final id = await KbApi.createChatConversation(
      kbIds: _kbIds,
      scopeType: _scopeType,
    );
    if (!mounted) return;
    if (id == null || id <= 0) {
      _toast('无法创建新对话');
      return;
    }
    setState(() {
      _conversationId = id;
      _messages.clear();
    });
    await _loadConversations(silent: true);
  }

  Future<bool> _onEnterVoiceMode() async {
    final granted = await _voiceInput.ensureMicPermission();
    if (!granted && mounted) {
      _toast('需要麦克风权限才能使用语音输入');
    }
    return granted;
  }

  Future<void> _onVoiceHoldStart() async {
    if (_sending || _uploading) return;
    if (!_asrAvailable) {
      _toast('语音识别服务未开启');
      return;
    }
    final consented = await ensureAiDataConsent(context);
    if (!consented || !mounted) return;
    try {
      await _voiceInput.holdStart();
    } catch (_) {
      _toast('需要麦克风权限才能使用语音输入');
    }
  }

  Future<void> _onVoiceHoldEnd() async {
    if (!_voiceInput.recording) return;
    final text = await _voiceInput.holdEnd();
    await _deliverVoiceText(text);
  }

  Future<void> _onVoiceAutoEnd(String? text) async {
    if (!mounted) return;
    _toast('单次语音最长 ${AsrClient.cachedStatus.maxSegmentSeconds} 秒');
    await _deliverVoiceText(text);
  }

  Future<void> _deliverVoiceText(String? text) async {
    if (!mounted) return;
    if (text == null || text.isEmpty) {
      if (_voiceInput.transcribing) return;
      _toast(AsrClient.lastError ?? '未识别到语音内容');
      return;
    }
    await _send(voiceText: text);
  }

  Future<void> _onVoiceHoldCancel() async {
    await _voiceInput.holdCancel();
  }

  Future<void> _send({String? voiceText}) async {
    final q = voiceText?.trim() ?? _ctrl.text.trim();
    if (q.isEmpty && !_pendingSlots.hasPending) return;
    if (_sending || _uploading || _kbIds.isEmpty) {
      if (_kbIds.isEmpty) _toast('请先打开知识库');
      return;
    }

    List<ChatAttachment> attachments = const [];
    if (_pendingSlots.hasPending) {
      setState(() => _uploading = true);
      final uploaded = await uploadComposerSlots(_pendingSlots);
      if (!mounted) return;
      setState(() => _uploading = false);
      if (uploaded == null) {
        _toast('上传失败，请重试');
        return;
      }
      attachments = uploaded;
      _pendingSlots.clear();
    }

    if (voiceText == null) _ctrl.clear();
    await _sendMessage(q, attachments: attachments);
  }

  void _showKbChatAttachSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MirrorColors.bgApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: MirrorColors.text2,
              ),
              title: Text('拍照', style: MirrorTheme.sans(fontSize: 15)),
              onTap: () {
                Navigator.pop(ctx);
                _kbChatPickCamera();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.image_outlined,
                color: MirrorColors.text2,
              ),
              title: Text('图片', style: MirrorTheme.sans(fontSize: 15)),
              onTap: () {
                Navigator.pop(ctx);
                _kbChatPickGallery();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.insert_drive_file_outlined,
                color: MirrorColors.text2,
              ),
              title: Text('文件', style: MirrorTheme.sans(fontSize: 15)),
              onTap: () {
                Navigator.pop(ctx);
                _kbChatPickFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _stageKbPick(PickedImageBytes file, {required bool isImage}) {
    if (_uploading || _sending) return;
    if (!isImage && chatAttachmentRequiresKbImport(file.name)) {
      _toast('请先在知识库中导入 PDF/Word 文档后再提问');
      return;
    }
    final sizeErr = validatePendingAttachmentSize(
      file.bytes.length,
      isImage: isImage,
    );
    if (sizeErr != null) {
      _toast(sizeErr);
      return;
    }
    setState(() {
      if (isImage) {
        if (_pendingSlots.image != null) _toast('已替换上一张图片');
        _pendingSlots.image = PendingChatAttachment.fromPicked(
          file,
          isImage: true,
        );
      } else {
        if (_pendingSlots.document != null) _toast('已替换上一个文件');
        _pendingSlots.document = PendingChatAttachment.fromPicked(
          file,
          isImage: false,
        );
      }
    });
  }

  Future<void> _kbChatPickCamera() async {
    final picked = await pickFromCamera();
    if (picked.isEmpty || !mounted) return;
    _stageKbPick(picked.first, isImage: true);
  }

  Future<void> _kbChatPickGallery() async {
    final picked = await pickFromGallery(allowMultiple: false, maxCount: 1);
    if (picked.isEmpty || !mounted) return;
    _stageKbPick(picked.first, isImage: true);
  }

  Future<void> _kbChatPickFile() async {
    final picked = await pickFiles(maxCount: 1);
    if (picked.isEmpty || !mounted) return;
    _stageKbPick(picked.first, isImage: pendingFileIsImage(picked.first.name));
  }

  Future<void> _sendMessage(
    String q, {
    List<ChatAttachment> attachments = const [],
  }) async {
    if (q.isEmpty && attachments.isEmpty) return;
    if (_sending || _kbIds.isEmpty) {
      if (_kbIds.isEmpty) _toast('请先打开知识库');
      return;
    }
    final consented = await ensureAiDataConsent(context);
    if (!consented || !mounted) return;
    setState(() {
      _sending = true;
      _messages.addAll([
        KbMessage(role: 'user', content: q, attachments: attachments),
        const KbMessage(role: 'assistant', content: '', streaming: true),
      ]);
    });
    _animateToEnd();

    final assistantIdx = _messages.length - 1;
    late final ChatStreamHandle stream;
    stream = KbSseClient.chatStream(
      question: q,
      kbIds: _kbIds,
      attachments: attachments,
      scopeType: _scopeType,
      conversationId: _conversationId,
      onDelta: (d) {
        if (!mounted || stream.cancelled) return;
        setState(() {
          final cur = _messages[assistantIdx];
          _messages[assistantIdx] = cur.copyWith(content: cur.content + d);
        });
        _animateToEnd();
      },
      onSources: (sources) {
        if (!mounted || stream.cancelled) return;
        setState(() {
          final cur = _messages[assistantIdx];
          _messages[assistantIdx] = cur.copyWith(sources: sources);
        });
      },
      onEmpty: (message) {
        if (!mounted || stream.cancelled) return;
        setState(() {
          final cur = _messages[assistantIdx];
          _messages[assistantIdx] = cur.copyWith(content: message);
        });
        _animateToEnd();
      },
      onDone: () {
        if (!mounted || stream.cancelled) return;
        setState(() {
          _sending = false;
          final cur = _messages[assistantIdx];
          if (cur.content.trim().isEmpty) {
            _messages[assistantIdx] = cur.copyWith(
              content: '未收到回答，请确认知识库文档已解析完成后再试。',
              streaming: false,
            );
          } else {
            _messages[assistantIdx] = cur.copyWith(streaming: false);
          }
        });
        _animateToEnd();
        _loadConversations(silent: true);
      },
      onConversationId: (id) {
        if (!mounted || stream.cancelled || id <= 0) return;
        setState(() => _conversationId = id);
      },
      onError: (m) {
        if (!mounted || stream.cancelled) return;
        setState(() {
          _sending = false;
          final cur = _messages[assistantIdx];
          _messages[assistantIdx] = cur.copyWith(content: m, streaming: false);
        });
      },
    );
    _activeStream = stream;
    try {
      await stream.done;
    } finally {
      if (stream.cancelled && mounted) {
        setState(() {
          _sending = false;
          if (assistantIdx < _messages.length) {
            final cur = _messages[assistantIdx];
            _messages[assistantIdx] = cur.copyWith(streaming: false);
          }
        });
      }
      _activeStream = null;
    }
  }

  void _openSource(KbMessageSource source) {
    if (!source.canPreview) {
      _toast('暂无法预览该引用');
      return;
    }
    final detail = KbStore.instance.detail;
    KbDocumentItem? doc;
    if (detail != null) {
      for (final d in detail.documents) {
        if (d.id == source.documentId) {
          doc = d;
          break;
        }
      }
    }
    doc ??= KbDocumentItem(
      id: source.documentId!,
      originalFilename: source.title,
      parseStatus: 'ready',
    );
    setState(() {
      _previewKbId = source.kbId;
      _previewDoc = doc;
    });
  }

  void _applySuggestion(String text) {
    _sendMessage(text);
  }

  static String _docDisplayName(String filename) {
    final trimmed = filename.trim();
    if (trimmed.isEmpty) return '这篇文档';
    final dot = trimmed.lastIndexOf('.');
    if (dot <= 0) return trimmed;
    return trimmed.substring(0, dot);
  }

  List<String> _kbChatSuggestions() {
    final kbIds = _kbIds;
    if (kbIds.length != 1) return const [];

    final detail = KbStore.instance.detail;
    if (detail == null || detail.id != kbIds.first) return const [];

    final readyDocs = detail.documents.where((d) => d.isReady).toList();
    if (readyDocs.isEmpty) return const [];

    final templates = [
      (String name) => '「$name」主要讲了什么？',
      (String name) => '帮我总结「$name」的要点',
      (String name) => '「$name」里有哪些值得注意的细节？',
    ];

    final out = <String>[];
    for (var i = 0; i < readyDocs.length && i < templates.length; i++) {
      out.add(templates[i](_docDisplayName(readyDocs[i].originalFilename)));
    }
    return out;
  }

  String _welcomeHint(String label) {
    final kbIds = _kbIds;
    if (kbIds.length != 1) {
      return 'Hi，基于「$label」提问吧。尽量使用文档里的具体名词或术语，检索会更准确。';
    }

    final detail = KbStore.instance.detail;
    if (detail == null || detail.id != kbIds.first) {
      return 'Hi，有任何关于这个知识库的问题，都尽管问 Mirror！';
    }

    if (detail.readyDocCount == 0 && kbHasPendingDocs(detail.documents)) {
      return '文档正在解析中，完成后会显示推荐问题。你也可以直接输入文档中的关键词提问。';
    }
    if (detail.readyDocCount == 0) {
      return '当前知识库还没有可用文档，请先上传并等待解析完成。';
    }
    if (_kbChatSuggestions().isNotEmpty) {
      return 'Hi，试试这些问题，或直接输入你想了解的内容：';
    }
    return 'Hi，有任何关于这个知识库的问题，都尽管问 Mirror！';
  }

  Widget _welcomeSection(String label) {
    final suggestions = _kbChatSuggestions();
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _welcomeHint(label),
            style: MirrorTheme.sans(
              fontSize: 15,
              color: MirrorColors.text,
              height: 1.55,
            ),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              decoration: BoxDecoration(
                color: MirrorColors.bgSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: MirrorColors.borderSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < suggestions.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    MirrorPressable(
                      onTap: _sending
                          ? null
                          : () => _applySuggestion(suggestions[i]),
                      borderRadius: BorderRadius.circular(8),
                      child: Text(
                        suggestions[i],
                        style: MirrorTheme.sans(
                          fontSize: 14,
                          color: MirrorColors.green,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            '当前范围：$label',
            style: MirrorTheme.mono(fontSize: 10.5, color: MirrorColors.text3),
          ),
        ],
      ),
    );
  }

  Widget _kbChatHeader(String label) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: MirrorColors.borderSoft)),
      ),
      child: Row(
        children: [
          if (widget.onBack != null) MirrorBackButton(onTap: widget.onBack),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MirrorTheme.sans(fontSize: 17, weight: FontWeight.w600),
            ),
          ),
          MirrorPressable(
            onTap: _sending ? null : _createNewConversation,
            borderRadius: BorderRadius.circular(8),
            padding: const EdgeInsets.all(8),
            child: Icon(
              Icons.note_add_outlined,
              size: 20,
              color: _sending ? MirrorColors.text3 : MirrorColors.text2,
            ),
          ),
          MirrorPressable(
            onTap: _openHistory,
            borderRadius: BorderRadius.circular(8),
            padding: const EdgeInsets.all(8),
            child: const Icon(
              Icons.history_rounded,
              size: 20,
              color: MirrorColors.text2,
            ),
          ),
        ],
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.scopeLabel ?? KbStore.instance.activeScopeLabel;
    final drawerW = MediaQuery.sizeOf(context).width * 0.75;
    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
            _kbChatHeader(label),
            Expanded(
              child: Stack(
                children: [
                  ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                    children: [
                      if (_messages.isEmpty && !_settlingHistoryScroll)
                        _welcomeSection(label),
                      for (final m in _messages)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _messageBubble(m),
                        ),
                    ],
                  ),
                  if (_settlingHistoryScroll)
                    Positioned.fill(
                      child: ColoredBox(
                        color: MirrorColors.bgApp,
                        child: const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            KbChatComposer(
              controller: _ctrl,
              enabled: !_sending && !_uploading,
              canSend:
                  !_sending &&
                  !_uploading &&
                  (_ctrl.text.trim().isNotEmpty || _pendingSlots.hasPending),
              canStop: _sending,
              onStop: _stopGeneration,
              pendingSlots: _pendingSlots,
              onRemovePendingImage: () =>
                  setState(() => _pendingSlots.image = null),
              onRemovePendingDocument: () =>
                  setState(() => _pendingSlots.document = null),
              onSend: _send,
              onAttach: _showKbChatAttachSheet,
              showVoiceMic: _showVoiceMic,
              voiceRecording: _voiceInput.recording,
              voiceTranscribing: _voiceInput.transcribing,
              voiceAmplitude: _voiceInput.amplitude,
              onEnterVoiceMode: _showVoiceMic ? _onEnterVoiceMode : null,
              onVoiceHoldStart: _showVoiceMic ? _onVoiceHoldStart : null,
              onVoiceHoldEnd: _showVoiceMic ? _onVoiceHoldEnd : null,
              onVoiceHoldCancel: _showVoiceMic ? _onVoiceHoldCancel : null,
            ),
          ],
        ),
        if (_historyOpen) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeHistory,
              child: Container(color: Colors.black.withValues(alpha: 0.35)),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: drawerW,
            child: Material(
              color: MirrorColors.bgApp,
              elevation: 8,
              child: SafeArea(
                child: SizedBox(
                  width: drawerW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                        child: Row(
                          children: [
                            Text(
                              '会话历史',
                              style: MirrorTheme.sans(
                                fontSize: 16,
                                weight: FontWeight.w600,
                                color: MirrorColors.text,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: _closeHistory,
                              icon: const Icon(Icons.close_rounded, size: 20),
                              color: MirrorColors.text3,
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: MirrorColors.borderSoft),
                      Expanded(
                        child: _loadingHistory
                            ? const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : _conversations.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                    _historyLoadError.isNotEmpty
                                        ? _historyLoadError
                                        : '暂无历史会话',
                                    style: MirrorTheme.sans(
                                      fontSize: 13,
                                      color: MirrorColors.text3,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
                                itemCount: _conversations.length,
                                separatorBuilder: (_, _) => const Divider(
                                  height: 1,
                                  indent: 52,
                                  color: MirrorColors.borderSoft,
                                ),
                                itemBuilder: (_, i) {
                                  final item = _conversations[i];
                                  final active =
                                      item.conversationId == _conversationId;
                                  return ListTile(
                                    dense: true,
                                    selected: active,
                                    selectedTileColor: MirrorColors.accentSoft
                                        .withValues(alpha: 0.35),
                                    leading: Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 18,
                                      color: active
                                          ? MirrorColors.accent
                                          : MirrorColors.text3,
                                    ),
                                    title: Text(
                                      item.displayTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: MirrorTheme.sans(
                                        fontSize: 14,
                                        weight: active
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: MirrorColors.text,
                                      ),
                                    ),
                                    subtitle: item.updatedAt.isNotEmpty
                                        ? Text(
                                            KbDocUi.relativeUpdated(
                                              item.updatedAt,
                                            ),
                                            style: MirrorTheme.sans(
                                              fontSize: 12,
                                              color: MirrorColors.text3,
                                            ),
                                          )
                                        : null,
                                    onTap: () => _switchConversation(item),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        if (_previewDoc != null && _previewKbId != null)
          Positioned.fill(
            child: KbDocumentViewer(
              kbId: _previewKbId!,
              doc: _previewDoc!,
              onClose: () => setState(() {
                _previewDoc = null;
                _previewKbId = null;
              }),
            ),
          ),
      ],
    );
  }

  Widget _messageBubble(KbMessage m) {
    if (m.isAssistant) {
      return KbAssistantMessage(
        message: m,
        onOpenSource: _openSource,
        onCopyFeedback: () => _toast('已复制'),
      );
    }
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: MirrorColors.text,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: _kbUserMessageBody(m),
      ),
    );
  }

  Widget _kbUserMessageBody(KbMessage m) {
    final text = m.content.trim();
    final hasText = text.isNotEmpty;
    final hasAtt = m.attachments.isNotEmpty;
    if (!hasText && !hasAtt) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasAtt) ...[
          ChatMessageAttachments(
            attachments: m.attachments,
            onDarkBackground: true,
          ),
          if (hasText) const SizedBox(height: 8),
        ],
        if (hasText)
          SelectableText(
            text,
            style: MirrorTheme.sans(
              fontSize: 13,
              height: 1.55,
              color: Colors.white,
            ),
          ),
      ],
    );
  }
}
