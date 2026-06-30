import 'package:flutter/material.dart';

import '../screens/post_detail_data.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';

/// 详情 / 发布预览共用的样式块渲染。
class PostBodyBlocksView extends StatelessWidget {
  const PostBodyBlocksView({super.key, required this.blocks});

  final List<PostBodyBlock> blocks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final b in blocks) _BlockWidget(block: b)],
    );
  }
}

class _BlockWidget extends StatelessWidget {
  const _BlockWidget({required this.block});

  final PostBodyBlock block;

  @override
  Widget build(BuildContext context) {
    switch (block.type) {
      case PostBodyBlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(block.text, style: MirrorTheme.sans(fontSize: 13, height: 1.7, letterSpacing: -0.003)),
        );
      case PostBodyBlockType.callout:
        final c = block.callout!;
        return _CalloutView(icon: c.icon, variant: c.variant, body: c.body);
      case PostBodyBlockType.compare:
        final c = block.compare!;
        return _CompareView(badTitle: c.badTitle, bad: c.bad, goodTitle: c.goodTitle, good: c.good);
      case PostBodyBlockType.code:
        return _CodeView(code: block.code!);
      case PostBodyBlockType.stats:
        return _StatsView(items: block.stats!);
    }
  }
}

class _CalloutView extends StatelessWidget {
  const _CalloutView({required this.icon, required this.variant, required this.body});

  final IconData icon;
  final CalloutVariant variant;
  final String body;

  @override
  Widget build(BuildContext context) {
    final (border, bg, fg) = switch (variant) {
      CalloutVariant.amber => (MirrorColors.amber, MirrorColors.amberSoft, const Color(0xFF5D3508)),
      CalloutVariant.green => (MirrorColors.green, MirrorColors.greenSoft, MirrorColors.greenText),
      CalloutVariant.accent => (MirrorColors.accent, MirrorColors.accentSoft, MirrorColors.accentDeep),
    };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border(left: BorderSide(color: border, width: 3)),
        borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 8),
          Expanded(child: Text(body, style: MirrorTheme.sans(fontSize: 12.5, height: 1.6, color: fg))),
        ],
      ),
    );
  }
}

class _CompareView extends StatelessWidget {
  const _CompareView({required this.badTitle, required this.bad, required this.goodTitle, required this.good});

  final String badTitle;
  final String bad;
  final String goodTitle;
  final String good;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: _CompareCol(title: badTitle, text: bad, bg: const Color(0xFFFEE2E2), fg: const Color(0xFF7F1D1D), border: const Color(0xFFFECACA))),
          const SizedBox(width: 8),
          Expanded(child: _CompareCol(title: goodTitle, text: good, bg: MirrorColors.greenSoft, fg: MirrorColors.greenText, border: const Color(0xFFC7E9DA))),
        ],
      ),
    );
  }
}

class _CompareCol extends StatelessWidget {
  const _CompareCol({required this.title, required this.text, required this.bg, required this.fg, required this.border});

  final String title;
  final String text;
  final Color bg;
  final Color fg;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: MirrorTheme.mono(fontSize: 9.5, letterSpacing: 0.06, color: fg.withValues(alpha: 0.7))),
          const SizedBox(height: 5),
          Text(text, style: MirrorTheme.sans(fontSize: 11.5, height: 1.5, color: fg)),
        ],
      ),
    );
  }
}

class _CodeView extends StatelessWidget {
  const _CodeView({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: MirrorColors.bgCard, borderRadius: BorderRadius.circular(8)),
      child: Text(code, style: MirrorTheme.mono(fontSize: 11, height: 1.7, color: MirrorColors.text)),
    );
  }
}

class _StatsView extends StatelessWidget {
  const _StatsView({required this.items});

  final List<({String v, String k})> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: MirrorColors.bgSoft,
                  border: Border.all(color: MirrorColors.borderSoft),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(items[i].v, style: MirrorTheme.sans(fontSize: 18, weight: FontWeight.w500, color: MirrorColors.accent, letterSpacing: -0.02)),
                    const SizedBox(height: 4),
                    Text(items[i].k, style: MirrorTheme.mono(fontSize: 9, letterSpacing: 0.04, color: MirrorColors.text3)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
