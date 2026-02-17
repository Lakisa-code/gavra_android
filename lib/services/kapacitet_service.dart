import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/route_config.dart';
import '../globals.dart';
import '../utils/grad_adresa_validator.dart';
import 'realtime/realtime_manager.dart';

/// 🎫 Servis za upravljanje kapacitetom polazaka
/// Omogućava realtime prikaz slobodnih mesta i admin kontrolu
class KapacitetService {
  static SupabaseClient get _supabase => supabase;

  // 🔄 GLOBAL REALTIME LISTENER za automatsko ažuriranje
  static StreamSubscription? _globalRealtimeSubscription;

  // 💾 CACHE za kapacitet (inicijalizuje se na startup)
  static Map<String, Map<String, int>> _kapacitetCache = {
    'BC': {},
    'VS': {},
  };
  static bool _kapacitetCacheInitialized = false;

  /// Vremena polazaka za Belu Crkvu (prema navBarType)
  static List<String> get bcVremena {
    final navType = navBarTypeNotifier.value;
    if (navType == 'praznici') {
      return RouteConfig.bcVremenaPraznici;
    } else if (navType == 'zimski') {
      return RouteConfig.bcVremenaZimski;
    } else {
      return RouteConfig.bcVremenaLetnji;
    }
  }

  /// Vremena polazaka za Vršac (prema navBarType)
  static List<String> get vsVremena {
    final navType = navBarTypeNotifier.value;
    if (navType == 'praznici') {
      return RouteConfig.vsVremenaPraznici;
    } else if (navType == 'zimski') {
      return RouteConfig.vsVremenaZimski;
    } else {
      return RouteConfig.vsVremenaLetnji;
    }
  }

  /// Sva moguća vremena (zimska + letnja + praznična) - za kapacitet tabelu
  static List<String> get svaVremenaBc {
    return {...RouteConfig.bcVremenaZimski, ...RouteConfig.bcVremenaLetnji, ...RouteConfig.bcVremenaPraznici}.toList();
  }

  static List<String> get svaVremenaVs {
    return {...RouteConfig.vsVremenaZimski, ...RouteConfig.vsVremenaLetnji, ...RouteConfig.vsVremenaPraznici}.toList();
  }

  /// Dohvati vremena za grad (sezonski)
  static List<String> getVremenaZaGrad(String grad) {
    if (GradAdresaValidator.isBelaCrkva(grad)) {
      return bcVremena;
    } else if (GradAdresaValidator.isVrsac(grad)) {
      return vsVremena;
    }
    return bcVremena; // default
  }

  /// Dohvati sva moguća vremena za grad (obe sezone) - za kapacitet tabelu
  static List<String> getSvaVremenaZaGrad(String grad) {
    if (GradAdresaValidator.isBelaCrkva(grad)) {
      return svaVremenaBc;
    } else if (GradAdresaValidator.isVrsac(grad)) {
      return svaVremenaVs;
    }
    return svaVremenaBc; // default
  }

  /// Dohvati kapacitet (max mesta) za sve polaske
  /// Vraća: {'BC': {'5:00': 8, '6:00': 8, ...}, 'VS': {'6:00': 8, ...}}
  static Future<Map<String, Map<String, int>>> getKapacitet() async {
    try {
      final response = await _supabase.from('kapacitet_polazaka').select('grad, vreme, max_mesta').eq('aktivan', true);

      final result = <String, Map<String, int>>{
        'BC': {},
        'VS': {},
      };

      // Inicijalizuj default vrednosti (sva vremena obe sezone)
      for (final vreme in svaVremenaBc) {
        result['BC']![vreme] = 8; // default
      }
      for (final vreme in svaVremenaVs) {
        result['VS']![vreme] = 8; // default
      }

      // Popuni iz baze
      for (final row in response as List) {
        final grad = row['grad'] as String;
        final rawVreme = row['vreme'] as String;
        final maxMesta = row['max_mesta'] as int;

        // ✅ NORMALIZUJ VREME iz baze (osigurava konzistentnost sa RouteConfig)
        final vreme = GradAdresaValidator.normalizeTime(rawVreme);

        if (result.containsKey(grad)) {
          result[grad]![vreme] = maxMesta;
        }
      }

      return result;
    } catch (e) {
      // Vrati default vrednosti (sva vremena obe sezone)
      return {
        'BC': {for (final v in svaVremenaBc) v: 8},
        'VS': {for (final v in svaVremenaVs) v: 8},
      };
    }
  }

  /// Stream kapaciteta (realtime ažuriranje) - koristi RealtimeManager
  static Stream<Map<String, Map<String, int>>> streamKapacitet() {
    final controller = StreamController<Map<String, Map<String, int>>>.broadcast();
    StreamSubscription? subscription;

    // Učitaj inicijalne podatke
    getKapacitet().then((data) {
      if (!controller.isClosed) {
        controller.add(data);
      }
    });

    // Koristi centralizovani RealtimeManager
    subscription = RealtimeManager.instance.subscribe('kapacitet_polazaka').listen((payload) {
      // Na bilo koju promenu, ponovo učitaj sve
      getKapacitet().then((data) {
        if (!controller.isClosed) {
          controller.add(data);
        }
      });
    });

    controller.onCancel = () {
      subscription?.cancel();
      RealtimeManager.instance.unsubscribe('kapacitet_polazaka');
    };

    return controller.stream;
  }

  /// Admin: Promeni kapacitet za određeni polazak
  static Future<bool> setKapacitet(String grad, String vreme, int maxMesta, {String? napomena}) async {
    try {
      // Prvo probaj update ako postoji zapis
      final updateResult = await _supabase
          .from('kapacitet_polazaka')
          .update({
            'max_mesta': maxMesta,
            'aktivan': true,
            if (napomena != null) 'napomena': napomena,
          })
          .eq('grad', grad)
          .eq('vreme', vreme)
          .select();

      // Ako update nije promenio ništa, uradi insert
      if (updateResult.isEmpty) {
        await _supabase.from('kapacitet_polazaka').insert({
          'grad': grad,
          'vreme': vreme,
          'max_mesta': maxMesta,
          'aktivan': true,
          if (napomena != null) 'napomena': napomena,
        });
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Admin: Deaktiviraj polazak (ne briše, samo sakriva)
  static Future<bool> deaktivirajPolazak(String grad, String vreme) async {
    try {
      await _supabase.from('kapacitet_polazaka').update({'aktivan': false}).eq('grad', grad).eq('vreme', vreme);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Admin: Aktiviraj polazak
  static Future<bool> aktivirajPolazak(String grad, String vreme) async {
    try {
      await _supabase.from('kapacitet_polazaka').update({'aktivan': true}).eq('grad', grad).eq('vreme', vreme);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Dohvati napomenu za polazak
  static Future<String?> getNapomena(String grad, String vreme) async {
    try {
      final response = await _supabase
          .from('kapacitet_polazaka')
          .select('napomena')
          .eq('grad', grad)
          .eq('vreme', vreme)
          .maybeSingle();

      return response?['napomena'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Dohvati kapacitet za grad/vreme (vraća iz cache-a)
  /// Vraća default 8 ako nije dostupno u cache-u
  static int getKapacitetSync(String grad, String vreme) {
    // Normalizuj vreme
    final normalizedVreme = GradAdresaValidator.normalizeTime(vreme);

    // Normalizuj grad (BC ili VS)
    final gradKey = GradAdresaValidator.isBelaCrkva(grad) ? 'BC' : 'VS';

    // Vrati iz cache-a ili default 8
    return _kapacitetCache[gradKey]?[normalizedVreme] ?? 8;
  }

  /// Inicijalizuj cache pri startu
  static Future<void> initializeKapacitetCache() async {
    if (_kapacitetCacheInitialized) return;

    try {
      final data = await getKapacitet();
      _kapacitetCache = data;
      _kapacitetCacheInitialized = true;
    } catch (e) {
      // Koristi default vrednosti
      _kapacitetCache = {
        'BC': {for (final v in svaVremenaBc) v: 8},
        'VS': {for (final v in svaVremenaVs) v: 8},
      };
      _kapacitetCacheInitialized = true;
    }

    // Pokreni realtime listener za ažuriranje cache-a
    startGlobalRealtimeListener();
  }

  /// Ažurira cache iz baze
  static Future<void> refreshKapacitetCache() async {
    try {
      final data = await getKapacitet();
      _kapacitetCache = data;
    } catch (e) {
      // Zadrži stari cache ako fetch nije useo
    }
  }

  /// 🚀 INICIJALIZUJ GLOBALNI REALTIME LISTENER
  /// Pozovi ovu funkciju jednom pri startu aplikacije (npr. u main.dart ili home_screen)
  static void startGlobalRealtimeListener() {
    // Ako već postoji subscription, preskoči
    if (_globalRealtimeSubscription != null) {
      return;
    }

    // Pokreni globalni listener
    _globalRealtimeSubscription = RealtimeManager.instance.subscribe('kapacitet_polazaka').listen((payload) {
      // Na svaku promenu, osveži cache
      refreshKapacitetCache();
    });
  }

  /// Zaustavi globalni listener (cleanup)
  static void stopGlobalRealtimeListener() {
    _globalRealtimeSubscription?.cancel();
    _globalRealtimeSubscription = null;
    RealtimeManager.instance.unsubscribe('kapacitet_polazaka');
    print('🛑 Globalni kapacitet listener zaustavljen');
  }
}
