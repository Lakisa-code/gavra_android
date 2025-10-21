import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/welcome_screen.dart';
import 'analytics_service.dart';
import 'firebase_service.dart';

/// 🔐 CENTRALIZOVANI AUTH MANAGER
/// Upravlja svim auth operacijama kroz Supabase Auth
class AuthManager {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Unified SharedPreferences key
  static const String _driverKey = 'current_driver';
  static const String _authSessionKey = 'auth_session';

  /// 📧 EMAIL AUTHENTICATION

  /// Registracija vozača sa email-om
  static Future<AuthResult> registerWithEmail(
    String driverName,
    String email,
    String password,
  ) async {
    try {
      if (!_isValidEmail(email)) {
        return AuthResult.error('Nevaljan format email-a');
      }

      final AuthResponse response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'driver_name': driverName,
          'display_name': driverName,
        },
      );

      if (response.user != null) {
        await _saveDriverSession(driverName);
        await AnalyticsService.logVozacPrijavljen(driverName);
        return AuthResult.success('Uspešna registracija');
      } else {
        return AuthResult.error('Registracija neuspešna');
      }
    } catch (e) {
      return AuthResult.error('Greška pri registraciji: ${e.toString()}');
    }
  }

  /// Prijava vozača sa email-om
  static Future<AuthResult> signInWithEmail(
    String email,
    String password,
  ) async {
    try {
      if (!_isValidEmail(email)) {
        return AuthResult.error('Nevaljan format email-a');
      }

      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        final driverName =
            (response.user!.userMetadata?['driver_name'] as String?) ?? response.user!.email?.split('@')[0] ?? 'Vozač';

        await _saveDriverSession(driverName);
        await AnalyticsService.logVozacPrijavljen(driverName);
        return AuthResult.success('Uspešna prijava');
      } else {
        return AuthResult.error('Prijava neuspešna');
      }
    } catch (e) {
      return AuthResult.error('Greška pri prijavi: ${e.toString()}');
    }
  }

  /// 🚗 DRIVER SESSION MANAGEMENT

  /// Postavi trenutnog vozača (bez email auth-a)
  static Future<void> setCurrentDriver(String driverName) async {
    await _saveDriverSession(driverName);
    await FirebaseService.setCurrentDriver(driverName);
    await AnalyticsService.logVozacPrijavljen(driverName);
  }

  /// Dobij trenutnog vozača
  static Future<String?> getCurrentDriver() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_driverKey);
  }

  /// 🚪 LOGOUT FUNCTIONALITY

  /// Centralizovan logout - briše sve session podatke
  static Future<void> logout(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentDriver = prefs.getString(_driverKey);

      // 1. Obriši Supabase session
      await _supabase.auth.signOut();

      // 2. Obriši SharedPreferences
      await prefs.remove(_driverKey);
      await prefs.remove('selected_driver'); // Legacy key cleanup
      await prefs.remove(_authSessionKey);

      // 3. Očisti Firebase session
      await FirebaseService.clearCurrentDriver();

      // 4. Analytics
      if (currentDriver != null) {
        await AnalyticsService.logVozacOdjavljen(currentDriver);
      }

      // 5. Navigiraj na WelcomeScreen
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute<void>(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      // Ignoriši greške u logout-u da ne blokira korisnika
    }
  }

  /// 🔍 STATUS CHECKS

  /// Da li je korisnik ulogovan preko email-a
  static bool isEmailAuthenticated() {
    return _supabase.auth.currentUser != null;
  }

  /// Da li je postavljan bilo koji vozač
  static Future<bool> hasActiveDriver() async {
    final driver = await getCurrentDriver();
    return driver != null && driver.isNotEmpty;
  }

  /// Dobij trenutnog auth korisnika
  static User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  /// 🛠️ HELPER METHODS

  static bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  static Future<void> _saveDriverSession(String driverName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_driverKey, driverName);
    await prefs.setString(_authSessionKey, DateTime.now().toIso8601String());
  }

  /// 🔄 MIGRATION HELPERS

  /// Pomoćna funkcija za migraciju starih session podataka
  static Future<void> migrateOldSessions() async {
    final prefs = await SharedPreferences.getInstance();

    // Migriraj selected_driver -> current_driver
    final oldDriver = prefs.getString('selected_driver');
    if (oldDriver != null) {
      await prefs.setString(_driverKey, oldDriver);
      await prefs.remove('selected_driver');
    }
  }
}

/// 📊 AUTH RESULT CLASS
class AuthResult {
  AuthResult.success(this.message) : isSuccess = true;
  AuthResult.error(this.message) : isSuccess = false;
  final bool isSuccess;
  final String message;
}
