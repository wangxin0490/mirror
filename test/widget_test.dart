import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Gallery loads with Mirror branding', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MirrorApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('MirrorX'), findsOneWidget);
    expect(find.text('手机号登录'), findsOneWidget);
  });
}
