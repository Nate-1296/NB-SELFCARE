import 'package:flutter/material.dart';

/// Motor visual específico para pantallas TCL 50 Pro NXTPAPER y tinta electrónica.
///
/// Características críticas:
/// - Cero elevación y eliminación absoluta de sombras difusas.
/// - Bordes sólidos de 1.5px tipo tinta impresa.
/// - Paleta de alto contraste blanco hueso / negro tinta mate.
/// - Supresión de animaciones superfluas para evitar estelas (ghosting).
abstract final class NxtpaperEinkTheme {
  // Paleta Claro Papel
  static const Color paperBackgroundLight = Color(0xFFF7F5F0);
  static const Color paperSurfaceLight = Color(0xFFFFFFFF);
  static const Color inkTextLight = Color(0xFF121212);
  static const Color inkBorderLight = Color(0xFF121212);

  // Paleta Oscuro Tinta
  static const Color inkBackgroundDark = Color(0xFF101214);
  static const Color inkSurfaceDark = Color(0xFF181A1D);
  static const Color paperTextDark = Color(0xFFEAE6DF);
  static const Color paperBorderDark = Color(0xFFEAE6DF);

  static const double borderWidth = 1.5;

  static ThemeData light() {
    const ColorScheme scheme = ColorScheme(
      brightness: Brightness.light,
      primary: inkTextLight,
      onPrimary: paperSurfaceLight,
      secondary: Color(0xFF333333),
      onSecondary: paperSurfaceLight,
      error: Color(0xFFB00020),
      onError: Colors.white,
      surface: paperSurfaceLight,
      onSurface: inkTextLight,
      outline: inkBorderLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: paperBackgroundLight,
      appBarTheme: const AppBarTheme(
        elevation: 0.0,
        scrolledUnderElevation: 0.0,
        backgroundColor: paperBackgroundLight,
        foregroundColor: inkTextLight,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0.0,
        shadowColor: Colors.transparent,
        color: paperSurfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: const BorderSide(color: inkBorderLight, width: borderWidth),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0.0,
          foregroundColor: paperSurfaceLight,
          backgroundColor: inkTextLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
            side: const BorderSide(color: inkBorderLight, width: borderWidth),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: inkTextLight,
          side: const BorderSide(color: inkBorderLight, width: borderWidth),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paperSurfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: inkBorderLight, width: borderWidth),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: inkBorderLight, width: borderWidth),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: inkBorderLight, width: 2.0),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        elevation: 0.0,
        backgroundColor: paperBackgroundLight,
        indicatorColor: Color(0xFFDDDAD3),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }

  static ThemeData dark() {
    const ColorScheme scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: paperTextDark,
      onPrimary: inkSurfaceDark,
      secondary: Color(0xFFCCCCCC),
      onSecondary: inkSurfaceDark,
      error: Color(0xFFCF6679),
      onError: Colors.black,
      surface: inkSurfaceDark,
      onSurface: paperTextDark,
      outline: paperBorderDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: inkBackgroundDark,
      appBarTheme: const AppBarTheme(
        elevation: 0.0,
        scrolledUnderElevation: 0.0,
        backgroundColor: inkBackgroundDark,
        foregroundColor: paperTextDark,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0.0,
        shadowColor: Colors.transparent,
        color: inkSurfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: const BorderSide(color: paperBorderDark, width: borderWidth),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0.0,
          foregroundColor: inkSurfaceDark,
          backgroundColor: paperTextDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
            side: const BorderSide(color: paperBorderDark, width: borderWidth),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: paperTextDark,
          side: const BorderSide(color: paperBorderDark, width: borderWidth),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inkSurfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: paperBorderDark, width: borderWidth),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: paperBorderDark, width: borderWidth),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: paperBorderDark, width: 2.0),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        elevation: 0.0,
        backgroundColor: inkBackgroundDark,
        indicatorColor: Color(0xFF282B30),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}

