import 'dart:io';

class GBoxDetector {
  static bool? _isInGBox;

  /// Detektuje da li aplikacija radi u GBox kontejneru
  static Future<bool> isRunningInGBox() async {
    if (_isInGBox != null) return _isInGBox!;

    try {
      // Metoda 1: Provjeri da li postoji GBox aplikacija na uređaju
      if (Platform.isAndroid) {
        try {
          final process =
              await Process.run('pm', ['list', 'packages', 'com.gbox.android']);
          if (process.stdout.toString().contains('com.gbox.android')) {
            _isInGBox = true;
            return true;
          }
        } catch (_) {
          // Fallback ako pm komanda ne radi
        }
      }

      // Metoda 2: Proveri environment varijable
      final isGBox = Platform.environment['GBOX_RUNTIME'] == '1';

      // Metoda 3: Jednostavna heuristika - ako je Huawei uređaj i nema greške sa Google Services
      if (!isGBox) {
        final brand = Platform.environment['ro.product.brand'] ?? '';
        if (brand.toLowerCase().contains('huawei')) {
          // Na Huawei uređaju, pretpostavi GBox ako nema očiglednih problema
          _isInGBox = false; // Konzervativno - bolje je biti siguran
          return false;
        }
      }

      _isInGBox = isGBox;
      return isGBox;
    } catch (e) {
      _isInGBox = false;
      return false;
    }
  }

  /// Prilagodi ponašanje aplikacije na osnovu GBox statusa
  static Future<void> configureForEnvironment() async {
    final inGBox = await isRunningInGBox();

    if (inGBox) {
      // GBox detektovan - koristi Google Services
    } else {
      // Native Huawei - koristi Huawei Services
    }
  }

  /// Jednostavan getter za konfiguraciju
  static Future<bool> shouldUseGoogleServices() async {
    return await isRunningInGBox();
  }

  /// Da li koristiti Firebase optimizovano
  static Future<bool> shouldOptimizeFirebase() async {
    final inGBox = await isRunningInGBox();
    return inGBox; // U GBox-u Firebase radi bolje
  }
}
