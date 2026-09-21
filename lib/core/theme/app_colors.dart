import 'package:flutter/material.dart';

class AppColors {
  // OFFICIAL DESIGN TOKENS
  static const Color xoroBlack = Color(0xFF000000);
  static const Color xoroSurface = Color(0xFF0D0D0D);
  static const Color xoroSurface2 = Color(0xFF141414);
  static const Color xoroSurface3 = Color(0xFF1C1C1C);
  static const Color xoroBlue = Color(0xFF1E90FF);
  static const Color xoroBlueDark = Color(0xFF1260CC);
  static const Color xoroWhite = Color(0xFFFFFFFF);
  static const Color xoroRed = Color(0xFFE53E3E);
  static const Color xoroRedDark = Color(0xFFC53030);
  static const Color xoroMuted = Color(0xFF666666);

  // Colores específicos para niveles y efectos
  static const Color electricBlue = Color(0xFF0055FF);
  static const Color goldenYellow = Color(0xFFFFD700);
  static const Color brightRed = Color(0xFFFF0033);

  // Transparencias y Bordes
  static Color xoroBorder = const Color(0xFFFFFFFF).withOpacity(0.08);
  static Color xoroBlueGlow = const Color(0xFF1E90FF).withOpacity(0.20);

  // Gradientes
  static const LinearGradient llanuraGradient = LinearGradient(
    colors: [xoroSurface, xoroBlack],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient blueGradient = LinearGradient(
    colors: [xoroBlue, xoroBlueDark],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient redGradient = LinearGradient(
    colors: [xoroRed, xoroRedDark],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
