import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'cache_service.dart';
import 'supabase_manager.dart';

/// 🚀 OPTIMIZOVANI KUSUR SERVIS
/// Rešava probleme duplog čuvanja i suvišne kompleksnosti
class OptimizedKusurService {
  static final StreamController<Map<String, double>> _kusurController =
      StreamController<Map<String, double>>.broadcast();

  /// 🎯 JEDNOSTAVNA STRATEGIJA: Baza -> Cache -> SharedPreferences
  static Future<double> getKusurForVozac(String vozacIme) async {
    try {
      // 1. CACHE PRVI (najbrži)
      final cacheKey = 'kusur_$vozacIme';
      final cached = CacheService.getFromMemory<double>(cacheKey);

      if (cached != null) {
      // Debug logging removed for production
return cached;
      }

      // 2. BAZA DRUGI (autoritativni izvor)
      final response = await SupabaseManager.safeSelect(
        'vozaci',
        columns: 'kusur',
        filters: {'ime': vozacIme},
      );

      if (response.isNotEmpty && response.first['kusur'] != null) {
        final kusur = (response.first['kusur'] as num).toDouble();

        // Sačuvaj u cache za buduće pozive
        CacheService.saveToMemory(cacheKey, kusur);
      // Debug logging removed for production
return kusur;
      }

      // 3. SHARED PREFERENCES FALLBACK (offline mode)
      final prefs = await SharedPreferences.getInstance();
      final fallback = prefs.getDouble('kusur_$vozacIme') ?? 0.0;

      if (fallback > 0) {
      // Debug logging removed for production
return fallback;
      }

      return 0.0;
    } catch (e) {
      // Debug logging removed for production
// EMERGENCY FALLBACK
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getDouble('kusur_$vozacIme') ?? 0.0;
      } catch (_) {
        return 0.0;
      }
    }
  }

  /// 💾 OPTIMIZOVANO ČUVANJE: Baza + Cache + Lokalno backup
  static Future<bool> updateKusurForVozac(String vozacIme, double novKusur) async {
    try {
      // 1. POKUŠAJ BAZU PRVI (glavni izvor istine)
      final response = await SupabaseManager.safeUpdateWithReturn(
        'vozaci',
        {'kusur': novKusur},
        {'ime': vozacIme},
      );

      if (response.isNotEmpty) {
        // SUCCESS - ažuriraj cache i lokalno
        final cacheKey = 'kusur_$vozacIme';
        CacheService.saveToMemory(cacheKey, novKusur);

        // Backup u SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('kusur_$vozacIme', novKusur);

        // Emituj stream update
        _kusurController.add({vozacIme: novKusur});
      // Debug logging removed for production
return true;
      }

      throw Exception('Database update failed');
    } catch (e) {
      // Debug logging removed for production
// FALLBACK: Sačuvaj samo lokalno
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('kusur_$vozacIme', novKusur);
        await prefs.setBool('kusur_${vozacIme}_pending_sync', true);
      // Debug logging removed for production
return false; // Označava da je samo lokalno sačuvano
      } catch (_) {
        return false;
      }
    }
  }

  /// 🔄 SYNC PENDING CHANGES (pozovi periodično)
  static Future<void> syncPendingChanges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.endsWith('_pending_sync')).toList();

      for (final key in keys) {
        final vozacIme = key.replaceAll('kusur_', '').replaceAll('_pending_sync', '');
        final pendingValue = prefs.getDouble('kusur_$vozacIme');

        if (pendingValue != null) {
          final success = await updateKusurForVozac(vozacIme, pendingValue);
          if (success) {
            // Ukloni pending flag ako je sync uspešan
            await prefs.remove(key);
      // Debug logging removed for production
}
        }
      }
    } catch (e) {
      // Debug logging removed for production
}
  }

  /// 📡 STREAM ZA REAL-TIME UPDATES
  static Stream<double> streamKusurForVozac(String vozacIme) async* {
    // Prvo vrati trenutnu vrednost
    final trenutni = await getKusurForVozac(vozacIme);
    yield trenutni;

    // Zatim slušaj za updates
    await for (final kusurMapa in _kusurController.stream) {
      if (kusurMapa.containsKey(vozacIme)) {
        yield kusurMapa[vozacIme]!;
      }
    }
  }

  /// 🧹 CLEANUP METODA
  static Future<void> cleanup() async {
    // Očisti stari cache
    CacheService.performAutomaticCleanup();

    // Sync any pending changes
    await syncPendingChanges();
  }
}
