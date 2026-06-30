import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/legal/mirror_legal_documents.dart';
import 'package:mirror_mobile/screens/legal_document_screen.dart';
import 'package:mirror_mobile/screens/mirror_screens.dart';
import 'package:mirror_mobile/widgets/login_legal_consent_footer.dart';

void main() {
  testWidgets('Welcome shows legal consent footer', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WelcomeScreen())),
    );
    expect(find.byType(LoginLegalConsentFooter), findsOneWidget);
    final richText = tester.widget<RichText>(
      find.descendant(
        of: find.byType(LoginLegalConsentFooter),
        matching: find.byType(RichText),
      ),
    );
    expect(richText.text.toPlainText(), contains('登录即表示同意'));
    expect(richText.text.toPlainText(), contains('用户协议'));
    expect(richText.text.toPlainText(), contains('隐私政策'));
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
