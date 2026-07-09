/// 第三方 AI 服务商披露（弹窗与隐私政策共用，App Store 5.1.1/5.1.2）。
class AiThirdPartyProvider {
  const AiThirdPartyProvider({
    required this.companyName,
    required this.services,
  });

  /// 公司法定/注册全称（弹窗与隐私政策须指名）。
  final String companyName;

  /// 在本应用中提供的 AI 能力说明。
  final String services;
}

/// 同意记录版本；服务商名单或披露文案变更时递增，以触发重新授权。
const kAiThirdPartyConsentVersion = 3;

/// 当前可能接收用户数据的第三方 AI 服务商（随模型路由可能选用其一或多个）。
const kAiThirdPartyProviders = [
  AiThirdPartyProvider(
    companyName: 'OpenAI, L.L.C.',
    services: '大语言模型推理（如 GPT 系列）',
  ),
  AiThirdPartyProvider(
    companyName: 'Anthropic, PBC',
    services: '大语言模型推理（如 Claude 系列）',
  ),
  AiThirdPartyProvider(
    companyName: 'Google LLC',
    services: '大语言模型推理（如 Gemini 系列）',
  ),
  AiThirdPartyProvider(
    companyName: '杭州深度求索人工智能基础技术研究有限公司',
    services: '大语言模型推理（DeepSeek 系列）',
  ),
  AiThirdPartyProvider(
    companyName: '北京智谱华章科技有限公司',
    services: '大语言模型推理（GLM 系列）与语音识别（GLM-ASR）',
  ),
];

/// 弹窗首段强调句（须明确「发送至具体公司」）。
String aiThirdPartyConsentLeadSentence() {
  final names = kAiThirdPartyProviders.map((p) => p.companyName).join('、');
  return '使用 AI 对话、知识库问答、语音输入、会议录音与纪要等功能时，'
      '您主动输入、上传、录制或发送的内容将被发送至以下第三方 AI 服务提供商：$names。'
      '具体由您所选模型或功能决定实际接收方。';
}

/// 隐私政策「第三方 AI 服务说明」正文。
String aiThirdPartyPrivacyPolicyBody() {
  final buf = StringBuffer()
    ..writeln('当您使用 AI 相关功能时，我们可能将以下数据发送至上述第三方 AI 服务提供商：')
    ..writeln('• 收集与发送的数据：您输入的文字、上传的图片/文件、语音及语音转写文本、会话上下文、知识库文档片段、会议录音及转写文本；')
    ..writeln('• 收集方式：由您在应用内主动输入、上传、录制或选择发送；')
    ..writeln('• 共享对象（指名）：');
  for (final p in kAiThirdPartyProviders) {
    buf.writeln('  - ${p.companyName}：${p.services}；');
  }
  buf.writeln(
    '• 用途：生成 AI 回复、语音转文字、知识库检索增强与会议纪要；'
    '• 保护：我们要求上述服务商提供与本政策同等或更严格的保护，并仅在实现功能所必需范围内处理数据；'
    '• 变更：若新增或更换服务商，我们将更新本政策并在必要时再次征得您的同意。',
  );
  return buf.toString().trim();
}
