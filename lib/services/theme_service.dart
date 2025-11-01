import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_manager.dart';

class ThemeService {
  static const String _kljucTeme = 'nocni_rezim';

  /// Dohvata da li je noćni režim uključen (deprecated - koristiti ThemeManager)
  static Future<bool> isNocniRezim() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kljucTeme) ?? false;
  }

  /// Postavlja noćni režim (deprecated - koristiti ThemeManager)
  static Future<void> setNocniRezim(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kljucTeme, enabled);
  }

  /// Prebacuje između svetle i tamne teme (deprecated - koristiti ThemeManager)
  static Future<bool> toggleNocniRezim() async {
    final trenutno = await isNocniRezim();
    await setNocniRezim(!trenutno);
    return !trenutno;
  }

  /// 🎨 Kreira svetlu temu - koristi ThemeManager
  static ThemeData svetlaTema({String? driverName}) {
    return ThemeManager().currentThemeData;
  }
}
