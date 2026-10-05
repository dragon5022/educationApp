import 'dart:math' as math;

import 'package:flutter/material.dart';

/// CSS custom properties of the TEEN web pages (`:root{--navy:…}`).
abstract final class TeenColors {
  static const navy = Color(0xFF1F3864);
  static const navyDeep = Color(0xFF0F1B33);
  static const gold = Color(0xFFBF9000);
  static const goldBright = Color(0xFFFFC83D);
  static const red = Color(0xFFE63946);
  static const redDeep = Color(0xFF8B1A24);
  static const green = Color(0xFF06A878);
  static const bgTop = Color(0xFF1A2742);
  static const bgBottom = Color(0xFF0D1626);
  static const text = Color(0xFFEDE4CC);
  static const lightBlue = Color(0xFFDEEBF7);
  static const paper = Color(0xFFFFFDF5);
  static const purple = Color(0xFF7C3AED);
  static const creamSoft = Color(0xFFF3E9CE);
}

/// Font families bundled from the web's Google Fonts link.
abstract final class TeenFonts {
  static const bungee = 'Bungee';
  static const russo = 'RussoOne';
  static const dela = 'DelaGothicOne';
  static const orbitron = 'Orbitron';
  static const zen = 'ZenKakuGothicNew';
  static const mplus = 'MPLUSRounded1c';

  /// `'Zen Kaku Gothic New','M PLUS Rounded 1c',sans-serif` (body).
  static const bodyFallback = [zen, mplus];

  /// Latin display faces have no kana/kanji; the web falls through the
  /// stack (`'Russo One','M PLUS Rounded 1c'`) or to the system gothic.
  static const jpFallback = [mplus, zen];
  static const sansFallback = [zen, mplus];
}

/// Converts a CSS blur radius (box-shadow / text-shadow / drop-shadow, where
/// sigma = r / 2) to Flutter's `blurRadius` (sigma = r * 0.57735 + 0.5).
double cssBlur(double r) => math.max(0, (r / 2 - 0.5) / 0.57735);

/// CSS `box-shadow: dx dy blur color` as a Flutter [BoxShadow].
BoxShadow cssShadow(double dx, double dy, double blur, Color color,
        {double spread = 0}) =>
    BoxShadow(
      offset: Offset(dx, dy),
      blurRadius: cssBlur(blur),
      spreadRadius: spread,
      color: color,
    );

/// CSS `text-shadow: dx dy blur color`.
Shadow cssTextShadow(double dx, double dy, double blur, Color color) =>
    Shadow(offset: Offset(dx, dy), blurRadius: cssBlur(blur), color: color);

/// Shorthand for a [TextStyle] in CSS terms: [ls] is `letter-spacing` in em.
TextStyle ts({
  required String family,
  required double size,
  FontWeight weight = FontWeight.w400,
  Color color = TeenColors.text,
  double ls = 0,
  double? height,
  List<Shadow>? shadows,
  List<String>? fallback,
  FontStyle? style,
}) =>
    TextStyle(
      fontFamily: family,
      fontFamilyFallback: fallback ??
          (family == TeenFonts.zen
              ? TeenFonts.bodyFallback
              : TeenFonts.jpFallback),
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: ls * size,
      height: height,
      shadows: shadows,
      fontStyle: style,
    );

ThemeData buildTeenTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: TeenColors.bgBottom,
      fontFamily: TeenFonts.zen,
      fontFamilyFallback: TeenFonts.bodyFallback,
      colorScheme: ColorScheme.fromSeed(
        seedColor: TeenColors.goldBright,
        brightness: Brightness.dark,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
