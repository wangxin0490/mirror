import 'package:flutter/material.dart';
import '../api/feed_api.dart';
import '../api/meeting_api.dart';
import '../api/me_api.dart';
import '../api/product_agent_api.dart';
import '../config/api_config.dart';
import '../config/review_flags.dart';
import '../models/feed_models.dart';
import '../models/meeting_models.dart';
import '../models/me_models.dart';
import '../models/toolbox_agent_models.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../data/mirror_authors.dart';
import '../widgets/mirror_avatar_preview.dart';
import '../widgets/mirror_pressable.dart';
import '../utils/media_url.dart';
import '../utils/toolbox_agent_icon.dart';
import '../widgets/phone_components.dart';

export 'kb/knowledge_base_screen.dart';
export 'product_agent_screens.dart';

// ─── S10 Skills ────────────────────────────────────────────────
class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key, this.onBack, this.onToolTap});

  final VoidCallback? onBack;
  final ValueChanged<String>? onToolTap;

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  List<SkillData> _skills = _fallbackSkills();

  @override
  void initState() {
    super.initState();
    _load();
  }

  static List<SkillData> _fallbackSkills() => [
    SkillData(
      slug: 'smart-assistant',
      displayName: '智能助手',
      description: '通用对话与任务执行，关联个人知识库问答',
      categoryTag: 'general',
      enabled: true,
      invokeCount: 67,
      tokenUsed: 456000,
    ),
    SkillData(
      slug: 'weekly-report',
      displayName: '周报生成',
      description: '从一周会话历史抽取关键产出 → 输出结构化飞书周报',
      categoryTag: 'writing',
      enabled: true,
      invokeCount: 14,
      tokenUsed: 128000,
    ),
    SkillData(
      slug: 'k8s-debug',
      displayName: 'K8s 排错',
      description: 'Pod OOM / CrashLoop 排错流程，串联 kubectl 与日志检索',
      categoryTag: 'devops',
      enabled: true,
      invokeCount: 8,
      tokenUsed: 64000,
    ),
  ];

  Future<void> _load() async {
    final list = await MeApi.fetchSkills();
    if (!mounted || list.isEmpty) return;
    setState(() => _skills = list);
  }

  ChipVariant _chipVariant(String tag) {
    switch (tag) {
      case 'devops':
        return ChipVariant.blue;
      case 'git':
        return ChipVariant.green;
      default:
        return ChipVariant.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MirrorAppBar(
          title: ' Tools',
          accentPart: '工具箱',
          actions: const [Icons.search, Icons.add],
          onBack: widget.onBack,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            children: [
              TabSwitch(
                tabs: ['我的工具 · ${_skills.length}', '市场', '调用记录'],
                activeIndex: 0,
              ),
              for (final s in _skills)
                MirrorPressable(
                  onTap: widget.onToolTap == null
                      ? null
                      : () => widget.onToolTap!(s.name),
                  child: _skill(
                    s.slug,
                    s.enabled,
                    s.description,
                    s.categoryTag,
                    '↑ ${s.invokeCount}',
                    _chipVariant(s.categoryTag),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _skill(
    String slug,
    bool on,
    String desc,
    String tag,
    String uses,
    ChipVariant chipVariant,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      border: Border.all(color: MirrorColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '/',
                    style: MirrorTheme.mono(
                      fontSize: 12,
                      color: MirrorColors.text3,
                      letterSpacing: 0,
                    ),
                  ),
                  TextSpan(
                    text: slug,
                    style: MirrorTheme.mono(
                      fontSize: 12,
                      color: MirrorColors.accent,
                      weight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            _toggle(on),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          desc,
          style: MirrorTheme.sans(
            fontSize: 12,
            color: MirrorColors.text2,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            MirrorChip(tag, variant: chipVariant),
            const Spacer(),
            Text(uses, style: MirrorTheme.mono(fontSize: 10, letterSpacing: 0)),
          ],
        ),
      ],
    ),
  );

  Widget _toggle(bool on) => Container(
    width: 32,
    height: 18,
    decoration: BoxDecoration(
      color: on ? MirrorColors.accent : MirrorColors.border,
      borderRadius: BorderRadius.circular(10),
    ),
    alignment: on ? Alignment.centerRight : Alignment.centerLeft,
    padding: const EdgeInsets.all(2),
    child: Container(
      width: 14,
      height: 14,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    ),
  );
}

// ─── S11 Soul ──────────────────────────────────────────────────
class SoulScreen extends StatefulWidget {
  const SoulScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<SoulScreen> createState() => _SoulScreenState();
}

class _SoulScreenState extends State<SoulScreen> {
  SoulData? _soul;
  late final TextEditingController _identityCtrl;
  late final TextEditingController _goalCtrl;
  List<String> _principles = [];
  List<String> _taboos = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _identityCtrl = TextEditingController();
    _goalCtrl = TextEditingController();
    _applySoul(_defaultSoul());
    _load();
  }

  @override
  void dispose() {
    _identityCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  SoulData _defaultSoul() => SoulData(
    agentName: 'Athena',
    tagline: '清醒、有据、敢于反对。',
    identity: '资深算法工程师助理，专注 LLM/Agent/RL 领域；擅长论文阅读、实验设计与代码评审。',
    goal: '帮我把"研究 → 实验 → 总结"的闭环做快、做准、做有沉淀。',
    principles: ['先给结论再给推理', '不确定就说不确定', '代码必须可执行', '引用必须有出处'],
    taboos: ['禁用 emoji', '禁用客套话'],
  );

  void _applySoul(SoulData s) {
    _soul = s;
    _identityCtrl.text = s.identity;
    _goalCtrl.text = s.goal;
    _principles = List<String>.from(s.principles);
    _taboos = List<String>.from(s.taboos);
  }

  Future<void> _load() async {
    final s = await MeApi.fetchSoul();
    if (!mounted || s == null) return;
    setState(() => _applySoul(s));
  }

  SoulData _draft() => SoulData(
    agentName: _soul?.agentName ?? 'Athena',
    tagline: _soul?.tagline ?? '',
    identity: _identityCtrl.text.trim(),
    goal: _goalCtrl.text.trim(),
    principles: List<String>.from(_principles),
    taboos: List<String>.from(_taboos),
  );

  Future<void> _save() async {
    final draft = _draft();
    if (draft.identity.isEmpty || draft.goal.isEmpty) return;
    setState(() => _saving = true);
    final saved = await MeApi.saveSoul(draft);
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved != null) setState(() => _applySoul(saved));
  }

  Future<void> _promptAddChip({required bool isPrinciple}) async {
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: MirrorColors.overlayDim,
      builder: (ctx) => _SoulAddChipSheet(
        title: isPrinciple ? '添加工作原则' : '添加禁区',
        label: isPrinciple ? 'PRINCIPLES' : 'TABOO',
        hint: isPrinciple ? '例如：先给结论再给推理' : '例如：禁用 emoji',
      ),
    );
    if (text == null || text.isEmpty || !mounted) return;
    setState(() {
      if (isPrinciple) {
        _principles = [..._principles, text];
      } else {
        _taboos = [..._taboos, text];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _soul ?? _defaultSoul();
    return Column(
      children: [
        MirrorAppBar(
          title: ' Soul',
          accentPart: '灵魂',
          onBack: widget.onBack,
          trailing: MirrorPressable(
            onTap: _saving ? null : _save,
            child: Text(
              _saving ? '保存中…' : '保存',
              style: MirrorTheme.mono(
                fontSize: 11,
                color: MirrorColors.accent,
                weight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: MirrorColors.bgSoft,
                  border: Border.all(color: MirrorColors.border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: MirrorColors.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.agentName,
                      style: MirrorTheme.sans(
                        fontSize: 18,
                        weight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        text: '"',
                        style: MirrorTheme.serif(
                          fontSize: 13,
                          color: MirrorColors.text2,
                        ),
                        children: [
                          TextSpan(
                            text: s.tagline,
                            style: MirrorTheme.serif(
                              fontSize: 13,
                              color: MirrorColors.accent,
                            ),
                          ),
                          const TextSpan(text: '"'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _field('我是谁 · IDENTITY', _identityCtrl, required: true),
              _field('一句话目标 · GOAL', _goalCtrl, required: true),
              _chipsField(
                '工作原则 · PRINCIPLES',
                _principles,
                onRemove: (i) => setState(
                  () =>
                      _principles = List<String>.from(_principles)..removeAt(i),
                ),
                onAdd: () => _promptAddChip(isPrinciple: true),
              ),
              _chipsField(
                '禁区 · TABOO',
                _taboos,
                onRemove: (i) => setState(
                  () => _taboos = List<String>.from(_taboos)..removeAt(i),
                ),
                onAdd: () => _promptAddChip(isPrinciple: false),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: MirrorColors.bgSoft,
                  border: Border.all(color: MirrorColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '原始 SOUL.md 编辑',
                      style: MirrorTheme.sans(
                        fontSize: 12,
                        color: MirrorColors.text2,
                      ),
                    ),
                    Text(
                      'ADVANCED →',
                      style: MirrorTheme.mono(
                        fontSize: 10,
                        color: MirrorColors.accent,
                        letterSpacing: 0.04,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    bool required = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (required)
              const Text(
                '+ 添加',
                style: TextStyle(color: MirrorColors.accent, fontSize: 8),
              ),
            Text(
              label,
              style: MirrorTheme.mono(fontSize: 10, letterSpacing: 0.04),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MirrorColors.bgSoft,
            border: Border.all(color: MirrorColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: ctrl,
            maxLines: null,
            style: MirrorTheme.sans(fontSize: 12.5, height: 1.55),
            cursorColor: MirrorColors.accent,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _chipsField(
    String label,
    List<String> chips, {
    required void Function(int) onRemove,
    required VoidCallback onAdd,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: MirrorTheme.mono(fontSize: 10, letterSpacing: 0.04)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ...List.generate(chips.length, (i) {
              final c = chips[i];
              return MirrorPressable(
                onTap: () => onRemove(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: MirrorColors.accentSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$c ×',
                    style: MirrorTheme.sans(
                      fontSize: 11,
                      color: MirrorColors.accentDeep,
                    ),
                  ),
                ),
              );
            }),
            MirrorPressable(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: MirrorColors.border,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '+ 添加',
                  style: MirrorTheme.sans(
                    fontSize: 11,
                    color: MirrorColors.text3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _SoulAddChipSheet extends StatefulWidget {
  const _SoulAddChipSheet({
    required this.title,
    required this.label,
    required this.hint,
  });

  final String title;
  final String label;
  final String hint;

  @override
  State<_SoulAddChipSheet> createState() => _SoulAddChipSheetState();
}

class _SoulAddChipSheetState extends State<_SoulAddChipSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: MirrorColors.bgApp,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.label,
                  style: MirrorTheme.mono(
                    fontSize: 10,
                    color: MirrorColors.text3,
                    letterSpacing: 0.06,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.title,
                  style: MirrorTheme.sans(
                    fontSize: 17,
                    weight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: MirrorColors.bgSoft,
                    border: Border.all(color: MirrorColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _ctrl,
                    autofocus: true,
                    maxLines: 3,
                    style: MirrorTheme.sans(fontSize: 15, height: 1.5),
                    cursorColor: MirrorColors.accent,
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      hintStyle: MirrorTheme.sans(
                        fontSize: 14,
                        color: MirrorColors.text3,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: MirrorPressable(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(color: MirrorColors.border),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '取消',
                            style: MirrorTheme.sans(
                              fontSize: 14,
                              color: MirrorColors.text2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MirrorPressable(
                        onTap: () {
                          final t = _ctrl.text.trim();
                          if (t.isNotEmpty) Navigator.pop(context, t);
                        },
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: MirrorColors.accent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '添加',
                            style: MirrorTheme.sans(
                              fontSize: 14,
                              color: Colors.white,
                            ),
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
    );
  }
}

// ─── S12 Memory ────────────────────────────────────────────────
class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  List<MemoryDoc> _docs = _fallbackDocs();
  List<MemoryItemData> _items = _fallbackItems();
  int _longTermCount = 47;

  @override
  void initState() {
    super.initState();
    _load();
  }

  static List<MemoryDoc> _fallbackDocs() => [
    MemoryDoc(key: 'MEMORY.md', count: 1432, limit: 2200, percent: 0.65),
    MemoryDoc(key: 'USER.md', count: 890, limit: 1375, percent: 0.64),
  ];

  static List<MemoryItemData> _fallbackItems() => [
    MemoryItemData(
      tag: 'env',
      content:
          '用户主力机为 M3 Max MacBook Pro 64GB；Python 项目统一用 uv 管理；偏好 ruff 而非 black',
      sourceRef: '从会话 #312 沉淀',
      relativeLabel: '3 天前',
      pinned: true,
    ),
    MemoryItemData(
      tag: 'project',
      content: '主项目 Athena-RL 部署在内网 K8s，命名空间 ai-prod；GPU 集群在 10.0.4.x',
      sourceRef: '从会话 #289 沉淀',
      relativeLabel: '1 周前',
      pinned: true,
    ),
    MemoryItemData(
      tag: 'lesson',
      content: 'GRPO 在小 batch 下不稳定，用户验证过 batch≥64 才收敛',
      sourceRef: '从会话 #318 沉淀',
      relativeLabel: '昨天',
      pinned: false,
    ),
    MemoryItemData(
      tag: 'preference',
      content: '用户讨厌"不确定"的修饰语堆叠（"可能"、"也许"），坚持给一个概率或不给',
      sourceRef: '从会话 #315 沉淀',
      relativeLabel: '2 天前',
      pinned: false,
    ),
  ];

  Future<void> _load() async {
    final data = await MeApi.fetchMemoryScreen();
    if (!mounted || data == null) return;
    setState(() {
      if (data.docs.isNotEmpty) _docs = data.docs;
      if (data.items.isNotEmpty) _items = data.items;
      _longTermCount = data.longTermCount;
    });
  }

  static String _fmtNum(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final d0 = _docs.isNotEmpty ? _docs[0] : _fallbackDocs()[0];
    final d1 = _docs.length > 1 ? _docs[1] : _fallbackDocs()[1];
    return Column(
      children: [
        MirrorAppBar(
          title: ' Memory',
          accentPart: '记忆',
          actions: const [Icons.search],
          onBack: widget.onBack,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            children: [
              TabSwitch(
                tabs: ['灵魂', '长时 · $_longTermCount', '画像'],
                activeIndex: 1,
              ),
              Row(
                children: [
                  Expanded(
                    child: _memStat(
                      d0.key,
                      _fmtNum(d0.count),
                      '/ ${_fmtNum(d0.limit)}',
                      d0.percent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _memStat(
                      d1.key,
                      _fmtNum(d1.count),
                      '/ ${_fmtNum(d1.limit)}',
                      d1.percent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final it in _items)
                _memCard(
                  it.pinned,
                  it.tag,
                  it.relativeLabel,
                  it.content,
                  it.sourceRef,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _memStat(String k, String v, String total, double pct) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: MirrorColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: MirrorTheme.mono(fontSize: 10, letterSpacing: 0.04)),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: v,
                style: MirrorTheme.sans(
                  fontSize: 20,
                  weight: FontWeight.w500,
                  letterSpacing: -0.02,
                ),
              ),
              TextSpan(
                text: total,
                style: MirrorTheme.sans(
                  fontSize: 13,
                  color: MirrorColors.text3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 3,
            backgroundColor: MirrorColors.bgCard,
            color: MirrorColors.accent,
          ),
        ),
      ],
    ),
  );

  Widget _memCard(
    bool pinned,
    String tag,
    String ts,
    String txt,
    String src,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      color: pinned ? MirrorColors.accentSoft : MirrorColors.bgApp,
      border: Border.all(
        color: pinned ? MirrorColors.accent : MirrorColors.border,
      ),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (pinned)
              const Icon(Icons.push_pin, size: 13, color: MirrorColors.accent),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: pinned ? Colors.white : MirrorColors.blueSoft,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                tag,
                style: MirrorTheme.mono(
                  fontSize: 9,
                  color: MirrorColors.blueText,
                  letterSpacing: 0,
                ),
              ),
            ),
            const Spacer(),
            Text(
              ts,
              style: MirrorTheme.mono(fontSize: 10, letterSpacing: 0.02),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          txt,
          style: MirrorTheme.sans(
            fontSize: 12.5,
            color: pinned ? MirrorColors.accentDeep : MirrorColors.text,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(src, style: MirrorTheme.mono(fontSize: 10, letterSpacing: 0)),
      ],
    ),
  );
}

// ─── S13 Routing ───────────────────────────────────────────────
class RoutingScreen extends StatefulWidget {
  const RoutingScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<RoutingScreen> createState() => _RoutingScreenState();
}

class _RoutingScreenState extends State<RoutingScreen> {
  List<RoutingUsageData> _usage = _fallbackUsage();

  @override
  void initState() {
    super.initState();
    _load();
  }

  static List<RoutingUsageData> _fallbackUsage() => [
    RoutingUsageData(
      icon: 'A',
      name: 'claude-4-opus',
      purpose: '推理 · 代码',
      cost: r'$ 12.40',
      green: false,
    ),
    RoutingUsageData(
      icon: 'O',
      name: 'gpt-4o',
      purpose: '视觉 · 通用',
      cost: r'$ 6.20',
      green: false,
    ),
    RoutingUsageData(
      icon: 'L',
      name: 'llama-3.3 · local',
      purpose: '闲聊 · 草稿',
      cost: 'free',
      green: true,
    ),
  ];

  Future<void> _load() async {
    final list = await MeApi.fetchRoutingUsage();
    if (!mounted || list.isEmpty) return;
    setState(() => _usage = list);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MirrorAppBar(
          title: ' Routing',
          accentPart: '模型',
          actions: const [Icons.settings_outlined],
          onBack: widget.onBack,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Container(
                height: 260,
                decoration: BoxDecoration(
                  color: MirrorColors.bgSoft,
                  border: Border.all(color: MirrorColors.border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: CustomPaint(
                  painter: _RoutingLinesPainter(),
                  child: Stack(
                    children: [
                      _node('推理 · Reasoning', true, 14, 14),
                      _node('代码 · Code', true, 14, 60),
                      _node('长文本 · Long-ctx', true, 14, 106),
                      _node('图像 · Vision', true, 14, 152),
                      _node('闲聊 · Casual', true, 14, 198),
                      _node('claude-4-opus', false, 14, 14),
                      _node('gpt-4o', false, 14, 60),
                      _node('gemini-2.5', false, 14, 106),
                      _node('qwen3-vl', false, 14, 152),
                      _node('llama · local', false, 14, 198, green: true),
                    ],
                  ),
                ),
              ),
              const SectionLabel('本月用量 · USAGE'),
              for (final u in _usage)
                _modelRow(u.icon, u.name, u.purpose, u.cost, green: u.green),
            ],
          ),
        ),
      ],
    );
  }

  Widget _node(
    String t,
    bool task,
    double left,
    double top, {
    bool green = false,
  }) => Positioned(
    left: task ? left : null,
    right: task ? null : 14,
    top: top,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: task ? MirrorColors.blueSoft : MirrorColors.accentSoft,
        border: Border.all(
          color: task ? MirrorColors.blueSoft : MirrorColors.accentSoft,
        ),
        borderRadius: BorderRadius.circular(8),
      ), // .node.task / .node.model
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: task
                  ? MirrorColors.blue
                  : (green ? MirrorColors.green : MirrorColors.accent),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            t,
            style: task
                ? MirrorTheme.sans(fontSize: 11, color: MirrorColors.blueText)
                : MirrorTheme.mono(
                    fontSize: 10.5,
                    color: MirrorColors.accentDeep,
                    weight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
          ),
        ],
      ),
    ),
  );

  Widget _modelRow(
    String icon,
    String nm,
    String p,
    String cost, {
    bool green = false,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      border: Border.all(color: MirrorColors.border),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: green ? MirrorColors.greenSoft : MirrorColors.accentSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            icon,
            style: MirrorTheme.sans(
              fontSize: 13,
              weight: MirrorFontWeight.medium,
              color: green ? MirrorColors.greenText : MirrorColors.accentDeep,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nm,
                style: MirrorTheme.sans(
                  fontSize: 12.5,
                  weight: FontWeight.w500,
                ),
              ),
              Text(
                p,
                style: MirrorTheme.mono(fontSize: 10.5, letterSpacing: 0),
              ),
            ],
          ),
        ),
        Text(
          cost,
          style: MirrorTheme.mono(
            fontSize: 10,
            color: MirrorColors.green,
            weight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ],
    ),
  );
}

class _RoutingLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MirrorColors.accent.withValues(alpha: 0.25)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (final y in [26.0, 72.0, 118.0, 164.0, 210.0]) {
      canvas.drawLine(Offset(120, y), Offset(200, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── S14 Cron ──────────────────────────────────────────────────
class CronScreen extends StatefulWidget {
  const CronScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<CronScreen> createState() => _CronScreenState();
}

class _CronScreenState extends State<CronScreen> {
  List<CronTaskData> _tasks = _fallbackTasks();

  @override
  void initState() {
    super.initState();
    _load();
  }

  static List<CronTaskData> _fallbackTasks() => [
    CronTaskData(
      name: '早间 AI 圈日报',
      iconKey: 'newspaper',
      enabled: true,
      scheduleLabel: '每天',
      cronExpr: '08:00',
      destination: '推送至飞书',
    ),
    CronTaskData(
      name: '周一晨会议题整理',
      iconKey: 'event',
      enabled: true,
      scheduleLabel: '每周一',
      cronExpr: '08:30',
      destination: '推送至本 App',
    ),
    CronTaskData(
      name: '值得关注的会话归档',
      iconKey: 'chat',
      enabled: true,
      scheduleLabel: '每天',
      cronExpr: '23:55',
      destination: '同步至云盘',
    ),
    CronTaskData(
      name: 'GPU 集群异常监控',
      iconKey: 'bolt',
      enabled: false,
      scheduleLabel: '每',
      cronExpr: '5min',
      destination: '异常推送至 TG',
    ),
  ];

  Future<void> _load() async {
    final list = await MeApi.fetchCronTasks();
    if (!mounted || list.isEmpty) return;
    setState(() => _tasks = list);
  }

  int get _activeCount => _tasks.where((t) => t.enabled).length;

  IconData _icon(String key, {bool blue = false}) {
    switch (key) {
      case 'newspaper':
        return Icons.newspaper_outlined;
      case 'chat':
        return Icons.chat_bubble_outline;
      case 'bolt':
        return Icons.bolt_outlined;
      case 'event':
        return Icons.event_outlined;
      default:
        return blue ? Icons.bolt_outlined : Icons.event_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MirrorAppBar(
          title: ' Cron',
          accentPart: '任务',
          actions: const [Icons.add],
          onBack: widget.onBack,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            children: [
              MirrorDashedBorder(
                padding: const EdgeInsets.all(14),
                child: ColoredBox(
                  color: MirrorColors.bgSoft,
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: MirrorColors.accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '用自然语言创建任务',
                              style: MirrorTheme.sans(
                                fontSize: 12.5,
                                color: MirrorColors.text2,
                              ),
                            ),
                            Text(
                              '"每周一上午 9 点把上周 GitHub Star 总结一下…"',
                              style: MirrorTheme.sans(
                                fontSize: 11.5,
                                color: MirrorColors.text3,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SectionLabel('进行中 · ACTIVE · $_activeCount'),
              for (final t in _tasks)
                _task(
                  _icon(t.iconKey, blue: t.iconKey == 'bolt'),
                  t.name,
                  t.enabled,
                  t.scheduleLabel,
                  t.cronExpr,
                  t.destination,
                  blue: t.iconKey == 'bolt',
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _task(
    IconData i,
    String nm,
    bool on,
    String when,
    String cron,
    String dest, {
    bool blue = false,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      border: Border.all(color: MirrorColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: blue ? MirrorColors.blueSoft : MirrorColors.accentSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                i,
                size: 16,
                color: blue ? MirrorColors.blueText : MirrorColors.accentDeep,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                nm,
                style: MirrorTheme.sans(fontSize: 13, weight: FontWeight.w500),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: on ? MirrorColors.greenSoft : MirrorColors.bgCard,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                on ? '● ON' : '○ PAUSED',
                style: MirrorTheme.mono(
                  fontSize: 10,
                  color: on ? MirrorColors.greenText : MirrorColors.text3,
                  letterSpacing: 0.02,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 38),
          child: Text.rich(
            TextSpan(
              style: MirrorTheme.mono(
                fontSize: 11,
                color: MirrorColors.text2,
                letterSpacing: 0,
              ),
              children: [
                TextSpan(text: '$when '),
                TextSpan(
                  text: cron,
                  style: MirrorTheme.mono(
                    fontSize: 11,
                    color: MirrorColors.accent,
                    weight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
                TextSpan(text: ' · $dest'),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

// ─── S15 Me ────────────────────────────────────────────────────
class MeScreen extends StatefulWidget {
  const MeScreen({
    super.key,
    this.onMyHome,
    this.onFollowingList,
    this.onFollowersList,
    this.onEditProfile,
    this.onComposeTap,
    this.onAgentsList,
    this.onQuotaTap,
    this.onAgentTap,
    this.onLogout,
    this.onAccountSettings,
  });

  final VoidCallback? onMyHome;
  final VoidCallback? onFollowingList;
  final VoidCallback? onFollowersList;
  final ValueChanged<MeProfile>? onEditProfile;
  final VoidCallback? onComposeTap;
  final VoidCallback? onAgentsList;
  final void Function(MeQuota quota, List<SkillData> skills)? onQuotaTap;
  final ValueChanged<ToolboxAgentItem>? onAgentTap;
  final VoidCallback? onLogout;
  final VoidCallback? onAccountSettings;

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  MeOverview? _data;
  bool _loading = true;
  List<ToolboxAgentItem> _toolbox = _MeScreenState._fallbackToolbox();

  static List<SkillData> _toolboxAsSkills(List<ToolboxAgentItem> agents) =>
      agents
          .map(
            (a) => SkillData(
              slug: a.agentCode,
              displayName: a.displayName,
              description: a.description,
              categoryTag: a.entryType,
              enabled: a.enabled,
              invokeCount: a.invokeCount,
              tokenUsed: a.tokenUsed,
            ),
          )
          .toList();

  static List<ToolboxAgentItem> _fallbackToolbox() => const [
    ToolboxAgentItem(
      agentCode: 'meeting-minutes',
      displayName: '会议纪要助手',
      description: '会议录音 → 自动生成纪要',
      iconKey: 'mic',
      entryType: 'workflow',
      enabled: true,
      uiConfig: ToolboxUIConfig(hubScreen: 'meeting'),
      invokeCount: 0,
      tokenUsed: 0,
    ),
    ToolboxAgentItem(
      agentCode: 'dg-coupon',
      displayName: '石化优惠券',
      description: '查券、查库存、查状态',
      iconKey: 'local_gas_station',
      entryType: 'chat',
      enabled: true,
      requiredModel: 'hermes-pro',
      defaultModel: 'hermes-pro',
      uiConfig: ToolboxUIConfig(
        renderer: 'dg-coupon',
        placeholder: '问问有哪些优惠券、查库存…',
        welcomeMessage: '你好，我可以帮你查石化优惠券、库存和券状态。',
      ),
      parserConfig: ToolboxParserConfig(structuredBlock: 'dg-coupon'),
      invokeCount: 0,
      tokenUsed: 0,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (ApiConfig.hasCachedProfile) {
      setState(
        () => _data = MeOverview.profilePlaceholder(ApiConfig.cachedProfile),
      );
    }
    await Future.wait([_load(), _loadToolbox()]);
  }

  Future<void> _loadToolbox() async {
    final listFuture = ProductAgentApi.fetchAgents(scope: 'toolbox');
    final meetingFuture = MeetingApi.listSessions(limit: 50);
    final list = await listFuture;
    final meetingPage = await meetingFuture;
    if (!mounted) return;
    final source = list.isNotEmpty ? list : _toolbox;
    if (list.isEmpty && meetingPage == null) return;
    setState(() => _toolbox = _withMeetingSessionCount(source, meetingPage));
  }

  static List<ToolboxAgentItem> _withMeetingSessionCount(
    List<ToolboxAgentItem> agents,
    MeetingListPage? page,
  ) {
    if (page == null) return agents;
    final count = page.totalCount > 0 ? page.totalCount : page.items.length;
    return agents
        .map(
          (agent) => agent.agentCode == 'meeting-minutes'
              ? _copyToolboxAgent(agent, invokeCount: count, tokenUsed: 0)
              : agent,
        )
        .toList();
  }

  static ToolboxAgentItem _copyToolboxAgent(
    ToolboxAgentItem agent, {
    int? invokeCount,
    int? tokenUsed,
  }) {
    return ToolboxAgentItem(
      agentCode: agent.agentCode,
      displayName: agent.displayName,
      description: agent.description,
      iconKey: agent.iconKey,
      entryType: agent.entryType,
      tokenUsed: tokenUsed ?? agent.tokenUsed,
      invokeCount: invokeCount ?? agent.invokeCount,
      enabled: agent.enabled,
      disabledReason: agent.disabledReason,
      requiredModel: agent.requiredModel,
      defaultModel: agent.defaultModel,
      capabilities: agent.capabilities,
      uiConfig: agent.uiConfig,
      parserConfig: agent.parserConfig,
    );
  }

  Future<void> _load() async {
    final overviewFuture = MeApi.fetchOverview();
    final feedFuture = ApiConfig.isLoggedIn && ApiConfig.userId > 0
        ? FeedApi.fetchUserProfile(ApiConfig.userId)
        : Future<FeedUserProfileResponse?>.value(null);
    final o = await overviewFuture;
    final feed = await feedFuture;
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (o != null) {
        var profile = o.profile;
        if (feed != null) {
          final fp = feed.profile;
          final likesLabel = fp.likesReceivedLabel.isNotEmpty
              ? fp.likesReceivedLabel
              : MeProfile.formatCount(fp.likesReceived);
          profile = profile.withSocialStats(
            following: fp.followingCount,
            followers: fp.followerCount,
            notes: fp.postCount,
            likesReceivedLabel: likesLabel,
          );
        }
        _data = MeOverview(
          profile: profile,
          quota: o.quota,
          mind: o.mind,
          channels: o.channels,
        );
        ApiConfig.saveSession(
          token: ApiConfig.accessToken,
          userId: ApiConfig.userId,
          displayName: profile.displayName,
          handle: profile.handle,
          avatarLetter: profile.avatarLetter,
        );
      }
    });
  }

  static IconData _channelIcon(String label) {
    if (label.contains('飞书') || label.contains('Lark')) return Icons.business;
    if (label.contains('微信')) return Icons.chat;
    return Icons.extension_outlined;
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null) {
      return Column(
        children: [
          const MirrorAppBar(title: ' Account', accentPart: '我的'),
          Expanded(
            child: Center(
              child: Text(
                _loading ? '加载中…' : '暂无资料',
                style: MirrorTheme.mono(
                  fontSize: 11,
                  color: MirrorColors.text3,
                ),
              ),
            ),
          ),
        ],
      );
    }
    final p = _data!.profile;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _meProfileHeader(p),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!ReviewFlags.hideBilling)
                      _quotaBox(
                        _data!.quota,
                        onTap: widget.onQuotaTap == null
                            ? null
                            : () => widget.onQuotaTap!(
                                _data!.quota,
                                _toolboxAsSkills(_toolbox),
                              ),
                      )
                    else if (widget.onQuotaTap != null)
                      Container(
                        key: const Key('me-token-usage-entry'),
                        margin: const EdgeInsets.only(bottom: 4),
                        child: _listSection([
                          _meRow(
                            icon: Icons.pie_chart_outline,
                            label: 'Token 使用明细',
                            sub: '按工具箱各技能独立统计',
                            onTap: () => widget.onQuotaTap!(
                              _data!.quota,
                              _toolboxAsSkills(_toolbox),
                            ),
                          ),
                        ]),
                      ),
                    const SectionLabel('我的工具箱 · TOOLBOX'),
                    _toolboxSection(),
                    if (widget.onAccountSettings != null) ...[
                      const SizedBox(height: 16),
                      _listSection([
                        _meRow(
                          icon: Icons.settings_outlined,
                          label: '账号与隐私',
                          sub: '用户协议 · 隐私政策 · 注销账号',
                          onTap: widget.onAccountSettings,
                        ),
                      ]),
                    ],
                    if (widget.onLogout != null) ...[
                      const SizedBox(height: 20),
                      MirrorPressable(
                        onTap: widget.onLogout,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            border: Border.all(color: MirrorColors.border),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '退出登录',
                            style: MirrorTheme.sans(
                              fontSize: 13,
                              color: MirrorColors.text2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _meProfileHeader(MeProfile p) {
    final me = MirrorAuthor.currentUser();
    final letter = p.avatarLetter.isNotEmpty ? p.avatarLetter : me.av;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        key: const Key('me-profile-card'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: MirrorColors.bgApp,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: MirrorColors.borderSoft),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MirrorPressable(
                  onTap: () => openMirrorAvatarPreview(
                    context,
                    letter: letter,
                    colors: me.avatarColors,
                    avatarUrl: p.avatarUrl,
                    title: p.displayName,
                  ),
                  borderRadius: BorderRadius.circular(36),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: MirrorColors.bgApp,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: me.avatarColors.first.withValues(alpha: 0.16),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: _meAvatar(p, letter, me.avatarColors, 64),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.displayName,
                                  style: MirrorTheme.sans(
                                    fontSize: 20,
                                    weight: FontWeight.w700,
                                    letterSpacing: -0.02,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '@${p.handle}',
                                  style: MirrorTheme.sans(
                                    fontSize: 12.5,
                                    color: MirrorColors.text3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          MirrorPressable(
                            onTap: widget.onEditProfile == null
                                ? null
                                : () => widget.onEditProfile!(p),
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: MirrorColors.bgSoft,
                                border: Border.all(
                                  color: MirrorColors.borderSoft,
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                '编辑资料',
                                style: MirrorTheme.sans(
                                  fontSize: 12,
                                  weight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p.bio.isNotEmpty ? p.bio : me.tagline,
                        style: MirrorTheme.sans(
                          fontSize: 12.5,
                          color: MirrorColors.text2,
                          height: 1.45,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: MirrorColors.bgSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MirrorColors.borderSoft),
              ),
              child: Row(
                children: [
                  _meStat(
                    '${p.following}',
                    '关注',
                    onTap: widget.onFollowingList,
                  ),
                  _meStat(
                    '${p.followers}',
                    '粉丝',
                    onTap: widget.onFollowersList,
                  ),
                  _meStat('${p.notes}', '笔记', onTap: widget.onMyHome),
                  _meStat(
                    p.likesReceivedLabel.isNotEmpty
                        ? p.likesReceivedLabel
                        : '0',
                    '获赞',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _meActionCard(
                    Icons.person_outline,
                    '我的主页',
                    onTap: widget.onMyHome,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _meActionCard(
                    Icons.edit_outlined,
                    '发布笔记',
                    onTap: widget.onComposeTap,
                    filled: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _meAvatar(
    MeProfile p,
    String letter,
    List<Color> colors,
    double size,
  ) {
    if (p.avatarUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          resolveMediaUrl(p.avatarUrl),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => AvatarGradient(
            label: letter,
            colors: colors,
            size: size,
            radius: size / 2,
          ),
        ),
      );
    }
    return AvatarGradient(
      label: letter,
      colors: colors,
      size: size,
      radius: size / 2,
    );
  }

  Widget _meDecorCircle(double size, Color color, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: alpha),
    ),
  );

  Widget _meStat(String v, String label, {VoidCallback? onTap}) => Expanded(
    child: MirrorPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Text(
            v,
            style: MirrorTheme.sans(fontSize: 15, weight: FontWeight.w700),
          ),
          Text(
            label,
            style: MirrorTheme.sans(fontSize: 10.5, color: MirrorColors.text3),
          ),
        ],
      ),
    ),
  );

  Widget _meActionCard(
    IconData icon,
    String label, {
    VoidCallback? onTap,
    bool filled = false,
  }) => MirrorPressable(
    onTap: onTap,
    borderRadius: BorderRadius.circular(22),
    child: Container(
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? MirrorColors.text : MirrorColors.bgApp,
        border: Border.all(
          color: filled ? MirrorColors.text : MirrorColors.border,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: filled ? Colors.white : MirrorColors.text2,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: MirrorTheme.sans(
              fontSize: 13,
              weight: FontWeight.w600,
              color: filled ? Colors.white : MirrorColors.text,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _toolboxSection() {
    final preview = _toolbox;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: MirrorColors.bgApp,
        border: Border.all(color: MirrorColors.borderSoft),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < preview.length; i++)
            _toolboxRow(
              preview[i],
              showDivider: i < preview.length - 1,
              onTap: widget.onAgentTap == null
                  ? null
                  : () => widget.onAgentTap!(preview[i]),
            ),
        ],
      ),
    );
  }

  Widget _toolboxRow(
    ToolboxAgentItem s, {
    required bool showDivider,
    VoidCallback? onTap,
  }) => MirrorPressable(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: MirrorColors.borderSoft))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: MirrorColors.accentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              toolboxAgentIcon(s.iconKey),
              size: 20,
              color: MirrorColors.accentDeep,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.displayName,
                  style: MirrorTheme.sans(
                    fontSize: 13.5,
                    weight: FontWeight.w500,
                  ),
                ),
                Text(
                  s.usageSubtitle,
                  style: MirrorTheme.mono(
                    fontSize: 10,
                    color: MirrorColors.text3,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          if (!s.enabled)
            Text(
              '已停用',
              style: MirrorTheme.mono(fontSize: 9, color: MirrorColors.text3),
            )
          else if (!ReviewFlags.hideBilling)
            Text(
              s.usageTrailing,
              style: MirrorTheme.mono(
                fontSize: 11,
                color: MirrorColors.accent,
                weight: FontWeight.w500,
              ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 16, color: MirrorColors.text3),
        ],
      ),
    ),
  );

  Widget _quotaBox(MeQuota q, {VoidCallback? onTap}) => MirrorPressable(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      key: const Key('me-quota-card'),
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
              if (onTap != null) ...[
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: MirrorColors.text3,
                ),
              ],
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
          _quotaProgressBar(q.displayPercent),
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
    ),
  );

  Widget _quotaProgressBar(double percent) {
    final p = percent.clamp(0.0, 1.0);
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
          widthFactor: p > 0 ? p : 0,
          child: Container(
            decoration: const BoxDecoration(gradient: MirrorGradients.purple),
          ),
        ),
      ),
    );
  }

  Widget _listSection(List<Widget> rows) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: MirrorColors.bgApp,
      border: Border.all(color: MirrorColors.borderSoft),
      borderRadius: BorderRadius.circular(16),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(children: rows),
  );

  Widget _meRow({
    required IconData icon,
    required String label,
    String? sub,
    String? badge,
    bool accent = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: MirrorColors.borderSoft)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accent ? MirrorColors.accentSoft : MirrorColors.bgCard,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 16,
                color: accent ? MirrorColors.accent : MirrorColors.text2,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: MirrorTheme.sans(
                      fontSize: 13,
                      weight: FontWeight.w500,
                    ),
                  ),
                  if (sub != null)
                    Text(
                      sub,
                      style: MirrorTheme.mono(fontSize: 10, letterSpacing: 0),
                    ),
                ],
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: MirrorColors.greenSoft,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  badge,
                  style: MirrorTheme.mono(
                    fontSize: 10,
                    color: MirrorColors.greenText,
                    weight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              )
            else
              const Icon(
                Icons.chevron_right,
                size: 16,
                color: MirrorColors.text3,
              ),
          ],
        ),
      ),
    );
  }
}

// KbChatScreen 见 export kb/knowledge_base_screen.dart（API + SSE 流式）

class ToolChatScreen extends StatelessWidget {
  const ToolChatScreen({super.key, required this.toolName, this.onBack});

  final String toolName;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return _SimpleToolChat(
      title: toolName,
      subtitle: '工具对话',
      onBack: onBack,
      hint: '描述你想完成的任务…',
      welcome: '你好，我是 $toolName。请告诉我需要什么帮助？',
    );
  }
}

class _SimpleToolChat extends StatelessWidget {
  const _SimpleToolChat({
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.welcome,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final String hint;
  final String welcome;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: MirrorColors.borderSoft)),
          ),
          child: Row(
            children: [
              MirrorBackButton(onTap: onBack),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: MirrorTheme.sans(
                        fontSize: 15,
                        weight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: MirrorTheme.mono(
                        fontSize: 10,
                        color: MirrorColors.text3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MirrorColors.bgSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    welcome,
                    style: MirrorTheme.sans(fontSize: 13, height: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: MirrorColors.borderSoft)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: MirrorColors.bgSoft,
                    border: Border.all(color: MirrorColors.border),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    hint,
                    style: MirrorTheme.sans(
                      fontSize: 12.5,
                      color: MirrorColors.text3,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: MirrorColors.text,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_upward,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
