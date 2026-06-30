import 'package:flutter/material.dart';

/// 与 index.html :root 完全一致
abstract final class MirrorColors {
  static const bgPage = Color(0xFFF6F5F2);
  static const bgApp = Color(0xFFFFFFFF);
  static const bgSoft = Color(0xFFFAFAF8);
  static const bgCard = Color(0xFFF4F4F2);
  static const border = Color(0xFFE8E6E1);
  static const borderSoft = Color(0xFFEFEDE8);
  static const text = Color(0xFF1A1916);
  static const text2 = Color(0xFF5C5A54);
  static const text3 = Color(0xFF9B988F);
  static const text4 = Color(0xFFC7C4BB);
  static const accent = Color(0xFF5B47E8);
  static const accentSoft = Color(0xFFEEEDFE);
  static const accentDeep = Color(0xFF3C3489);
  static const accentBorder = Color(0xFFD9D5FA);
  static const green = Color(0xFF1D9E75);
  static const greenSoft = Color(0xFFE1F5EE);
  static const greenText = Color(0xFF085041);
  static const blue = Color(0xFF185FA5);
  static const blueSoft = Color(0xFFE6F1FB);
  static const blueText = Color(0xFF0C447C);
  static const amber = Color(0xFFBA7517);
  static const amberSoft = Color(0xFFFAEEDA);
  static const coral = Color(0xFFD85A30);
  static const coralSoft = Color(0xFFFAECE7);
  static const coralText = Color(0xFF993C1D);
  static const pink = Color(0xFFE84A85);
  static const pinkSoft = Color(0xFFFCE7EE);
  static const pinkText = Color(0xFF8C2950);
  static const phoneBezel = Color(0xFF1F1D1A);
  static const drivePro = Color(0xFFFFD27A);
  static const wechatGreen = Color(0xFF1AAD19);
  static const overlayDim = Color(0x661A1916);
  static const labelBackdrop = Color(0x4D000000);
  static const white14 = Color(0x24FFFFFF);
  static const white70 = Color(0xB3FFFFFF);
}

/// index.html 渐变（135deg = topLeft → bottomRight）
abstract final class MirrorGradients {
  static const purple = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5B47E8), Color(0xFF8B6FFF)],
  );
  static const pink = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE84A85), Color(0xFFFF9CC4)],
  );
  static const green = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1D9E75), Color(0xFF56C9A0)],
  );
  static const amber = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFBA7517), Color(0xFFE8AC55)],
  );
  static const blue = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF185FA5), Color(0xFF56A8E8)],
  );
  static const dark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1916), Color(0xFF5C5A54)],
  );
  static const coral = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD85A30), Color(0xFFFF9468)],
  );
  static const deepPurple = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3C3489), Color(0xFF7C6FE8)],
  );
  static const postCover = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5B47E8), Color(0xFF3C3489)],
  );
  static const paywall = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3C3489), Color(0xFF5B47E8)],
  );
  static const driveHeader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5B47E8), Color(0xFF3C3489)],
  );
  static const profile = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5B47E8), Color(0xFF8B6FFF)],
  );

  static LinearGradient avatar(List<Color> c) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: c,
      );
}

abstract final class MirrorShadows {
  static const phone = [
    BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x26282620), blurRadius: 24, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x2E282620), blurRadius: 60, offset: Offset(0, 24)),
  ];
  static const fab = BoxShadow(color: Color(0x665B47E8), blurRadius: 12, offset: Offset(0, 4));
  static const tabOn = BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1));
}
