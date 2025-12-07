import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🎫 Servis za upravljanje kapacitetom polazaka
/// Omogućava realtime prikaz slobodnih mesta i admin kontrolu
class KapacitetService {
  static final _supabase = Supabase.instance.client;

  // Cache za kapacitet da smanjimo upite
  static Map<String, Map<String, int>>? _kapacitetCache;
  static DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 5);

  /// Vremena polazaka za Belu Crkvu (zimski raspored)
  static const List<String> bcVremena = [
    '5:00',
    '6:00',
    '7:00',
    '8:00',
    '9:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:30',
    '18:00',
  ];

  /// Vremena polazaka za Vršac (zimski raspored)
  static const List<String> vsVremena = [
    '6:00',
    '7:00',
    '8:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:30',
    '17:00',
    '19:00',
  ];

  /// Dohvati vremena za grad
  static List<String> getVremenaZaGrad(String grad) {
    final normalizedGrad = grad.toLowerCase();
    if (normalizedGrad.contains('bela') || normalizedGrad == 'bc') {
      return bcVremena;
    } else if (normalizedGrad.contains('vrsac') || normalizedGrad.contains('vršac') || normalizedGrad == 'vs') {
      return vsVremena;
    }
    return bcVremena; // default
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

      // Inicijalizuj default vrednosti
      for (final vreme in bcVremena) {
        result['BC']![vreme] = 8; // default
      }
      for (final vreme in vsVremena) {
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

      debugPrint('✅ KapacitetService: Učitan kapacitet - BC: ${result['BC']!.length}, VS: ${result['VS']!.length}');
      return result;
    } catch (e) {
      debugPrint('❌ KapacitetService getKapacitet greška: $e');
      // Vrati default vrednosti
      return {
        'BC': {for (final v in bcVremena) v: 8},
        'VS': {for (final v in vsVremena) v: 8},
      };
    }
  }

  /// Stream kapaciteta (realtime ažuriranje)
  static Stream<Map<String, Map<String, int>>> streamKapacitet() {
    return _supabase.from('kapacitet_polazaka').stream(primaryKey: ['id']).map((data) {
      final result = <String, Map<String, int>>{
        'BC': {for (final v in bcVremena) v: 8},
        'VS': {for (final v in vsVremena) v: 8},
      };

      for (final row in data) {
        if (row['aktivan'] != true) continue;

        final grad = row['grad'] as String?;
        final vreme = row['vreme'] as String?;
        final maxMesta = row['max_mesta'] as int?;

        if (grad != null && vreme != null && maxMesta != null) {
          if (result.containsKey(grad)) {
            result[grad]![vreme] = maxMesta;
          }
        }
      }

      // Ažuriraj cache
      _kapacitetCache = result;
      _cacheTime = DateTime.now();

      return result;
    });
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

      debugPrint('✅ KapacitetService: Kapacitet postavljen - $grad $vreme = $maxMesta');
      return true;
    } catch (e) {
      debugPrint('❌ KapacitetService setKapacitet greška: $e');
      return false;
    }
  }

  /// Admin: Deaktiviraj polazak (ne briše, samo sakriva)
  static Future<bool> deaktivirajPolazak(String grad, String vreme) async {
    try {
      await _supabase.from('kapacitet_polazaka').update({'aktivan': false}).eq('grad', grad).eq('vreme', vreme);

      _kapacitetCache = null;
      debugPrint('🚫 KapacitetService: Polazak deaktiviran - $grad $vreme');
      return true;
    } catch (e) {
      debugPrint('❌ KapacitetService deaktivirajPolazak greška: $e');
      return false;
    }
  }

  /// Admin: Aktiviraj polazak
  static Future<bool> aktivirajPolazak(String grad, String vreme) async {
    try {
      await _supabase.from('kapacitet_polazaka').update({'aktivan': true}).eq('grad', grad).eq('vreme', vreme);

      _kapacitetCache = null;
      debugPrint('✅ KapacitetService: Polazak aktiviran - $grad $vreme');
      return true;
    } catch (e) {
      debugPrint('❌ KapacitetService aktivirajPolazak greška: $e');
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
      debugPrint('❌ KapacitetService getNapomena greška: $e');
      return null;
    }
  }

  /// Očisti cache (pozovi nakon ručnih promena u bazi)
  static void clearCache() {
    _kapacitetCache = null;
    _cacheTime = null;
    debugPrint('🗑️ KapacitetService: Cache očišćen');
  }
}
