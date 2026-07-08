import 'package:flutter/material.dart';

import '../theme/mirror_colors.dart';
import '../theme/mirror_theme.dart';

/// AI 生成内容显式标识样式（GB/T 41806 文本内容标识）。
enum AiGeneratedLabelStyle {
  /// 文本起始：`( AI生成 )`
  textPrefix,

  /// 文本末尾：`( AI生成 )`
  textSuffix,

  /// 角标起始：`AI` 上标
  superscriptPrefix,

  /// 角标末尾：`AI` 上标
  superscriptSuffix,
}

/// AI 生成内容显式标识常量。
abstract final class AiGeneratedLabel {
  /// 文字形式标识，同时包含 AI 与「生成」要素。
  static const textLabel = '( AI生成 )';

  /// 角标形式标识。
  static const superscriptLabel = 'AI';

  /// 正文旁标识字号（略小于正文，符合应用内提示规范）。
  static const double fontSize = 11;

  /// 浅色辅助文字，与正文区分且清晰可辨。
  static const color = MirrorColors.text3;
}

/// 文字形式显式标识 `( AI生成 )`。
class AiGeneratedTextLabel extends StatelessWidget {
  const AiGeneratedTextLabel({super.key});

  static TextStyle style({double? fontSize}) {
    return MirrorTheme.sans(
      fontSize: fontSize ?? AiGeneratedLabel.fontSize,
      color: AiGeneratedLabel.color,
      weight: FontWeight.w400,
      height: 1.4,
    );
  }

  static InlineSpan textSpan({double? fontSize}) {
    return TextSpan(text: AiGeneratedLabel.textLabel, style: style(fontSize: fontSize));
  }

  @override
  Widget build(BuildContext context) {
    return Text(AiGeneratedLabel.textLabel, style: style());
  }
}

/// 角标形式显式标识 `AI`。
class AiGeneratedSuperscriptLabel extends StatelessWidget {
  const AiGeneratedSuperscriptLabel({super.key, this.fontSize = 9});

  final double fontSize;

  static TextStyle style({double fontSize = 9}) {
    return MirrorTheme.sans(
      fontSize: fontSize,
      color: AiGeneratedLabel.color,
      weight: FontWeight.w500,
      height: 1,
    );
  }

  static WidgetSpan widgetSpan({double fontSize = 10}) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.top,
      child: Transform.translate(
        offset: const Offset(0, -4),
        child: Text(AiGeneratedLabel.superscriptLabel, style: style(fontSize: fontSize)),
      ),
    );
  }

  static InlineSpan textSpan({double fontSize = 10}) {
    return TextSpan(
      text: AiGeneratedLabel.superscriptLabel,
      style: style(fontSize: fontSize).copyWith(fontFeatures: const [FontFeature.superscripts()]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(textSpan(fontSize: fontSize));
  }
}

/// 为 AI 生成内容块附加显式标识。
class AiGeneratedContentFrame extends StatelessWidget {
  const AiGeneratedContentFrame({
    super.key,
    required this.child,
    this.visible = true,
    this.style = AiGeneratedLabelStyle.textSuffix,
  });

  final Widget child;
  final bool visible;
  final AiGeneratedLabelStyle style;

  @override
  Widget build(BuildContext context) {
    if (!visible) return child;

    switch (style) {
      case AiGeneratedLabelStyle.textPrefix:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AiGeneratedTextLabel(),
            child,
          ],
        );
      case AiGeneratedLabelStyle.textSuffix:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            child,
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: const AiGeneratedTextLabel(),
            ),
          ],
        );
      case AiGeneratedLabelStyle.superscriptPrefix:
      case AiGeneratedLabelStyle.superscriptSuffix:
        return child;
    }
  }
}
