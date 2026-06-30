import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../layout/adaptive_layout.dart';

class OrientationController extends StatefulWidget {
  const OrientationController({super.key, required this.child});

  final Widget child;

  @override
  State<OrientationController> createState() => _OrientationControllerState();
}

class _OrientationControllerState extends State<OrientationController> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyOrientations();
  }

  Future<void> _applyOrientations() async {
    if (kIsWeb) return;

    final tablet = isTabletLayout(context);
    if (tablet) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
