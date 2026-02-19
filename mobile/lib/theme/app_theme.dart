import 'package:flutter/material.dart';

class AppTheme {
  static const Color darkBlue = Color(0xFF46546C);
  static const Color lightBlue = Color(0xFF94C5D0);
  static const Color cardBorder = Color(0xFFE6E0DD);
  static const Color surface = Color(0xFFF8F7F6);
  static const Color iconBg = Color(0xFFEDEDED);

  static ThemeData build() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: surface,
      colorScheme: ColorScheme.fromSeed(
        seedColor: darkBlue,
        primary: darkBlue,
        surface: surface,
      ),
      fontFamily: 'SF Pro Display',
    );
  }
}
