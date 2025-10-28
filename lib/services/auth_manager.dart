import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/welcome_screen.dart';
import 'analytics_service.dart';
import 'firebase_auth_service.dart';
import 'firebase_service.dart';

/// � CENTRALIZOVANI AUTH MANAGER - FIREBASE EDITION
/// Upravlja svim auth operacijama kroz Firebase Auth + Supabase podatke
class AuthManager {
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

      final authResult = await FirebaseAuthService.registerWithEmail(
        email: email,
        password: password,
        vozacName: driverName,
      );

      if (authResult.isSuccess) {
        await _saveDriverSession(driverName);
        await AnalyticsService.logVozacPrijavljen(driverName);
        return AuthResult.success(authResult.message);
      } else {
        return AuthResult.error(authResult.message);
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

      final authResult = await FirebaseAuthService.signInWithEmail(
        email: email,
        password: password,
      );

      if (authResult.isSuccess && authResult.user != null) {
        final driverName = authResult.user!.displayName ?? authResult.user!.email?.split('@')[0] ?? 'Vozač';

        await _saveDriverSession(driverName);
        await AnalyticsService.logVozacPrijavljen(driverName);
        return AuthResult.success(authResult.message);
      } else {
        return AuthResult.error(authResult.message);
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

      // 1. Obriši Firebase Auth session
      await FirebaseAuthService.signOut();

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
    return FirebaseAuthService.isLoggedIn;
  }

  /// 🔒 Da li je email potvrđen
  static bool isEmailVerified() {
    return FirebaseAuthService.isEmailVerified;
  }

  /// Da li je postavljan bilo koji vozač
  static Future<bool> hasActiveDriver() async {
    final driver = await getCurrentDriver();
    return driver != null && driver.isNotEmpty;
  }

  /// Dobij trenutnog auth korisnika
  static firebase_auth.User? getCurrentUser() {
    return FirebaseAuthService.currentUser;
  }

  /// 📧 EMAIL VERIFICATION METHODS

  /// Ponovno slanje email verifikacije
  static Future<AuthResult> resendEmailVerification() async {
    try {
      final result = await FirebaseAuthService.resendEmailVerification();
      return result.isSuccess ? AuthResult.success(result.message) : AuthResult.error(result.message);
    } catch (e) {
      return AuthResult.error('Greška pri slanju verifikacije: ${e.toString()}');
    }
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
