import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import 'realtime/realtime_manager.dart';
import 'statistika_service.dart';
import 'vozac_mapping_service.dart';
import 'voznje_log_service.dart';

class DailyCheckInService {
  // 🔧 SINGLETON PATTERN za kusur stream - koristi JEDAN RealtimeManager channel za sve vozače
  static final Map<String, StreamController<double>> _kusurControllers = {};
  static final Map<String, double> _kusurCache = {}; // 💾 Cache poslednje vrednosti
  static StreamSubscription? _globalSubscription;
  static bool _isSubscribed = false;

  /// Stream za real-time ažuriranje kusura - SINGLETON sa RealtimeManager
  static Stream<double> streamTodayAmount(String vozac) {
    final today = DateTime.now().toIso8601String().split('T')[0];

    // 🔥 Kreiramo StreamController koji će biti vraćen odmah
    final controller = StreamController<double>.broadcast();

    // 🔥 Asinhrono normalizujemo ime i pokrećemo logiku
    _initializeStream(vozac, today, controller);

    return controller.stream;
  }

  /// Pomoćna metoda za asinhronu inicijalizaciju streama sa normalizovanim imenom
  static Future<void> _initializeStream(String vozac, String today, StreamController<double> controller) async {
    // Normalizuj ime
    final zvanicnoIme =
        await VozacMappingService.getVozacIme(await VozacMappingService.getVozacUuid(vozac) ?? '') ?? vozac;

    // Ako već postoji aktivan controller za ovog (normalizovanog) vozača, prosledi vrednosti
    if (_kusurControllers.containsKey(zvanicnoIme) && !_kusurControllers[zvanicnoIme]!.isClosed) {
      debugPrint('📊 [DailyCheckInService] Reusing existing kusur stream for $zvanicnoIme');

      // Pretplati se na postojeći stream da bi ovaj controller dobijao update-ove
      final subscription = _kusurControllers[zvanicnoIme]!.stream.listen((val) {
        if (!controller.isClosed) controller.add(val);
      });

      controller.onCancel = () {
        subscription.cancel();
      };

      // Fetchuj trenutnu vrednost
      await _fetchKusurForVozac(zvanicnoIme, today, controller);
      return;
    }

    _kusurControllers[zvanicnoIme] = controller;
    debugPrint('🆕 [DailyCheckInService] Creating NEW kusur stream for $zvanicnoIme');

    // Učitaj inicijalne podatke
    await _fetchKusurForVozac(zvanicnoIme, today, controller);

    // Osiguraj globalni subscription
    _ensureGlobalSubscription(today);
  }

  /// 🔧 Fetch kusur za vozača
  static Future<void> _fetchKusurForVozac(
    String vozac,
    String today,
    StreamController<double> controller,
  ) async {
    try {
      debugPrint('🔍 [Kusur] Fetching kusur for vozac=$vozac, datum=$today');
      final data = await supabase
          .from('daily_reports')
          .select('sitan_novac')
          .or('vozac.eq."$vozac",vozac.ilike."$vozac"') // Fleksibilnije poređenje imena
          .eq('datum', today)
          .maybeSingle();

      debugPrint('🔍 [Kusur] Query result: $data');
      if (!controller.isClosed) {
        final amount = (data?['sitan_novac'] as num?)?.toDouble() ?? 0.0;
        debugPrint('🔍 [Kusur] Adding amount to stream: $amount');
        _kusurCache[vozac] = amount; // 💾 Sačuvaj u cache
        controller.add(amount);
      }
    } catch (e) {
      debugPrint('❌ [Kusur] Fetch error: $e');
    }
  }

  /// 🔌 Osiguraj globalni subscription preko RealtimeManager
  static void _ensureGlobalSubscription(String today) {
    if (_isSubscribed && _globalSubscription != null) {
      debugPrint('♻️ [DailyCheckInService] Realtime subscription already exists');
      return;
    }

    debugPrint('🔌 [DailyCheckInService] Creating realtime subscription for daily_reports');

    // Koristi centralizovani RealtimeManager - JEDAN channel za sve vozače!
    _globalSubscription = RealtimeManager.instance.subscribe('daily_reports').listen((payload) {
      debugPrint('🔔 [DailyCheckInService] Realtime event received: ${payload.eventType}');
      _handleRealtimeKusurUpdate(payload, today);
    });

    _isSubscribed = true;
  }

  /// 🔄 Handle realtime kusur update koristeći payload umesto full refetch
  static void _handleRealtimeKusurUpdate(PostgresChangePayload payload, String today) {
    try {
      final newRecord = payload.newRecord;
      final vozac = newRecord['vozac'] as String?;

      if (vozac == null) {
        debugPrint('⚠️ [DailyCheckInService] Realtime event bez vozača, ignorišem');
        return;
      }

      // Koristi vozac ime direktno (trebalo bi već biti normalizovano)
      final normalizedVozac = vozac;

      // Proveri da li imamo aktivan controller za ovog vozača
      if (_kusurControllers.containsKey(normalizedVozac) && !_kusurControllers[normalizedVozac]!.isClosed) {
        debugPrint('🔄 [DailyCheckInService] Updating kusur for $normalizedVozac');
        _fetchKusurForVozac(normalizedVozac, today, _kusurControllers[normalizedVozac]!);
      } else {
        debugPrint('⚠️ [DailyCheckInService] No active controller for $normalizedVozac, skipping update');
      }
    } catch (e) {
      debugPrint('❌ [DailyCheckInService] Error handling realtime update: $e');
    }
  }

  /// 🧹 Čisti kusur cache za vozača
  static void clearKusurCache(String vozac) {
    _kusurControllers[vozac]?.close();
    _kusurControllers.remove(vozac);
    _kusurCache.remove(vozac); // 💾 Obriši i cached vrednost

    // Ako nema više aktivnih controllera, zatvori globalni subscription
    if (_kusurControllers.isEmpty && _globalSubscription != null) {
      _globalSubscription?.cancel();
      RealtimeManager.instance.unsubscribe('daily_reports');
      _globalSubscription = null;
      _isSubscribed = false;
    }
  }

  /// 🧹 Čisti sve kusur cache-eve
  static void clearAllKusurCache() {
    for (final controller in _kusurControllers.values) {
      controller.close();
    }
    _kusurControllers.clear();
    _kusurCache.clear(); // 💾 Obriši sve cached vrednosti

    // Zatvori globalni subscription
    _globalSubscription?.cancel();
    RealtimeManager.instance.unsubscribe('daily_reports');
    _globalSubscription = null;
    _isSubscribed = false;
  }

  /// 🧹 Dispose za čišćenje na exit aplikacije
  static void dispose() {
    clearAllKusurCache();
  }

  /// Initialize stream with current value
  static Future<void> initializeStreamForVozac(String vozac) async {
    final currentAmount = await getTodayAmount(vozac) ?? 0.0;
    if (_kusurControllers.containsKey(vozac) && !_kusurControllers[vozac]!.isClosed) {
      _kusurControllers[vozac]!.add(currentAmount);
    }
  }

  /// Inicijalizuj realtime stream za vozača tako da kocka prati bazu
  static StreamSubscription<dynamic> initializeRealtimeForDriver(String vozac) {
    return Stream<dynamic>.empty().listen((_) {});
  }

  /// Proveri da li je vozač već uradio check-in za dati datum (podrazumevano danas)
  /// Proverava DIREKTNO BAZU - source of truth
  static Future<bool> hasCheckedInToday(String vozac, {DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final todayStr = targetDate.toIso8601String().split('T')[0]; // YYYY-MM-DD

    try {
      // 👤 Normalizuj ime vozača koristeći mapping
      final zvanicnoIme =
          await VozacMappingService.getVozacIme(await VozacMappingService.getVozacUuid(vozac) ?? '') ?? vozac;

      final response = await supabase
          .from('daily_reports')
          .select('sitan_novac')
          .eq('vozac', zvanicnoIme)
          .eq('datum', todayStr)
          .maybeSingle()
          .timeout(const Duration(seconds: 15)); // Povećan timeout na 15s

      if (response != null) {
        // Emituj update za stream
        final sitanNovac = (response['sitan_novac'] as num?)?.toDouble() ?? 0.0;
        _kusurCache[zvanicnoIme] = sitanNovac; // 💾 Sačuvaj u cache
        if (_kusurControllers.containsKey(zvanicnoIme) && !_kusurControllers[zvanicnoIme]!.isClosed) {
          _kusurControllers[zvanicnoIme]!.add(sitanNovac);
        }
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ [DailyCheckIn] Check-in status check failed/timed out: $e');
      // Ako nismo sigurni, vraćamo false da bi dozvolili unos, ali UI će hendlovati
    }

    return false;
  }

  /// Sačuvaj daily check-in (sitan novac i kilometraža)
  static Future<void> saveCheckIn(
    String vozac,
    double sitanNovac, {
    double? kilometraza,
    DateTime? date,
  }) async {
    final today = date ?? DateTime.now();

    // 👤 Normalizuj ime vozača koristeći mapping
    final zvanicnoIme =
        await VozacMappingService.getVozacIme(await VozacMappingService.getVozacUuid(vozac) ?? '') ?? vozac;

    // 🌐 DIREKTNO U BAZU - upsert će ažurirati ako već postoji za danas
    try {
      await _saveToSupabase(zvanicnoIme, sitanNovac, today, kilometraza: kilometraza)
          .timeout(const Duration(seconds: 20)); // Povećan timeout na 20s

      // Ažuriraj stream za UI
      _kusurCache[zvanicnoIme] = sitanNovac; // 💾 Sačuvaj u cache
      if (_kusurControllers.containsKey(zvanicnoIme) && !_kusurControllers[zvanicnoIme]!.isClosed) {
        _kusurControllers[zvanicnoIme]!.add(sitanNovac);
      }
    } catch (e) {
      debugPrint('❌ [DailyCheckIn] Save failed: $e');
      rethrow; // Propagiraj grešku da UI zna da nije uspelo
    }
  }

  /// Dohvati iznos za dati datum - DIREKTNO IZ BAZE
  static Future<double?> getTodayAmount(String vozac, {DateTime? date}) async {
    try {
      // 👤 Normalizuj ime
      final zvanicnoIme =
          await VozacMappingService.getVozacIme(await VozacMappingService.getVozacUuid(vozac) ?? '') ?? vozac;

      final targetDate = date ?? DateTime.now();
      final today = targetDate.toIso8601String().split('T')[0];
      final data = await supabase
          .from('daily_reports')
          .select('sitan_novac')
          .eq('vozac', zvanicnoIme)
          .eq('datum', today)
          .maybeSingle();
      return (data?['sitan_novac'] as num?)?.toDouble();
    } catch (e) {
      return null;
    }
  }

  /// 📋 Proveri da li je popis već sačuvan za dati datum (podrazumevano danas)
  static Future<bool> isPopisSavedToday(String vozac, {DateTime? date}) async {
    try {
      // 👤 Normalizuj ime
      final zvanicnoIme =
          await VozacMappingService.getVozacIme(await VozacMappingService.getVozacUuid(vozac) ?? '') ?? vozac;

      final targetDate = date ?? DateTime.now();
      final today = targetDate.toIso8601String().split('T')[0];
      final data = await supabase
          .from('daily_reports')
          .select('pokupljeni_putnici')
          .eq('vozac', zvanicnoIme)
          .eq('datum', today)
          .maybeSingle();
      // Popis je sačuvan ako postoji zapis sa pokupljenim putnicima
      return data != null && data['pokupljeni_putnici'] != null;
    } catch (e) {
      return false;
    }
  }

  /// Sačuvaj u Supabase tabelu daily_reports
  static Future<Map<String, dynamic>?> _saveToSupabase(
    String vozac,
    double sitanNovac,
    DateTime datum, {
    double? kilometraza,
  }) async {
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        final vozacId = await VozacMappingService.getVozacUuid(vozac);
        final updateData = {
          'vozac': vozac,
          'vozac_id': vozacId,
          'datum': datum.toIso8601String().split('T')[0],
          'sitan_novac': sitanNovac,
          'checkin_vreme': DateTime.now().toIso8601String(),
        };

        if (kilometraza != null) {
          updateData['kilometraza'] = kilometraza;
        }

        final response = await supabase
            .from('daily_reports')
            .upsert(
              updateData,
              onConflict: 'vozac,datum',
            )
            .select()
            .maybeSingle();

        if (response is Map<String, dynamic>) return response;
        return null;
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) rethrow;
        await Future.delayed(Duration(seconds: retryCount * 1));
        debugPrint('⚠️ [DailyCheckIn] Retry $retryCount/3 due to: $e');
      }
    }
    return null;
  }

  /// 📊 NOVI: Sačuvaj kompletan dnevni popis - DIREKTNO U BAZU
  static Future<void> saveDailyReport(
    String vozac,
    DateTime datum,
    Map<String, dynamic> popisPodaci,
  ) async {
    try {
      // 👤 Normalizuj ime vozača
      final zvanicnoIme =
          await VozacMappingService.getVozacIme(await VozacMappingService.getVozacUuid(vozac) ?? '') ?? vozac;

      await _savePopisToSupabase(zvanicnoIme, popisPodaci, datum);
    } catch (e) {
      rethrow;
    }
  }

  /// 📊 NOVI: Dohvati poslednji popis za vozača - DIREKTNO IZ BAZE
  static Future<Map<String, dynamic>?> getLastDailyReport(String vozac) async {
    try {
      // 👤 Normalizuj ime
      final zvanicnoIme =
          await VozacMappingService.getVozacIme(await VozacMappingService.getVozacUuid(vozac) ?? '') ?? vozac;

      final data = await supabase
          .from('daily_reports')
          .select()
          .eq('vozac', zvanicnoIme)
          .order('datum', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data != null) {
        return {
          'datum': DateTime.parse(data['datum']),
          'popis': _convertDbToPopis(data),
        };
      }
    } catch (e) {
      // Error handled silently
    }
    return null;
  }

  /// 📊 NOVI: Dohvati popis za specifičan datum - DIREKTNO IZ BAZE
  static Future<Map<String, dynamic>?> getDailyReportForDate(String vozac, DateTime datum) async {
    try {
      // 👤 Normalizuj ime
      final zvanicnoIme =
          await VozacMappingService.getVozacIme(await VozacMappingService.getVozacUuid(vozac) ?? '') ?? vozac;

      final datumStr = datum.toIso8601String().split('T')[0];
      final data =
          await supabase.from('daily_reports').select().eq('vozac', zvanicnoIme).eq('datum', datumStr).maybeSingle();

      if (data != null) {
        return {
          'datum': datum,
          'popis': _convertDbToPopis(data),
        };
      }
    } catch (e) {
      // Error handled silently
    }
    return null;
  }

  /// Helper: Konvertuj DB red u popis format
  static Map<String, dynamic> _convertDbToPopis(Map<String, dynamic> data) {
    return {
      'ukupanPazar': (data['ukupan_pazar'] as num?)?.toDouble() ?? 0.0,
      'sitanNovac': (data['sitan_novac'] as num?)?.toDouble() ?? 0.0,
      'otkazaniPutnici': data['otkazani_putnici'] ?? 0,
      'naplaceniPutnici': data['naplaceni_putnici'] ?? 0,
      'pokupljeniPutnici': data['pokupljeni_putnici'] ?? 0,
      'dugoviPutnici': data['dugovi_putnici'] ?? 0,
      'mesecneKarte': data['mesecne_karte'] ?? 0,
      'kilometraza': (data['kilometraza'] as num?)?.toDouble() ?? 0.0,
      'automatskiGenerisan': data['automatski_generisan'] ?? false,
    };
  }

  /// 📊 AUTOMATSKO GENERISANJE POPISA ZA PRETHODNI DAN
  /// ✅ FIX: Koristi VoznjeLogService direktno za tačne statistike
  static Future<Map<String, dynamic>?> generateAutomaticReport(
    String vozac,
    DateTime targetDate,
  ) async {
    try {
      // 🚫 PRESKAČI VIKENDE - ne radi se subotom i nedeljom
      if (targetDate.weekday == 6 || targetDate.weekday == 7) {
        return null;
      }

      // 1. OSNOVNI PODACI ZA CILJANI DATUM
      final dayStart = DateTime(targetDate.year, targetDate.month, targetDate.day);
      final dayEnd = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);

      // 2. ✅ DIREKTNE STATISTIKE IZ VOZNJE_LOG - tačni podaci
      final stats = await VoznjeLogService.getStatistikePoVozacu(
        vozacIme: vozac,
        datum: targetDate,
      );

      final pokupljeniPutnici = stats['voznje'] as int? ?? 0;
      final otkazaniPutnici = stats['otkazivanja'] as int? ?? 0;
      final mesecneKarte = stats['uplate'] as int? ?? 0;
      final ukupanPazar = stats['pazar'] as double? ?? 0.0;

      // 3. SITAN NOVAC - UČITAJ RUČNO UNET KUSUR
      double sitanNovac;
      try {
        sitanNovac = await getTodayAmount(vozac) ?? 0.0;
      } catch (e) {
        sitanNovac = 0.0;
      }

      // 4. KILOMETRAŽA
      double kilometraza;
      try {
        kilometraza = await StatistikaService.instance.getKilometrazu(vozac, dayStart, dayEnd);
      } catch (e) {
        kilometraza = 0.0;
      }

      // 5. DUŽNICI - dnevni putnici koji su pokupljeni ali nisu platili
      final dugoviPutnici = await VoznjeLogService.getBrojDuznikaPoVozacu(
        vozacIme: vozac,
        datum: targetDate,
      );

      // 6. KREIRAJ POPIS OBJEKAT
      final automatskiPopis = {
        'vozac': vozac,
        'datum': targetDate.toIso8601String(),
        'ukupanPazar': ukupanPazar,
        'sitanNovac': sitanNovac,
        'otkazaniPutnici': otkazaniPutnici,
        'naplaceniPutnici': mesecneKarte,
        'pokupljeniPutnici': pokupljeniPutnici,
        'dugoviPutnici': dugoviPutnici,
        'mesecneKarte': mesecneKarte,
        'kilometraza': kilometraza,
        'automatskiGenerisan': true,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // 7. SAČUVAJ AUTOMATSKI POPIS
      await saveDailyReport(vozac, targetDate, automatskiPopis);
      return automatskiPopis;
    } catch (e) {
      debugPrint('❌ generateAutomaticReport error: $e');
      return null;
    }
  }

  /// 📊 HELPER: Sačuvaj popis u Supabase
  static Future<void> _savePopisToSupabase(
    String vozac,
    Map<String, dynamic> popisPodaci,
    DateTime datum,
  ) async {
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        final vozacId = await VozacMappingService.getVozacUuid(vozac);
        await supabase.from('daily_reports').upsert(
          {
            'vozac': vozac,
            'vozac_id': vozacId,
            'datum': datum.toIso8601String().split('T')[0],
            'ukupan_pazar': popisPodaci['ukupanPazar'] ?? 0.0,
            'sitan_novac': popisPodaci['sitanNovac'] ?? 0.0,
            'checkin_vreme': DateTime.now().toIso8601String(),
            'otkazani_putnici': popisPodaci['otkazaniPutnici'] ?? 0,
            'naplaceni_putnici': popisPodaci['naplaceniPutnici'] ?? 0,
            'pokupljeni_putnici': popisPodaci['pokupljeniPutnici'] ?? 0,
            'dugovi_putnici': popisPodaci['dugoviPutnici'] ?? 0,
            'mesecne_karte': popisPodaci['mesecneKarte'] ?? 0,
            'kilometraza': popisPodaci['kilometraza'] ?? 0.0,
            'automatski_generisan': popisPodaci['automatskiGenerisan'] ?? true,
            'created_at': datum.toIso8601String(),
          },
          onConflict: 'vozac,datum',
        );
        return;
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) rethrow;
        await Future.delayed(Duration(seconds: retryCount * 1));
      }
    }
  }

  /// Proveri da li je vozač čekiran za danas
  static Future<bool> isCheckedIn(String vozac) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final response =
          await supabase.from('daily_reports').select('id').eq('vozac', vozac).eq('datum', today).maybeSingle();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Čekiraj vozača i postavi sitan novac
  static Future<bool> checkIn(String vozac, double amount) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final data = await supabase
          .from('daily_reports')
          .upsert({
            'vozac': vozac,
            'datum': today,
            'sitan_novac': amount,
            'checkin_vreme': DateTime.now().toIso8601String(),
          })
          .select()
          .maybeSingle();

      return data != null;
    } catch (e) {
      return false;
    }
  }

  /// 💰 Dohvati sve sitne novce za vozača (istorija)
  static Future<List<Map<String, dynamic>>> getKusurHistory(String vozac) async {
    try {
      final data = await supabase
          .from('daily_reports')
          .select('datum, sitan_novac')
          .eq('vozac', vozac)
          .order('datum', ascending: false);

      return (data as List)
          .map<Map<String, dynamic>>((item) => {
                'datum': DateTime.parse(item['datum']),
                'sitanNovac': (item['sitan_novac'] as num?)?.toDouble() ?? 0.0,
              })
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// 💰 Update sitan novac (kusur)
  static Future<bool> updateKusur(String vozac, double newAmount) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final data = await supabase
          .from('daily_reports')
          .upsert({
            'vozac': vozac,
            'datum': today,
            'sitan_novac': newAmount,
          })
          .select()
          .maybeSingle();

      return data != null;
    } catch (e) {
      return false;
    }
  }

  /// 📊 Dohvati sve sitan novac podatke za danas (za admina)
  static Future<List<Map<String, dynamic>>> getTodayKusurAdmin() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final data = await supabase.from('daily_reports').select('vozac, sitan_novac').eq('datum', today);

      return (data as List)
          .map<Map<String, dynamic>>((item) => {
                'vozac': item['vozac'],
                'sitanNovac': (item['sitan_novac'] as num?)?.toDouble() ?? 0.0,
              })
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// 📊 Generiši izveštaj za kraj dana
  static Future<void> generateEndOfDayReport(String vozac) async {
    try {
      final today = DateTime.now();
      final todayStr = today.toIso8601String().split('T')[0];
      final stats = await VoznjeLogService.getStatistikePoVozacu(
        vozacIme: vozac,
        datum: today,
      );

      await supabase
          .from('daily_reports')
          .update({
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('vozac', vozac)
          .eq('datum', todayStr);
    } catch (_) {}
  }

  /// Dohvati poslednju zabeleženu kilometražu za vozača
  static Future<double> getLastKm(String vozac) async {
    try {
      // 👤 Normalizuj ime
      final zvanicnoIme =
          await VozacMappingService.getVozacIme(await VozacMappingService.getVozacUuid(vozac) ?? '') ?? vozac;

      final data = await supabase
          .from('daily_reports')
          .select('kilometraza')
          .eq('vozac', zvanicnoIme)
          .order('datum', ascending: false)
          .limit(1)
          .maybeSingle();

      return (data?['kilometraza'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }
}
