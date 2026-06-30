import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/mirror_app_keys.dart';
import 'app/mirror_prototype.dart';
import 'config/api_config.dart';
import 'config/debug_flags.dart';
import 'theme/mirror_colors.dart';
import 'theme/mirror_theme.dart';
import 'services/meeting_foreground_task.dart';
import 'services/meeting_notification_service.dart';
import 'widgets/meeting_recording_overlay.dart';
import 'widgets/network_ninja_host.dart';
import 'widgets/orientation_controller.dart';
import 'widgets/platform_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    MeetingForegroundTask.ensureInitialized();
  }
  await MeetingNotificationService.init();
  _configureSystemUi();
  debugPrint('[Mirror API] baseUrl=${ApiConfig.baseUrl}');
  if (DebugFlags.networkNinjaEnabled) {
    debugPrint('[Mirror] Network Ninja 已启用：左下角黑色「API」按钮可查看抓包');
  } else if (!kDebugMode) {
    debugPrint('[Mirror] 抓包未开启，Release 请加 --dart-define=NETWORK_NINJA=true');
  }
  runApp(const OrientationController(child: MirrorApp()));
}

void _configureSystemUi() {
  if (kIsWeb) return;
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: MirrorColors.bgApp,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  // 方向策略见 OrientationController
}

class MirrorApp extends StatelessWidget {
  const MirrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: mirrorRootNavigatorKey,
      scaffoldMessengerKey: mirrorScaffoldMessengerKey,
      title: 'Mirror',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: MirrorTheme.light(),
      scrollBehavior: const MirrorScrollBehavior(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              child!,
              const MeetingRecordingOverlay(),
            ],
          ),
        );
      },
      home: platformShell(
        child: DebugFlags.networkNinjaEnabled
            ? const NetworkNinjaBootstrap(child: MirrorPrototype())
            : const MirrorPrototype(),
      ),
    );
  }
}
