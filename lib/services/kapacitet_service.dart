import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/route_config.dart';
import '../utils/schedule_utils.dart';

/// 🎫 Servis za upravljanje kapacitetom polazaka
/// Omogućava realtime prikaz slobodnih mesta i admin kontrolu
class KapacitetService {
  static final _supabase = Supabase.instance.client;

  // Cache za kapacitet da smanjimo upite
  static Map<String, Map<String, int>>? _kapacitetCache;
  static DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 5);

  /// Vremena polazaka za Belu Crkvu (sezonski)
  static List<String> get bcVremena {
    final jeZimski = isZimski(DateTime.now());
    return jeZimski ? RouteConfig.bcVremenaZimski : RouteConfig.bcVremenaLetnji;
  }

  /// Vremena polazaka za Vršac (sezonski)
  static List<String> get vsVremena {
    final jeZimski = isZimski(DateTime.now());
    return jeZimski ? RouteConfig.vsVremenaZimski : RouteConfig.vsVremenaLetnji;
  }

  /// Sva moguća vremena (zimska + letnja) - za kapacitet tabelu
  static List<String> get svaVremenaBc {
    return {...RouteConfig.bcVremenaZimski, ...RouteConfig.bcVremenaLetnji}.toList();
  }

  static List<String> get svaVremenaVs {
    return {...RouteConfig.vsVremenaZimski, ...RouteConfig.vsVremenaLetnji}.toList();
  }

  /// Dohvati vremena za grad (sezonski)
  static List<String> getVremenaZaGrad(String grad) {
    final normalizedGrad = grad.toLowerCase();
    if (normalizedGrad.contains('bela') || normalizedGrad == 'bc') {
      return bcVremena;
    } else if (normalizedGrad.contains('vrsac') || normalizedGrad.contains('vršac') || normalizedGrad == 'vs') {
      return vsVremena;
    }
    return bcVremena; // default
  }

  /// Dohvati sva moguća vremena za grad (obe sezone) - za kapacitet tabelu
  static List<String> getSvaVremenaZaGrad(String grad) {
    final normalizedGrad = grad.toLowerCase();
    if (normalizedGrad.contains('bela') || normalizedGrad == 'bc') {
      return svaVremenaBc;
    } else if (normalizedGrad.contains('vrsac') || normalizedGrad.contains('vršac') || normalizedGrad == 'vs') {
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

  /// Stream kapaciteta (realtime ažuriranje) - direktan Supabase
  static Stream<Map<String, Map<String, int>>> streamKapacitet() {
    final controller = StreamController<Map<String, Map<String, int>>>.broadcast();

    // Učitaj inicijalne podatke
    getKapacitet().then((data) {
      if (!controller.isClosed) {
        controller.add(data);
      }
    });

    // Direktan Supabase realtime
    final channel = _supabase.channel('kapacitet_polazaka_stream');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'kapacitet_polazaka',
          callback: (payload) {
            // Na bilo koju promenu, ponovo učitaj sve
            getKapacitet().then((data) {
              if (!controller.isClosed) {
                controller.add(data);
              }
            });
          },
        )
        .subscribe();

    // Cleanup kad se stream zatvori
    controller.onCancel = () {
      channel.unsubscribe();
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
    } catch (e) {
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
}
