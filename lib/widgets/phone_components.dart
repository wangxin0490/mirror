import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_spacing.dart';
import '../theme/mirror_theme.dart';
import 'mirror_icon.dart';
import 'mirror_pressable.dart';

class MirrorAppBar extends StatelessWidget {
  const MirrorAppBar({
    super.key,
    required this.title,
    this.accentPart,
    this.actions,
    this.trailing,
    this.onBack,
  });

  final String title;
  final String? accentPart;
  final List<IconData>? actions;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: MirrorColors.borderSoft)),
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            MirrorBackButton(onTap: onBack),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: MirrorTheme.sans(fontSize: 17, weight: MirrorFontWeight.medium, letterSpacing: -0.015),
                children: [
                  if (accentPart != null) ...[
                    TextSpan(
                      text: accentPart,
                      style: MirrorTheme.sans(fontSize: 17, weight: MirrorFontWeight.medium, color: MirrorColors.accent, letterSpacing: -0.015),
                    ),
                    TextSpan(
                      text: ' · ',
                      style: MirrorTheme.sans(fontSize: 17, weight: MirrorFontWeight.regular, color: MirrorColors.text3, letterSpacing: -0.015),
                    ),
                  ],
                  TextSpan(text: title),
                ],
              ),
            ),
          ),
          if (trailing != null)
            trailing!
          else if (actions != null)
            Row(
              children: actions!
                  .map((i) => Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: Icon(i, size: 18, color: MirrorColors.text2),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

enum MirrorTab { feed, sessions, knowledge, me }

/// Material FAB 凹槽肩长（默认 15）；略加长以贴近图 1 的缓入 S 形肩。
const _kTabBarNotchLipSpread = 28.0;
const _kTabBarNotchArcInset = 0.5;

/// Tab 栏顶部平滑凹槽（Material 凹槽算法，统一填充与顶边描边）。
class _MirrorTabBarArcPainter extends CustomPainter {
  _MirrorTabBarArcPainter({
    required this.guestCenter,
    required this.guestRadius,
  });

  final Offset guestCenter;
  final double guestRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final host = Offset.zero & size;
    final guest = Rect.fromCircle(
      center: Offset(size.width / 2, guestCenter.dy),
      radius: guestRadius,
    );

    canvas.drawPath(
      _mirrorTabBarFillPath(host, guest),
      Paint()..color = MirrorColors.bgApp,
    );

    canvas.drawPath(
      _mirrorTabBarTopEdgePath(host, guest),
      Paint()
        ..color = MirrorColors.borderSoft
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MirrorTabBarArcPainter oldDelegate) =>
      oldDelegate.guestCenter != guestCenter ||
      oldDelegate.guestRadius != guestRadius;
}

List<Offset> _mirrorTabBarNotchPoints(Rect host, Rect guest) {
  final r = guest.width / 2.0;
  final spread = math.max(_kTabBarNotchLipSpread, r * 0.68);
  final a = -r - _kTabBarNotchArcInset;
  final b = host.top - guest.center.dy;
  final denom = a * a + b * b - r * r;
  if (denom <= 0) return [];

  final n2 = math.sqrt(b * b * r * r * denom);
  final p2xA = ((a * r * r) - n2) / (a * a + b * b);
  final p2xB = ((a * r * r) + n2) / (a * a + b * b);
  final p2yA = math.sqrt(math.max(0, r * r - p2xA * p2xA));
  final p2yB = math.sqrt(math.max(0, r * r - p2xB * p2xB));

  final p = List<Offset>.filled(6, Offset.zero);
  p[0] = Offset(a - spread, b);
  p[1] = Offset(a, b);
  final cmp = b < 0 ? -1.0 : 1.0;
  p[2] = cmp * p2yA > cmp * p2yB ? Offset(p2xA, p2yA) : Offset(p2xB, p2yB);
  p[3] = Offset(-p[2].dx, p[2].dy);
  p[4] = Offset(-p[1].dx, p[1].dy);
  p[5] = Offset(-p[0].dx, p[0].dy);
  for (var i = 0; i < p.length; i += 1) {
    p[i] += guest.center;
  }
  return p;
}

void _addMirrorTabBarNotchTop(Path path, Rect host, List<Offset> p) {
  if (p.length < 6) {
    path
      ..moveTo(host.left, host.top)
      ..lineTo(host.right, host.top);
    return;
  }
  final r = (p[3].dx - p[2].dx).abs() / 2;
  final notchR = Radius.circular(r > 0 ? r : 1.0);

  // 与 CircularNotchedRectangle 相同的三段式：肩二次贝塞尔 + 底圆弧 + 肩二次贝塞尔。
  path
    ..moveTo(host.left, host.top)
    ..lineTo(p[0].dx, p[0].dy)
    ..quadraticBezierTo(p[1].dx, p[1].dy, p[2].dx, p[2].dy)
    ..arcToPoint(p[3], radius: notchR, clockwise: false)
    ..quadraticBezierTo(p[4].dx, p[4].dy, p[5].dx, p[5].dy)
    ..lineTo(host.right, host.top);
}

Path _mirrorTabBarTopEdgePath(Rect host, Rect guest) {
  final path = Path();
  _addMirrorTabBarNotchTop(path, host, _mirrorTabBarNotchPoints(host, guest));
  return path;
}

Path _mirrorTabBarFillPath(Rect host, Rect guest) {
  final path = Path();
  _addMirrorTabBarNotchTop(path, host, _mirrorTabBarNotchPoints(host, guest));
  path
    ..lineTo(host.right, host.bottom)
    ..lineTo(host.left, host.bottom)
    ..close();
  return path;
}

class MirrorTabBar extends StatelessWidget {
  const MirrorTabBar({
    super.key,
    required this.active,
    this.onSelect,
    this.onSmartChatTap,
  });

  final MirrorTab active;
  final ValueChanged<MirrorTab>? onSelect;
  final VoidCallback? onSmartChatTap;

  static const _centerSize = 52.0;
  static const _barHeight = 50.0;
  static const _logoBottom = 12.0;
  static const _logoGap = 4.0;

  double get _notchRadius => _centerSize / 2 + _logoGap;

  /// 与中间 Logo 圆心对齐（Stack 高度 = 栏高）。
  double get _guestCenterDy => _barHeight - _logoBottom - _centerSize / 2;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _barHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _barHeight,
            child: CustomPaint(
              painter: _MirrorTabBarArcPainter(
                guestCenter: Offset(0, _guestCenterDy),
                guestRadius: _notchRadius,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: _sideTab(MirrorTab.feed, Icons.home_outlined, Icons.home, '生态')),
                  Expanded(child: _sideTab(MirrorTab.sessions, Icons.chat_bubble_outline, Icons.chat_bubble, '消息')),
                  SizedBox(width: _centerSize + 2),
                  Expanded(child: _sideTab(MirrorTab.knowledge, Icons.menu_book_outlined, Icons.menu_book, '知识库')),
                  Expanded(child: _sideTab(MirrorTab.me, Icons.person_outline, Icons.person, '我的')),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: _logoBottom,
            child: Center(child: _centerSmartChat()),
          ),
        ],
      ),
    );
  }

  Widget _sideTab(MirrorTab tab, IconData icon, IconData iconActive, String label) {
    final on = tab == active;
    return MirrorPressable(
      onTap: onSelect == null ? null : () => onSelect!(tab),
      borderRadius: BorderRadius.circular(MirrorRadius.r8),
      padding: const EdgeInsets.only(bottom: 2, top: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(on ? iconActive : icon, size: 22, color: on ? MirrorColors.text : MirrorColors.text3),
          const SizedBox(height: 2),
          Text(
            label,
            style: MirrorTheme.sans(
              fontSize: 10,
              weight: on ? FontWeight.w600 : FontWeight.w500,
              color: on ? MirrorColors.text : MirrorColors.text3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _centerSmartChat() {
    return MirrorPressable(
      onTap: onSmartChatTap,
      borderRadius: BorderRadius.circular(_centerSize / 2),
      child: SizedBox(
        width: _centerSize,
        height: _centerSize,
        child: ClipOval(
          child: Image.asset(
            MirrorIcon.tabChatAssetPath,
            width: _centerSize,
            height: _centerSize,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

class MirrorBackButton extends StatelessWidget {
  const MirrorBackButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MirrorPressable(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
      borderRadius: BorderRadius.circular(8),
      child: const Icon(Icons.chevron_left, size: 22, color: MirrorColors.text2),
    );
  }
}

class MirrorChip extends StatelessWidget {
  const MirrorChip(this.label, {super.key, this.variant = ChipVariant.neutral});

  final String label;
  final ChipVariant variant;

  @override
  Widget build(BuildContext context) {
    Color bg = MirrorColors.bgSoft;
    Color fg = MirrorColors.text2;
    Border? border = Border.all(color: MirrorColors.border);

    switch (variant) {
      case ChipVariant.accent:
        bg = MirrorColors.accentSoft;
        fg = MirrorColors.accentDeep;
        border = null;
      case ChipVariant.blue:
        bg = MirrorColors.blueSoft;
        fg = MirrorColors.blueText;
        border = null;
      case ChipVariant.green:
        bg = MirrorColors.greenSoft;
        fg = MirrorColors.greenText;
        border = null;
      case ChipVariant.coral:
        bg = MirrorColors.coralSoft;
        fg = MirrorColors.coralText;
        border = null;
      case ChipVariant.pink:
        bg = MirrorColors.pinkSoft;
        fg = MirrorColors.pinkText;
        border = null;
      case ChipVariant.neutral:
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(MirrorRadius.r6),
        border: border,
      ),
      child: Text(label, style: MirrorTheme.sans(fontSize: 11, color: fg)),
    );
  }
}

enum ChipVariant { neutral, accent, blue, green, coral, pink }

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.onTrailingTap});

  final String text;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(text, style: MirrorTheme.mono(fontSize: 10, letterSpacing: 0.06)),
          const SizedBox(width: 8),
          const Expanded(child: Divider(color: MirrorColors.border, height: 1)),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onTrailingTap,
              behavior: HitTestBehavior.opaque,
              child: Text(trailing!, style: MirrorTheme.mono(fontSize: 9.5, color: MirrorColors.accent, letterSpacing: 0)),
            ),
          ],
        ],
      ),
    );
  }
}

class TabSwitch extends StatelessWidget {
  const TabSwitch({super.key, required this.tabs, required this.activeIndex});

  final List<String> tabs;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: MirrorColors.bgCard,
        borderRadius: BorderRadius.circular(MirrorRadius.r10),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final on = i == activeIndex;
          return Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: on ? MirrorColors.bgApp : Colors.transparent,
                borderRadius: BorderRadius.circular(MirrorRadius.r7),
                boxShadow: on ? const [MirrorShadows.tabOn] : null,
              ),
              alignment: Alignment.center,
              child: Text(
                tabs[i],
                style: MirrorTheme.sans(
                  fontSize: 12,
                  weight: FontWeight.w500,
                  color: on ? MirrorColors.text : MirrorColors.text3,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class AvatarGradient extends StatelessWidget {
  const AvatarGradient({
    super.key,
    required this.label,
    required this.colors,
    this.size = 44,
    this.radius,
  });

  final String label;
  final List<Color> colors;
  final double size;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: MirrorGradients.avatar(colors),
        borderRadius: BorderRadius.circular(radius ?? size / 2),
      ),
      child: Text(
        label,
        style: MirrorTheme.sans(
          fontSize: size * 0.36,
          weight: FontWeight.w500,
          color: Colors.white,
          letterSpacing: -0.02,
        ),
      ),
    );
  }
}

/// 通讯录/会话头像预设（与 HTML class 一致）
abstract final class MirrorAvatars {
  static const lin = [Color(0xFFE84A85), Color(0xFFFF9CC4)];
  static const chen = [Color(0xFF5B47E8), Color(0xFF8B6FFF)];
  static const shen = [Color(0xFFBA7517), Color(0xFFE8AC55)];
  static const zhou = [Color(0xFF1D9E75), Color(0xFF56C9A0)];
  static const group = [Color(0xFF185FA5), Color(0xFF56A8E8)];
  static const bot = [Color(0xFF3C3489), Color(0xFF7C6FE8)];
  static const a1 = chen;
  static const a2 = lin;
  static const a3 = zhou;
  static const a4 = shen;
  static const a5 = [Color(0xFF185FA5), Color(0xFF56A8E8)];
  static const a6 = [Color(0xFF1A1916), Color(0xFF5C5A54)];
}

class MirrorHeroAvatar extends StatelessWidget {
  const MirrorHeroAvatar({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: MirrorColors.text,
            borderRadius: BorderRadius.circular(size * 0.29),
          ),
          alignment: Alignment.center,
          child: MirrorIcon(size: size * 0.46),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: size * 0.29,
            height: size * 0.29,
            decoration: BoxDecoration(
              color: MirrorColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: MirrorColors.bgApp, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// 封面角标（backdrop blur 近似）
class CoverLabel extends StatelessWidget {
  const CoverLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: MirrorColors.labelBackdrop,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: MirrorTheme.mono(fontSize: 9, color: Colors.white, letterSpacing: 0.04)),
    );
  }
}

LinearGradient coverGradient(List<Color> c) => MirrorGradients.avatar(c);

/// 与 CSS `border: 1px dashed var(--border)` 一致
class MirrorDashedBorder extends StatelessWidget {
  const MirrorDashedBorder({
    super.key,
    required this.child,
    this.radius = 12,
    this.color = MirrorColors.border,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double radius;
  final Color color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(color: color, radius: radius),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final len = (dist + 4 < metric.length) ? 4.0 : metric.length - dist;
        canvas.drawPath(metric.extractPath(dist, dist + len), paint);
        dist += 6;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter old) => old.color != color || old.radius != radius;
}
