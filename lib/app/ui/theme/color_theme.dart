import 'package:flutter/material.dart';

class ColorTheme {
  // Primary colors based on logo
  static const Color primary = Color(0xFF00B0FF); // Bright blue from the "e" in logo
  static const Color primaryDark = Color(0xFF0091EA); // Darker shade of logo blue
  static const Color primaryLight = Color(0xFFE1F5FE); // Light blue for subtle highlights

  // Secondary colors complementing the logo
  static const Color secondary = Color(0xFF001F33); // Dark navy from graduation cap
  static const Color secondaryLight = Color(0xFF37474F); // Lighter version of cap color

  // Interface colors
  static const Color background = Color(0xFFF5F5F5); // Soft white background
  static const Color card = Colors.white;
  static const Color text = Color(0xFF333333); // Slightly softer than pure black
  static const Color textSecondary = Color(0xFF666666);
  static const Color accent = Color(0xFF00B0FF); // Using logo blue as accent

  // Semantic colors for e-learning
  static const Color success = Color(0xFF4CAF50); // Green for positive feedback
  static const Color warning = Color(0xFFFFC107); // Amber for cautions/alerts
  static const Color error = Color(0xFFF44336); // Red for errors
  static const Color info = Color(0xFF2196F3); // Blue for informational elements

  // Dark mode colors
  static const Color darkBackground = Color(0xFF001F33); // Dark navy from cap
  static const Color darkCardBackground = Color(0xFF002D4A); // Slightly lighter navy
  static const Color darkAppBar = Color(0xFF003660); // Medium navy for app bar
  static const Color darkText = Color(0xFFE5E5E5); // Soft white for readability
  static const Color darkTextSecondary = Color(0xFFA0A0A0);
  static const Color darkInputBackground = Color(0xFF002D4A); // Dark navy input fields
}