import 'package:flutter/material.dart';
import '../screens/mirror_screens.dart';
import '../screens/mirror_screens_part2.dart';
import '../screens/post_detail_screen.dart';
import '../screens/mirror_screens_part3.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../widgets/mirror_icon.dart';
import '../widgets/phone_frame.dart';

class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: MirrorColors.bgPage,
          gradient: RadialGradient(
            center: const Alignment(-0.8, -1),
            radius: 0.6,
            colors: [MirrorColors.accent.withValues(alpha: 0.04), Colors.transparent],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _PageHeader()),
            SliverToBoxAdapter(child: _TipBar()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 120),
              sliver: SliverToBoxAdapter(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final cols = w > 1100 ? 3 : (w > 720 ? 2 : 1);
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: cols,
                      mainAxisSpacing: 56,
                      crossAxisSpacing: 32,
                      childAspectRatio: cols == 1 ? 0.42 : 0.48,
                      children: _galleryItems(),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(child: _FooterNote()),
          ],
        ),
      ),
    );
  }

  List<Widget> _galleryItems() => [
        _item(
          PhoneFrame(useHtmlDimensions: true, time: '9:41', child: const WelcomeScreen()),
          '01 / 15', 'Welcome', '启动',
          '入口页强调"自托管"与"陪伴"，引导 30 秒完成灵魂初始化',
        ),
        _item(
          PhoneFrame(useHtmlDimensions: true, time: '9:42', child: const ChatScreen(previewMode: true)),
          '02 / 15', 'Conversation', '与 Mirror',
          '工具调用一行收起，重点回到内容本身',
        ),
        _item(
          PhoneFrame(useHtmlDimensions: true, time: '9:42', child: const SessionsScreen()),
          '03 / 15', 'Messages', '通讯',
          'Mirror 单独成卡置顶，其余按时间排——一眼能扫完',
        ),
        _item(
          PhoneFrame(useHtmlDimensions: true, time: '9:43', child: const HumanChatScreen()),
          '04 / 15', 'Human Chat', '和朋友',
          '和通讯录里的人对话 —— 可互相分享 Soul、Skill、付费 Agent',
        ),
        _item(
          PhoneFrame(useHtmlDimensions: true, time: '9:43', child: const FeedScreen()),
          '05 / 15', 'Plaza', '生态圈',
          '小红书式双列瀑布流。分享 Soul 配置 / Skill 心得 / 模型对比，FAB 发帖',
        ),
        _item(
          PhoneFrame(useHtmlDimensions: true, time: '9:43', child: const PostScreen()),
          '06 / 15', 'Post', '付费内容',
          '付费卡只保留必要元素 —— 标题、价格、解锁按钮、一行社交证明',
        ),
        _item(
          PhoneFrame(useHtmlDimensions: true, time: '9:43', child: const ShareSheetScreen()),
          '07 / 15', 'Share Sheet', '转发浮层',
          '通讯录常用联系人横排 + 外部渠道。底部"分销返佣"把推广做成赚钱机制',
        ),
        _item(
          PhoneFrame(useHtmlDimensions: true, time: '9:44', child: const ContactsScreen()),
          '08 / 15', 'Contacts', '通讯录',
          '按角色徽章分层，关注/互关/推荐三态',
        ),
        _item(
          PhoneFrame(useHtmlDimensions: true, time: '9:44', statusBarLight: true, child: const DriveScreen()),
          '09 / 15', 'Drive', '云盘',
          '用户文件 + Agent 自动同步（SOUL/MEMORY/Skills）',
        ),
        _item(
          PhoneFrame(useHtmlDimensions: true, time: '9:45', child: const SkillsScreen()),
          '10 / 15', 'Skills', '技能库',
          '/slug 风格命名，自动生成标记 + 调用次数',
        ),
        _item(
          PhoneFrame(useHtmlDimensions: true, time: '9:45', child: const SoulScreen()),
          '11 / 15', 'Soul', '灵魂编辑器',
          '把 SOUL.md 拆成结构化字段。可一键分享到生态圈',
        ),
        _item(
          PhoneFrame(useHtmlDimensions: true, time: '9:46', child: const MemoryScreen()),
          '12 / 15', 'Memory', '长时记忆',
          'pin 过条目高亮置顶。tab 切换 灵魂 / 长时 / 画像 三层',
        ),
        _item(
          PhoneFrame(useHtmlDimensions: true, time: '9:46', child: const RoutingScreen()),
          '13 / 15', 'Routing', '模型路由',
          '"任务 → 模型"路由图 + 本月用量与成本',
        ),
        _item(
          PhoneFrame(useHtmlDimensions: true, time: '9:47', child: const CronScreen()),
          '14 / 15', 'Cron', '定时任务',
          '自然语言创建任务 + 周期/渠道/下次运行时间',
        ),
        _item(
          PhoneFrame(useHtmlDimensions: true, time: '9:47', child: const MeScreen()),
          '15 / 15', 'Account', '我的',
          '个人资料、Token 配额、Agent 心智入口与渠道绑定',
        ),
      ];

  Widget _item(Widget phone, String num, String name, String accent, String desc) => Center(
        child: PhoneGalleryItem(phone: phone, num: num, name: name, accent: accent, desc: desc),
      );
}

class _PageHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 80, 32, 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: MirrorColors.text, borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: const MirrorIcon(size: 26),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mirror Mobile', style: MirrorTheme.sans(fontSize: 22, weight: FontWeight.w500, letterSpacing: -0.02)),
                    Text('PROTOTYPE · V0.3 · 15 SCREENS · FLUTTER', style: MirrorTheme.mono(fontSize: 10, letterSpacing: 0.06)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 56),
            const Divider(color: MirrorColors.border),
            const SizedBox(height: 56),
            LayoutBuilder(
              builder: (context, c) {
                if (c.maxWidth > 900) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: 14,
                        child: RichText(
                          text: TextSpan(
                            style: MirrorTheme.sans(fontSize: 58, weight: FontWeight.w400, height: 1.05, letterSpacing: -0.03),
                            children: [
                              const TextSpan(text: 'Talk to your '),
                              TextSpan(text: 'agent', style: MirrorTheme.sans(fontSize: 58, color: MirrorColors.accent, weight: FontWeight.w500, letterSpacing: -0.03)),
                              const TextSpan(text: ',\n'),
                              TextSpan(text: 'share with ', style: MirrorTheme.sans(fontSize: 58, color: MirrorColors.text3, letterSpacing: -0.03)),
                              TextSpan(text: 'friends', style: MirrorTheme.sans(fontSize: 58, color: MirrorColors.accent, weight: FontWeight.w500, letterSpacing: -0.03)),
                              const TextSpan(text: ',\n'),
                              TextSpan(text: 'grow as a ', style: MirrorTheme.sans(fontSize: 58, color: MirrorColors.text3, letterSpacing: -0.03)),
                              TextSpan(text: 'community', style: MirrorTheme.sans(fontSize: 58, color: MirrorColors.accent, weight: FontWeight.w500, letterSpacing: -0.03)),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 80),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('v0.3 把对话做成统一通讯入口——你的 Mirror、通讯录里的朋友、甚至别人的付费 Agent，全在一个列表里。', style: MirrorTheme.sans(fontSize: 14, color: MirrorColors.text2, height: 1.75)),
                            const SizedBox(height: 14),
                            Text('每个界面都减去了多余的标签、徽章和密集元信息。简单优雅是这一版的核心。', style: MirrorTheme.sans(fontSize: 14, color: MirrorColors.text2, height: 1.75)),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Talk to your agent,\nshare with friends,\ngrow as a community.', style: MirrorTheme.sans(fontSize: 32, height: 1.1, letterSpacing: -0.03)),
                    const SizedBox(height: 24),
                    Text('v0.3 统一通讯入口 · 简单优雅', style: MirrorTheme.sans(fontSize: 14, color: MirrorColors.text2, height: 1.75)),
                  ],
                );
              },
            ),
            const SizedBox(height: 72),
            _MetaGrid(),
            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }
}

class _MetaGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cells = [
      ('通讯入口', '1', ' · 人 / AI'),
      ('付费形式', '买断 · ', '订阅'),
      ('设计语言', 'Quiet ', 'Calm'),
      ('屏幕数', '15', ' screens'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: MirrorColors.border,
        border: Border.all(color: MirrorColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, c) {
          final cols = c.maxWidth > 600 ? 4 : 2;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 1, crossAxisSpacing: 1, childAspectRatio: cols == 4 ? 1.6 : 1.4),
            itemCount: cells.length,
            itemBuilder: (_, i) {
              final cell = cells[i];
              return ColoredBox(
                color: MirrorColors.bgApp,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(26, 22, 26, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cell.$1, style: MirrorTheme.mono(fontSize: 10, letterSpacing: 0.06)),
                      const SizedBox(height: 10),
                      RichText(
                        text: TextSpan(
                          style: MirrorTheme.sans(fontSize: 22, weight: FontWeight.w500, letterSpacing: -0.02),
                          children: [
                            if (cell.$2.isNotEmpty) TextSpan(text: cell.$2, style: const TextStyle(color: MirrorColors.accent)),
                            TextSpan(text: cell.$3),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _TipBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: MirrorColors.accentSoft,
            border: Border.all(color: Color(0xFFD9D5FA)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.touch_app_outlined, size: 18, color: MirrorColors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'v0.3 主张「简单而不失优雅」—— 减去 badges、密集元信息和过深的层级，让每屏一眼可读',
                  style: MirrorTheme.sans(fontSize: 13, color: MirrorColors.accentDeep, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 120, 32, 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: const Divider(color: MirrorColors.border),
      ),
    );
  }
}
