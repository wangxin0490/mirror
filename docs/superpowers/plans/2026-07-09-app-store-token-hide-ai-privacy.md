# App Store Token Hide + AI Privacy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permanently hide all Token/usage/billing UI and purchase prompts, and strengthen the first-use third-party AI consent dialog so App Store review can pass 3.1.1 surface checks and 5.1.1/5.1.2 disclosure requirements.

**Architecture:** Remove `ReviewFlags`/`HIDE_BILLING` entirely and hard-hide billing/usage surfaces in product UI while keeping unused detail-screen code. Centralize AI disclosure copy in `ai_third_party_disclosure.dart`, bump consent version to force re-consent, and ensure every AI/ASR send path calls `ensureAiDataConsent` before network I/O.

**Tech Stack:** Flutter/Dart, `flutter_test`, SharedPreferences (`AiConsentStore`), GitHub Actions iOS workflow.

**Spec:** `docs/superpowers/specs/2026-07-09-app-store-token-hide-ai-privacy-design.md`

---

## File map

| File | Responsibility |
|------|----------------|
| `lib/config/review_flags.dart` | Delete after all references removed |
| `.github/workflows/ios-appstore.yml` | Remove `HIDE_BILLING` dart-define |
| `lib/utils/relay_error_messages.dart` | Neutral quota/402 copy (no 充值) |
| `lib/screens/mirror_screens.dart` | Neutral trial/balance/purchase copy; remove billing price UI |
| `lib/screens/mirror_screens_part3.dart` | Me: hide quota + Token entry; toolbox: hide usage numbers; Routing: hide USAGE block |
| `lib/screens/product_agent_screens.dart` | Hide agent `usageSubtitle` |
| `lib/app/mirror_prototype.dart` | Stop wiring `onQuotaTap` → tokenUsage |
| `lib/screens/token_usage_detail_screen.dart` | Remove `ReviewFlags` refs (keep file, unreachable from product) |
| `lib/pages/gallery_page.dart` | Soften Token/用量 gallery blurbs |
| `lib/legal/ai_third_party_disclosure.dart` | Bump consent version; strengthen lead/body copy |
| `lib/widgets/ai_data_consent_dialog.dart` | Show collection-method line; keep named providers + data kinds |
| `lib/legal/mirror_legal_documents.dart` | Update `updatedAt` |
| `test/relay_error_messages_test.dart` | Create: assert no purchase/充值 wording |
| `test/ai_data_consent_test.dart` | Extend: collection method + data kinds + version |
| `test/billing_ui_hidden_test.dart` | Create: Me screen has no Token/余额 entry |

---

### Task 1: Neutralize quota / purchase error copy

**Files:**
- Create: `test/relay_error_messages_test.dart`
- Modify: `lib/utils/relay_error_messages.dart`
- Modify: `lib/screens/mirror_screens.dart` (quota reason map ~1245–1247)

- [ ] **Step 1: Write the failing test**

Create `test/relay_error_messages_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/utils/relay_error_messages.dart';

void main() {
  test('quota and 402 messages do not mention recharge or Token purchase', () {
    final quota = RelayErrorMessages.userMessage(
      upstream: 'insufficient_quota exceeded your current quota 余额不足',
    );
    final status402 = RelayErrorMessages.userMessage(code: '402');

    for (final msg in [quota, status402]) {
      expect(msg, isNot(contains('充值')));
      expect(msg, isNot(contains('购买')));
      expect(msg, isNot(contains('Token')));
      expect(msg, contains('换一个模型'));
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/relay_error_messages_test.dart`

Expected: FAIL because current copy contains `充值`.

- [ ] **Step 3: Update relay error copy**

In `lib/utils/relay_error_messages.dart`, change both quota upstream and `402` branches to:

```dart
'${userErrorPrefix}暂时无法继续，请稍后再试或换一个模型试试。'
```

- [ ] **Step 4: Update chat quota reason map**

In `lib/screens/mirror_screens.dart`, replace:

```dart
'trial_exhausted' => '体验额度已用完，购买 Token 后可继续对话',
'balance_exhausted' => '该模型 Token 已用完，请充值',
'not_purchased' => '请购买该模型 Token 包',
```

with:

```dart
'trial_exhausted' => '体验额度已用完，请稍后再试或换一个模型',
'balance_exhausted' => '该模型暂时无法继续，请稍后再试或换一个模型',
'not_purchased' => '该模型暂时不可用，请换一个模型试试',
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/relay_error_messages_test.dart`

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add test/relay_error_messages_test.dart lib/utils/relay_error_messages.dart lib/screens/mirror_screens.dart
git commit -m "fix(compliance): neutralize quota messages that imply Token purchase"
```

---

### Task 2: Hide Me-screen billing / Token entry and disconnect navigation

**Files:**
- Create: `test/billing_ui_hidden_test.dart`
- Modify: `lib/screens/mirror_screens_part3.dart` (MeScreen build ~1649–1674)
- Modify: `lib/app/mirror_prototype.dart` (`onQuotaTap` wiring ~645–652)

- [ ] **Step 1: Write the failing widget test**

Create `test/billing_ui_hidden_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_mobile/screens/mirror_screens_part3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MeScreen does not show Token usage entry or quota billing labels',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MeScreen()),
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
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/billing_ui_hidden_test.dart`

Expected: FAIL — current `hideBilling=true` branch still shows `Token 使用明细` / `me-token-usage-entry`.

- [ ] **Step 3: Remove Me billing UI blocks**

In `lib/screens/mirror_screens_part3.dart` `_MeScreenState.build`, delete the entire block:

```dart
if (!ReviewFlags.hideBilling)
  _quotaBox(...)
else if (widget.onQuotaTap != null)
  Container(key: const Key('me-token-usage-entry'), ...)
```

Leave the next widgets (`SectionLabel('我的工具箱 · TOOLBOX')`, etc.) intact. Keep `onQuotaTap` parameter on `MeScreen` for now (unused) or remove it in the same edit if the analyzer complains — prefer removing the parameter and all call-site wiring in Step 4.

Also remove any `import '../config/review_flags.dart';` from this file if no longer needed after Task 3/4 (if still needed for toolbox trailing, leave until Task 3).

- [ ] **Step 4: Disconnect product navigation to TokenUsageDetailScreen**

In `lib/app/mirror_prototype.dart`, remove `onQuotaTap: (quota, skills) { ... }` from `MeScreen(...)`. Leave `PrototypeRoute.tokenUsage` case and `TokenUsageDetailScreen` file in place (unreachable from Me).

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/billing_ui_hidden_test.dart`

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add test/billing_ui_hidden_test.dart lib/screens/mirror_screens_part3.dart lib/app/mirror_prototype.dart
git commit -m "fix(compliance): hide Me token usage entry and disconnect navigation"
```

---

### Task 3: Hide toolbox / agent Token usage numbers

**Files:**
- Modify: `lib/screens/mirror_screens_part3.dart` (toolbox row ~2080–2104)
- Modify: `lib/screens/product_agent_screens.dart` (agent list subtitle ~123–129)

- [ ] **Step 1: Write failing assertions into billing UI test**

Append to `test/billing_ui_hidden_test.dart`:

```dart
  test('toolbox usage subtitle containing tokens is not shown in product agent list copy helpers', () {
    // Guardrail: product UI must not render strings that include "tokens".
    // Concrete widget coverage is in MeScreen toolbox rows after load; this
    // documents the forbidden pattern for reviewers of the change.
    const forbidden = 'tokens ·';
    expect(forbidden, isNot(contains('充值')));
  });
```

Prefer a stronger check if easy: after pumping `MeScreen`, assert `find.textContaining('tokens')` findsNothing once toolbox fallback data is visible. Fallback toolbox in `_MeScreenState._fallbackToolbox()` includes `tokenUsed` values — after Step 3 those must not appear as `tokens` text.

Replace the weak helper test above with:

```dart
  testWidgets('MeScreen toolbox rows do not show token usage text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MeScreen())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('tokens'), findsNothing);
    expect(find.textContaining('TOKEN'), findsNothing);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/billing_ui_hidden_test.dart`

Expected: FAIL if fallback toolbox still renders `usageSubtitle` with `tokens`.

- [ ] **Step 3: Stop rendering usage subtitle/trailing in Me toolbox rows**

In `lib/screens/mirror_screens_part3.dart` toolbox row builder, remove the `Text(s.usageSubtitle, ...)` widget and the `else if (!ReviewFlags.hideBilling) Text(s.usageTrailing, ...)` branch. Keep display name, enabled/disabled label, and chevron.

- [ ] **Step 4: Stop rendering usage subtitle in product agent list**

In `lib/screens/product_agent_screens.dart`, remove the `Text(a.usageSubtitle, ...)` under `a.displayName` (or replace with `a.description` only if description is already shown elsewhere — do **not** substitute token text). Prefer removing the subtitle line entirely if it only showed usage.

- [ ] **Step 5: Run tests**

Run: `flutter test test/billing_ui_hidden_test.dart`

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add test/billing_ui_hidden_test.dart lib/screens/mirror_screens_part3.dart lib/screens/product_agent_screens.dart
git commit -m "fix(compliance): hide toolbox and agent token usage numbers"
```

---

### Task 4: Remove ReviewFlags switch and CI dart-define

**Files:**
- Delete: `lib/config/review_flags.dart`
- Modify: `.github/workflows/ios-appstore.yml` (remove line with `HIDE_BILLING`)
- Modify: `lib/screens/mirror_screens.dart` (~3258 billing price)
- Modify: `lib/screens/token_usage_detail_screen.dart` (remove ReviewFlags usage)
- Modify: any remaining files still importing `review_flags.dart`

- [ ] **Step 1: Find remaining references**

Run: `rg -n "ReviewFlags|HIDE_BILLING|review_flags" -g "*.dart" -g "*.yml"`

Expected hits before cleanup: `mirror_screens.dart`, `token_usage_detail_screen.dart`, `mirror_screens_part3.dart` (if any left), `ios-appstore.yml`, `review_flags.dart`.

- [ ] **Step 2: Hard-hide remaining billing UI gated by ReviewFlags**

In `lib/screens/mirror_screens.dart` Soul/import card (~3258), delete the `if (!ReviewFlags.hideBilling) Text('¥12', ...)` widget so price never shows; keep `一键导入 →`.

In `lib/screens/token_usage_detail_screen.dart`, replace ReviewFlags-dependent getters with non-billing defaults that keep the orphan screen compiling:

```dart
bool get _walletMode => false;
bool get _showSummaryCard => !_quota.isWalletMode;
```

Remove `import '../config/review_flags.dart';` from that file.

- [ ] **Step 3: Remove CI define and delete ReviewFlags**

In `.github/workflows/ios-appstore.yml`, delete:

```yaml
args+=(--dart-define=HIDE_BILLING=true)
```

Delete `lib/config/review_flags.dart`.

- [ ] **Step 4: Verify no references remain**

Run: `rg -n "ReviewFlags|HIDE_BILLING|review_flags" -g "*.dart" -g "*.yml"`

Expected: no matches.

Run: `flutter analyze lib test`

Expected: no errors related to missing `ReviewFlags`.

- [ ] **Step 5: Commit**

```bash
git add -A lib/config/review_flags.dart lib/screens/mirror_screens.dart lib/screens/token_usage_detail_screen.dart lib/screens/mirror_screens_part3.dart .github/workflows/ios-appstore.yml
git commit -m "chore(compliance): remove HIDE_BILLING switch; permanently hide billing UI"
```

---

### Task 5: Hide Routing USAGE block and soften gallery copy

**Files:**
- Modify: `lib/screens/mirror_screens_part3.dart` (`RoutingScreen` ~1034–1036)
- Modify: `lib/pages/gallery_page.dart` (~121, ~131)

- [ ] **Step 1: Remove USAGE section from RoutingScreen**

Delete:

```dart
const SectionLabel('本月用量 · USAGE'),
for (final u in _usage)
  _modelRow(u.icon, u.name, u.purpose, u.cost, green: u.green),
```

Keep the routing graph above. Optionally leave `_usage` / `_load` unused for now; if analyzer warns, prefix with ignore or remove dead fields in the same edit (`_usage`, `_fallbackUsage`, `_load`, `_modelRow` only if unused).

- [ ] **Step 2: Soften gallery blurbs**

In `lib/pages/gallery_page.dart`, change Token/用量 marketing lines to non-billing wording, e.g.:

```dart
'"任务 → 模型"路由图',
'个人资料、Agent 心智入口与渠道绑定',
```

- [ ] **Step 3: Analyze**

Run: `flutter analyze lib/screens/mirror_screens_part3.dart lib/pages/gallery_page.dart`

Expected: no errors (fix unused-member warnings if any).

- [ ] **Step 4: Commit**

```bash
git add lib/screens/mirror_screens_part3.dart lib/pages/gallery_page.dart
git commit -m "fix(compliance): hide routing usage block and soften gallery copy"
```

---

### Task 6: Strengthen AI consent disclosure + bump consent version

**Files:**
- Modify: `lib/legal/ai_third_party_disclosure.dart`
- Modify: `lib/widgets/ai_data_consent_dialog.dart`
- Modify: `lib/legal/mirror_legal_documents.dart`
- Modify: `test/ai_data_consent_test.dart`

- [ ] **Step 1: Extend failing tests**

Update `test/ai_data_consent_test.dart` to also assert:

```dart
test('consent lead mentions collection is user-initiated', () {
  final lead = aiThirdPartyConsentLeadSentence();
  expect(lead, contains('主动'));
});

test('privacy policy body includes collection method and data kinds', () {
  final body = aiThirdPartyPrivacyPolicyBody();
  expect(body, contains('收集方式'));
  expect(body, contains('会话上下文'));
  expect(body, contains('会议录音'));
});

testWidgets('AiDataConsentDialog lists data kinds and collection method', (tester) async {
  // open dialog as existing test does
  expect(find.textContaining('可能发送的数据包括'), findsOneWidget);
  expect(find.textContaining('主动输入、上传、录制或选择发送'), findsOneWidget);
  expect(find.textContaining('您输入的文字、图片、文件与语音'), findsOneWidget);
});
```

Also assert consent version constant:

```dart
test('consent version bumped for re-authorization', () {
  expect(kAiThirdPartyConsentVersion, greaterThanOrEqualTo(3));
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/ai_data_consent_test.dart`

Expected: FAIL on version (>=3) and/or missing collection-method UI line.

- [ ] **Step 3: Strengthen disclosure copy and bump version**

In `lib/legal/ai_third_party_disclosure.dart`:

```dart
const kAiThirdPartyConsentVersion = 3;

String aiThirdPartyConsentLeadSentence() {
  final names = kAiThirdPartyProviders.map((p) => p.companyName).join('、');
  return '使用 AI 对话、知识库问答、语音输入、会议录音与纪要等功能时，'
      '您主动输入、上传、录制或发送的内容将被发送至以下第三方 AI 服务提供商：$names。'
      '具体由您所选模型或功能决定实际接收方。';
}
```

Keep `aiThirdPartyPrivacyPolicyBody()` content aligned (already has 收集方式 / 数据种类); tighten wording only if tests require.

In `lib/widgets/ai_data_consent_dialog.dart`, after the data-kinds list and before the consent footer, add:

```dart
const SizedBox(height: 12),
Text('收集方式：', style: MirrorTheme.sans(fontSize: 13, weight: FontWeight.w600)),
const SizedBox(height: 6),
Text(
  '仅在您主动输入、上传、录制或选择发送时收集并发送上述数据。',
  style: MirrorTheme.sans(fontSize: 13, height: 1.45, color: MirrorColors.text2),
),
```

In `lib/legal/mirror_legal_documents.dart`:

```dart
String get updatedAt => '2026年7月9日';
```

Also update the privacy policy contact section date string if it hardcodes `2026年7月8日`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/ai_data_consent_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/legal/ai_third_party_disclosure.dart lib/widgets/ai_data_consent_dialog.dart lib/legal/mirror_legal_documents.dart test/ai_data_consent_test.dart
git commit -m "feat(compliance): strengthen AI third-party consent disclosure and bump version"
```

---

### Task 7: Audit AI entry points for ensureAiDataConsent

**Files:**
- Verify (modify only if missing):  
  `lib/screens/mirror_screens.dart`  
  `lib/screens/kb/knowledge_base_screen.dart`  
  `lib/screens/meeting/meeting_hub_screen.dart`  
  `lib/screens/product_agent_screens.dart`  
  `lib/screens/dg_coupon_chat_screen.dart`  
- Optionally add: `test/ai_consent_entrypoints_test.dart` (source-scan style) if useful

- [ ] **Step 1: Inventory send/ASR paths**

Run:

```bash
rg -n "ensureAiDataConsent|AsrClient\.|AgentSse|sendMessage|_send\(|transcribe|openMeetingVoice|openKbVoice" lib/screens lib/widgets lib/services -g "*.dart"
```

Confirm every user-triggered AI/ASR network path awaits `ensureAiDataConsent` **before** the request.

Known required sites (must remain present):

| Location | Action |
|----------|--------|
| `mirror_screens.dart` | chat send + voice input |
| `knowledge_base_screen.dart` | KB ask + voice import + voice input |
| `meeting_hub_screen.dart` | start recording + upload audio |
| `product_agent_screens.dart` | agent send |
| `dg_coupon_chat_screen.dart` | coupon agent send |

- [ ] **Step 2: Patch any missing gate**

If a path sends user content to AI/ASR without consent, add at the top of that method:

```dart
final consented = await ensureAiDataConsent(context);
if (!consented || !mounted) return;
```

Import: `package:mirror_mobile/widgets/ai_data_consent_dialog.dart` (or relative `../widgets/ai_data_consent_dialog.dart`).

- [ ] **Step 3: Add a lightweight source guard test (optional but recommended)**

Create `test/ai_consent_entrypoints_test.dart`:

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('critical AI screens reference ensureAiDataConsent', () {
    const files = [
      'lib/screens/mirror_screens.dart',
      'lib/screens/kb/knowledge_base_screen.dart',
      'lib/screens/meeting/meeting_hub_screen.dart',
      'lib/screens/product_agent_screens.dart',
      'lib/screens/dg_coupon_chat_screen.dart',
    ];
    for (final path in files) {
      final src = File(path).readAsStringSync();
      expect(src.contains('ensureAiDataConsent'), isTrue, reason: path);
    }
  });
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/ai_data_consent_test.dart test/ai_consent_entrypoints_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/screens test/ai_consent_entrypoints_test.dart
git commit -m "fix(compliance): ensure all AI entry points require third-party consent"
```

(If no code changes beyond the new test, commit the test alone.)

---

### Task 8: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Run focused compliance tests**

```bash
flutter test test/relay_error_messages_test.dart test/billing_ui_hidden_test.dart test/ai_data_consent_test.dart test/ai_consent_entrypoints_test.dart
```

Expected: all PASS

- [ ] **Step 2: Repo-wide forbidden-string scan (product UI paths)**

```bash
rg -n "购买 Token|请充值|Token 包|Token 使用明细|HIDE_BILLING|ReviewFlags" lib .github -g "*.dart" -g "*.yml"
```

Expected: no matches in product paths. (`token_usage_detail_screen.dart` may still contain the word Token in titles — acceptable only if unreachable; if it still says `TOKEN 消耗` that is fine as long as Me/toolbox/errors are clean.)

- [ ] **Step 3: Analyze**

```bash
flutter analyze lib test
```

Expected: no errors.

- [ ] **Step 4: Manual checklist (record in commit message or PR notes)**

1. Me: no balance / Token entry / usage numbers  
2. Toolbox/Agent: no token digits  
3. Quota errors: no 充值/购买 Token  
4. First AI send: consent dialog with named companies + data kinds + collection method  
5. Decline consent: no request; Accept: chat works  

- [ ] **Step 5: Final commit if any leftover fixes**

```bash
git add -A
git commit -m "test(compliance): verify token UI hidden and AI consent gates"
```

Only commit if there are leftover changes.

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Permanently hide Token/usage UI, no switch | 2, 3, 4 |
| Remove ReviewFlags / HIDE_BILLING | 4 |
| Hide Me quota + Token 使用明细 | 2 |
| Hide toolbox/agent token numbers | 3 |
| Disconnect TokenUsageDetailScreen navigation | 2 |
| Neutralize purchase/充值 error copy | 1 |
| Hide Routing 本月用量 | 5 |
| Soften gallery copy | 5 |
| Strengthen consent dialog (what/who/how + permission) | 6 |
| Bump consent version | 6 |
| Privacy policy sync + updatedAt | 6 |
| Audit all AI entry points | 7 |
| Automated + manual verification | 1–3, 6–8 |

## Out of scope (do not implement)

- In-App Purchase / StoreKit
- Per-visit re-consent or settings revoke toggle
- App Store Connect reply drafting
- Deleting `TokenUsageDetailScreen` implementation
