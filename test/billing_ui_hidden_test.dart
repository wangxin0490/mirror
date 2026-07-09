import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/config/api_config.dart';
import 'package:mirror_mobile/screens/mirror_screens_part3.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MeScreen does not show Token usage entry or quota billing labels',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await ApiConfig.saveSession(
      token: 't',
      userId: 1,
      displayName: '测试用户',
      handle: 'test',
      avatarLetter: '测',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MeScreen(),
        ),
      ),
    );
    await tester.pump();
    // Allow overview load futures to settle or fail without crashing UI.
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Token 使用明细'), findsNothing);
    expect(find.textContaining('按 Token 消耗计费'), findsNothing);
    expect(find.textContaining('账户余额'), findsNothing);
    expect(find.byKey(const Key('me-token-usage-entry')), findsNothing);
  });

  testWidgets('MeScreen toolbox rows do not show token usage numbers',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await ApiConfig.saveSession(
      token: 't',
      userId: 1,
      displayName: '测试用户',
      handle: 'test',
      avatarLetter: '测',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('tokens'), findsNothing);
    expect(find.textContaining('TOKEN'), findsNothing);
  });
}
