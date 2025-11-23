import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/welcome_screen.dart';
import '../utils/vozac_boja.dart';
import 'analytics_service.dart';
import 'firebase_service.dart';

/// � CENTRALIZOVANI AUTH MANAGER - SUPABASE EDITION
/// Upravlja svim auth operacijama kroz Supabase Auth + Supabase podatke
class AuthManager {
  // Unified SharedPreferences key
  static const String _driverKey = 'current_driver';
  static const String _authSessionKey = 'auth_session';
  static const String _deviceIdKey = 'device_id';
  static const String _rememberedDevicesKey = 'remembered_devices';

  /// 📧 EMAIL AUTHENTICATION

  /// Registracija vozača sa email-om
  static Future<AuthResult> registerWithEmail(
    String driverName,
    String email,
    String password, {
    bool remember = true,
  }) async {
    try {
      if (!_isValidEmail(email)) {
        return AuthResult.error('Nevaljan format email-a');
      }

      // 🔒 VALIDACIJA: Email mora biti dozvoljen za vozača
      if (!VozacBoja.isEmailDozvoljenForVozac(email, driverName)) {
        return AuthResult.error(
          'Email $email nije dozvoljen za vozača $driverName',
        );
      }

      // 1. Kreiranje korisnika u Supabase Auth
      final authResponse = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        return AuthResult.error('Registracija nije uspela');
      }

      // 2. Postavljanje display name-a
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {'display_name': driverName},
        ),
      );

      // 3. Kreiranje profila u Supabase
      await _createUserProfileInSupabase(
        supabaseUid: authResponse.user!.id,
        email: email,
        vozacName: driverName,
      );

      await _saveDriverSession(driverName);
      // 📱 AUTOMATSKI ZAPAMTI UREĐAJ posle uspešne registracije (ako je traženo)
      if (remember) await rememberDevice(email, driverName);
      await AnalyticsService.logVozacPrijavljen(driverName);

      return AuthResult.success('Registracija uspešna! Proverite svoj email za confirmation link.');
    } catch (e) {
      return AuthResult.error('Greška pri registraciji: ${e.toString()}');
    }
  }

  /// Prijava vozača sa email-om
  static Future<AuthResult> signInWithEmail(
    String email,
    String password, {
    bool remember = true,
  }) async {
    try {
      if (!_isValidEmail(email)) {
        return AuthResult.error('Nevaljan format email-a');
      }

      // Prijava u Supabase Auth
      final authResponse = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.user != null) {
        // 🔄 PRIORITET: Koristi VozacBoja mapiranje za email -> vozač ime
        String? driverName = VozacBoja.getVozacForEmail(authResponse.user!.email);
        if (driverName == null || !VozacBoja.isValidDriver(driverName)) {
          return AuthResult.error('Niste ovlašćeni za pristup aplikaciji');
        }

        await _saveDriverSession(driverName);
        // 📱 AUTOMATSKI ZAPAMTI UREĐAJ posle uspešnog login-a (ako je traženo)
        if (remember) await rememberDevice(email, driverName);
        await AnalyticsService.logVozacPrijavljen(driverName);

        return AuthResult.success('Uspešno ulogovanje!');
      } else {
        return AuthResult.error('Prijava nije uspela');
      }
    } catch (e) {
      return AuthResult.error('Greška pri prijavi: ${e.toString()}');
    }
  }

  /// 🚗 DRIVER SESSION MANAGEMENT

  /// Postavi trenutnog vozača (bez email auth-a)
  static Future<void> setCurrentDriver(String driverName) async {
    // Validacija da je vozač prepoznat
    if (!VozacBoja.isValidDriver(driverName)) {
      throw ArgumentError('Nepoznat vozač: $driverName');
    }
    await _saveDriverSession(driverName);
    await FirebaseService.setCurrentDriver(driverName);
    await AnalyticsService.logVozacPrijavljen(driverName);
    // Push service removed - using only realtime notifications
  }

  /// Dobij trenutnog vozača
  static Future<String?> getCurrentDriver() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_driverKey);
  }

  /// 🚪 LOGOUT FUNCTIONALITY

  /// Centralizovan logout - briše sve session podatke
  static Future<void> logout(BuildContext context) async {
    // Prikaži loading
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentDriver = prefs.getString(_driverKey);

      // 1. Obriši Supabase Auth session
      await Supabase.instance.client.auth.signOut();

      // 2. Obriši SharedPreferences - ali sačuvaj zapamćene uređaje
      // Ukloni jedino active session ključeve
      await prefs.remove(_driverKey);
      await prefs.remove(_authSessionKey);

      // 3. Očisti Firebase session (ako postoji)
      try {
        await FirebaseService.clearCurrentDriver();
        // Push service removed - using only realtime notifications
        // Firebase Messaging removed - using Supabase realtime
      } catch (e) {
        // Firebase clear greška
      }

      // 4. Analytics
      if (currentDriver != null) {
        try {
          await AnalyticsService.logVozacOdjavljen(currentDriver);
        } catch (e) {
          // Analytics greška
        }
      }

      // 5. Zatvori loading i navigiraj
      if (context.mounted) {
        Navigator.of(context).pop(); // Zatvori loading
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute<void>(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      // Logout greška
      // Zatvori loading čak i ako ima greška
      if (context.mounted) {
        Navigator.of(context).pop();
        // Forsiraj navigaciju na welcome screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute<void>(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );
      }
    }
  }

  /// 🔍 STATUS CHECKS

  /// Da li je korisnik ulogovan preko email-a
  static bool isEmailAuthenticated() {
    return Supabase.instance.client.auth.currentUser != null;
  }

  /// 🔒 Da li je email potvrđen
  static bool isEmailVerified() {
    return Supabase.instance.client.auth.currentUser?.emailConfirmedAt != null;
  }

  /// Da li je postavljan bilo koji vozač
  static Future<bool> hasActiveDriver() async {
    final driver = await getCurrentDriver();
    return driver != null && driver.isNotEmpty;
  }

  /// Dobij trenutnog auth korisnika
  static User? getCurrentUser() {
    return Supabase.instance.client.auth.currentUser;
  }

  /// 📧 EMAIL VERIFICATION METHODS

  /// Ponovno slanje email verifikacije
  static Future<AuthResult> resendEmailVerification() async {
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.email,
        email: Supabase.instance.client.auth.currentUser?.email,
      );
      return AuthResult.success('Novi confirmation link je poslat na vaš email');
    } catch (e) {
      return AuthResult.error('Greška pri slanju verifikacije: ${e.toString()}');
    }
  }

  /// 🛠️ HELPER METHODS

  static bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  /// Public helper kept for compatibility with previous Firebase API calls
  static bool isValidEmailFormat(String email) => _isValidEmail(email);

  static Future<void> _saveDriverSession(String driverName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_driverKey, driverName);
    await prefs.setString(_authSessionKey, DateTime.now().toIso8601String());
  }

  /// 🗄️ SUPABASE INTEGRATION

  /// Kreiranje korisničkog profila u Supabase
  static Future<void> _createUserProfileInSupabase({
    required String supabaseUid,
    required String email,
    required String vozacName,
  }) async {
    try {
      await Supabase.instance.client.from('korisnici').insert({
        'supabase_uid': supabaseUid,
        'email': email,
        'vozac_name': vozacName,
        'created_at': DateTime.now().toIso8601String(),
        'is_active': true,
      });
    } catch (e) {
      // Log greška ali ne prekidaj registraciju
      // Supabase sync nije kritičan za registraciju
    }
  }

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

  /// 📱 DEVICE RECOGNITION

  /// Generiše jedinstveni device ID
  static Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null) {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = '${androidInfo.id}_${androidInfo.model}_${androidInfo.brand}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = '${iosInfo.identifierForVendor}_${iosInfo.model}';
      } else {
        deviceId = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
      }

      await prefs.setString(_deviceIdKey, deviceId);
    }

    return deviceId;
  }

  /// Zapamti ovaj uređaj za automatski login
  static Future<void> rememberDevice(String email, String driverName) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await _getDeviceId();

    // Format: "deviceId:email:driverName"
    final deviceInfo = '$deviceId:$email:$driverName';

    // Sačuvaj u listi zapamćenih uređaja
    final rememberedDevices = prefs.getStringList(_rememberedDevicesKey) ?? [];

    // Ukloni stari entry za isti email ako postoji
    rememberedDevices.removeWhere((device) => device.contains(':$email:'));

    // Dodaj novi
    rememberedDevices.add(deviceInfo);

    await prefs.setStringList(_rememberedDevicesKey, rememberedDevices);
  }

  /// Proveri da li je ovaj uređaj zapamćen
  static Future<Map<String, String>?> getRememberedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await _getDeviceId();
    final rememberedDevices = prefs.getStringList(_rememberedDevicesKey) ?? [];

    for (final deviceInfo in rememberedDevices) {
      final parts = deviceInfo.split(':');
      if (parts.length == 3 && parts[0] == deviceId) {
        return {
          'email': parts[1],
          'driverName': parts[2],
        };
      }
    }

    return null;
  }

  /// Zaboravi ovaj uređaj
  static Future<void> forgetDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await _getDeviceId();
    final rememberedDevices = prefs.getStringList(_rememberedDevicesKey) ?? [];

    // Ukloni sve entries za ovaj device ID
    rememberedDevices.removeWhere((device) => device.startsWith('$deviceId:'));

    await prefs.setStringList(_rememberedDevicesKey, rememberedDevices);
  }
}

/// 📊 AUTH RESULT CLASS
class AuthResult {
  AuthResult.success([this.message = '']) : isSuccess = true;
  AuthResult.error(this.message) : isSuccess = false;
  final bool isSuccess;
  final String message;
}
