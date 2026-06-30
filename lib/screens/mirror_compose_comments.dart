import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../api/feed_api.dart';
import '../screens/post_detail_data.dart';
import '../services/image_picker_service.dart';
import '../api/me_api.dart';
import '../mappers/feed_comment_mapper.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../widgets/compose_image_thumb.dart';
import '../models/personal_kb.dart';
import '../widgets/compose_segments_editor.dart';
import '../widgets/mirror_pressable.dart';
import '../widgets/mirror_scroll.dart';
import '../widgets/phone_components.dart';
import '../widgets/mirror_user_avatar.dart';

class _ComposeImage {
  _ComposeImage({required this.id, required this.name, required this.bytes});

  final String id;
  final String name;
  final Uint8List bytes;
}

// ─── 发帖 Compose ───────────────────────────────────────────────
class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key, this.onBack, this.onPublished});

  final VoidCallback? onBack;
  final VoidCallback? onPublished;

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  int _imageSeq = 0;
  bool _publishing = false;
  final _titleCtrl = TextEditingController();
  List<PostBodyBlock> _segments = [const PostBodyBlock.paragraph('')];
  final List<String> _tags = [];
  final List<_ComposeImage> _coverImages = [];
  final List<_ComposeImage> _bodyImages = [];
  String? _sharedKbId;
  String _sharedKbName = '不分享知识库';
  int _sharedKbReadyDocCount = 0;
  String _visibility = '公开';
  List<ShareablePersonalKb> _personalKbs = [];
  bool _personalKbsLoading = false;

  static const _maxCoverImages = 9;
  static const _maxImages = 9;

  @override
  void initState() {
    super.initState();
    _loadMyProfile();
    _loadPersonalKbs();
    _loadDraft();
  }

  Future<void> _loadPersonalKbs() async {
    setState(() => _personalKbsLoading = true);
    final items = await FeedApi.fetchPersonalKbsForShare();
    if (!mounted) return;
    setState(() {
      _personalKbs = items;
      _personalKbsLoading = false;
      if (_sharedKbId != null && _sharedKbId != 'draft') {
        final match = items.where((k) => k.id == _sharedKbId).toList();
        if (match.isNotEmpty) _sharedKbName = match.first.name;
      }
    });
  }

  Future<void> _loadMyProfile() async {
    final overview = await MeApi.fetchOverview();
    if (!mounted || overview == null) return;
    setState(() => _sharedKbName = '不分享知识库');
  }

  bool get _sharePersonalKb {
    final id = _sharedKbId?.trim();
    if (id == null || id.isEmpty || id == 'draft' || id == 'legacy') return false;
    return true;
  }

  String get _draftCategory => 'soul';

  Future<void> _loadDraft() async {
    final d = await FeedApi.getDraft();
    if (!mounted || d == null) return;
    final title = (d['title'] ?? '').trim();
    final bodyRaw = d['body'] ?? '';
    if (title.isEmpty && bodyRaw.toString().trim().isEmpty) return;
    if (_titleCtrl.text.trim().isNotEmpty || _segments.any((b) => b.type != PostBodyBlockType.paragraph || b.text.trim().isNotEmpty)) {
      return;
    }

    final tagsRaw = d['tags'] ?? '';
    final vis = d['visibility'] ?? '';
    final shareKb = d['share_personal_kb'] == true || d['share_personal_kb'] == 'true' || d['share_personal_kb'] == '1';
    final kbName = (d['shared_kb_name'] ?? '').toString();
    final kbIdRaw = (d['shared_kb_id'] ?? '').toString().trim();

    setState(() {
      _titleCtrl.text = title;
      _segments = composeSegmentsFromBody(bodyRaw.toString());
      final kb = composeSharedKbFromBody(bodyRaw.toString());
      if (kb != null && kb.kbId != 'legacy') {
        _sharedKbId = kb.kbId;
        _sharedKbName = kb.name;
      }
      if (tagsRaw.isNotEmpty) {
        _tags
          ..clear()
          ..addAll(tagsRaw.split('|').map((t) => t.trim()).where((t) => t.isNotEmpty));
      }
      if (vis == 'private') _visibility = '仅自己';
      if (kbIdRaw.isNotEmpty && kbIdRaw != 'draft') {
        _sharedKbId = kbIdRaw;
        if (kbName.isNotEmpty) _sharedKbName = kbName;
      } else if (shareKb && kbName.isNotEmpty && _sharedKbId == null) {
        _sharedKbName = kbName;
      }
    });
    _toast('已恢复草稿');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: MirrorTheme.sans(fontSize: 13, color: Colors.white)),
        backgroundColor: MirrorColors.text,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      ),
    );
  }

  SharedKbAttachment? _sharedKbAttachment() {
    if (!_sharePersonalKb || _sharedKbId == null) return null;
    return SharedKbAttachment(
      kbId: _sharedKbId!,
      name: _sharedKbName,
      readyDocCount: _sharedKbReadyDocCount,
    );
  }

  String _encodedBody() => composeBodyPayload(
        segments: _segments,
        sharedKb: _sharedKbAttachment(),
      );

  Future<void> _pickCoverImage() async {
    if (_coverImages.length >= _maxCoverImages) {
      _toast('封面最多 $_maxCoverImages 张');
      return;
    }
    final remain = _maxCoverImages - _coverImages.length;
    final picked = await pickImages(allowMultiple: true, maxCount: remain);
    if (picked.isEmpty) return;
    final added = <_ComposeImage>[];
    for (final f in picked) {
      _imageSeq++;
      added.add(_ComposeImage(id: 'cover_$_imageSeq', name: f.name, bytes: f.bytes));
    }
    setState(() => _coverImages.addAll(added));
    _toast('已添加 ${added.length} 张封面');
  }

  Future<void> _pickBodyImages() async {
    if (_bodyImages.length >= _maxImages) {
      _toast('详情图最多 $_maxImages 张');
      return;
    }
    final remain = _maxImages - _bodyImages.length;
    final picked = await pickImages(allowMultiple: true, maxCount: remain);
    if (picked.isEmpty) return;
    final added = <_ComposeImage>[];
    for (final f in picked) {
      _imageSeq++;
      added.add(_ComposeImage(id: 'img_$_imageSeq', name: f.name, bytes: f.bytes));
    }
    if (added.isEmpty) {
      _toast('未能读取图片，请换一张试试');
      return;
    }
    setState(() => _bodyImages.addAll(added));
    _toast('已添加 ${added.length} 张详情图');
  }

  void _removeCover(String id) => setState(() => _coverImages.removeWhere((e) => e.id == id));

  void _removeBodyImage(String id) => setState(() => _bodyImages.removeWhere((e) => e.id == id));

  Future<void> _saveDraft() async {
    if (_titleCtrl.text.trim().isEmpty && !composeHasContent(_segments, hasCover: _coverImages.isNotEmpty)) {
      _toast('请先写点内容再保存');
      return;
    }
    final ok = await FeedApi.saveDraft({
      'title': _titleCtrl.text,
      'body': _encodedBody(),
      'category': _draftCategory,
      'tags': _tags.join('|'),
      'share_personal_kb': _sharePersonalKb ? 'true' : 'false',
      'shared_kb_id': _sharePersonalKb ? (_sharedKbId ?? '') : '',
      'shared_kb_name': _sharePersonalKb ? _sharedKbName : '',
      'cover_style': 'h1',
      'visibility': _visibility == '仅自己' ? 'private' : 'public',
    });
    if (!mounted) return;
    _toast(ok ? '草稿已保存，下次进入将自动恢复' : '保存失败，请确认已登录且 Redis 可用');
  }

  void _appendSegment(PostBodyBlock block) => setState(() => _segments = [..._segments, block]);

  Future<void> _publish() async {
    if (_publishing) return;
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _toast('请填写标题');
      return;
    }
    if (!composeHasContent(_segments, galleryUrls: const [], hasCover: _coverImages.isNotEmpty) && _bodyImages.isEmpty) {
      _toast('请添加正文样式块、封面或详情图片');
      return;
    }
    setState(() => _publishing = true);
    final coverUrls = <String>[];
    for (final img in _coverImages) {
      final uploaded = await FeedApi.uploadImage(img.bytes, img.name);
      if (uploaded != null) coverUrls.add(uploaded.objectKey);
    }
    final bodyUrls = <String>[];
    for (final img in _bodyImages) {
      final uploaded = await FeedApi.uploadImage(img.bytes, img.name);
      if (uploaded != null) bodyUrls.add(uploaded.objectKey);
    }
    final coverUrl = coverUrls.isNotEmpty ? coverUrls.first : null;
    if (!mounted) return;
    final result = await FeedApi.createPostResult(
      category: _draftCategory,
      title: title,
      body: composeBodyPayload(
        segments: _segments,
        coverImageUrls: coverUrls,
        galleryImageUrls: bodyUrls,
        sharedKb: _sharedKbAttachment(),
      ),
      coverStyle: coverUrl != null ? 'h1' : 'h2',
      coverLabel: '',
      tags: List<String>.from(_tags),
      visibility: _visibility == '仅自己' ? 'private' : 'public',
      coverImageUrl: coverUrl ?? '',
      sharedKbId: _sharePersonalKb ? _sharedKbId : null,
      sharedKbName: _sharePersonalKb ? _sharedKbName : null,
      sharePersonalKb: _sharePersonalKb,
    );
    if (!mounted) return;
    setState(() => _publishing = false);
    if (result.card == null) {
      _toast(result.error ?? '发布失败，请检查网络与登录状态');
      return;
    }
    widget.onPublished?.call();
    widget.onBack?.call();
  }

  Future<void> _addTag() async {
    final ctrl = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('添加标签', style: MirrorTheme.sans(fontSize: 15, weight: FontWeight.w500)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: '如 Prompt工程 或 周报模板'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              var t = ctrl.text.trim();
              if (t.isEmpty) return;
              if (!t.startsWith('#')) t = '#$t';
              Navigator.pop(ctx, t);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (tag != null && !_tags.contains(tag)) {
      setState(() => _tags.add(tag));
    }
  }

  Future<void> _pickVisibility() async {
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('谁可以看', style: MirrorTheme.sans(fontSize: 15, weight: FontWeight.w500)),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, '公开'), child: const Text('公开')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, '仅自己'), child: const Text('仅自己')),
        ],
      ),
    );
    if (v != null) setState(() => _visibility = v);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: MirrorColors.borderSoft))),
          child: Row(
            children: [
              MirrorPressable(
                onTap: widget.onBack,
                padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                borderRadius: BorderRadius.circular(8),
                child: Text('取消', style: MirrorTheme.sans(fontSize: 13, color: MirrorColors.text2)),
              ),
              Expanded(child: Text('发布笔记', textAlign: TextAlign.center, style: MirrorTheme.sans(fontSize: 14, weight: MirrorFontWeight.medium, letterSpacing: -0.01))),
              Row(
                children: [
                  MirrorPressable(
                    onTap: _publishing ? null : _saveDraft,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Text('草稿', style: MirrorTheme.mono(fontSize: 11, letterSpacing: 0)),
                  ),
                  const SizedBox(width: 8),
                  MirrorPressable(
                    onTap: _publishing ? null : _publish,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(color: MirrorColors.text, borderRadius: BorderRadius.circular(14)),
                      child: Text(
                        _publishing ? '发布中…' : '发布',
                        style: MirrorTheme.sans(fontSize: 12, weight: MirrorFontWeight.medium, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: MirrorScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _coverSection(),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleCtrl,
                  style: MirrorTheme.sans(fontSize: 18, weight: MirrorFontWeight.medium, letterSpacing: -0.015),
                  decoration: InputDecoration(
                    hintText: '起一个让人想点开的标题…',
                    hintStyle: MirrorTheme.sans(fontSize: 18, color: MirrorColors.text4, weight: MirrorFontWeight.regular),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
                const Divider(height: 23, color: MirrorColors.borderSoft),
                ComposeSegmentsEditor(
                  segments: _segments,
                  enabled: !_publishing,
                  onChanged: (next) => setState(() => _segments = next),
                ),
                if (_bodyImages.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final img in _bodyImages) _imageThumb(img, onRemove: () => _removeBodyImage(img.id)),
                    ],
                  ),
                  Text('详情图 ${_bodyImages.length}/$_maxImages', style: MirrorTheme.mono(fontSize: 10, color: MirrorColors.text4)),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (final t in _tags) _tagPill(t, () => setState(() => _tags.remove(t))),
                    MirrorPressable(
                      onTap: _addTag,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(border: Border.all(color: MirrorColors.border), borderRadius: BorderRadius.circular(6)),
                        child: Text('+ 加标签', style: MirrorTheme.sans(fontSize: 11.5, color: MirrorColors.text3)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _shareKbRow(),
                MirrorPressable(onTap: _pickVisibility, child: _composeExtra(Icons.visibility_outlined, '谁可以看', _visibility)),
                const SizedBox(height: 72),
              ],
            ),
          ),
        ),
        ComposeSegmentsToolbar(
          enabled: !_publishing,
          onParagraph: () => _appendSegment(const PostBodyBlock.paragraph('')),
          onImage: _pickBodyImages,
          onCode: () => _appendSegment(const PostBodyBlock.code('// 代码片段')),
          onStats: () => _appendSegment(const PostBodyBlock.stats([
                (v: '92', k: '指标 A'),
                (v: '87', k: '指标 B'),
                (v: '24×', k: 'ROI'),
              ])),
          onCallout: () => _appendSegment(const PostBodyBlock.callout(
                icon: Icons.check,
                variant: CalloutVariant.green,
                body: '在此填写结论或提示…',
              )),
          onCompare: () => _appendSegment(const PostBodyBlock.compare(
                badTitle: 'before',
                bad: '改进前描述',
                goodTitle: 'after',
                good: '改进后描述',
              )),
        ),
      ],
    );
  }

  Future<void> _pickSharedKb() async {
    if (_publishing) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final bottomInset = MediaQuery.viewPaddingOf(sheetCtx).bottom;
        final maxHeight = MediaQuery.sizeOf(sheetCtx).height * 0.48;
        return Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottomInset),
          child: _ShareKbPickerSheet(
            maxHeight: maxHeight,
            loading: _personalKbsLoading,
            personalKbs: _personalKbs,
            selectedKbId: _sharedKbId,
            onClose: () => Navigator.pop(sheetCtx),
            onPick: (id, name) {
              Navigator.pop(sheetCtx);
              _applyKbPick(id, name);
            },
          ),
        );
      },
    );
  }

  void _applyKbPick(String? id, String name) {
    setState(() {
      if (id == null || id.isEmpty) {
        _sharedKbId = null;
        _sharedKbName = '不分享知识库';
        _sharedKbReadyDocCount = 0;
      } else {
        _sharedKbId = id;
        _sharedKbName = name;
        final match = _personalKbs.where((k) => k.id == id).toList();
        _sharedKbReadyDocCount = match.isNotEmpty ? match.first.readyDocCount : 0;
      }
    });
  }

  Widget _coverSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('图片（可多选）', style: MirrorTheme.mono(fontSize: 10, color: MirrorColors.text3, letterSpacing: 0.06)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final img in _coverImages) _imageThumb(img, onRemove: () => _removeCover(img.id)),
            if (_coverImages.length < _maxCoverImages) _addImageTile(label: '添加图片', onTap: _pickCoverImage),
          ],
        ),
        if (_coverImages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '已选 ${_coverImages.length}/$_maxCoverImages 张 · 首张用于动态列表封面，其余用于详情轮播',
              style: MirrorTheme.mono(fontSize: 10, color: MirrorColors.text4),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('可多选封面；底部「图片」用于正文详情图', style: MirrorTheme.sans(fontSize: 11, color: MirrorColors.text4)),
          ),
      ],
    );
  }

  Widget _imageThumb(_ComposeImage img, {required VoidCallback onRemove}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ComposeImageThumb(
            key: ValueKey(img.id),
            bytes: img.bytes,
            size: 96,
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: MirrorPressable(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(color: MirrorColors.text, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _addImageTile({required String label, required VoidCallback onTap}) => MirrorPressable(
        onTap: _publishing ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: MirrorColors.bgSoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: MirrorColors.border, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_photo_alternate_outlined, color: MirrorColors.accent, size: 24),
              const SizedBox(height: 4),
              Text(label, style: MirrorTheme.sans(fontSize: 11, color: MirrorColors.text3)),
            ],
          ),
        ),
      );

  Widget _tagPill(String t, VoidCallback onRemove) => MirrorPressable(
        onTap: onRemove,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(color: MirrorColors.accentSoft, borderRadius: BorderRadius.circular(6)),
          child: Text('$t ×', style: MirrorTheme.sans(fontSize: 11.5, color: MirrorColors.accentDeep)),
        ),
      );

  Widget _shareKbRow() => MirrorPressable(
        onTap: _pickSharedKb,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: MirrorColors.bgSoft, border: Border.all(color: MirrorColors.borderSoft), borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              const Icon(Icons.menu_book_outlined, size: 16, color: MirrorColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('分享个人知识库', style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text2)),
                    Text(
                      _sharePersonalKb ? _sharedKbName : '点击选择要附带的分类',
                      style: MirrorTheme.mono(fontSize: 10, color: MirrorColors.text3, letterSpacing: 0),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 16, color: MirrorColors.text3),
            ],
          ),
        ),
      );

  Widget _composeExtra(IconData i, String label, String sub) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: MirrorColors.bgSoft, border: Border.all(color: MirrorColors.borderSoft), borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Icon(i, size: 16, color: MirrorColors.accent),
            const SizedBox(width: 10),
            Text(label, style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text2)),
            const Spacer(),
            Text(sub, style: MirrorTheme.mono(fontSize: 10, letterSpacing: 0)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 14, color: MirrorColors.text3),
          ],
        ),
      );

  Widget _tool(IconData i, String label, {VoidCallback? onTap, bool accent = false}) => Expanded(
        child: MirrorPressable(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(i, size: 20, color: accent ? MirrorColors.accent : MirrorColors.text2),
              const SizedBox(height: 4),
              Text(
                label,
                style: MirrorTheme.mono(fontSize: 10, color: accent ? MirrorColors.accent : MirrorColors.text3, letterSpacing: 0),
              ),
            ],
          ),
        ),
      );
}

class _ShareKbPickerSheet extends StatelessWidget {
  const _ShareKbPickerSheet({
    required this.maxHeight,
    required this.loading,
    required this.personalKbs,
    required this.selectedKbId,
    required this.onClose,
    required this.onPick,
  });

  final double maxHeight;
  final bool loading;
  final List<ShareablePersonalKb> personalKbs;
  final String? selectedKbId;
  final VoidCallback onClose;
  final void Function(String? id, String name) onPick;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MirrorColors.bgApp,
      elevation: 12,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text('选择要分享的知识库', style: MirrorTheme.sans(fontSize: 15, weight: FontWeight.w600)),
                  ),
                  MirrorPressable(
                    onTap: onClose,
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.close, size: 18, color: MirrorColors.text3),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  _kbPickerTile(
                    title: '不分享',
                    selected: selectedKbId == null,
                    onTap: () => onPick(null, '不分享知识库'),
                  ),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
                    )
                  else if (personalKbs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                      child: Text(
                        '暂无个人知识库，请先在「知识库」页创建分类',
                        style: MirrorTheme.sans(fontSize: 13, color: MirrorColors.text3),
                      ),
                    )
                  else
                    for (final kb in personalKbs)
                      _kbPickerTile(
                        title: kb.name,
                        subtitle: kb.readyDocCount > 0 ? '${kb.readyDocCount} 篇文档 · 个人知识库分类' : '个人知识库分类',
                        leading: const Icon(Icons.folder_outlined, color: MirrorColors.accent, size: 20),
                        selected: selectedKbId == kb.id,
                        onTap: () => onPick(kb.id, kb.name),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kbPickerTile({
    required String title,
    String? subtitle,
    Widget? leading,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      MirrorPressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: MirrorColors.borderSoft))),
          child: Row(
            children: [
              if (leading != null) ...[leading, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: MirrorTheme.sans(fontSize: 14)),
                    if (subtitle != null)
                      Text(subtitle, style: MirrorTheme.sans(fontSize: 11, color: MirrorColors.text3)),
                  ],
                ),
              ),
              if (selected) const Icon(Icons.check_circle, color: MirrorColors.accent, size: 18),
            ],
          ),
        ),
      );
}

// ─── 评论 Comments ──────────────────────────────────────────────
class CommentsScreen extends StatefulWidget {
  const CommentsScreen({
    super.key,
    this.onBack,
    this.commentCount = '412',
    this.openForCompose = false,
  });

  final VoidCallback? onBack;
  final String commentCount;
  /// 从帖子底栏「说点什么…」进入时自动聚焦输入框
  final bool openForCompose;

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final _liked = <int>{0};
  final _input = TextEditingController();
  final _focus = FocusNode();
  String? _replyTo;

  @override
  void initState() {
    super.initState();
    if (widget.openForCompose) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startReply(String name) {
    setState(() => _replyTo = name);
    _focus.requestFocus();
  }

  void _clearReply() => setState(() {
        _replyTo = null;
        _input.clear();
      });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(6, 2, 16, 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: MirrorColors.borderSoft))),
          child: Row(
            children: [
              MirrorBackButton(onTap: widget.onBack),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: MirrorTheme.sans(fontSize: 14, weight: MirrorFontWeight.medium, letterSpacing: -0.01),
                    children: [
                      const TextSpan(text: '评论 '),
                      TextSpan(text: '${widget.commentCount} 条', style: MirrorTheme.mono(fontSize: 11, color: MirrorColors.text3, weight: MirrorFontWeight.regular, letterSpacing: 0)),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Text('按热度', style: MirrorTheme.mono(fontSize: 11, letterSpacing: 0)),
                  const Icon(Icons.expand_more, size: 14, color: MirrorColors.text3),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: MirrorScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: CommentsThreadList(
              liked: _liked,
              onLikeToggle: (id) => setState(() => _liked.contains(id) ? _liked.remove(id) : _liked.add(id)),
              onReply: (name, {parentId = 0, userId = 0}) => _startReply(name),
              compact: false,
            ),
          ),
        ),
        CommentsComposeBar(
          controller: _input,
          focusNode: _focus,
          replyTo: _replyTo,
          onClearReply: _clearReply,
        ),
      ],
    );
  }
}

/// 底部评论输入条（帖子详情 / 评论页共用）
class CommentsComposeBar extends StatelessWidget {
  const CommentsComposeBar({
    super.key,
    required this.controller,
    required this.focusNode,
    this.replyTo,
    this.onClearReply,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? replyTo;
  final VoidCallback? onClearReply;

  String get _hint => replyTo == null ? '说点什么…' : '回复 $replyTo…';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: const BoxDecoration(
        color: MirrorColors.bgApp,
        border: Border(top: BorderSide(color: MirrorColors.borderSoft)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (replyTo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text('回复 $replyTo', style: MirrorTheme.mono(fontSize: 10, color: MirrorColors.accent, letterSpacing: 0)),
                  const Spacer(),
                  MirrorPressable(
                    onTap: onClearReply,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text('取消', style: MirrorTheme.sans(fontSize: 11, color: MirrorColors.text3)),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: const BoxDecoration(gradient: MirrorGradients.profile, shape: BoxShape.circle),
                child: Text('L', style: MirrorTheme.sans(fontSize: 12, weight: MirrorFontWeight.medium, color: Colors.white)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: MirrorColors.bgSoft,
                    border: Border.all(color: MirrorColors.border),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: _hint,
                      hintStyle: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text3),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),
              const Icon(Icons.sentiment_satisfied_alt_outlined, size: 18, color: MirrorColors.text3),
              const SizedBox(width: 10),
              const Icon(Icons.alternate_email, size: 18, color: MirrorColors.text3),
            ],
          ),
        ],
      ),
    );
  }
}

/// 评论区列表（帖子页预览与评论页共用）
class CommentsThreadList extends StatelessWidget {
  const CommentsThreadList({
    super.key,
    required this.liked,
    required this.onLikeToggle,
    required this.onReply,
    this.compact = false,
    this.maxItems,
    this.rows,
    this.commentsLoaded,
  });

  final Set<int> liked;
  final void Function(int id) onLikeToggle;
  final void Function(String name, {int parentId, int userId}) onReply;
  final bool compact;
  final int? maxItems;
  final List<CommentRowView>? rows;
  final bool? commentsLoaded;

  @override
  Widget build(BuildContext context) {
    if (rows != null) {
      if (rows!.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Text(
            commentsLoaded == true ? '还没有评论，来说第一句吧' : '加载评论中…',
            style: MirrorTheme.sans(fontSize: 13, color: MirrorColors.text3),
          ),
        );
      }
      var list = rows!
          .map(
            (r) => _commentItem(
              r.id,
              r.userId,
              r.av,
              r.grad,
              r.avatarUrl,
              r.name,
              r.role,
              r.roleBg,
              r.roleFg,
              r.text,
              r.time,
              r.likes,
              nested: r.nested
                  .map((n) => _Nest(n.commentId, n.userId, n.av, n.grad, n.avatarUrl, n.name, n.isAuthor, n.replyTo, n.text))
                  .toList(),
              moreReplies: r.moreReplies,
            ),
          )
          .toList();
      if (maxItems != null) list = list.take(maxItems!).toList();
      return Column(children: list);
    }
    final items = <Widget>[
      _commentItem(
        0,
        0,
        '陈',
        MirrorGradients.purple,
        '',
        '陈墨',
        'K8S 大佬',
        MirrorColors.blueSoft,
        MirrorColors.blueText,
        '第三条"代码必须可执行"这句深得我心。我以前总是被 Agent 给的伪代码坑到，加了这条之后省心一倍。',
        '2 小时前',
        '238',
        nested: compact
            ? null
            : [
                _Nest(0, 0, '林', MirrorColors.accent, '', '林岸', true, '陈墨', '是的，这条是我被坑出来的。后面我又加了一条"输出的命令必须先解释影响范围"，更稳。'),
                _Nest(0, 0, '陈', MirrorColors.accent, '', '陈墨', false, '林岸', '这条要偷！K8s 场景下太需要了，kubectl delete 之前必须先 dry-run。'),
              ],
        moreReplies: compact ? null : '展开剩余 24 条回复 →',
      ),
      _commentItem(1, 0, '周', MirrorGradients.green, '', '周野', '长文专家', MirrorColors.greenSoft, MirrorColors.greenText, '禁止 emoji 这条我犹豫了好久，最近终于加上去。世界清净了。', '3 小时前', '147'),
      if (!compact)
        _commentItem(
          2,
          0,
          '沈',
          MirrorGradients.amber,
          '',
          '沈知微',
          'PROMPT 工匠',
          MirrorColors.pinkSoft,
          MirrorColors.pinkText,
          '借鉴了这个结构，我的 Lyra 也升级了。一句话目标这个字段尤其有用——逼着自己想清楚到底要什么。',
          '5 小时前',
          '89',
          nested: [_Nest(0, 0, '林', MirrorColors.accent, '', '林岸', true, '沈知微', '一句话目标是我最纠结写的，但确实是收益最大的字段。期待看你的 Lyra！')],
        ),
      if (!compact) ...[
        _commentItem(3, 0, '徐', MirrorGradients.blue, '', '徐潼', null, null, null, '有没有英文版？想给国外同事看一下。', '昨天', '23'),
        _commentItem(4, 0, '高', MirrorGradients.dark, '', '高临', '凌晨 3 点', MirrorColors.coralSoft, MirrorColors.coralText, '"敢于反对"这点学到了。我一开始的 Iris 总在我犯傻的时候顺着我夸，后来狠下心改了 Soul，立刻清爽。', '昨天', '312'),
        _commentItem(5, 0, '钟', MirrorGradients.purple, '', '钟意', '编辑推荐', MirrorColors.pinkSoft, MirrorColors.pinkText, '已经把这篇推到首页啦，太有结构了！期待你下一篇讲讲 MEMORY 的部分～', '2 天前', '156'),
        _commentItem(6, 0, '小', MirrorGradients.pink, '', '小苇', null, null, null, '禁词清单求一份！发邮件也行 🙏', '2 天前', '67'),
      ],
    ];
    final shown = maxItems != null ? items.take(maxItems!).toList() : items;
    return Column(children: shown);
  }

  Widget _commentItem(
    int id,
    int userId,
    String av,
    LinearGradient grad,
    String avatarUrl,
    String name,
    String? role,
    Color? roleBg,
    Color? roleFg,
    String text,
    String time,
    String likes, {
    List<_Nest>? nested,
    String? moreReplies,
  }) {
    final on = liked.contains(id);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 10 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MirrorUserAvatar(size: 32, letter: av, avatarUrl: avatarUrl, gradient: grad, fontSize: 13),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(name, style: MirrorTheme.sans(fontSize: 11.5, color: MirrorColors.text3, weight: MirrorFontWeight.medium)),
                    if (role != null && roleBg != null && roleFg != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: roleBg, borderRadius: BorderRadius.circular(3)),
                        child: Text(role, style: MirrorTheme.mono(fontSize: 8.5, color: roleFg, letterSpacing: 0.02)),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(text, style: MirrorTheme.sans(fontSize: 13, height: 1.55, letterSpacing: -0.003)),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(time, style: MirrorTheme.mono(fontSize: 10, letterSpacing: 0)),
                    const SizedBox(width: 14),
                    MirrorPressable(
                      onTap: () => onReply(name, parentId: id, userId: userId),
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('回复', style: MirrorTheme.sans(fontSize: 11, color: MirrorColors.text3)),
                    ),
                    const Spacer(),
                    MirrorPressable(
                      onTap: () => onLikeToggle(id),
                      child: Row(
                        children: [
                          Icon(on ? Icons.favorite : Icons.favorite_border, size: 14, color: on ? MirrorColors.pink : MirrorColors.text3),
                          const SizedBox(width: 3),
                          Text(likes, style: MirrorTheme.mono(fontSize: 10, color: on ? MirrorColors.pink : MirrorColors.text3, letterSpacing: 0)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (nested != null && nested.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: MirrorColors.bgSoft, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < nested.length; i++) ...[
                          if (i > 0) const Divider(height: 17, color: MirrorColors.borderSoft),
                          _nestRow(nested[i]),
                        ],
                        if (moreReplies != null) ...[
                          const SizedBox(height: 8),
                          Text(moreReplies, style: MirrorTheme.mono(fontSize: 11, color: MirrorColors.accent, weight: MirrorFontWeight.medium, letterSpacing: 0)),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _nestRow(_Nest n) => MirrorPressable(
        onTap: () => onReply(n.name, parentId: n.commentId, userId: n.userId),
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MirrorUserAvatar(size: 20, letter: n.av, avatarUrl: n.avatarUrl, color: n.avColor, fontSize: 10),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(n.name, style: MirrorTheme.sans(fontSize: 10.5, color: MirrorColors.text3, weight: MirrorFontWeight.medium)),
                    if (n.isAuthor)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: MirrorColors.accentSoft, borderRadius: BorderRadius.circular(3)),
                        child: Text('作者', style: MirrorTheme.mono(fontSize: 8.5, color: MirrorColors.accent, letterSpacing: 0.04)),
                      ),
                    Text.rich(
                      TextSpan(
                        style: MirrorTheme.sans(fontSize: 10.5, color: MirrorColors.text3),
                        children: [
                          const TextSpan(text: '回复 '),
                          TextSpan(text: '@${n.replyTo}', style: MirrorTheme.sans(fontSize: 10.5, color: MirrorColors.accent, weight: MirrorFontWeight.medium)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(n.text, style: MirrorTheme.sans(fontSize: 12.5, height: 1.5)),
              ],
            ),
          ),
        ],
        ),
      );
}

class _Nest {
  const _Nest(this.commentId, this.userId, this.av, this.avColor, this.avatarUrl, this.name, this.isAuthor, this.replyTo, this.text);
  final int commentId;
  final int userId;
  final String av;
  final Color avColor;
  final String avatarUrl;
  final String name;
  final bool isAuthor;
  final String replyTo;
  final String text;
}
