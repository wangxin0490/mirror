import 'package:flutter/material.dart';
import '../theme/mirror_theme.dart';

class MirrorScrollView extends StatelessWidget {
  const MirrorScrollView({
    super.key,
    required this.child,
    this.padding,
    this.controller,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const MirrorScrollBehavior(),
      child: SingleChildScrollView(
        controller: controller,
        padding: padding,
        child: child,
      ),
    );
  }
}

class MirrorListView extends StatelessWidget {
  const MirrorListView({
    super.key,
    required this.children,
    this.padding,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const MirrorScrollBehavior(),
      child: ListView(
        padding: padding,
        children: children,
      ),
    );
  }
}
