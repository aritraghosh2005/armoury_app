import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  /// Global state flag indicating whether Light mode is active
  static bool isLight = false;

  // Backgrounds: Clean architectural slate vs true pitch OLED black
  static Color get bg =>
      isLight ? const Color(0xFFF1F5F9) : const Color(0xFF000000);
  static Color get cardBg =>
      isLight ? const Color(0xFFFFFFFF) : const Color(0x40101010);
  static Color get cardBgElevated =>
      isLight ? const Color(0xFFF8FAFC) : const Color(0x66151515);
  static Color get cardBgHighlight =>
      isLight ? const Color(0xFFE2E8F0) : const Color(0x1FFFFFFF);

  // Foregrounds & Contrasts: Deep high-contrast ink in light mode vs crisp white in dark mode
  static Color get fg =>
      isLight ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF);
  static Color get dim =>
      isLight ? const Color(0xFF475569) : const Color(0xFF888888);
  static Color get dimmer =>
      isLight ? const Color(0xFF64748B) : const Color(0xFF444444);
  static Color get subtle =>
      isLight ? const Color(0xFFE2E8F0) : const Color(0xFF222222);

  // Borders: Sharp architectural lines
  static Color get border =>
      isLight ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF);
  static Color get borderMedium =>
      isLight ? const Color(0xFFCBD5E1) : const Color(0xFF555555);
  static Color get borderSubtle =>
      isLight ? const Color(0xFFE2E8F0) : const Color(0xFF262626);
  static Color get dividerLine =>
      isLight ? const Color(0x22000000) : const Color(0x28FFFFFF);

  // Status Indicators
  static Color get statusOk =>
      isLight ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF);
  static Color get statusLow =>
      isLight ? const Color(0xFF475569) : const Color(0xFFAAAAAA);
  static Color get statusDepleted =>
      isLight ? const Color(0xFF64748B) : const Color(0xFF555555);

  // Purge / Danger Indicators (Dark Crimson Red)
  static const Color purgeRed = Color(0xFFFF3B30);
  static const Color purgeBorder = Color(0xFF8B0000);
  static const Color purgeBg = Color(0x38440000);
  static const Color purgeBgActive = Color(0xFF6B0000);
}

class AppTypography {
  static TextStyle mono({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double letterSpacing = 0.5,
    double? height,
    TextDecoration? decoration,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? AppColors.fg,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
    );
  }

  static TextStyle title({Color? color}) => mono(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: color ?? AppColors.fg,
        letterSpacing: 1.0,
      );

  static TextStyle heading({Color? color}) => mono(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: color ?? AppColors.fg,
        letterSpacing: 0.8,
      );

  static TextStyle body({Color? color}) => mono(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: color ?? AppColors.fg,
        letterSpacing: 0.4,
      );

  static TextStyle caption({Color? color}) => mono(
        fontSize: 10,
        fontWeight: FontWeight.normal,
        color: color ?? AppColors.dim,
        letterSpacing: 0.6,
      );

  static TextStyle ascii({Color? color}) => mono(
        fontSize: 7.2,
        fontWeight: FontWeight.bold,
        color: color ?? AppColors.fg,
        letterSpacing: -0.5,
        height: 1.15,
      );
}

ThemeData buildTerminalTheme({bool isLight = false}) {
  final monoFontFamily = GoogleFonts.jetBrainsMono().fontFamily;
  final base = isLight ? ThemeData.light(useMaterial3: true) : ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: isLight
        ? ColorScheme.light(
            surface: AppColors.cardBg,
            primary: AppColors.fg,
            onPrimary: AppColors.bg,
            secondary: AppColors.dim,
            onSurface: AppColors.fg,
          )
        : ColorScheme.dark(
            surface: AppColors.cardBg,
            primary: AppColors.fg,
            onPrimary: AppColors.bg,
            secondary: AppColors.dim,
            onSurface: AppColors.fg,
          ),
    textTheme: base.textTheme.apply(
      fontFamily: monoFontFamily,
      bodyColor: AppColors.fg,
      displayColor: AppColors.fg,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: AppColors.border, width: 1),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: AppColors.borderSubtle, width: 1),
      ),
    ),
  );
}
