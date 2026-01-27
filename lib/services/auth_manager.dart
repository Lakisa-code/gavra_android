import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../globals.dart';
import '../screens/welcome_screen.dart';
import '../utils/vozac_boja.dart';
import 'firebase_service.dart';
import 'huawei_push_service.dart';
import 'push_token_service.dart';

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

    // 🧹 Invalidira stari cache pre postavljanja novog
    invalidateCache();

    await _saveDriverSession(driverName);
    await FirebaseService.setCurrentDriver(driverName);

    // 📱 Ažuriraj push token u pozadini - NE BLOKIRAJ login flow
    _updatePushTokenWithUserId(driverName);

    // Postavi novi cache
    _cachedDriver = driverName;
    _cacheTime = DateTime.now();
  }

  /// 📱 Ažurira push token sa user_id i vozac_id vozača
  /// Podržava i FCM (Google) i HMS (Huawei) tokene
  static Future<void> _updatePushTokenWithUserId(String driverName) async {
    try {
      debugPrint('🔄 [AuthManager] Ažuriram token za vozača: $driverName');

      // Dohvati vozac_id iz VozacBoja cache-a
      final vozac = VozacBoja.getVozac(driverName);
      final vozacId = vozac?.id;
      debugPrint('🔄 [AuthManager] vozac_id: $vozacId');

      // 1. Pokušaj FCM token (Google/Samsung uređaji)
      final fcmToken = await FirebaseService.getFCMToken();
      if (fcmToken != null && fcmToken.isNotEmpty) {
        debugPrint('🔄 [AuthManager] FCM token: ${fcmToken.substring(0, 30)}...');
        final success = await PushTokenService.registerToken(
          token: fcmToken,
          provider: 'fcm',
          userType: 'vozac',
          userId: driverName,
          vozacId: vozacId,
        );
        debugPrint('🔄 [AuthManager] FCM registracija: ${success ? "USPEH" : "NEUSPEH"}');
      }

      // 2. Pokušaj HMS token (Huawei uređaji)
      // HMS token se dobija kroz initialize() ili stream, pa ažuriramo postojeći
      try {
        final hmsToken = await HuaweiPushService().initialize();
        if (hmsToken != null && hmsToken.isNotEmpty) {
          debugPrint('🔄 [AuthManager] HMS token: ${hmsToken.substring(0, 30)}...');
          final success = await PushTokenService.registerToken(
            token: hmsToken,
            provider: 'huawei',
            userType: 'vozac',
            userId: driverName,
            vozacId: vozacId,
          );
          debugPrint('🔄 [AuthManager] HMS registracija: ${success ? "USPEH" : "NEUSPEH"}');
        }
      } catch (e) {
        // HMS nije dostupan na ovom uređaju - OK
        debugPrint('🔄 [AuthManager] HMS nije dostupan: $e');
      }
    } catch (e) {
      debugPrint('❌ [AuthManager] Greška pri ažuriranju tokena: $e');
    }
  }

  // 🔄 Memory cache sa TTL (5 minuta)
  static String? _cachedDriver;
  static DateTime? _cacheTime;
  static const Duration _cacheTTL = Duration(minutes: 5);

  /// Dobij trenutnog vozača - ČITA IZ SUPABASE po FCM/HMS tokenu
  /// Fallback na SharedPreferences ako nema interneta
  static Future<String?> getCurrentDriver() async {
    // 1. Proveri memory cache (TTL 5 min)
    if (_cachedDriver != null && _cacheTime != null) {
      if (DateTime.now().difference(_cacheTime!) < _cacheTTL) {
        return _cachedDriver;
      }
    }

    // 2. Pokušaj iz Supabase
    try {
      final driverFromSupabase = await _getDriverFromSupabase();
      if (driverFromSupabase != null) {
        _cachedDriver = driverFromSupabase;
        _cacheTime = DateTime.now();
        // Sinhronizuj sa SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_driverKey, driverFromSupabase);
        return driverFromSupabase;
      }
    } catch (e) {
      debugPrint('⚠️ [AuthManager] Supabase nedostupan: $e');
    }

    // 3. Fallback na SharedPreferences (offline mod)
    final prefs = await SharedPreferences.getInstance();
    final localDriver = prefs.getString(_driverKey);
    if (localDriver != null) {
      _cachedDriver = localDriver;
      _cacheTime = DateTime.now();
    }
    return localDriver;
  }

  /// 🔍 Dohvati vozača iz Supabase po FCM/HMS tokenu
  static Future<String?> _getDriverFromSupabase() async {
    // Dobij trenutni FCM token
    String? token;

    try {
      token = await FirebaseService.getFCMToken();

      // Ako nema FCM, probaj HMS (Huawei) - koristi cached token
      if (token == null || token.isEmpty) {
        try {
          // 🛡️ KORISTI CACHED TOKEN umesto initialize() da izbegneš beskonačnu petlju
          token = HuaweiPushService().cachedToken;
        } catch (_) {
          // HMS nije dostupan
        }
      }

      if (token == null || token.isEmpty) {
        debugPrint('⚠️ [AuthManager] Nema FCM/HMS tokena');
        return null;
      }

      // Query push_tokens po tokenu - zaštiti pristup preko globalnog gettera
      try {
        final response = await supabase
            .from('push_tokens')
            .select('user_id')
            .eq('token', token)
            .eq('user_type', 'vozac')
            .maybeSingle();

        if (response != null && response['user_id'] != null) {
          final userId = response['user_id'] as String;
          debugPrint('✅ [AuthManager] Vozač iz Supabase: $userId');
          return userId;
        }
      } catch (supabaseError) {
        // Supabase nije inicijalizovan ili je nedostupan
        debugPrint('⚠️ [AuthManager] Supabase greška: $supabaseError');
        return null;
      }

      return null;
    } catch (e) {
      debugPrint('❌ [AuthManager] Greška pri čitanju iz Supabase: $e');
      return null;
    }
  }

  /// 🧹 Invalidira cache (pozovi nakon login/logout)
  static void invalidateCache() {
    _cachedDriver = null;
    _cacheTime = null;
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

      // 🧹 Invalidira memory cache
      invalidateCache();

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
