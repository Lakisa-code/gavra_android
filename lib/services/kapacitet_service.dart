import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/route_config.dart';
import '../globals.dart';
import '../utils/grad_adresa_validator.dart';
import '../utils/schedule_utils.dart';
import 'realtime/realtime_manager.dart';

/// 🎫 Servis za upravljanje kapacitetom polazaka
/// Omogućava realtime prikaz slobodnih mesta i admin kontrolu
class KapacitetService {
  static SupabaseClient get _supabase => supabase;

  // Cache za kapacitet da smanjimo upite
  static Map<String, Map<String, int>>? _kapacitetCache;
  static DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 5);

  // 🔄 GLOBAL REALTIME LISTENER za automatsko ažuriranje cache-a
  static StreamSubscription? _globalRealtimeSubscription;

  /// Vremena polazaka za Belu Crkvu (prema navBarType)
  static List<String> get bcVremena {
    final navType = navBarTypeNotifier.value;
    switch (navType) {
      case 'praznici':
        return RouteConfig.bcVremenaPraznici;
      case 'zimski':
        return RouteConfig.bcVremenaZimski;
      case 'letnji':
        return RouteConfig.bcVremenaLetnji;
      default: // 'auto'
        return isZimski(DateTime.now()) ? RouteConfig.bcVremenaZimski : RouteConfig.bcVremenaLetnji;
    }
  }

  /// Vremena polazaka za Vršac (prema navBarType)
  static List<String> get vsVremena {
    final navType = navBarTypeNotifier.value;
    switch (navType) {
      case 'praznici':
        return RouteConfig.vsVremenaPraznici;
      case 'zimski':
        return RouteConfig.vsVremenaZimski;
      case 'letnji':
        return RouteConfig.vsVremenaLetnji;
      default: // 'auto'
        return isZimski(DateTime.now()) ? RouteConfig.vsVremenaZimski : RouteConfig.vsVremenaLetnji;
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
    // Proveri cache
    if (_kapacitetCache != null && _cacheTime != null && DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      return _kapacitetCache!;
    }

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
        final vreme = row['vreme'] as String;
        final maxMesta = row['max_mesta'] as int;

        if (result.containsKey(grad)) {
          result[grad]![vreme] = maxMesta;
        }
      }

      // Sačuvaj u cache
      _kapacitetCache = result;
      _cacheTime = DateTime.now();

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
      // 🚀 PAYLOAD FILTERING: Ažuriraj cache direktno ako je moguće
      if (payload.eventType == PostgresChangeEvent.update || payload.eventType == PostgresChangeEvent.insert) {
        final grad = payload.newRecord['grad'] as String?;
        final vreme = payload.newRecord['vreme'] as String?;
        final maxMesta = payload.newRecord['max_mesta'] as int?;

        if (grad != null && vreme != null && maxMesta != null && _kapacitetCache != null) {
          if (_kapacitetCache!.containsKey(grad)) {
            _kapacitetCache![grad]![vreme] = maxMesta;
            if (!controller.isClosed) {
              controller.add(Map.from(_kapacitetCache!));
            }
            return; // Uspešno ažurirano, preskoči full fetch
          }
        }
      }

      // Na bilo koju drugu promenu (DELETE) ili ako cache nije inicijalizovan, ponovo učitaj sve
      getKapacitet().then((data) {
        if (!controller.isClosed) {
          controller.add(data);
        }
      });
    });

    // Cleanup kad se stream zatvori
    controller.onCancel = () {
      subscription?.cancel();
      RealtimeManager.instance.unsubscribe('kapacitet_polazaka');
    };

    return controller.stream;
  }

  /// Admin: Promeni kapacitet za određeni polazak
  static Future<bool> setKapacitet(String grad, String vreme, int maxMesta, {String? napomena}) async {
    try {
      await _supabase.from('kapacitet_polazaka').upsert({
        'grad': grad,
        'vreme': vreme,
        'max_mesta': maxMesta,
        'aktivan': true,
        if (napomena != null) 'napomena': napomena,
      }, onConflict: 'grad,vreme');

      // Invalidate cache
      _kapacitetCache = null;

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Admin: Deaktiviraj polazak (ne briše, samo sakriva)
  static Future<bool> deaktivirajPolazak(String grad, String vreme) async {
    try {
      await _supabase.from('kapacitet_polazaka').update({'aktivan': false}).eq('grad', grad).eq('vreme', vreme);

      _kapacitetCache = null;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Admin: Aktiviraj polazak
  static Future<bool> aktivirajPolazak(String grad, String vreme) async {
    try {
      await _supabase.from('kapacitet_polazaka').update({'aktivan': true}).eq('grad', grad).eq('vreme', vreme);

      _kapacitetCache = null;
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

  /// Očisti cache (pozovi nakon ručnih promena u bazi)
  static void clearCache() {
    _kapacitetCache = null;
    _cacheTime = null;
  }

  /// Dohvati kapacitet za grad/vreme iz cache-a (sinhrono)
  /// Vraća default 8 ako nije u cache-u
  static int getKapacitetSync(String grad, String vreme) {
    if (_kapacitetCache == null) return 8;

    final normalizedGrad = grad.toLowerCase();
    String gradKey;
    if (normalizedGrad.contains('bela') || normalizedGrad == 'bc') {
      gradKey = 'BC';
    } else if (normalizedGrad.contains('vrsac') || normalizedGrad.contains('vršac') || normalizedGrad == 'vs') {
      gradKey = 'VS';
    } else {
      return 8;
    }

    return _kapacitetCache![gradKey]?[vreme] ?? 8;
  }

  /// Osiguraj da je cache popunjen (pozovi na inicijalizaciji)
  static Future<void> ensureCacheLoaded() async {
    if (_kapacitetCache == null) {
      await getKapacitet();
    }
  }

  /// 🚀 INICIJALIZUJ GLOBALNI REALTIME LISTENER
  /// Pozovi ovu funkciju jednom pri startu aplikacije (npr. u main.dart ili home_screen)
  static void startGlobalRealtimeListener() {
    // Prvo učitaj cache
    ensureCacheLoaded();

    // Ako već postoji subscription, preskoči
    if (_globalRealtimeSubscription != null) {
      return;
    }

    // Pokreni globalni listener koji će ažurirati cache u pozadini
    _globalRealtimeSubscription = RealtimeManager.instance.subscribe('kapacitet_polazaka').listen((payload) {
      print('🎫 Kapacitet realtime update: ${payload.eventType}');

      // Ažuriraj cache direktno za performanse
      if (payload.eventType == PostgresChangeEvent.update || payload.eventType == PostgresChangeEvent.insert) {
        final grad = payload.newRecord['grad'] as String?;
        final vreme = payload.newRecord['vreme'] as String?;
        final maxMesta = payload.newRecord['max_mesta'] as int?;
        final aktivan = payload.newRecord['aktivan'] as bool? ?? true;

        if (grad != null && vreme != null && maxMesta != null && _kapacitetCache != null) {
          if (_kapacitetCache!.containsKey(grad)) {
            if (aktivan) {
              _kapacitetCache![grad]![vreme] = maxMesta;
              print('✅ Cache ažuriran: $grad $vreme = $maxMesta mesta');
            } else {
              // Ako je deaktiviran, postavi na 0 ili ukloni
              _kapacitetCache![grad]!.remove(vreme);
              print('🚫 Polazak deaktiviran: $grad $vreme');
            }
          }
        }
      } else if (payload.eventType == PostgresChangeEvent.delete) {
        // Na DELETE invaliduj cache potpuno
        _kapacitetCache = null;
        print('🗑️ Kapacitet obrisan, cache invalidiran');
        // Ponovo učitaj
        getKapacitet();
      }
    });

    print('🚀 Globalni kapacitet realtime listener pokrenut!');
  }

  /// Zaustavi globalni listener (cleanup)
  static void stopGlobalRealtimeListener() {
    _globalRealtimeSubscription?.cancel();
    _globalRealtimeSubscription = null;
    print('🛑 Globalni kapacitet listener zaustavljen');
  }
}
