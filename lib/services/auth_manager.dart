import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../globals.dart';
import '../screens/welcome_screen.dart';
import '../utils/vozac_boja.dart';
import 'firebase_service.dart';

/// 🔐 CENTRALIZOVANI AUTH MANAGER
/// Upravlja lokalnim auth operacijama kroz SharedPreferences
/// Koristi device recognition i session management bez Supabase Auth
class AuthManager {
  // Unified SharedPreferences key
  static const String _driverKey = 'current_driver';
  static const String _authSessionKey = 'auth_session';
  static const String _deviceIdKey = 'device_id';
  static const String _rememberedDevicesKey = 'remembered_devices';

  /// 🚗 DRIVER SESSION MANAGEMENT

  /// Postavi trenutnog vozača (bez email auth-a)
  static Future<void> setCurrentDriver(String driverName) async {
    // Validacija da je vozač prepoznat
    if (!VozacBoja.isValidDriver(driverName)) {
      throw ArgumentError('Vozač "$driverName" nije registrovan');
    }
    await _saveDriverSession(driverName);
    await FirebaseService.setCurrentDriver(driverName);
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
    // 🔧 FIX: Koristi GLOBALNI navigatorKey umesto context-a
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    // Prikaži loading
    showDialog<void>(
      context: navigator.context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Obriši SharedPreferences - SVE session podatke uključujući zapamćene uređaje
      await prefs.remove(_driverKey);
      await prefs.remove(_authSessionKey);
      await prefs.remove(_rememberedDevicesKey);

      // 3. Očisti Firebase session (ako postoji)
      try {
        await FirebaseService.clearCurrentDriver();
      } catch (_) {}

      // 4. Zatvori loading i navigiraj
      navigator.pop();
      navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } catch (_) {
      // Logout greška - svejedno navigiraj na welcome
      try {
        navigator.pop(); // Zatvori loading
      } catch (_) {}
      navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }

  /// 🔍 STATUS CHECKS

  /// Da li je postavljan bilo koji vozač
  static Future<bool> hasActiveDriver() async {
    final driver = await getCurrentDriver();
    return driver != null && driver.isNotEmpty;
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
