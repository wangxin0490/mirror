import 'package:flutter/material.dart';

import '../api/me_api.dart';
import '../models/me_models.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../widgets/phone_components.dart';

class TokenUsageDetailScreen extends StatefulWidget {
  const TokenUsageDetailScreen({
    super.key,
    required this.quota,
    required this.skills,
    this.onBack,
  });

  final MeQuota quota;
  final List<SkillData> skills;
  final VoidCallback? onBack;

  @override
  State<TokenUsageDetailScreen> createState() => _TokenUsageDetailScreenState();
}

class _TokenUsageDetailScreenState extends State<TokenUsageDetailScreen> {
  late MeQuota _quota = widget.quota;
  late List<SkillData> _skills = widget.skills;
  List<TokenUsageEntry> _entries = const [];
  bool _loading = true;
  bool _loadedFromApi = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bundle = await MeApi.fetchTokenUsage();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (bundle != null) {
        _loadedFromApi = true;
        _quota = bundle.quota;
        _entries = bundle.entries;
      }
    });
  }

  bool get _walletMode => _quota.isWalletMode;

  List<SkillData> get _visibleSkills {
    final skills = _skills.where((s) {
      if (s.isSessionCountOnly) return s.invokeCount > 0;
      return s.tokenUsed > 0;
    }).toList();
    skills.sort((a, b) => b.tokenUsed.compareTo(a.tokenUsed));
    return skills;
  }

  @override
  Widget build(BuildContext context) {
    final skills = _visibleSkills;

    return Column(
      children: [
        MirrorAppBar(
          title: ' Usage',
          accentPart: _walletMode ? '金额用量' : 'TOKEN 消耗',
          onBack: widget.onBack,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            children: [
              _summaryCard(_quota),
              const SectionLabel('按技能统计 · BY SKILL'),
              if (_loading && !_loadedFromApi)
                _emptyHint('加载中…')
              else if (skills.isEmpty)
                _emptyHint('暂无技能消耗记录')
              else
                _skillBreakdownCard(skills),
              const SectionLabel('近期明细 · RECENT'),
              if (_loading && !_loadedFromApi)
                _emptyHint('加载中…')
              else if (_entries.isEmpty)
                _emptyHint('暂无消耗记录')
              else
                _entriesCard(_entries),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(MeQuota q) {
    final p = q.displayPercent.clamp(0.0, 1.0);
    return Container(
      key: const Key('token-usage-summary'),
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MirrorColors.bgApp,
        border: Border.all(color: MirrorColors.borderSoft),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Spacer(),
              Text(
                '${q.percentInt}% 已用',
                style: MirrorTheme.mono(
                  fontSize: 11,
                  color: MirrorColors.text2,
                  weight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: q.displayUsedMain,
                  style: MirrorTheme.sans(
                    fontSize: 34,
                    weight: FontWeight.w700,
                    letterSpacing: -0.03,
                    color: MirrorColors.text,
                  ),
                ),
                if (q.displayUsedSuffix.isNotEmpty)
                  TextSpan(
                    text: q.displayUsedSuffix,
                    style: MirrorTheme.sans(
                      fontSize: 17,
                      weight: FontWeight.w600,
                      color: MirrorColors.text2,
                    ),
                  ),
                TextSpan(
                  text: ' / ${q.displayTotalLabel}',
                  style: MirrorTheme.sans(
                    fontSize: 14,
                    color: MirrorColors.text3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            q.isWalletMode ? '按金额计费 · 账户余额' : '按 Token 消耗计费 · 工具箱各技能独立统计',
            style: MirrorTheme.sans(fontSize: 11, color: MirrorColors.text3),
          ),
          const SizedBox(height: 14),
          _progressBar(p),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '剩余 ${q.displayRemainingLabel}',
                style: MirrorTheme.mono(
                  fontSize: 10,
                  color: MirrorColors.text2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressBar(double percent) {
    return Container(
      height: 10,
      decoration: BoxDecoration(
        color: MirrorColors.accentSoft,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: MirrorColors.accentBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: percent > 0 ? percent : 0,
          child: Container(
            decoration: const BoxDecoration(gradient: MirrorGradients.purple),
          ),
        ),
      ),
    );
  }

  Widget _skillBreakdownCard(List<SkillData> skills) {
    return Container(
      decoration: BoxDecoration(
        color: MirrorColors.bgApp,
        border: Border.all(color: MirrorColors.borderSoft),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < skills.length; i++)
            _skillRow(
              skills[i],
              showDivider: i < skills.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _skillRow(
    SkillData skill, {
    required bool showDivider,
  }) {
    if (skill.isSessionCountOnly) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(bottom: BorderSide(color: MirrorColors.borderSoft))
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                skill.name,
                style: MirrorTheme.sans(
                  fontSize: 13.5,
                  weight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              skill.usageTrailing,
              style: MirrorTheme.mono(
                fontSize: 11,
                color: MirrorColors.accent,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: MirrorColors.borderSoft))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  skill.name,
                  style: MirrorTheme.sans(
                    fontSize: 13.5,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                skill.tokenUsedLabel,
                style: MirrorTheme.mono(
                  fontSize: 11,
                  color: MirrorColors.accent,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${skill.invokeCount} 次调用',
            style: MirrorTheme.mono(fontSize: 10, color: MirrorColors.text3),
          ),
        ],
      ),
    );
  }

  Widget _entriesCard(List<TokenUsageEntry> entries) {
    return Container(
      decoration: BoxDecoration(
        color: MirrorColors.bgApp,
        border: Border.all(color: MirrorColors.borderSoft),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++)
            _entryRow(entries[i], showDivider: i < entries.length - 1),
        ],
      ),
    );
  }

  Widget _entryRow(TokenUsageEntry entry, {required bool showDivider}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: MirrorColors.borderSoft))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: MirrorTheme.sans(
                    fontSize: 13.5,
                    weight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.subtitle,
                  style: MirrorTheme.sans(
                    fontSize: 11.5,
                    color: MirrorColors.text2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.timeLabel,
                  style: MirrorTheme.mono(
                    fontSize: 10,
                    color: MirrorColors.text3,
                  ),
                ),
              ],
            ),
          ),
          if (entry.tokens > 0)
            Text(
              '-${entry.tokensLabel}',
              style: MirrorTheme.mono(
                fontSize: 12,
                color: MirrorColors.text,
                weight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyHint(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            text,
            style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text3),
          ),
        ),
      );
}
