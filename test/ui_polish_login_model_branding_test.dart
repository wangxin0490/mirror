import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/config/api_config.dart';
import 'package:mirror_mobile/screens/auth_screens.dart';
import 'package:mirror_mobile/screens/mirror_screens.dart';
import 'package:mirror_mobile/screens/mirror_screens_part3.dart';
import 'package:mirror_mobile/widgets/mirror_icon.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Welcome shows MirrorX branding and slogan', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WelcomeScreen())),
    );
    expect(find.text('MirrorX'), findsOneWidget);
    expect(find.text('Mirror'), findsOneWidget);
    expect(find.text('照见知识、映射能力'), findsOneWidget);
    expect(find.byType(MirrorIcon), findsWidgets);
  });

  testWidgets('Chat model picker changes selected model', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ChatScreen(previewMode: true))));

    expect(find.text('claude-4'), findsOneWidget);

    await tester.tap(find.byKey(const Key('chat-model-picker')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('gpt-4o'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('gpt-4o'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('gpt-4o'), findsWidgets);
  });

  testWidgets('Login is two-step: phone then OTP', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PhoneLoginScreen())),
    );
    expect(find.text('MirrorX'), findsOneWidget);
    expect(find.byKey(const Key('login-phone-field')), findsOneWidget);
    expect(find.text('输入手机号'), findsOneWidget);
    expect(find.byKey(const Key('login-code-step')), findsNothing);

    await tester.enterText(find.byKey(const Key('login-phone-field')), '13800138000');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const Key('login-code-step')), findsOneWidget);
    expect(find.text('输入验证码'), findsOneWidget);
    expect(find.byKey(const Key('login-resend-countdown')), findsOneWidget);
    expect(find.text('60s'), findsOneWidget);
  });

  testWidgets('Me header is compact (no huge whitespace)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await ApiConfig.saveSession(
      token: 't',
      userId: 1,
      displayName: '测试用户',
      handle: 'test',
      avatarLetter: '测',
    );
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MeScreen())),
    );
    await tester.pump();

    final card = find.byKey(const Key('me-profile-card'));
    expect(card, findsOneWidget);

    final size = tester.getSize(card);
    expect(size.height, lessThan(360));
  });
}
