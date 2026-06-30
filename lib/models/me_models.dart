// 我的页 API 数据模型（与 dt_go /api/v1/me 对齐）。

class MeOverview {
  MeOverview({
    required this.profile,
    required this.quota,
    required this.mind,
    required this.channels,
  });

  final MeProfile profile;
  final MeQuota quota;
  final MeMindSummary mind;
  final List<MeChannel> channels;

  /// 仅用缓存资料占位，等待 overview 接口返回。
  factory MeOverview.profilePlaceholder(MeProfile profile) => MeOverview(
    profile: profile,
    quota: MeQuota.walletPlaceholder(),
    mind: MeMindSummary(
      principleCount: 0,
      tabooCount: 0,
      agentName: 'Athena',
      memoryCount: 0,
      skillCount: 0,
      routingCost: 0,
      cronActive: 0,
    ),
    channels: const [],
  );

  factory MeOverview.fromJson(Map<String, dynamic> j) {
    final ch = (j['channels'] as List<dynamic>? ?? [])
        .map((e) => MeChannel.fromJson(e as Map<String, dynamic>))
        .toList();
    return MeOverview(
      profile: MeProfile.fromJson(j['profile'] as Map<String, dynamic>),
      quota: MeQuota.fromJson(j['quota'] as Map<String, dynamic>),
      mind: MeMindSummary.fromJson(j['mind_summary'] as Map<String, dynamic>),
      channels: ch,
    );
  }
}

class MeProfile {
  MeProfile({
    required this.displayName,
    required this.handle,
    required this.homeUrl,
    required this.avatarLetter,
    required this.following,
    required this.followers,
    required this.notes,
    this.likesReceivedLabel = '0',
    this.avatarUrl = '',
    this.bio = '',
  });

  final String displayName;
  final String handle;
  final String homeUrl;
  final String avatarLetter;
  final String avatarUrl;
  final String bio;
  final int following;
  final int followers;
  final int notes;
  final String likesReceivedLabel;

  factory MeProfile.fromJson(Map<String, dynamic> j) {
    final likes = (j['likes_received'] as num?)?.toInt() ?? 0;
    final likesLabel = j['likes_received_label'] as String?;
    return MeProfile(
      displayName: j['display_name'] as String? ?? '',
      handle: j['handle'] as String? ?? '',
      homeUrl: j['home_url'] as String? ?? '',
      avatarLetter: j['avatar_letter'] as String? ?? '?',
      avatarUrl: j['avatar_url'] as String? ?? '',
      bio: j['bio'] as String? ?? '',
      following: j['following_count'] as int? ?? 0,
      followers: j['follower_count'] as int? ?? 0,
      notes: j['note_count'] as int? ?? 0,
      likesReceivedLabel: (likesLabel != null && likesLabel.isNotEmpty)
          ? likesLabel
          : MeProfile.formatCount(likes),
    );
  }

  static String formatCount(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}w';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  /// 与「我的主页」`GET /feed/users/:id/profile` 统计对齐。
  MeProfile withSocialStats({
    required int following,
    required int followers,
    required int notes,
    required String likesReceivedLabel,
  }) =>
      MeProfile(
        displayName: displayName,
        handle: handle,
        homeUrl: homeUrl,
        avatarLetter: avatarLetter,
        avatarUrl: avatarUrl,
        bio: bio,
        following: following,
        followers: followers,
        notes: notes,
        likesReceivedLabel: likesReceivedLabel,
      );

  Map<String, dynamic> toUpdateJson() => {
    'display_name': displayName,
    'bio': bio,
    'avatar_url': avatarUrl,
  };
}

class MeQuota {
  MeQuota({
    this.balanceYuan = '0.000000',
    this.consumedYuan = '0.000000',
    this.syncStatus = 'pending',
    this.planName,
    this.syncedAt,
    this.tokenUsed,
    this.tokenLimit,
    this.tokenPercent,
  });

  final String balanceYuan;
  final String consumedYuan;
  final String syncStatus;
  final String? planName;
  final String? syncedAt;

  /// Token 明细页字段（`GET /me/token-usage`）；overview 为 null。
  final int? tokenUsed;
  final int? tokenLimit;
  final double? tokenPercent;

  factory MeQuota.walletPlaceholder() => MeQuota();

  factory MeQuota.fromJson(Map<String, dynamic> j) {
    if (j.containsKey('balance_yuan') || j.containsKey('consumed_yuan')) {
      return MeQuota(
        balanceYuan: j['balance_yuan'] as String? ?? '0.000000',
        consumedYuan: j['consumed_yuan'] as String? ?? '0.000000',
        syncStatus: j['sync_status'] as String? ?? 'pending',
        planName: j['plan_name'] as String?,
        syncedAt: j['synced_at'] as String?,
      );
    }
    if (j.containsKey('token_used') || j.containsKey('token_limit')) {
      return MeQuota.fromTokenJson(j);
    }
    return MeQuota(
      balanceYuan: j['balance_yuan'] as String? ?? '0.000000',
      consumedYuan: j['consumed_yuan'] as String? ?? '0.000000',
      syncStatus: j['sync_status'] as String? ?? 'pending',
      planName: j['plan_name'] as String?,
      syncedAt: j['synced_at'] as String?,
    );
  }

  factory MeQuota.fromTokenJson(Map<String, dynamic> j) {
    final used = (j['token_used'] as num?)?.toInt() ?? 0;
    final limit = (j['token_limit'] as num?)?.toInt() ?? 1;
    final p = (j['usage_percent'] as num?)?.toDouble() ?? (used / limit);
    return MeQuota(
      tokenUsed: used,
      tokenLimit: limit,
      tokenPercent: p,
    );
  }

  bool get isWalletMode => tokenUsed == null && tokenLimit == null;

  int get used => tokenUsed ?? 0;
  int get limit => tokenLimit ?? 1;
  double get percent => tokenPercent ?? 0;

  String get usedK => '${(used / 1000).round()}';
  String get limitLabel => limit >= 1000000 ? '${limit ~/ 1000000}M' : '$limit';
  int get percentInt => isWalletMode ? walletPercentInt : (percent * 100).round();

  double get balanceAmount => double.tryParse(balanceYuan) ?? 0;
  double get consumedAmount => double.tryParse(consumedYuan) ?? 0;
  double get walletTotalAmount => balanceAmount + consumedAmount;

  double get walletPercent {
    final total = walletTotalAmount;
    if (total <= 0) return 0;
    return (consumedAmount / total).clamp(0.0, 1.0);
  }

  int get walletPercentInt => (walletPercent * 100).round();

  /// 主数字（钱包为已消耗金额 ¥）
  String get displayUsedMain => isWalletMode
      ? '¥${_formatYuanMain(consumedAmount)}'
      : usedK;

  /// 主数字后缀（token 为 k；金额 ≥1000 时在 ¥ 数字后接 k）
  String get displayUsedSuffix {
    if (!isWalletMode) return 'k';
    return consumedAmount >= 1000 ? 'k' : '';
  }

  /// 总量标签
  String get displayTotalLabel => isWalletMode
      ? '¥${formatYuanCompact(walletTotalAmount)}'
      : limitLabel;

  /// 剩余标签
  String get displayRemainingLabel => isWalletMode
      ? '¥${formatYuanCompact(balanceAmount)}'
      : '${((limit - used) / 1000).round()}k';

  double get displayPercent => isWalletMode ? walletPercent : percent;

  static String formatYuanCompact(double yuan) {
    final abs = yuan.abs();
    if (abs >= 1000000) {
      return '${(yuan / 1000000).toStringAsFixed(1)}M';
    }
    if (abs >= 1000) {
      final k = yuan / 1000;
      return k >= 100 ? '${k.round()}k' : '${k.toStringAsFixed(1)}k';
    }
    if (abs >= 1) {
      return yuan >= 100 ? yuan.round().toString() : yuan.toStringAsFixed(2);
    }
    return yuan.toStringAsFixed(2);
  }

  static String _formatYuanMain(double yuan) {
    if (yuan.abs() >= 1000) {
      final k = yuan / 1000;
      return k >= 100 ? '${k.round()}' : k.toStringAsFixed(1);
    }
    if (yuan.abs() >= 1) {
      return yuan >= 100 ? yuan.round().toString() : yuan.toStringAsFixed(2);
    }
    return yuan.toStringAsFixed(2);
  }

  String get balanceDisplay {
    final v = double.tryParse(balanceYuan);
    if (v == null) return balanceYuan;
    return '¥${v.toStringAsFixed(2)}';
  }

  String get consumedDisplay {
    final v = double.tryParse(consumedYuan);
    if (v == null) return consumedYuan;
    return '¥${v.toStringAsFixed(2)}';
  }
}

class MeMindSummary {
  MeMindSummary({
    required this.principleCount,
    required this.tabooCount,
    required this.agentName,
    required this.memoryCount,
    required this.skillCount,
    required this.routingCost,
    required this.cronActive,
  });

  final int principleCount;
  final int tabooCount;
  final String agentName;
  final int memoryCount;
  final int skillCount;
  final double routingCost;
  final int cronActive;

  factory MeMindSummary.fromJson(Map<String, dynamic> j) {
    final soul = j['soul'] as Map<String, dynamic>? ?? {};
    final mem = j['memory'] as Map<String, dynamic>? ?? {};
    final sk = j['skills'] as Map<String, dynamic>? ?? {};
    final rt = j['routing'] as Map<String, dynamic>? ?? {};
    final cr = j['cron'] as Map<String, dynamic>? ?? {};
    return MeMindSummary(
      principleCount: soul['principle_count'] as int? ?? 0,
      tabooCount: soul['taboo_count'] as int? ?? 0,
      agentName: soul['agent_name'] as String? ?? 'Athena',
      memoryCount: mem['long_term_count'] as int? ?? 0,
      skillCount: sk['total_count'] as int? ?? 0,
      routingCost: (rt['month_cost_usd'] as num?)?.toDouble() ?? 0,
      cronActive: cr['active_count'] as int? ?? 0,
    );
  }

  String get soulSub => '$principleCount 条原则 · $tabooCount 条禁区';
  String get memorySub => '长时 $memoryCount 条';
  String get skillsSub => '$skillCount 个';
  String get routingSub => '本月 \$${routingCost.toStringAsFixed(1)}';
  String get cronSub => '$cronActive 个进行中';
}

class MeChannel {
  MeChannel({required this.label, required this.status});

  final String label;
  final String status;

  factory MeChannel.fromJson(Map<String, dynamic> j) => MeChannel(
    label: j['label'] as String? ?? '',
    status: j['status'] as String? ?? 'disconnected',
  );

  String? get badge => status == 'connected' ? '已连接' : null;
}

class SoulData {
  SoulData({
    required this.agentName,
    required this.tagline,
    required this.identity,
    required this.goal,
    required this.principles,
    required this.taboos,
  });

  final String agentName;
  final String tagline;
  final String identity;
  final String goal;
  final List<String> principles;
  final List<String> taboos;

  factory SoulData.fromJson(Map<String, dynamic> j) => SoulData(
    agentName: j['agent_name'] as String? ?? 'Athena',
    tagline: j['tagline'] as String? ?? '',
    identity: j['identity'] as String? ?? '',
    goal: j['goal'] as String? ?? '',
    principles: (j['principles'] as List<dynamic>? ?? [])
        .map((e) => '$e')
        .toList(),
    taboos: (j['taboos'] as List<dynamic>? ?? []).map((e) => '$e').toList(),
  );

  Map<String, dynamic> toJson() => {
    'agent_name': agentName,
    'tagline': tagline,
    'identity': identity,
    'goal': goal,
    'principles': principles,
    'taboos': taboos,
  };
}

class MemoryDoc {
  MemoryDoc({
    required this.key,
    required this.count,
    required this.limit,
    required this.percent,
  });

  final String key;
  final int count;
  final int limit;
  final double percent;

  factory MemoryDoc.fromJson(Map<String, dynamic> j) => MemoryDoc(
    key: j['doc_key'] as String? ?? '',
    count: j['char_count'] as int? ?? 0,
    limit: j['char_limit'] as int? ?? 0,
    percent: (j['percent'] as num?)?.toDouble() ?? 0,
  );
}

class MemoryItemData {
  MemoryItemData({
    required this.tag,
    required this.content,
    required this.sourceRef,
    required this.relativeLabel,
    required this.pinned,
  });

  final String tag;
  final String content;
  final String sourceRef;
  final String relativeLabel;
  final bool pinned;

  factory MemoryItemData.fromJson(Map<String, dynamic> j) => MemoryItemData(
    tag: j['tag'] as String? ?? '',
    content: j['content'] as String? ?? '',
    sourceRef: j['source_ref'] as String? ?? '',
    relativeLabel: j['relative_label'] as String? ?? '',
    pinned: j['pinned'] == true,
  );
}

class SkillData {
  SkillData({
    required this.slug,
    required this.description,
    required this.categoryTag,
    required this.enabled,
    required this.invokeCount,
    this.displayName,
    this.tokenUsed = 0,
  });

  final String slug;
  final String description;
  final String categoryTag;
  final bool enabled;
  final int invokeCount;
  final String? displayName;
  final int tokenUsed;

  String get name =>
      (displayName != null && displayName!.isNotEmpty) ? displayName! : slug;

  String get tokenUsedLabel {
    if (tokenUsed <= 0) return '0';
    if (tokenUsed >= 1000000)
      return '${(tokenUsed / 1000000).toStringAsFixed(1)}M';
    if (tokenUsed >= 1000) return '${(tokenUsed / 1000).round()}k';
    return '$tokenUsed';
  }

  bool get isSessionCountOnly => slug == 'meeting-minutes';

  String get usageSubtitle => isSessionCountOnly
      ? '$invokeCount 次'
      : '$tokenUsedLabel tokens · $invokeCount 次调用';

  String get usageTrailing => isSessionCountOnly ? '$invokeCount' : tokenUsedLabel;

  factory SkillData.fromJson(Map<String, dynamic> j) => SkillData(
    slug: j['slug'] as String? ?? '',
    description: j['description'] as String? ?? '',
    categoryTag: j['category_tag'] as String? ?? '',
    enabled: j['enabled'] == true,
    invokeCount: j['invoke_count'] as int? ?? 0,
    displayName: j['display_name'] as String?,
    tokenUsed: (j['token_used'] as num?)?.toInt() ?? 0,
  );

  factory SkillData.fromTokenStatJson(Map<String, dynamic> j) => SkillData(
    slug: j['slug'] as String? ?? '',
    description: '',
    categoryTag: '',
    enabled: true,
    invokeCount: j['invoke_count'] as int? ?? 0,
    displayName: j['display_name'] as String?,
    tokenUsed: (j['token_used'] as num?)?.toInt() ?? 0,
  );
}

class TokenUsageEntry {
  TokenUsageEntry({
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    required this.tokens,
    this.amountYuan,
  });

  final String title;
  final String subtitle;
  final String timeLabel;
  final int tokens;
  final double? amountYuan;

  String get tokensLabel {
    if (tokens >= 1000000) return '${(tokens / 1000000).toStringAsFixed(1)}M';
    if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}k';
    return '$tokens';
  }

  String get amountLabel {
    if (amountYuan == null) return '';
    return '-¥${MeQuota.formatYuanCompact(amountYuan!)}';
  }

  factory TokenUsageEntry.fromJson(Map<String, dynamic> j) => TokenUsageEntry(
    title: j['title'] as String? ?? '',
    subtitle: j['subtitle'] as String? ?? '',
    timeLabel: j['time_label'] as String? ?? '',
    tokens: (j['tokens'] as num?)?.toInt() ?? 0,
    amountYuan: (j['amount_yuan'] as num?)?.toDouble(),
  );
}

class TokenUsageBundle {
  TokenUsageBundle({
    required this.quota,
    required this.skills,
    required this.entries,
  });

  final MeQuota quota;
  final List<SkillData> skills;
  final List<TokenUsageEntry> entries;

  factory TokenUsageBundle.fromJson(Map<String, dynamic> j) {
    final skills = (j['skills'] as List<dynamic>? ?? [])
        .map(
          (e) => SkillData.fromTokenStatJson(e as Map<String, dynamic>),
        )
        .toList();
    final entries = (j['entries'] as List<dynamic>? ?? [])
        .map((e) => TokenUsageEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return TokenUsageBundle(
      quota: MeQuota.fromJson(j['quota'] as Map<String, dynamic>? ?? {}),
      skills: skills,
      entries: entries,
    );
  }
}

class RoutingUsageData {
  RoutingUsageData({
    required this.icon,
    required this.name,
    required this.purpose,
    required this.cost,
    required this.green,
  });

  final String icon;
  final String name;
  final String purpose;
  final String cost;
  final bool green;

  factory RoutingUsageData.fromJson(Map<String, dynamic> j) {
    final local = j['is_local'] == true;
    final cost = (j['cost_usd'] as num?)?.toDouble() ?? 0;
    return RoutingUsageData(
      icon: (j['model_label'] as String? ?? 'M')[0].toUpperCase(),
      name: j['model_label'] as String? ?? '',
      purpose: j['task_labels'] as String? ?? '',
      cost: local || cost == 0 ? 'free' : r'$ ${cost.toStringAsFixed(2)}',
      green: local || cost == 0,
    );
  }
}

class CronTaskData {
  CronTaskData({
    required this.name,
    required this.iconKey,
    required this.enabled,
    required this.scheduleLabel,
    required this.cronExpr,
    required this.destination,
  });

  final String name;
  final String iconKey;
  final bool enabled;
  final String scheduleLabel;
  final String cronExpr;
  final String destination;

  factory CronTaskData.fromJson(Map<String, dynamic> j) => CronTaskData(
    name: j['name'] as String? ?? '',
    iconKey: j['icon_key'] as String? ?? 'default',
    enabled: j['enabled'] == true,
    scheduleLabel: j['schedule_label'] as String? ?? '',
    cronExpr: j['cron_expr'] as String? ?? '',
    destination: j['destination'] as String? ?? '',
  );
}
