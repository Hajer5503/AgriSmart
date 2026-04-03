import 'package:flutter/material.dart';

class AppTheme {
  // 🎨 Palette inspirée du liquid glass (tons verts naturels)
  static const Color greenDark = Color(0xFF0D5020);
  static const Color greenPrimary = Color(0xFF34C759);
  static const Color greenLight = Color(0xFF4CD964);
  static const Color greenAccent = Color(0xFF30D158);
  
  // Couleurs de fond avec effet glassmorphism
  static const Color glassBackground = Color(0xFFF5FFF7);
  static const Color glassSurface = Color(0xFFFAFFFB);
  static const Color glassBorder = Color(0xFFD0F0D8);
  
  // Couleurs pour les cartes
  static const Color cardGreen = Color(0xFFE8F9ED);
  static const Color cardWhite = Color(0xFFFFFFFF);

  static ThemeData light() {
    final scheme = ColorScheme(
      brightness: Brightness.light,
      
      primary: greenPrimary,
      onPrimary: Colors.white,
      primaryContainer: cardGreen,
      onPrimaryContainer: greenDark,
      
      secondary: greenLight,
      onSecondary: Colors.white,
      secondaryContainer: glassBackground,
      onSecondaryContainer: greenDark,
      
      tertiary: greenAccent,
      onTertiary: Colors.white,
      tertiaryContainer: glassSurface,
      onTertiaryContainer: greenDark,
      
      surface: cardWhite,
      onSurface: Color(0xFF1C1C1E),
      
      surfaceContainerHighest: glassSurface,
      onSurfaceVariant: Color(0xFF3C3C43).withValues(alpha: 0.6),
      
      outline: glassBorder,
      error: Color(0xFFFF3B30),
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: glassBackground,
      
      // AppBar avec effet glassmorphism
      appBarTheme: AppBarTheme(
        backgroundColor: glassSurface.withValues(alpha: 0.8),
        foregroundColor: greenDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: greenDark,
          letterSpacing: -0.5,
        ),
      ),
      
      // Cards avec effet glass
      cardTheme: CardThemeData(
        color: cardWhite.withValues(alpha: 0.7),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
      ),
      
      // Boutons avec effet iOS
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: greenPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
          ),
        ),
      ),
      
      // FloatingActionButton iOS style
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: greenPrimary,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      
      // NavigationBar avec effet glass
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardWhite.withValues(alpha: 0.8),
        indicatorColor: greenPrimary.withValues(alpha: 0.15),
        elevation: 0,
        height: 70,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: -0.2,
            );
          }
          return const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
            letterSpacing: -0.2,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: greenPrimary, size: 26);
          }
          return IconThemeData(color: Color(0xFF3C3C43).withValues(alpha: 0.5), size: 24);
        }),
      ),
      
      // Input decoration iOS style
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glassSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: glassBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: glassBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: greenPrimary, width: 2),
        ),
        labelStyle: TextStyle(
          color: Color(0xFF3C3C43).withValues(alpha: 0.6),
          fontSize: 16,
          letterSpacing: -0.3,
        ),
      ),
      
      // Typography iOS style
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
          height: 1.2,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.3,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        bodyLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.4,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.3,
        ),
        labelLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
      ),
    );
  }
}
