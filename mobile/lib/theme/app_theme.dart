import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF2F5D50);
  static const Color pressed = Color(0xFF254A40);
  static const Color light = Color(0xFF5E867B);
  static const Color soft = Color(0xFFE8F2EC);
  static const Color primarySoft = soft;
  static const Color surface = Color(0xFFF7F5F2);
  static const Color card = Color(0xFFFFFFFF);
  static const Color headerStart = Color(0xFF8EA684);
  static const Color headerEnd = Color(0xFF6F8F69);
  static const Color homeAccent = Color(0xFF4D6B57);
  static const Color homeCard = Color(0xFFDCE7D4);
  static const Color homeIconBackground = Color(0xFFE6F0E6);
  static const Color terracotta = Color(0xFFD98371);
  static const Color sand = Color(0xFFE5DCCA);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF374151);
  static const Color cardBorder = Color(0xFFE5E7EB);
  static const Color iconBg = soft;
  static const Color darkBlue = primary;
  static const Color lightBlue = light;

  static List<BoxShadow> get softShadow => const [
        BoxShadow(
          color: Color(0x120F1B16),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ];

  static ThemeData build() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: terracotta,
      surface: surface,
      onPrimary: Colors.white,
      onSurface: textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: surface,
      colorScheme: colorScheme,
      fontFamily: 'SF Pro Display',
      dividerColor: cardBorder,
      splashColor: primary.withValues(alpha: 0.08),
      highlightColor: Colors.transparent,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          color: textPrimary,
          fontWeight: FontWeight.w800,
          height: 1.08,
        ),
        headlineMedium: TextStyle(
          fontSize: 26,
          color: textPrimary,
          fontWeight: FontWeight.w700,
          height: 1.12,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: textPrimary,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textMuted,
          height: 1.4,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return light.withValues(alpha: 0.35);
            }
            if (states.contains(WidgetState.pressed)) {
              return pressed;
            }
            return primary;
          }),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return Colors.white.withValues(alpha: 0.08);
            }
            return null;
          }),
          elevation: const WidgetStatePropertyAll(0),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: cardBorder),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        labelStyle: const TextStyle(
          color: textMuted,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFFAFB7B1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFC84C4C)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFC84C4C), width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: card,
        contentTextStyle: const TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}
