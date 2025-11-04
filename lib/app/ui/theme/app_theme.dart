import 'package:flutter/material.dart';
import 'text_theme.dart';
import 'color_theme.dart';

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      primaryColor: ColorTheme.primary,
      primaryColorDark: ColorTheme.primaryDark,
      primaryColorLight: ColorTheme.primaryLight,
      scaffoldBackgroundColor: ColorTheme.background,
      colorScheme: ColorScheme.light(
        primary: ColorTheme.primary,
        secondary: ColorTheme.secondary,
        background: ColorTheme.background,
        error: ColorTheme.error,
        surface: ColorTheme.card,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onBackground: ColorTheme.text,
        onSurface: ColorTheme.text,
        onError: Colors.white,
      ),
      textTheme: AppTextTheme.textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: ColorTheme.primary,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: AppTextTheme.textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        shadowColor: ColorTheme.primary.withOpacity(0.2),
      ),
      buttonTheme: ButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        buttonColor: ColorTheme.primary,
        textTheme: ButtonTextTheme.primary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorTheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: 2,
          shadowColor: ColorTheme.primary.withOpacity(0.3),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ColorTheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ColorTheme.primary,
          side: BorderSide(color: ColorTheme.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ColorTheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ColorTheme.error),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: Colors.grey[50],
        hintStyle: TextStyle(color: Colors.grey[400]),
        prefixIconColor: ColorTheme.primary,
        suffixIconColor: ColorTheme.primary,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return ColorTheme.primary;
          }
          return Colors.grey[300]!;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return ColorTheme.primary;
          }
          return Colors.grey[300]!;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return ColorTheme.primary;
          }
          return Colors.grey[400]!;
        }),
        trackColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return ColorTheme.primaryLight;
          }
          return Colors.grey[300]!;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: ColorTheme.primary,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: ColorTheme.primary,
        thumbColor: ColorTheme.primary,
        overlayColor: ColorTheme.primary.withOpacity(0.2),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey[200],
        thickness: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: ColorTheme.primary,
        unselectedItemColor: Colors.grey[600],
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: ColorTheme.primary,
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: ColorTheme.primary,
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData.dark().copyWith(
      primaryColor: ColorTheme.primary,
      scaffoldBackgroundColor: ColorTheme.darkBackground,
      colorScheme: ColorScheme.dark(
        primary: ColorTheme.primary,
        secondary: ColorTheme.accent,
        background: ColorTheme.darkBackground,
        error: ColorTheme.error,
        surface: ColorTheme.darkCardBackground,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onBackground: ColorTheme.darkText,
        onSurface: ColorTheme.darkText,
        onError: Colors.white,
      ),
      textTheme: AppTextTheme.darkTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: ColorTheme.darkAppBar,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: AppTextTheme.darkTextTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        color: ColorTheme.darkCardBackground,
        shadowColor: Colors.black.withOpacity(0.3),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorTheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.3),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ColorTheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ColorTheme.primary,
          side: BorderSide(color: ColorTheme.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ColorTheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ColorTheme.error),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: ColorTheme.darkInputBackground,
        hintStyle: TextStyle(color: Colors.grey[500]),
        prefixIconColor: ColorTheme.primary,
        suffixIconColor: ColorTheme.primary,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return ColorTheme.primary;
          }
          return Colors.grey[700]!;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return ColorTheme.primary;
          }
          return Colors.grey[700]!;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return ColorTheme.primary;
          }
          return Colors.grey[600]!;
        }),
        trackColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return ColorTheme.primaryLight.withOpacity(0.5);
          }
          return Colors.grey[800]!;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: ColorTheme.primary,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: ColorTheme.primary,
        thumbColor: ColorTheme.primary,
        overlayColor: ColorTheme.primary.withOpacity(0.2),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey[800],
        thickness: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: ColorTheme.darkAppBar,
        selectedItemColor: ColorTheme.primary,
        unselectedItemColor: Colors.grey[500],
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: ColorTheme.primary,
        unselectedLabelColor: Colors.grey[500],
        indicatorColor: ColorTheme.primary,
      ),
    );
  }
}