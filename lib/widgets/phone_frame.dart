import 'package:flutter/material.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';

/// 手机外框尺寸（index.html 为 340×720；交互原型略加宽以减轻「屏窄」感）
const double kPhoneWidth = 375;
const double kPhoneHeight = 794;
/// index.html 画廊展示用原始尺寸
const double kPhoneWidthHtml = 340;
const double kPhoneHeightHtml = 720;
const double kPhoneBezel = 10;
const double kPhoneRadius = 42;
const double kScreenRadius = 34;

class PhoneFrame extends StatelessWidget {
  const PhoneFrame({
    super.key,
    required this.child,
    this.time = '9:41',
    this.statusBarLight = false,
    this.useHtmlDimensions = false,
  });

  final Widget child;
  final String time;
  final bool statusBarLight;
  /// 画廊 15 屏展示时与 index.html `.phone` 340×720 一致
  final bool useHtmlDimensions;

  double get _outerW => useHtmlDimensions ? kPhoneWidthHtml : kPhoneWidth;
  double get _outerH => useHtmlDimensions ? kPhoneHeightHtml : kPhoneHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _outerW,
      height: _outerH,
      decoration: BoxDecoration(
        color: MirrorColors.phoneBezel,
        borderRadius: BorderRadius.circular(kPhoneRadius),
        boxShadow: MirrorShadows.phone,
      ),
      padding: const EdgeInsets.all(kPhoneBezel),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(kScreenRadius),
            child: ColoredBox(
              color: MirrorColors.bgApp,
              child: Column(
                children: [
                  PhoneStatusBar(time: time, light: statusBarLight),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
          Positioned(
            top: 18 - kPhoneBezel,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 84,
                height: 22,
                decoration: BoxDecoration(
                  color: MirrorColors.phoneBezel,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PhoneStatusBar extends StatelessWidget {
  const PhoneStatusBar({super.key, required this.time, this.light = false});

  final String time;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final fg = light ? Colors.white : MirrorColors.text;
    return SizedBox(
      height: 36,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(time, style: MirrorTheme.sans(fontSize: 12, weight: FontWeight.w500, color: fg)),
            Row(
              children: [
                Icon(Icons.signal_cellular_alt, size: 13, color: fg),
                const SizedBox(width: 5),
                Icon(Icons.wifi, size: 13, color: fg),
                const SizedBox(width: 5),
                Icon(Icons.battery_full, size: 13, color: fg),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ScreenLabel extends StatelessWidget {
  const ScreenLabel({
    super.key,
    required this.num,
    required this.name,
    required this.accent,
    required this.desc,
  });

  final String num;
  final String name;
  final String accent;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Column(
        children: [
          Text(num, style: MirrorTheme.mono(fontSize: 10, letterSpacing: 0.08)),
          const SizedBox(height: 6),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: MirrorTheme.sans(fontSize: 18, weight: FontWeight.w500),
              children: [
                TextSpan(text: name),
                TextSpan(text: ' · ', style: MirrorTheme.sans(fontSize: 18, color: MirrorColors.text4, weight: FontWeight.w400)),
                TextSpan(text: accent, style: MirrorTheme.sans(fontSize: 18, color: MirrorColors.accent, weight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(desc, textAlign: TextAlign.center, style: MirrorTheme.sans(fontSize: 12, color: MirrorColors.text3, height: 1.6)),
        ],
      ),
    );
  }
}

class PhoneGalleryItem extends StatelessWidget {
  const PhoneGalleryItem({
    super.key,
    required this.phone,
    required this.num,
    required this.name,
    required this.accent,
    required this.desc,
  });

  final Widget phone;
  final String num;
  final String name;
  final String accent;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        phone,
        const SizedBox(height: 22),
        ScreenLabel(num: num, name: name, accent: accent, desc: desc),
      ],
    );
  }
}
