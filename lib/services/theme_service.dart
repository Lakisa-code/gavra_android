import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';
import 'analytics_service.dart';

class ThemeService {
  static const String _kljucTeme = 'nocni_rezim';

  /// Dohvata da li je noćni režim uključen
  static Future<bool> isNocniRezim() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kljucTeme) ?? false;
  }

  /// Postavlja noćni režim
  static Future<void> setNocniRezim(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kljucTeme, enabled);

    // 📊 Analytics - tema promenjena
    await AnalyticsService.logTemaPromenjena(enabled);
  }

  /// Prebacuje između svetle i tamne teme
  static Future<bool> toggleNocniRezim() async {
    final trenutno = await isNocniRezim();
    await setNocniRezim(!trenutno);
    return !trenutno;
  }

  /// 🎨 Kreira svetlu temu - Automatska selekcija iz 3 teme!
  /// Triple Blue Fashion / Dark Theme / Pink Svetlana
  static ThemeData svetlaTema({String? driverName}) {
    // Koristi ThemeSelector za automatsku selekciju tema
    // Ova funkcija uvek vraća svetlu temu, noćni režim se kontroliše kroz themeMode
    return ThemeSelector.getThemeForDriver(driverName);
  }

  /// 🌙 Kreira tamnu temu optimizovanu za vožnju noću
  static ThemeData tamnaTema() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      // 🎯 Tamna color scheme - SVE TAMNO sa sivom!
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        // Primary - siva za dugmad
        primary: Color(0xFF9E9E9E),
        onPrimary: Colors.white,
        primaryContainer: Color(0xFF616161),
        onPrimaryContainer: Colors.white,
        // Secondary - zelena za akcije
        secondary: Color(0xFF66BB6A),
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFF2E7D32),
        onSecondaryContainer: Color(0xFF81C784),
        // Surface - tamne pozadine
        surface: Color(0xFF121212),
        onSurface: Color(0xFFE0E0E0),
        surfaceContainerHighest: Color(0xFF1E1E1E),
        // Error
        error: Color(0xFFFF5252),
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212), // 🌙 TAMNA pozadina
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E), // 🌙 TAMNA app bar
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      // cardTheme: skipped for Flutter 3.24.3 compatibility
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9E9E9E), // Siva dugmad
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textTheme: const TextTheme(
        // SVE BELO na tamnom!
        headlineLarge: TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          color: Color(0xFFE0E0E0),
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(color: Color(0xFFE0E0E0), fontSize: 16),
        bodyMedium: TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
        bodySmall: TextStyle(color: Color(0xFF9E9E9E), fontSize: 12),
        labelLarge: TextStyle(
          color: Color(0xFFE0E0E0),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E1E1E), // 🌙 TAMNA polja
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF424242)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF424242)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF9E9E9E), width: 2),
        ),
        hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
        labelStyle: const TextStyle(color: Color(0xFF9E9E9E)),
      ),
      // dialogTheme, dividerTheme, iconTheme: skipped for Flutter 3.24.3 compatibility
    );
  }
}
