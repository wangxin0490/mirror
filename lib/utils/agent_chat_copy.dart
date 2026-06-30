import 'package:flutter/services.dart';

import '../models/agent_models.dart';

Future<bool> copyTextToClipboard(String text) async {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;
  await Clipboard.setData(ClipboardData(text: trimmed));
  return true;
}

String formatAgentMessageForCopy(AgentMessage message) {
  return message.content.trim();
}

String formatAgentConversationMarkdown({
  String? title,
  required List<AgentMessage> messages,
}) {
  final buf = StringBuffer();
  final heading = title?.trim();
  if (heading != null && heading.isNotEmpty) {
    buf.writeln('# $heading');
    buf.writeln();
  }
  for (final m in messages) {
    if (m.streaming || m.content.trim().isEmpty) continue;
    buf.writeln(m.isUser ? '**用户**' : '**Mirror**');
    buf.writeln();
    buf.writeln(m.content.trim());
    buf.writeln();
  }
  return buf.toString().trim();
}
