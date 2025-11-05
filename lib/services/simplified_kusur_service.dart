import 'dart:async';

import '../globals.dart';
import 'cache_service.dart';
import 'supabase_manager.dart';

/// JEDNOSTAVAN KUSUR SERVIS - Bez mapiranja, direktno po imenima vozača
/// OPTIMIZOVAN sa SupabaseManager za connection pooling
class SimplifiedKusurService {
  /// Stream controller za real-time ažuriranje kusur kocki
  static final StreamController<Map<String, double>> _kusurController =
      StreamController<Map<String, double>>.broadcast();

  /// Dobij kusur za određenog vozača iz baze - OPTIMIZOVANO
  static Future<double> getKusurForVozac(String vozacIme) async {
    try {
      // CACHE OPTIMIZOVANO - prvo pokušaj iz cache
      final cacheKey = 'kusur_vozac_$vozacIme';
      final cached = CacheService.getFromMemory<double>(
        cacheKey,
        maxAge: const Duration(minutes: 2),
      );

      if (cached != null) {
        // Debug logging removed for production
        return cached;
      }
      // Debug logging removed for production
// OPTIMIZOVANO sa SupabaseManager
      final response = await SupabaseManager.safeSelect(
        'vozaci',
        columns: 'kusur',
        filters: {'ime': vozacIme},
      );

      if (response.isNotEmpty && response.first['kusur'] != null) {
        final kusur = (response.first['kusur'] as num).toDouble();

        // Sačuvaj u cache
        CacheService.saveToMemory(cacheKey, kusur);
        // Debug logging removed for production
        return kusur;
      }
      // Debug logging removed for production
      return 0.0;
    } catch (e) {
      // Debug logging removed for production
      return 0.0;
    }
  }

  /// Postavi jutarnji kusur za vozača (samo jednom dnevno)
  static Future<bool> setJutarnjiKusur(
    String vozacIme,
    double jutarnjiKusur,
  ) async {
    try {
      // 🌅 JUTARNJA LOGIKA: Postavi početni kusur za dan
      await supabase.rpc<void>(
        'update_vozac_kusur',
        params: {'vozac_ime': vozacIme, 'novi_kusur': jutarnjiKusur},
      ).timeout(const Duration(seconds: 3));

      // Sačuvaj jutarnji kusur u cache za kalkulacije
      final jutarnjiKey = 'jutarnji_kusur_${vozacIme}_${DateTime.now().toIso8601String().split('T')[0]}';
      CacheService.saveToMemory(jutarnjiKey, jutarnjiKusur);

      // Invalidate ostali cache
      final cacheKey = 'kusur_vozac_$vozacIme';
      CacheService.clearFromMemory(cacheKey);
      CacheService.clearFromMemory('kusur_svi_vozaci');

      // Emituj ažuriranje preko stream-a
      _emitKusurUpdate(vozacIme, jutarnjiKusur);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Oduzmi pazar od tekućeg kusura
  static Future<bool> oduzmiPazarOdKusura(
    String vozacIme,
    double pazarIznos,
  ) async {
    try {
      // Dobij trenutni kusur
      final trenutniKusur = await getKusurForVozac(vozacIme);

      // Izračunaj novi kusur (ne može ispod 0)
      final noviKusur = (trenutniKusur - pazarIznos).clamp(0.0, double.infinity);

      // Ažuriraj kusur u bazi
      await supabase.rpc<void>(
        'update_vozac_kusur',
        params: {'vozac_ime': vozacIme, 'novi_kusur': noviKusur},
      ).timeout(const Duration(seconds: 3));

      // Invalidate cache
      final cacheKey = 'kusur_vozac_$vozacIme';
      CacheService.clearFromMemory(cacheKey);
      CacheService.clearFromMemory('kusur_svi_vozaci');

      // Emituj ažuriranje
      _emitKusurUpdate(vozacIme, noviKusur);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Dobij jutarnji kusur za vozača (iz cache-a)
  static Future<double> getJutarnjiKusur(String vozacIme) async {
    final jutarnjiKey = 'jutarnji_kusur_${vozacIme}_${DateTime.now().toIso8601String().split('T')[0]}';
    final cached = CacheService.getFromMemory<double>(jutarnjiKey);
    return cached ?? 0.0;
  }

  /// Proveri da li je vozač već uradio jutarnji check-in danas
  static Future<bool> isJutarnjiCheckInDone(String vozacIme) async {
    final jutarnjiKey = 'jutarnji_kusur_${vozacIme}_${DateTime.now().toIso8601String().split('T')[0]}';
    final cached = CacheService.getFromMemory<double>(jutarnjiKey);
    return cached != null;
  }

  static Future<bool> updateKusurForVozac(
    String vozacIme,
    double noviKusur,
  ) async {
    try {
      // 🕐 VALIDACIJA: Kusur se ažurira samo tokom radnih sati
      final now = DateTime.now();
      final currentHour = now.hour;

      // Blokiran update van radnih sati (pre 5:00 ili posle 23:00)
      if (currentHour < 5 || currentHour > 23) {
        return false;
      }

      // 🚀 PRIMARNI PRISTUP: RPC funkcija (pouzdaniji za numeric tipove)
      await supabase.rpc<void>(
        'update_vozac_kusur',
        params: {'vozac_ime': vozacIme, 'novi_kusur': noviKusur},
      ).timeout(const Duration(seconds: 2));

      // Invalidate cache za ovog vozača
      final cacheKey = 'kusur_vozac_$vozacIme';
      CacheService.clearFromMemory(cacheKey);
      CacheService.clearFromMemory('kusur_svi_vozaci');

      // Emituj ažuriranje preko stream-a
      _emitKusurUpdate(vozacIme, noviKusur);
      return true;
    } catch (e) {
      // 🧪 FALLBACK: Direct UPDATE sa string kastovanjem
      try {
        await supabase
            .from('vozaci')
            .update({'kusur': noviKusur.toString()})
            .eq('ime', vozacIme)
            .timeout(const Duration(seconds: 2));

        // Invalidate cache
        final cacheKey = 'kusur_vozac_$vozacIme';
        CacheService.clearFromMemory(cacheKey);
        CacheService.clearFromMemory('kusur_svi_vozaci');

        _emitKusurUpdate(vozacIme, noviKusur);
        return true;
      } catch (e2) {
        return false;
      }
    }
  }

  /// Stream za real-time praćenje kusur-a određenog vozača
  static Stream<double> streamKusurForVozac(String vozacIme) async* {
    // Odmah pošalji trenutnu vrednost
    final trenutniKusur = await getKusurForVozac(vozacIme);
    yield trenutniKusur;

    // Zatim slušaj za ažuriranja
    await for (final kusurMapa in _kusurController.stream) {
      if (kusurMapa.containsKey(vozacIme)) {
        yield kusurMapa[vozacIme]!;
      }
    }
  }

  /// Dobij kusur za sve vozače odjednom - CACHE OPTIMIZOVANO
  static Future<Map<String, double>> getKusurSvihVozaca() async {
    try {
      // CACHE OPTIMIZOVANO - pokušaj iz cache
      const cacheKey = 'kusur_svi_vozaci';
      final cached = CacheService.getFromMemory<Map<String, double>>(
        cacheKey,
        maxAge: const Duration(minutes: 3),
      );

      if (cached != null) {
        // Debug logging removed for production
        return cached;
      }
      // Debug logging removed for production
// OPTIMIZOVANO sa SupabaseManager
      final response = await SupabaseManager.safeSelect(
        'vozaci',
        columns: 'ime, kusur',
      );

      final Map<String, double> rezultat = {};

      for (final row in response) {
        final ime = row['ime'] as String;
        final kusur = (row['kusur'] as num?)?.toDouble() ?? 0.0;
        rezultat[ime] = kusur;

        // Sačuvaj i individualne cache za svaki vozač
        CacheService.saveToMemory('kusur_vozac_$ime', kusur);
      }

      // Sačuvaj kompletnu mapu u cache
      CacheService.saveToMemory(cacheKey, rezultat);
      // Debug logging removed for production
      return rezultat;
    } catch (e) {
      // Debug logging removed for production
      return {};
    }
  }

  /// Privatni helper za emitovanje ažuriranja
  static void _emitKusurUpdate(String vozacIme, double noviKusur) {
    if (!_kusurController.isClosed) {
      _kusurController.add({vozacIme: noviKusur});
    }
  }

  /// Resetuj kusur za vozača na 0
  static Future<bool> resetKusurForVozac(String vozacIme) async {
    return await updateKusurForVozac(vozacIme, 0.0);
  }

  /// Dodaj iznos u kusur vozača (increment)
  static Future<bool> dodajUKusur(String vozacIme, double iznos) async {
    final trenutniKusur = await getKusurForVozac(vozacIme);
    final noviKusur = trenutniKusur + iznos;
    return await updateKusurForVozac(vozacIme, noviKusur);
  }

  /// Oduzmi iznos iz kusur vozača (decrement)
  static Future<bool> oduzmiIzKusur(String vozacIme, double iznos) async {
    final trenutniKusur = await getKusurForVozac(vozacIme);
    final noviKusur = (trenutniKusur - iznos).clamp(0.0, double.infinity);
    return await updateKusurForVozac(vozacIme, noviKusur);
  }

  /// Zatvori stream controller - MEMORY LEAK PREVENTION
  static void dispose() {
    if (!_kusurController.isClosed) {
      _kusurController.close();
    }
  }

  /// Proveri da li je stream controller aktivan
  static bool get isActive => !_kusurController.isClosed;
}
