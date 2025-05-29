import 'package:flutter/material.dart';
import 'color_theme.dart';

class AppTextTheme {
  static TextTheme get textTheme {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: ColorTheme.text,
        fontFamily: 'Cairo',
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: ColorTheme.text,
        fontFamily: 'Cairo',
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: ColorTheme.text,
        fontFamily: 'Cairo',
      ),
      headlineLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: ColorTheme.text,
        fontFamily: 'Cairo',
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: ColorTheme.text,
        fontFamily: 'Cairo',
      ),
      headlineSmall: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: ColorTheme.text,
        fontFamily: 'Cairo',
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: ColorTheme.text,
        fontFamily: 'Cairo',
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: ColorTheme.text,
        fontFamily: 'Cairo',
      ),
      titleSmall: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: ColorTheme.text,
        fontFamily: 'Cairo',
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: ColorTheme.text,
        fontFamily: 'Cairo',
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: ColorTheme.text,
        fontFamily: 'Cairo',
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        color: ColorTheme.textSecondary,
        fontFamily: 'Cairo',
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: ColorTheme.text,
        fontFamily: 'Cairo',
      ),
    );
  }

  static TextTheme get darkTextTheme {
    return textTheme.apply(
      bodyColor: ColorTheme.darkText,
      displayColor: ColorTheme.darkText,
    );
  }
}