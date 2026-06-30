import 'package:flutter/material.dart';

import '../models/personal_kb.dart';
import '../models/post_body_envelope.dart';
import '../screens/post_detail_data.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../widgets/mirror_pressable.dart';
import '../widgets/post_body_blocks_view.dart';

/// 发布页正文：可排序的样式块列表 + 底部插入工具栏。
class ComposeSegmentsEditor extends StatelessWidget {
  const ComposeSegmentsEditor({
    super.key,
    required this.segments,
    required this.onChanged,
    this.enabled = true,
  });

  final List<PostBodyBlock> segments;
  final ValueChanged<List<PostBodyBlock>> onChanged;
  final bool enabled;

  void _update(int index, PostBodyBlock block) {
    final next = [...segments];
    next[index] = block;
    onChanged(next);
  }

  void _remove(int index) {
    final next = [...segments]..removeAt(index);
    onChanged(next);
  }

  void _moveUp(int index) {
    if (index <= 0) return;
    final next = [...segments];
    final item = next.removeAt(index);
    next.insert(index - 1, item);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('点击下方工具插入段落、指标卡、提示框等样式块', style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text4)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < segments.length; i++)
          _SegmentCard(
            key: ValueKey('seg_${i}_${segments[i].type.name}'),
            block: segments[i],
            enabled: enabled,
            onChanged: (b) => _update(i, b),
            onRemove: () => _remove(i),
            onMoveUp: i > 0 ? () => _moveUp(i) : null,
          ),
      ],
    );
  }
}

class ComposeSegmentsToolbar extends StatelessWidget {
  const ComposeSegmentsToolbar({
    super.key,
    required this.onParagraph,
    required this.onImage,
    required this.onCode,
    required this.onStats,
    required this.onCallout,
    required this.onCompare,
    this.enabled = true,
  });

  final VoidCallback onParagraph;
  final VoidCallback onImage;
  final VoidCallback onCode;
  final VoidCallback onStats;
  final VoidCallback onCallout;
  final VoidCallback onCompare;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      decoration: const BoxDecoration(
        color: MirrorColors.bgApp,
        border: Border(top: BorderSide(color: MirrorColors.borderSoft)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _tool(Icons.notes_outlined, '段落', onParagraph),
            _tool(Icons.add_photo_alternate_outlined, '图片', onImage),
            _tool(Icons.code, '代码', onCode),
            _tool(Icons.grid_view_rounded, '指标', onStats),
            _tool(Icons.tips_and_updates_outlined, '提示', onCallout),
            _tool(Icons.compare_arrows, '对比', onCompare),
          ],
        ),
      ),
    );
  }

  Widget _tool(IconData icon, String label, VoidCallback onTap) => Expanded(
        child: MirrorPressable(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: enabled ? MirrorColors.text2 : MirrorColors.text4),
              const SizedBox(height: 4),
              Text(label, style: MirrorTheme.mono(fontSize: 10, color: enabled ? MirrorColors.text3 : MirrorColors.text4, letterSpacing: 0)),
            ],
          ),
        ),
      );
}

class _SegmentCard extends StatefulWidget {
  const _SegmentCard({
    super.key,
    required this.block,
    required this.enabled,
    required this.onChanged,
    required this.onRemove,
    this.onMoveUp,
  });

  final PostBodyBlock block;
  final bool enabled;
  final ValueChanged<PostBodyBlock> onChanged;
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp;

  @override
  State<_SegmentCard> createState() => _SegmentCardState();
}

class _SegmentCardState extends State<_SegmentCard> {
  late TextEditingController _paragraphCtrl;
  late TextEditingController _codeCtrl;

  @override
  void initState() {
    super.initState();
    _paragraphCtrl = TextEditingController(text: widget.block.type == PostBodyBlockType.paragraph ? widget.block.text : '');
    _codeCtrl = TextEditingController(text: widget.block.code ?? '');
  }

  @override
  void didUpdateWidget(covariant _SegmentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block != widget.block) {
      if (widget.block.type == PostBodyBlockType.paragraph && _paragraphCtrl.text != widget.block.text) {
        _paragraphCtrl.text = widget.block.text;
      }
      if (widget.block.type == PostBodyBlockType.code && _codeCtrl.text != (widget.block.code ?? '')) {
        _codeCtrl.text = widget.block.code ?? '';
      }
    }
  }

  @override
  void dispose() {
    _paragraphCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: MirrorColors.bgSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MirrorColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(_label(widget.block), style: MirrorTheme.mono(fontSize: 10, color: MirrorColors.text3, letterSpacing: 0.04)),
              const Spacer(),
              if (widget.onMoveUp != null)
                MirrorPressable(
                  onTap: widget.enabled ? widget.onMoveUp : null,
                  padding: const EdgeInsets.all(4),
                  child: const Icon(Icons.arrow_upward, size: 16, color: MirrorColors.text3),
                ),
              MirrorPressable(
                onTap: widget.enabled ? widget.onRemove : null,
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.close, size: 16, color: MirrorColors.text3),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _editor(),
          const SizedBox(height: 8),
          Opacity(opacity: 0.92, child: PostBodyBlocksView(blocks: [widget.block])),
        ],
      ),
    );
  }

  String _label(PostBodyBlock b) => switch (b.type) {
        PostBodyBlockType.paragraph => '段落',
        PostBodyBlockType.stats => '指标卡',
        PostBodyBlockType.callout => '提示框',
        PostBodyBlockType.compare => '对比',
        PostBodyBlockType.code => '代码',
      };

  Widget _editor() {
    switch (widget.block.type) {
      case PostBodyBlockType.paragraph:
        return TextField(
          enabled: widget.enabled,
          maxLines: null,
          controller: _paragraphCtrl,
          onChanged: (t) => widget.onChanged(PostBodyBlock.paragraph(t)),
          style: MirrorTheme.sans(fontSize: 13.5, height: 1.65),
          decoration: InputDecoration(
            hintText: '分享心得、案例或模板…',
            hintStyle: MirrorTheme.sans(fontSize: 13.5, color: MirrorColors.text4),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        );
      case PostBodyBlockType.stats:
        return _StatsEditor(block: widget.block, enabled: widget.enabled, onChanged: widget.onChanged);
      case PostBodyBlockType.callout:
        return _CalloutEditor(block: widget.block, enabled: widget.enabled, onChanged: widget.onChanged);
      case PostBodyBlockType.compare:
        return _CompareEditor(block: widget.block, enabled: widget.enabled, onChanged: widget.onChanged);
      case PostBodyBlockType.code:
        return TextField(
          enabled: widget.enabled,
          maxLines: 6,
          controller: _codeCtrl,
          onChanged: (t) => widget.onChanged(PostBodyBlock.code(t)),
          style: MirrorTheme.mono(fontSize: 12, height: 1.6),
          decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
        );
    }
  }
}

class _StatsEditor extends StatefulWidget {
  const _StatsEditor({required this.block, required this.enabled, required this.onChanged});

  final PostBodyBlock block;
  final bool enabled;
  final ValueChanged<PostBodyBlock> onChanged;

  @override
  State<_StatsEditor> createState() => _StatsEditorState();
}

class _StatsEditorState extends State<_StatsEditor> {
  late List<TextEditingController> _v;
  late List<TextEditingController> _k;

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant _StatsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block != widget.block) {
      _disposeControllers();
      _syncControllers();
    }
  }

  void _syncControllers() {
    final items = widget.block.stats ?? const [];
    _v = [for (final s in items) TextEditingController(text: s.v)];
    _k = [for (final s in items) TextEditingController(text: s.k)];
    while (_v.length < 3) {
      _v.add(TextEditingController());
      _k.add(TextEditingController());
    }
  }

  void _disposeControllers() {
    for (final c in _v) {
      c.dispose();
    }
    for (final c in _k) {
      c.dispose();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _emit() {
    final items = <({String v, String k})>[];
    for (var i = 0; i < 3; i++) {
      items.add((v: _v[i].text.trim(), k: _k[i].text.trim()));
    }
    widget.onChanged(PostBodyBlock.stats(items));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    enabled: widget.enabled,
                    controller: _v[i],
                    onChanged: (_) => _emit(),
                    style: MirrorTheme.sans(fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '数值',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    enabled: widget.enabled,
                    controller: _k[i],
                    onChanged: (_) => _emit(),
                    style: MirrorTheme.sans(fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '标签',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CalloutEditor extends StatefulWidget {
  const _CalloutEditor({required this.block, required this.enabled, required this.onChanged});

  final PostBodyBlock block;
  final bool enabled;
  final ValueChanged<PostBodyBlock> onChanged;

  @override
  State<_CalloutEditor> createState() => _CalloutEditorState();
}

class _CalloutEditorState extends State<_CalloutEditor> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.block.callout?.body ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.block.callout!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          children: [
            for (final v in CalloutVariant.values)
              ChoiceChip(
                label: Text(v.name, style: MirrorTheme.mono(fontSize: 10)),
                selected: c.variant == v,
                onSelected: widget.enabled
                    ? (_) => widget.onChanged(PostBodyBlock.callout(icon: c.icon, variant: v, body: c.body))
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          enabled: widget.enabled,
          maxLines: 3,
          controller: _ctrl,
          onChanged: (t) => widget.onChanged(PostBodyBlock.callout(icon: c.icon, variant: c.variant, body: t)),
          style: MirrorTheme.sans(fontSize: 13, height: 1.5),
          decoration: InputDecoration(
            hintText: '提示或结论…',
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.all(10),
          ),
        ),
      ],
    );
  }
}

class _CompareEditor extends StatefulWidget {
  const _CompareEditor({required this.block, required this.enabled, required this.onChanged});

  final PostBodyBlock block;
  final bool enabled;
  final ValueChanged<PostBodyBlock> onChanged;

  @override
  State<_CompareEditor> createState() => _CompareEditorState();
}

class _CompareEditorState extends State<_CompareEditor> {
  late final TextEditingController _badH;
  late final TextEditingController _bad;
  late final TextEditingController _goodH;
  late final TextEditingController _good;

  @override
  void initState() {
    super.initState();
    final c = widget.block.compare!;
    _badH = TextEditingController(text: c.badTitle);
    _bad = TextEditingController(text: c.bad);
    _goodH = TextEditingController(text: c.goodTitle);
    _good = TextEditingController(text: c.good);
  }

  @override
  void dispose() {
    _badH.dispose();
    _bad.dispose();
    _goodH.dispose();
    _good.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(PostBodyBlock.compare(
      badTitle: _badH.text.trim(),
      bad: _bad.text,
      goodTitle: _goodH.text.trim(),
      good: _good.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    Widget field(TextEditingController c, String hint) => TextField(
          enabled: widget.enabled,
          controller: c,
          onChanged: (_) => _emit(),
          style: MirrorTheme.sans(fontSize: 12.5),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
        );
    return Column(
      children: [
        field(_badH, '左侧标题'),
        const SizedBox(height: 6),
        field(_bad, '改进前'),
        const SizedBox(height: 8),
        field(_goodH, '右侧标题'),
        const SizedBox(height: 6),
        field(_good, '改进后'),
      ],
    );
  }
}

List<PostBodyBlock> composeSegmentsFromBody(String? body) {
  final parsed = PostBodyEnvelopeCodec.parse(body ?? '');
  if (parsed.blocks.isNotEmpty) return parsed.blocks;
  final tail = parsed.markdownTail.trim();
  if (tail.isNotEmpty) return [PostBodyBlock.paragraph(tail)];
  return [const PostBodyBlock.paragraph('')];
}

SharedKbAttachment? composeSharedKbFromBody(String? body) => PostBodyEnvelopeCodec.parse(body ?? '').sharedKb;

String composeBodyPayload({
  required List<PostBodyBlock> segments,
  List<String> coverImageUrls = const [],
  List<String> galleryImageUrls = const [],
  SharedKbAttachment? sharedKb,
}) {
  final tailParts = <String>[];
  for (final url in galleryImageUrls) {
    tailParts.add('![]($url)');
  }
  return PostBodyEnvelopeCodec.encode(
    sharedKb: sharedKb,
    coverImageUrls: coverImageUrls,
    blocks: segments,
    markdownTail: tailParts.join('\n\n'),
  );
}

bool composeHasContent(List<PostBodyBlock> segments, {List<String> galleryUrls = const [], bool hasCover = false}) {
  if (hasCover || galleryUrls.isNotEmpty) return true;
  for (final b in segments) {
    switch (b.type) {
      case PostBodyBlockType.paragraph:
        if (b.text.trim().isNotEmpty) return true;
      case PostBodyBlockType.stats:
        if (b.stats?.any((e) => e.v.isNotEmpty || e.k.isNotEmpty) ?? false) return true;
      case PostBodyBlockType.callout:
        if (b.callout?.body.trim().isNotEmpty ?? false) return true;
      case PostBodyBlockType.compare:
        final c = b.compare;
        if (c != null && (c.bad.trim().isNotEmpty || c.good.trim().isNotEmpty)) return true;
      case PostBodyBlockType.code:
        if ((b.code ?? '').trim().isNotEmpty) return true;
    }
  }
  return false;
}
