# App Store 合规：隐藏 Token 用量 + 强化 AI 隐私同意

**日期：** 2026-07-09  
**背景：** App Store 拒审（Submission `c9c483e5-48fd-4db9-b784-c57c1245171f`，Version 1.0 (10)）  
- Guideline 3.1.1：应用访问站外购买的数字内容/订阅，但未提供 IAP  
- Guideline 5.1.1(i) / 5.1.2(i)：向第三方 AI 共享个人数据前，未充分说明并征得同意  

**本次范围（用户确认）：**
1. 将 tokens 的用量都隐藏起来（永久隐藏 UI，不删代码，不要开关）
2. 完善 AI 隐私合规（强化现有首次同意弹窗）

**明确不做：** IAP 接入、每次进功能重复弹窗、设置内撤销开关、App Store Connect 回复撰写。

---

## 1. Token / 用量隐藏

### 目标

用户在 App 内看不到任何 Token、余额、用量数字或购买/充值引导；相关实现代码保留，只是不渲染、不从产品导航进入。

### 决策

采用「UI 层永久不渲染」方案：移除 `ReviewFlags` / `HIDE_BILLING` 开关语义，产品路径一律不展示用量与计费相关 UI。

### 改动清单

1. **移除开关**
   - 删除 `lib/config/review_flags.dart`（或等价地移除所有引用后删除文件）
   - 从 `.github/workflows/ios-appstore.yml` 去掉 `--dart-define=HIDE_BILLING=true`
   - 清理所有 `ReviewFlags.hideBilling` 分支，改为「不展示」的固定行为

2. **「我的」页**
   - 不展示账户余额 / 配额卡片
   - 不展示「Token 使用明细」入口（当前 `hideBilling=true` 时仍会露出，必须一并去掉）

3. **工具箱 / Agent 列表**
   - 不展示含 token 数字的 `usageSubtitle` / `usageTrailing`（如 `131 tokens · 3 次调用`）
   - 若副标题含 token，则整段用量副标题隐藏；可仅保留名称，或仅展示不含 token 的调用次数文案（若保留次数，不得出现 “token(s)” / “Token” 计费语义）

4. **导航**
   - 产品路径不再进入 `TokenUsageDetailScreen`
   - 保留 `token_usage_detail_screen.dart` 等实现文件，便于日后恢复

5. **错误 / 额度文案**
   - 将「购买 Token」「请充值」「Token 包」「请充值或换一个模型」等改为中性文案  
     示例：`暂时无法继续，请稍后再试或换一个模型`
   - 覆盖点至少包括：
     - `lib/screens/mirror_screens.dart` 中额度相关映射
     - `lib/utils/relay_error_messages.dart` 中 quota / 402 文案

6. **其它展示面**
   - Agent 心智等页面中的「本月用量 · USAGE」及用量数字：隐藏或去掉用量区块
   - 内部 gallery 文案可顺带去掉 Token/用量表述（非审核主路径）

### 不做

- 不删除 Me API、模型字段、明细页实现
- 不接入 IAP
- 不保留 dart-define / 远程配置开关

---

## 2. AI 隐私合规（强化首次同意）

### 目标

满足 5.1.1(i) / 5.1.2(i)：在向第三方 AI 发送个人数据前，说明「发什么、发给谁」，并取得明确同意；隐私政策同步指名第三方。

### 决策

强化现有首次一次性同意弹窗（`AiDataConsentDialog` + `ensureAiDataConsent`），不改为每次进入功能都弹窗。

### 弹窗要求

1. 标题：保持「第三方 AI 数据处理授权」
2. 首段：明确使用 AI 功能时，数据将发送至下列第三方公司（列出法定全称）
3. 接收方：公司全称 + 用途（LLM / ASR 等），数据源为 `kAiThirdPartyProviders`
4. 数据种类：文字/图片/文件/语音及转写、会话上下文、知识库片段、会议录音与转写
5. 收集方式：仅用户主动输入、上传、录制或发送时
6. 明确动作：须点「同意并继续」才可继续；「暂不使用」则中止，不发请求
7. 链接：可打开完整《隐私政策》
8. 版本：`kAiThirdPartyConsentVersion` 递增（2 → 3），文案变更后强制重新授权

### 入口核对

以下路径在发起网络请求前必须调用 `ensureAiDataConsent`；不同意则不发起请求：

- 主对话发送 / 语音输入
- 知识库问答、语音导入、语音输入
- 会议录音 / 上传音频
- Product Agent / 其它 Agent 聊天（含 `dg_coupon_chat` 等）

实现时扫描所有 AI/ASR 发送路径，补齐漏网入口。

### 隐私政策

- 「第三方 AI 服务说明」与弹窗共用 `lib/legal/ai_third_party_disclosure.dart`
- 写明：收集内容、方式、共享对象（指名）、用途、同等保护要求
- 更新日期随本次修订调整（`MirrorLegalDocument.updatedAt`）

### 不做

- 每次进入 AI 主功能重复确认
- 设置页「撤回 AI 同意」开关（本次范围外）

---

## 3. 测试与验收

### 自动化

- 扩展 `test/ai_data_consent_test.dart`：
  - 弹窗含「发什么 / 发给谁 / 同意与拒绝」
  - 隐私政策含指名第三方
  - 同意版本变更后需重新同意（若有对应 store 测试）
- 用量隐藏相关断言（新增或扩展现有 widget/unit 测试）：
  - 「我的」无「Token 使用明细」/余额入口文案
  - 额度错误文案不含「充值」「购买 Token」

### 手工验收（审核视角）

1. 登录后进「我的」：看不到余额、Token 明细、用量数字
2. 工具箱 / Agent：看不到 token 消耗数字
3. 触发额度用尽类错误：无购买/充值引导
4. 首次发 AI 消息：先出同意弹窗；点「暂不使用」不发请求；点「同意并继续」后可正常对话
5. 知识库问答、会议录音路径同样先同意

### 范围外

- IAP 接入
- App Store Connect 回复文案撰写

---

## 4. 主要触及文件（预期）

| 区域 | 文件 |
|------|------|
| 开关移除 | `lib/config/review_flags.dart`, `.github/workflows/ios-appstore.yml` |
| 我的 / 工具箱 | `lib/screens/mirror_screens_part3.dart`, `lib/screens/product_agent_screens.dart` |
| 对话额度文案 | `lib/screens/mirror_screens.dart`, `lib/utils/relay_error_messages.dart` |
| 用量页（保留不入口） | `lib/screens/token_usage_detail_screen.dart`, `lib/app/mirror_prototype.dart` |
| AI 同意 | `lib/widgets/ai_data_consent_dialog.dart`, `lib/legal/ai_third_party_disclosure.dart`, `lib/legal/mirror_legal_documents.dart`, `lib/services/ai_consent_store.dart` |
| 测试 | `test/ai_data_consent_test.dart` 及用量隐藏相关测试 |

---

## 5. 成功标准

- 审核员在 iPad 上走查时，看不到 Token/余额/用量/购买引导
- 首次使用任一 AI 能力前，必须看到指名第三方与数据种类的同意弹窗，且拒绝后无数据外发
- 隐私政策与弹窗披露一致，并含第三方公司全称
