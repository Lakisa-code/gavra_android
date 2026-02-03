import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🔐 BIOMETRIC SERVICE
/// Servis za biometrijsku autentifikaciju (otisak prsta, Face ID)
class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // Ključevi za storage
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _savedPhoneKey = 'biometric_saved_phone';
  static const String _savedPinKey = 'biometric_saved_pin';

  /// Proveri da li uređaj podržava biometriju
  static Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  /// Proveri da li uređaj ima upisane biometrijske podatke
  static Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  /// Dobij listu dostupnih biometrijskih tipova
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Da li je biometrija dostupna (uređaj podržava + ima upisane podatke)
  static Future<bool> isBiometricAvailable() async {
    final isSupported = await isDeviceSupported();
    final canCheck = await canCheckBiometrics();
    return isSupported && canCheck;
  }

  /// Da li je biometrija uključena za korisnika
  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  /// Uključi/isključi biometriju
  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);

    if (!enabled) {
      // Obriši sačuvane kredencijale
      await _secureStorage.delete(key: _savedPhoneKey);
      await _secureStorage.delete(key: _savedPinKey);
    }
  }

  /// Sačuvaj kredencijale za biometrijsku prijavu
  static Future<void> saveCredentials({
    required String phone,
    required String pin,
  }) async {
    await _secureStorage.write(key: _savedPhoneKey, value: phone);
    await _secureStorage.write(key: _savedPinKey, value: pin);
    await setBiometricEnabled(true);
  }

  /// Dobij sačuvane kredencijale
  static Future<Map<String, String>?> getSavedCredentials() async {
    final phone = await _secureStorage.read(key: _savedPhoneKey);
    final pin = await _secureStorage.read(key: _savedPinKey);

    if (phone != null && pin != null) {
      return {'phone': phone, 'pin': pin};
    }
    return null;
  }

  /// Obriši sačuvane kredencijale
  static Future<void> clearCredentials() async {
    await _secureStorage.delete(key: _savedPhoneKey);
    await _secureStorage.delete(key: _savedPinKey);
    await setBiometricEnabled(false);
  }

  /// Autentifikuj korisnika biometrijom
  /// Vraća true ako je uspešno, false ako nije
  static Future<bool> authenticate({
    String reason = 'Prijavite se otiskom prsta',
  }) async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) return false;

      return await _auth.authenticate(
        localizedReason: reason,
      );
    } on PlatformException {
      // Biometric auth failed silently
      return false;
    }
  }

  /// Dobij tekst za tip biometrije (za UI)
  static Future<String> getBiometricTypeText() async {
    final types = await getAvailableBiometrics();

    if (types.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (types.contains(BiometricType.fingerprint)) {
      return 'otisak prsta';
    } else if (types.contains(BiometricType.iris)) {
      return 'iris';
    } else if (types.contains(BiometricType.strong) || types.contains(BiometricType.weak)) {
      return 'biometriju';
    }
    return 'biometriju';
  }

  /// Dobij ikonu za tip biometrije
  static Future<String> getBiometricIcon() async {
    final types = await getAvailableBiometrics();

    if (types.contains(BiometricType.face)) {
      return '😊'; // Face ID
    } else if (types.contains(BiometricType.fingerprint)) {
      return '👆'; // Fingerprint
    }
    return '🔐';
  }
}
