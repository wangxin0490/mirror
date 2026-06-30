import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';
import '../utils/safe_uri.dart';
import '../utils/strip_emoji.dart';
import 'agent_copy_button.dart';

/// KB / Agent 共用聊天 Markdown 渲染（gpt_markdown + 引用角标 + 代码复制）。
class ChatMarkdownBody extends StatelessWidget {
  const ChatMarkdownBody({
    super.key,
    required this.source,
    this.onCitationTap,
    this.onLinkTap,
    this.onCopyFeedback,
  });

  final String source;
  final void Function(int index)? onCitationTap;
  final Future<void> Function(String url)? onLinkTap;
  final VoidCallback? onCopyFeedback;

  static const citationScheme = 'mirror-citation://';

  static final _idCitationRe = RegExp(r'\[ID:(\d+)\]');
  static final _numCitationRe = RegExp(r'(?<!\()\[(\d+)\](?!\()');
  static final _bareUrlRe = RegExp(
    r'(?<!\]\()(?<!\()(https?://[^\s\)\>]+|/api/v1/agent/hermes-files/[^\s\)\>]+)',
  );

  /// gpt_markdown 在交给 [linkBuilder] 前会给子 span 注入 theme.linkColor，
  /// 需递归覆盖才能统一 Mirror 引用/链接样式。
  static InlineSpan _withLinkStyle(InlineSpan span, TextStyle style) {
    if (span is! TextSpan) return span;
    return TextSpan(
      text: span.text,
      style: style.merge(span.style).copyWith(
            color: style.color,
            decoration: style.decoration,
            decorationColor: style.decorationColor,
            fontWeight: style.fontWeight,
            fontSize: style.fontSize,
          ),
      children: span.children?.map((c) => _withLinkStyle(c, style)).toList(),
    );
  }

  /// 将 `[ID:N]` / `[N]` 转为可点击的 citation 链接，供 gpt_markdown 解析。
  @visibleForTesting
  static String preprocessCitations(String raw) {
    var out = raw.replaceAllMapped(_idCitationRe, (m) {
      final n = m.group(1)!;
      return '[ID:$n]($citationScheme$n)';
    });
    out = out.replaceAllMapped(_numCitationRe, (m) {
      final n = m.group(1)!;
      return '[$n]($citationScheme$n)';
    });
    return out;
  }

  /// 去掉模型输出的 emoji（当前字体无法渲染时会显示 □）。
  @visibleForTesting
  static String preprocessEmoji(String raw) => stripEmoji(raw);

  /// 将裸 URL / Mirror 文件路径转为 Markdown 链接，便于点击预览。
  @visibleForTesting
  static String preprocessAutolinks(String raw) {
    return raw.replaceAllMapped(_bareUrlRe, (m) {
      final url = m.group(1)!;
      if (url.contains('](') || url.contains('mirror-citation://')) {
        return url;
      }
      final label = safeFilenameFromUrl(url);
      final linkLabel = label != '附件' ? label : url;
      return '[$linkLabel](${sanitizePercentEncoding(url)})';
    });
  }

  static const _linkColor = MirrorColors.accentDeep;

  Widget _citationBadge(String label) {
    return Text(
      label,
      style: MirrorTheme.sans(
        fontSize: 11,
        color: _linkColor,
        weight: FontWeight.w600,
      ),
    );
  }

  void _tapCitation(String raw) {
    final idx = int.tryParse(raw);
    if (idx != null && onCitationTap != null) {
      onCitationTap!(idx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodyStyle = MirrorTheme.sans(fontSize: 13, height: 1.6, color: MirrorColors.text);
    final md = preprocessAutolinks(
      preprocessCitations(preprocessEmoji(source)),
    );
    final mdTheme = GptMarkdownThemeData(
      brightness: Brightness.light,
      linkColor: _linkColor,
      linkHoverColor: MirrorColors.accent,
    );

    return GptMarkdownTheme(
      gptThemeData: mdTheme,
      child: GptMarkdown(
        md,
        style: bodyStyle,
        followLinkColor: false,
        onLinkTap: (url, title) {
          if (url.startsWith(citationScheme)) {
            _tapCitation(url.substring(citationScheme.length));
            return;
          }
          if (onLinkTap != null) {
            onLinkTap!(url);
          }
        },
        sourceTagBuilder: (ctx, content, style) {
          return GestureDetector(
            onTap: () => _tapCitation(content),
            child: _citationBadge(content),
          );
        },
        linkBuilder: (ctx, text, url, style) {
          final citation = url.startsWith(citationScheme);
          final linkStyle = style.copyWith(
            color: _linkColor,
            fontWeight: citation ? FontWeight.w600 : style.fontWeight,
            fontSize: citation ? 11 : style.fontSize,
            decoration: citation ? TextDecoration.none : TextDecoration.underline,
            decorationColor: citation ? null : _linkColor,
          );
          final styled = _withLinkStyle(text, linkStyle);
          return GestureDetector(
            onTap: () {
              if (citation) {
                _tapCitation(url.substring(citationScheme.length));
              } else {
                onLinkTap?.call(url);
              }
            },
            child: Text.rich(styled is TextSpan ? styled : TextSpan(children: [styled])),
          );
        },
      codeBuilder: (ctx, lang, code, closed) {
        final label = lang.trim().isEmpty ? 'code' : lang.trim();
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          decoration: BoxDecoration(
            color: MirrorColors.bgSoft,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: MirrorColors.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: MirrorTheme.mono(fontSize: 9, color: MirrorColors.text3, letterSpacing: 0.06),
                    ),
                  ),
                  if (onCopyFeedback != null)
                    AgentCopyButton(
                      text: code.trimRight(),
                      tooltip: '复制代码',
                      iconSize: 14,
                      padding: const EdgeInsets.all(2),
                      onCopied: onCopyFeedback,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              SelectableText(
                code.trimRight(),
                style: MirrorTheme.mono(fontSize: 11, height: 1.6, color: MirrorColors.text),
              ),
            ],
          ),
        );
        },
      ),
    );
  }
}
