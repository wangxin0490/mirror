import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/legal/ai_third_party_disclosure.dart';
import 'package:mirror_mobile/legal/mirror_legal_documents.dart';
import 'package:mirror_mobile/widgets/ai_data_consent_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('consent lead sentence names third-party AI companies', () {
    final lead = aiThirdPartyConsentLeadSentence();
    expect(lead, contains('您的数据将被发送至以下第三方 AI 服务提供商'));
    for (final p in kAiThirdPartyProviders) {
      expect(lead, contains(p.companyName));
    }
  });

  test('privacy policy section names third-party AI companies', () {
    final body = aiThirdPartyPrivacyPolicyBody();
    expect(body, contains('共享对象（指名）'));
    for (final p in kAiThirdPartyProviders) {
      expect(body, contains(p.companyName));
    }

    final sections = MirrorLegalDocument.privacyPolicy.sections;
    final shared = sections.firstWhere((s) => s.heading.contains('共享'));
    for (final p in kAiThirdPartyProviders) {
      expect(shared.body, contains(p.companyName));
    }
  });

  testWidgets('AiDataConsentDialog shows named providers before consent', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => AiDataConsentDialog.show(context),
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('第三方 AI 数据处理授权'), findsOneWidget);
    expect(find.text('同意并继续'), findsOneWidget);
    expect(find.text('暂不使用'), findsOneWidget);

    for (final p in kAiThirdPartyProviders) {
      expect(find.textContaining(p.companyName), findsWidgets);
    }
  });
}
