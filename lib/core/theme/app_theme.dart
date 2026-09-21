import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.xoroBlue,
      scaffoldBackgroundColor: AppColors.xoroBlack,
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.xoroBlue,
        secondary: AppColors.goldenYellow,
        error: AppColors.xoroRed,
        surface: AppColors.xoroSurface2,
        onPrimary: AppColors.xoroWhite,
        onSurface: AppColors.xoroWhite,
        onBackground: AppColors.xoroWhite,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.xoroWhite),
        titleTextStyle: TextStyle(color: AppColors.xoroWhite, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.xoroWhite),
        bodyMedium: TextStyle(color: AppColors.xoroWhite),
      ),
    );
  }
}
