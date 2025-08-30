import 'package:shared_preferences/shared_preferences.dart';

class PasswordService {
  static const String _passwordPrefix = 'driver_password_';

  // Default šifre ako nisu postavljen custom-e
  static const Map<String, String> _defaultPasswords = {
    'Bilevski': '2222',
    'Bruda': '1111',
    'Bojan': '1919',
    'Svetlana': '0013',
  };

  /// Dohvati šifru za vozača
  static Future<String> getPassword(String driverName) async {
    final prefs = await SharedPreferences.getInstance();
    final customPassword = prefs.getString('$_passwordPrefix$driverName');

    // Ako ima custom šifru, koristi je, inače default
    return customPassword ?? _defaultPasswords[driverName] ?? '0000';
  }

  /// Postavi novu šifru za vozača
  static Future<bool> setPassword(String driverName, String newPassword) async {
    if (newPassword.trim().isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(
        '$_passwordPrefix$driverName', newPassword.trim());
  }

  /// Resetuj šifru na default
  static Future<bool> resetPassword(String driverName) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.remove('$_passwordPrefix$driverName');
  }

  /// Proveri da li vozač ima custom šifru
  static Future<bool> hasCustomPassword(String driverName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('$_passwordPrefix$driverName');
  }

  /// Dohvati sve dostupne vozače
  static List<String> getAllDrivers() {
    return _defaultPasswords.keys.toList();
  }
}
