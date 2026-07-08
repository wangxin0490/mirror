import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/legal/mirror_legal_documents.dart';
import 'package:mirror_mobile/screens/legal_document_screen.dart';
import 'package:mirror_mobile/screens/mirror_screens.dart';
import 'package:mirror_mobile/widgets/login_legal_consent_footer.dart';

void main() {
  testWidgets('Welcome shows legal consent checkbox', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WelcomeScreen())),
    );
    expect(find.byKey(const Key('login-legal-consent-checkbox')), findsOneWidget);

    await tester.tap(find.byKey(const Key('login-legal-consent-checkbox')));
    await tester.pump();

    final richText = tester
        .widgetList<RichText>(find.byType(RichText))
        .firstWhere((w) => w.text.toPlainText().contains('我已阅读并同意'));
    expect(richText.text.toPlainText(), contains('用户协议'));
    expect(richText.text.toPlainText(), contains('隐私政策'));
  });

  testWidgets('Welcome login without consent shows dialog with decline', (tester) async {
    var loginTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WelcomeScreen(onPhoneLogin: () => loginTapped = true),
        ),
      ),
    );

    await tester.tap(find.text('手机号登录'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-legal-consent-dialog')), findsOneWidget);
    expect(find.byKey(const Key('login-legal-consent-decline')), findsOneWidget);
    expect(loginTapped, isFalse);

    await tester.tap(find.byKey(const Key('login-legal-consent-decline')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-legal-consent-dialog')), findsNothing);
    expect(loginTapped, isFalse);
  });

  testWidgets('Welcome login proceeds after explicit consent', (tester) async {
    var loginTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WelcomeScreen(onPhoneLogin: () => loginTapped = true),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('login-legal-consent-checkbox')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('手机号登录'));
    await tester.pumpAndSettle();

    expect(loginTapped, isTrue);
    expect(find.byKey(const Key('login-legal-consent-dialog')), findsNothing);
  });

  testWidgets('Legal document screen shows privacy sections', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => LegalDocumentScreen.open(
                  context,
                  MirrorLegalDocument.privacyPolicy,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('隐私政策'), findsOneWidget);
    expect(find.text('二、我们收集的信息'), findsOneWidget);
  });
}
