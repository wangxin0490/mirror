/// 去掉 Geist / NotoSansSC 无法渲染的 emoji 与箭头符号，避免聊天里出现 □ 占位符。
String stripEmoji(String input) {
  if (input.isEmpty) return input;
  var out = _normalizeArrowGlyphs(input);
  out = out.replaceAll(
    RegExp(r'\p{Extended_Pictographic}', unicode: true),
    '',
  );
  out = out.replaceAll(
    RegExp(
      r'[\u2600-\u27BF\u2300-\u23FF\u2B50-\u2B55\u3030\u303D\u3297-\u3299]',
      unicode: true,
    ),
    '',
  );
  out = out.replaceAll(RegExp(r'[\uFE0F\u200D]'), '');
  return out;
}

/// LLM 常用 →/➡ 等箭头，当前聊天字体缺字形时会显示 □。
String _normalizeArrowGlyphs(String input) {
  var out = input.replaceAllMapped(
    RegExp(
      r'(\d{1,2}:\d{2})\s*[\u2190-\u2194\u21D2\u21D4\u27A1\u2794\u279C\u27F6\uFEFF\uFE0E\uFE0F]\s*(\d{1,2}:\d{2})',
      unicode: true,
    ),
    (m) => '${m[1]}-${m[2]}',
  );
  out = out.replaceAll(
    RegExp(
      r'[\u2190-\u2194\u21D2\u21D4\u27A1\u2794\u279C\u27F6\uFEFF]',
      unicode: true,
    ),
    '至',
  );
  return out;
}
