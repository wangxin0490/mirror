import 'package:flutter/material.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';

/// post-details-4.html 轮播 slide 内容
abstract final class PostSlides {
  static Widget quote(String text, {bool onPaper = false}) => Text(
        text,
        textAlign: TextAlign.center,
        style: MirrorTheme.serif(
          fontSize: 22,
          weight: FontWeight.w500,
          height: 1.4,
          style: FontStyle.italic,
          letterSpacing: -0.01,
          color: onPaper ? MirrorColors.text : Colors.white,
        ),
      );

  static Widget soulCode() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text.rich(
          TextSpan(
            style: MirrorTheme.mono(fontSize: 11.5, height: 1.85, color: Colors.white),
            children: [
              TextSpan(text: '# 我是谁\n', style: MirrorTheme.mono(fontSize: 11.5, color: Colors.white54).copyWith(fontStyle: FontStyle.italic)),
              const TextSpan(text: 'IDENTITY:\n  "资深算法工程师助理"\n  "专注 LLM/Agent/RL"\n\n'),
              TextSpan(text: 'GOAL:\n', style: MirrorTheme.mono(fontSize: 11.5, color: const Color(0xFFFFD27A))),
              const TextSpan(text: '  "研究→实验→总结\n  的闭环要快要准\n  要有沉淀。"', style: TextStyle(color: Color(0xFFA5F3D6))),
            ],
          ),
        ),
      );

  static Widget principles({bool onPaper = false}) {
    final items = ['先给结论再给推理', '不确定就说"不确定"', '代码必须可执行', '引用必须有出处'];
    final numBg = onPaper ? MirrorColors.accent : Colors.white.withValues(alpha: 0.18);
    final numFg = onPaper ? Colors.white : Colors.white;
    final textColor = onPaper ? MirrorColors.text : Colors.white;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i < items.length - 1 ? 6 : 0),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: numBg, borderRadius: BorderRadius.circular(6)),
                  child: Text('${i + 1}', style: MirrorTheme.mono(fontSize: 11, weight: FontWeight.w500, color: numFg)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(items[i], style: MirrorTheme.sans(fontSize: 13.5, height: 1.9, color: textColor))),
              ],
            ),
          ),
      ],
    );
  }

  static Widget banlist() => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ban('禁用 emoji'),
          _ban('禁用客套话'),
          _ban('禁用 "我可以为您..."', strike: true),
          _ban('禁用 "也许 / 可能"', strike: true),
        ],
      );

  static Widget _ban(String t, {bool strike = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: RichText(
          text: TextSpan(
            style: MirrorTheme.mono(fontSize: 14, height: 2, weight: FontWeight.w500, color: Colors.white),
            children: [
              const TextSpan(text: '× ', style: TextStyle(color: Color(0xFFFCA5A5), fontWeight: FontWeight.w700)),
              TextSpan(
                text: t,
                style: strike
                    ? const TextStyle(decoration: TextDecoration.lineThrough, decorationColor: Color(0x4DFFFFFF))
                    : null,
              ),
            ],
          ),
        ),
      );

  static Widget baxh() => Row(
        children: [
          Expanded(child: _baxhCol('BEFORE', const Color(0xFFFCA5A5), '好的！我来为您处理这个问题，让我一步步分析…')),
          const SizedBox(width: 12),
          Expanded(child: _baxhCol('AFTER', const Color(0xFFA5F3D6), 'GRPO 三步：免 critic、组内归一化、规则奖励。')),
        ],
      );

  static Widget _baxhCol(String h, Color hColor, String p) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(h, style: MirrorTheme.mono(fontSize: 9.5, letterSpacing: 0.06, color: hColor)),
            const SizedBox(height: 8),
            Text(p, style: MirrorTheme.sans(fontSize: 11.5, height: 1.55, color: Colors.white)),
          ],
        ),
      );

  static Widget alert({required String title, required IconData icon, required List<(String, String)> rows, String? lastValueColor}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 22, color: const Color(0xFFFCA5A5)),
            const SizedBox(width: 6),
            Text(title, style: MirrorTheme.sans(fontSize: 20, weight: FontWeight.w500, color: const Color(0xFFFCA5A5), letterSpacing: -0.02)),
          ],
        ),
        const SizedBox(height: 6),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(r.$1, style: MirrorTheme.mono(fontSize: 12, color: Colors.white, height: 1.85)),
                Text(
                  r.$2,
                  style: MirrorTheme.mono(
                    fontSize: 12,
                    height: 1.85,
                    weight: FontWeight.w500,
                    color: lastValueColor != null && r.$2 == lastValueColor ? MirrorColors.text3 : const Color(0xFFFCA5A5),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static Widget skillTrigger() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(10)),
        child: Text.rich(
          TextSpan(
            style: MirrorTheme.mono(fontSize: 11.5, height: 1.85, color: Colors.white),
            children: [
              TextSpan(text: '# 一行调用\n', style: MirrorTheme.mono(fontSize: 11.5, color: Colors.white54).copyWith(fontStyle: FontStyle.italic)),
              TextSpan(text: r'$ ', style: MirrorTheme.mono(fontSize: 11.5, color: Colors.white)),
              TextSpan(text: '/k8s-debug', style: MirrorTheme.mono(fontSize: 11.5, color: const Color(0xFFFFD27A))),
              const TextSpan(text: ' athena-rl\n\n▸ Skill loaded · v1.2.0\n▸ Loading kubectl ctx\n▸ Reading SOUL.md\n▸ Reading MEMORY.md\n\n'),
              const TextSpan(text: '✓ ready · 0.4s', style: TextStyle(color: Color(0xFFA5F3D6))),
            ],
          ),
        ),
      );

  static Widget timeline(List<(String, String, bool arrow)> items) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final it in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 46, child: Text(it.$1, style: MirrorTheme.mono(fontSize: 9.5, color: Colors.white60))),
                  Text(it.$3 ? '→' : '✓', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: it.$3 ? const Color(0xFFFFD27A) : const Color(0xFFA5F3D6))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(it.$2, style: MirrorTheme.mono(fontSize: 11, color: Colors.white, height: 1.75))),
                ],
              ),
            ),
        ],
      );

  static Widget bigsum({required String label, required String big, required List<(String, String)> stats, String? quote}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: MirrorTheme.mono(fontSize: 10, letterSpacing: 0.08, color: Colors.white70)),
        const SizedBox(height: 6),
        Text(big, style: MirrorTheme.sans(fontSize: 36, weight: FontWeight.w500, letterSpacing: -0.03, color: Colors.white, height: 1)),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0) const SizedBox(width: 24),
              Column(
                children: [
                  Text(stats[i].$2, style: MirrorTheme.mono(fontSize: 16, weight: FontWeight.w500, color: const Color(0xFFA5F3D6))),
                  Text(stats[i].$1, style: MirrorTheme.mono(fontSize: 11, color: Colors.white)),
                ],
              ),
            ],
          ],
        ),
        if (quote != null) ...[
          const SizedBox(height: 18),
          Text(quote, textAlign: TextAlign.center, style: MirrorTheme.serif(fontSize: 13, style: FontStyle.italic, height: 1.5, color: Colors.white.withValues(alpha: 0.85))),
        ],
      ],
    );
  }

  static Widget statCompare() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('WEEKLY REPORT BENCHMARK', style: MirrorTheme.mono(fontSize: 10, letterSpacing: 0.08, color: Colors.white70)),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _statCol('92', '/100', 'CLAUDE-4'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('vs', style: MirrorTheme.serif(fontSize: 22, style: FontStyle.italic, color: Colors.white54)),
              ),
              _statCol('87', '/100', 'GPT-4o'),
            ],
          ),
          const SizedBox(height: 18),
          Text('N = 50 篇 · 双盲评分', style: MirrorTheme.mono(fontSize: 11, color: Colors.white70)),
        ],
      );

  static Widget _statCol(String n, String sub, String lbl) => Column(
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: n, style: MirrorTheme.sans(fontSize: 54, weight: FontWeight.w500, color: Colors.white, letterSpacing: -0.04)),
                TextSpan(text: sub, style: MirrorTheme.sans(fontSize: 18, color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(lbl, style: MirrorTheme.mono(fontSize: 10, letterSpacing: 0.08, color: Colors.white70)),
        ],
      );

  static Widget dimensionBars() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('5 个维度 · 满分 100', style: MirrorTheme.mono(fontSize: 10, letterSpacing: 0.08, color: Colors.white70)),
          const SizedBox(height: 14),
          for (final d in [('结构', 92, 88), ('准确', 95, 90), ('简洁', 96, 78), ('语气', 88, 92), ('速度', 85, 96)])
            _barRow(d.$1, d.$2, d.$3),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legend(const Color(0xFFA5F3D6), 'Claude-4'),
              const SizedBox(width: 14),
              _legend(const Color(0xFFFCA5A5), 'GPT-4o'),
            ],
          ),
        ],
      );

  static Widget _barRow(String lab, int aPct, int bPct) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          children: [
            SizedBox(width: 60, child: Text(lab, style: MirrorTheme.mono(fontSize: 9.5, color: Colors.white.withValues(alpha: 0.85)))),
            Expanded(
              child: Container(
                height: 8,
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                child: Row(
                  children: [
                    Expanded(flex: aPct, child: Container(decoration: BoxDecoration(color: const Color(0xFFA5F3D6), borderRadius: BorderRadius.circular(4)))),
                    if (bPct > 0) const SizedBox(width: 2),
                    Expanded(flex: bPct, child: Container(decoration: BoxDecoration(color: const Color(0xFFFCA5A5), borderRadius: BorderRadius.circular(4)))),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  static Widget _legend(Color c, String t) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          Text(t, style: MirrorTheme.mono(fontSize: 9.5, color: Colors.white.withValues(alpha: 0.8))),
        ],
      );

  static Widget costTable() => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _costRow('50 篇周报 / 月', '', hl: false),
          _costRow('Claude-4', '¥ 240', hl: false),
          _costRow('GPT-4o', '¥ 180', hl: false),
          _costRow('人工撰写', '¥ 6,000', strike: true),
          _costRow('节省', '¥ 5,760', hl: true),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox.shrink(),
                Text('ROI = 24×', style: MirrorTheme.mono(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
              ],
            ),
          ),
        ],
      );

  static Widget _costRow(String l, String r, {bool hl = false, bool strike = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l, style: MirrorTheme.mono(fontSize: 13, color: hl ? const Color(0xFFFFD27A) : Colors.white)),
            Text(
              r,
              style: MirrorTheme.mono(
                fontSize: 13,
                weight: hl ? FontWeight.w500 : FontWeight.w400,
                color: hl ? const Color(0xFFFFD27A) : Colors.white,
              ).copyWith(
                decoration: strike ? TextDecoration.lineThrough : null,
                decorationColor: Colors.white54,
              ),
            ),
          ],
        ),
      );

  static Widget irisAwaken() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(10)),
        child: Text.rich(
          TextSpan(
            style: MirrorTheme.mono(fontSize: 11.5, height: 1.85, color: Colors.white),
            children: [
              TextSpan(text: '# Iris awakens · Auto trigger\n', style: MirrorTheme.mono(fontSize: 11.5, color: Colors.white54).copyWith(fontStyle: FontStyle.italic)),
              const TextSpan(text: '[03:14:08] Alert received\n[03:14:09] Loading SOUL.md\n[03:14:09] Loading MEMORY.md\n[03:14:10] /night-shift activate\n\n'),
              const TextSpan(text: '▸ User asleep · proceed\n▸ Permission scope: triage', style: TextStyle(color: Color(0xFFA5F3D6))),
            ],
          ),
        ),
      );
}
