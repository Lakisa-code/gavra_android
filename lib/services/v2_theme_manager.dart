import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'v2_theme_registry.dart';

// THEME MANAGER - Upravljanje trenutnom temom
class ThemeManager extends ChangeNotifier {
  factory ThemeManager() => _instance;
  ThemeManager._internal() {
    _currentTheme = ThemeRegistry.getTheme(_currentThemeId) ?? ThemeRegistry.defaultTheme;
  }
  static final ThemeManager _instance = ThemeManager._internal();

  static const String _themePrefsKey = 'selected_theme_id';

  String _currentThemeId = 'triple_blue_fashion';
  ThemeDefinition? _currentTheme;
  final ValueNotifier<ThemeData> _themeNotifier = ValueNotifier(ThemeRegistry.defaultTheme.themeData);

  /// Trenutna tema ID
  String get currentThemeId => _currentThemeId;

  /// ValueNotifier za reaktivno slušanje tema
  ValueNotifier<ThemeData> get themeNotifier => _themeNotifier;

  /// Trenutna tema definicija
  ThemeDefinition get currentTheme => _currentTheme!;

  /// Trenutni ThemeData
  ThemeData get currentThemeData => currentTheme.themeData;

  /// Trenutni gradient
  LinearGradient get currentGradient => currentTheme.gradient;

  /// Trenutni gradijent za pozadinu (shortcut)
  LinearGradient get backgroundGradient => currentGradient;

  /// Initialize - učitaj poslednju selekciju
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedThemeId = prefs.getString(_themePrefsKey);

      if (savedThemeId != null && ThemeRegistry.hasTheme(savedThemeId)) {
        // Učitaj sačuvanu temu
        _currentThemeId = savedThemeId;
        _currentTheme = ThemeRegistry.getTheme(savedThemeId);
      } else {
        // Fallback na default temu
        final defaultTheme = ThemeRegistry.defaultTheme;
        _currentThemeId = defaultTheme.id;
        _currentTheme = defaultTheme;
      }
    } catch (e) {
      debugPrint('[ThemeManager] Greška pri učitavanju teme, koristi default: $e');
      final defaultTheme = ThemeRegistry.defaultTheme;
      _currentThemeId = defaultTheme.id;
      _currentTheme = defaultTheme;
    }

    _themeNotifier.value = currentThemeData; // Ažuriraj ValueNotifier
    notifyListeners();
  }

  /// Promeni temu
  Future<void> changeTheme(String themeId) async {
    if (!ThemeRegistry.hasTheme(themeId)) {
      throw Exception('Tema $themeId ne postoji!');
    }

    // Sačuvaj izbor u SharedPreferences PRE nego ažuriramo state
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themePrefsKey, themeId);
    } catch (e) {
      debugPrint('[ThemeManager] Greška pri čuvanju teme: $e');
    }

    _currentThemeId = themeId;
    _currentTheme = ThemeRegistry.getTheme(themeId);

    // Obavesti listenere
    _themeNotifier.value = currentThemeData;
    notifyListeners();
  }

  /// Sledeća tema u listi (za cycling)
  Future<void> nextTheme() async {
    final themeNames = ThemeRegistry.themeNames;
    final currentIndex = themeNames.indexOf(_currentThemeId);
    final nextIndex = (currentIndex + 1) % themeNames.length;
    await changeTheme(themeNames[nextIndex]);
  }

  @override
  void dispose() {
    _themeNotifier.dispose();
    super.dispose();
  }
}
