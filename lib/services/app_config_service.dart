import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';

/// ⚙️ APP CONFIG SERVICE
/// Upravlja konfiguracijom aplikacije koja se može menjati dinamički
/// BEZ potrebe za izmenom koda i novom verzijom aplikacije.
class AppConfigService {
  static SupabaseClient get _supabase => supabase;

  // Singleton
  static final AppConfigService _instance = AppConfigService._internal();
  factory AppConfigService() => _instance;
  AppConfigService._internal();

  // 📝 LOCAL DEFAULTS (Ako baza nije dostupna)
  static const int _defaultSqueezeInLimit = 4; // Granica za "Drugi kombi"
  static const int _defaultBusCapacity = 15; // Standardni kapacitet
  static const int _defaultCancelLimitHours = 2; // Koliko sati pre može da se otkaže

  // 🗄️ CACHED CONFIG
  final Map<String, dynamic> _configCache = {};

  /// Učitava konfiguraciju iz baze pri startu aplikacije
  Future<void> loadConfig() async {
    try {
      final response = await _supabase.from('app_config').select();
      if (response.isNotEmpty) {
        // Pretvaramo listu [{key: "limit", value: 4}] u mapu {"limit": 4}
        for (var row in response) {
          if (row['key'] != null && row['value'] != null) {
            _configCache[row['key']] = row['value'];
          }
        }
      }
    } catch (e) {
      // Fallback na defaulte ako tabela ne postoji ili nema neta
      print('⚠️ Greška pri učitavanju konfiguracije: $e');
    }
  }

  /// 🔢 LIMIT ZA DRUGI KOMBI (Squeeze-in Limit)
  /// Koliko ljudi na čekanju aktivira "Ljubičasti mod"?
  int get squeezeInLimit => int.tryParse(_configCache['squeeze_in_limit']?.toString() ?? '') ?? _defaultSqueezeInLimit;

  /// 🚌 STANDARDNI KAPACITET
  int get defaultCapacity => int.tryParse(_configCache['default_capacity']?.toString() ?? '') ?? _defaultBusCapacity;

  /// ⏰ ROK ZA OTKAZIVANJE (u satima)
  int get cancelLimitHours =>
      int.tryParse(_configCache['cancel_limit_hours']?.toString() ?? '') ?? _defaultCancelLimitHours;
}
