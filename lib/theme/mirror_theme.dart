import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'mirror_colors.dart';

/// 与 index.html :root 字体一致：Geist / Geist Mono / Noto Serif SC
/// 字重不做额外加粗映射，CSS 500 → w500，400 → w400，600 → w600
abstract final class MirrorFontWeight {
  static const regular = FontWeight.w400;
  static const medium = FontWeight.w500;
  static const semibold = FontWeight.w600;
}

abstract final class MirrorTheme {
  /// Web 端使用 pubspec 打包字体，不依赖 Google CDN / fontFamilyFallback。
  static const _webSansFamily = 'MirrorSans';
  static const _webSerifFamily = 'MirrorSans';

  /// Geist / NotoSansSC 不含 emoji 字形；回退到系统彩色 emoji 字体。
  static const emojiFontFallback = [
    'Apple Color Emoji',
    'Segoe UI Emoji',
    'Noto Color Emoji',
    'Android Emoji',
  ];

  static TextStyle _webTextStyle({
    required String? fontFamily,
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
    FontStyle? fontStyle,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: emojiFontFallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
    );
  }

  static TextTheme _emojiFallbackTextTheme(TextTheme base) {
    TextStyle? patch(TextStyle? style) =>
        style?.copyWith(fontFamilyFallback: emojiFontFallback);
    return base.copyWith(
      displayLarge: patch(base.displayLarge),
      displayMedium: patch(base.displayMedium),
      displaySmall: patch(base.displaySmall),
      headlineLarge: patch(base.headlineLarge),
      headlineMedium: patch(base.headlineMedium),
      headlineSmall: patch(base.headlineSmall),
      titleLarge: patch(base.titleLarge),
      titleMedium: patch(base.titleMedium),
      titleSmall: patch(base.titleSmall),
      bodyLarge: patch(base.bodyLarge),
      bodyMedium: patch(base.bodyMedium),
      bodySmall: patch(base.bodySmall),
      labelLarge: patch(base.labelLarge),
      labelMedium: patch(base.labelMedium),
      labelSmall: patch(base.labelSmall),
    );
  }

  static ThemeData light() {
    if (kIsWeb) {
      final base = ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: _webSansFamily,
      );
      return base.copyWith(
        scaffoldBackgroundColor: MirrorColors.bgApp,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        hoverColor: MirrorColors.accentSoft.withValues(alpha: 0.35),
        colorScheme: const ColorScheme.light(
          primary: MirrorColors.accent,
          surface: MirrorColors.bgApp,
          onSurface: MirrorColors.text,
          surfaceTint: Colors.transparent,
        ),
        textTheme: _emojiFallbackTextTheme(
          base.textTheme.apply(
            bodyColor: MirrorColors.text,
            displayColor: MirrorColors.text,
          ),
        ),
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(MirrorColors.border),
          radius: const Radius.circular(4),
          thickness: WidgetStateProperty.all(3),
        ),
      );
    }

    final textTheme = _emojiFallbackTextTheme(
      GoogleFonts.geistTextTheme().apply(
        bodyColor: MirrorColors.text,
        displayColor: MirrorColors.text,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: MirrorColors.bgApp,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: MirrorColors.accentSoft.withValues(alpha: 0.35),
      fontFamily: GoogleFonts.geist().fontFamily,
      colorScheme: const ColorScheme.light(
        primary: MirrorColors.accent,
        surface: MirrorColors.bgApp,
        onSurface: MirrorColors.text,
        surfaceTint: Colors.transparent,
      ),
      textTheme: textTheme,
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(MirrorColors.border),
        radius: const Radius.circular(4),
        thickness: WidgetStateProperty.all(3),
      ),
    );
  }

  /// var(--sans) · 默认 400，标题/按钮多为 500
  static TextStyle sans({
    double? fontSize,
    FontWeight weight = MirrorFontWeight.regular,
    Color? color,
    double? height,
    double letterSpacing = -0.005,
  }) {
    if (kIsWeb) {
      return _webTextStyle(
        fontFamily: _webSansFamily,
        fontSize: fontSize,
        fontWeight: weight,
        color: color ?? MirrorColors.text,
        height: height,
        letterSpacing: letterSpacing,
      );
    }
    return GoogleFonts.geist(
      fontSize: fontSize,
      fontWeight: weight,
      color: color ?? MirrorColors.text,
      height: height,
      letterSpacing: letterSpacing,
    ).copyWith(fontFamilyFallback: emojiFontFallback);
  }

  /// var(--mono) · 默认继承 400
  ///
  /// Web 端 [MirrorMono] 仅含拉丁字母，混排中文会缺字（方框）。
  /// 因此 Web 回退到 [MirrorSans]，保留字距风格。
  static TextStyle mono({
    double? fontSize,
    FontWeight weight = MirrorFontWeight.regular,
    Color? color,
    double letterSpacing = 0.04,
    double? height,
  }) {
    if (kIsWeb) {
      return _webTextStyle(
        fontFamily: _webSansFamily,
        fontSize: fontSize,
        fontWeight: weight,
        color: color ?? MirrorColors.text3,
        letterSpacing: letterSpacing,
        height: height,
      );
    }
    return GoogleFonts.geistMono(
      fontSize: fontSize,
      fontWeight: weight,
      color: color ?? MirrorColors.text3,
      letterSpacing: letterSpacing,
      height: height,
    ).copyWith(fontFamilyFallback: emojiFontFallback);
  }

  /// var(--serif) · 引用/封面多为 italic + 500
  static TextStyle serif({
    double? fontSize,
    FontWeight weight = MirrorFontWeight.medium,
    Color? color,
    FontStyle style = FontStyle.italic,
    double? height,
    double letterSpacing = -0.01,
  }) {
    if (kIsWeb) {
      return _webTextStyle(
        fontFamily: _webSerifFamily,
        fontSize: fontSize,
        fontWeight: weight,
        color: color ?? MirrorColors.text,
        fontStyle: style,
        height: height,
        letterSpacing: letterSpacing,
      );
    }
    return GoogleFonts.notoSerifSc(
      fontSize: fontSize,
      fontWeight: weight,
      color: color ?? MirrorColors.text,
      fontStyle: style,
      height: height,
      letterSpacing: letterSpacing,
    ).copyWith(fontFamilyFallback: emojiFontFallback);
  }
}

/// iOS 式滚动，去掉 Material overscroll 光晕
class MirrorScrollBehavior extends ScrollBehavior {
  const MirrorScrollBehavior();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics();
}
