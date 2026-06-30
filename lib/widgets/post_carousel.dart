import 'dart:async';

import 'package:flutter/material.dart';
import '../layout/adaptive_layout.dart';
import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';

/// post-details-4.html `.carousel` — 默认 400px 高、自动轮播、圆点、计数、箭头
class PostCarousel extends StatefulWidget {
  const PostCarousel({
    super.key,
    required this.slides,
    this.intervalMs = 3500,
    this.height = 400,
  });

  final List<PostCarouselSlide> slides;
  final int intervalMs;
  final double height;

  @override
  State<PostCarousel> createState() => _PostCarouselState();
}

class PostCarouselSlide {
  const PostCarouselSlide({
    required this.slideNum,
    required this.gradient,
    required this.child,
    this.lightOnDark = true,
    this.fullBleed = false,
  });

  final String slideNum;
  final Gradient gradient;
  final Widget child;
  final bool lightOnDark;
  /// 为 true 时图片铺满轮播区域（不缩在 Center 内）。
  final bool fullBleed;
}

class _PostCarouselState extends State<PostCarousel> {
  late final PageController _page = PageController();
  int _index = 0;
  Timer? _timer;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _startAuto();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  void _startAuto() {
    _timer?.cancel();
    if (widget.slides.length <= 1) return;
    _timer = Timer.periodic(Duration(milliseconds: widget.intervalMs), (_) {
      if (!mounted || _hovering) return;
      _go((_index + 1) % widget.slides.length);
    });
  }

  void _go(int i) {
    setState(() => _index = i);
    _page.animateToPage(i, duration: const Duration(milliseconds: 500), curve: const Cubic(0.32, 0.72, 0, 1));
  }

  void _restartAuto() {
    _timer?.cancel();
    _startAuto();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.slides.length;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: adaptiveAspectFrame(
        context: context,
        phoneHeight: widget.height,
        widthOverHeight: kPostCarouselAspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _page,
              itemCount: total,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                final s = widget.slides[i];
                if (s.fullBleed) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(decoration: BoxDecoration(gradient: s.gradient)),
                      Positioned.fill(child: s.child),
                      Positioned(
                        top: 12,
                        left: 14,
                        child: Text(
                          s.slideNum,
                          style: MirrorTheme.mono(
                            fontSize: 9,
                            letterSpacing: 0.08,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return DecoratedBox(
                  decoration: BoxDecoration(gradient: s.gradient),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          child: Text(
                            s.slideNum,
                            style: MirrorTheme.mono(
                              fontSize: 9,
                              letterSpacing: 0.08,
                              color: s.lightOnDark ? Colors.white70 : MirrorColors.text3,
                            ),
                          ),
                        ),
                        Center(child: s.child),
                      ],
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 12,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${_index + 1} / $total',
                  style: MirrorTheme.mono(fontSize: 10, letterSpacing: 0.04, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(total, (i) {
                  final on = i == _index;
                  return GestureDetector(
                    onTap: () {
                      _go(i);
                      _restartAuto();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      width: on ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: on ? Colors.white : Colors.white.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(on ? 3 : 3),
                      ),
                    ),
                  );
                }),
              ),
            ),
            if (_hovering && total > 1) ...[
              _nav(Icons.chevron_left, Alignment.centerLeft, () {
                _go((_index - 1 + total) % total);
                _restartAuto();
              }),
              _nav(Icons.chevron_right, Alignment.centerRight, () {
                _go((_index + 1) % total);
                _restartAuto();
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _nav(IconData icon, Alignment align, VoidCallback onTap) {
    return Align(
      alignment: align,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
