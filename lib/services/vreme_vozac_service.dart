import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import '../utils/vozac_boja.dart';

/// 🚐 VREME VOZAC SERVICE
/// Servis za dodeljivanje vozača celom vremenu/terminu
/// Npr: BC 18:00 ponedeljak -> Ivan (svi putnici na tom terminu idu sa Ivanom)
class VremeVozacService {
  // Singleton pattern
  static final VremeVozacService _instance = VremeVozacService._internal();
  factory VremeVozacService() => _instance;
  VremeVozacService._internal();

  // Supabase client
  SupabaseClient get _supabase => supabase;

  // 🗄️ Keš za brzo čitanje - ključ je "grad|vreme|dan"
  final Map<String, String?> _cache = {};

  // Stream controller za obaveštavanje o promenama
  final _changesController = StreamController<void>.broadcast();
  Stream<void> get onChanges => _changesController.stream;

  /// 🔍 Dobij vozača za specifično vreme
  /// [grad] - 'Bela Crkva' ili 'Vršac'
  /// [vreme] - '18:00', '5:00', itd.
  /// [dan] - 'pon', 'uto', 'sre', 'cet', 'pet'
  /// Vraća ime vozača ili null ako nije dodeljen
  Future<String?> getVozacZaVreme(String grad, String vreme, String dan) async {
    final normalizedVreme = _normalizeTime(vreme);
    if (normalizedVreme == null) return null;

    final cacheKey = '$grad|$normalizedVreme|$dan';

    // Proveri keš prvo
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    try {
      final response = await _supabase
          .from('vreme_vozac')
          .select('vozac_ime')
          .eq('grad', grad)
          .eq('vreme', normalizedVreme)
          .eq('dan', dan)
          .maybeSingle();

      final vozacIme = response?['vozac_ime'] as String?;
      _cache[cacheKey] = vozacIme;
      return vozacIme;
    } catch (e) {
      // print('⚠️ Greška pri čitanju vreme_vozac: $e');
      return null;
    }
  }

  /// 🔍 Dobij vozača za specifično vreme - SINHRONO iz keša
  /// Koristi se u putnik.dart gde ne možemo async
  /// MORA SE PRVO POZVATI loadAllVremeVozac() za učitavanje keša!
  String? getVozacZaVremeSync(String grad, String vreme, String dan) {
    final normalizedVreme = _normalizeTime(vreme);
    if (normalizedVreme == null) return null;

    final cacheKey = '$grad|$normalizedVreme|$dan';
    return _cache[cacheKey];
  }

  /// 📥 Učitaj sve vreme_vozac zapise u keš
  /// Poziva se na početku aplikacije i nakon promena
  Future<void> loadAllVremeVozac() async {
    try {
      final response = await _supabase.from('vreme_vozac').select('grad, vreme, dan, vozac_ime');

      _cache.clear();
      for (final row in response as List) {
        final grad = row['grad'] as String;
        final rawVreme = row['vreme'] as String;
        final dan = row['dan'] as String;
        final vozacIme = row['vozac_ime'] as String?;

        final normalizedVreme = _normalizeTime(rawVreme);
        if (normalizedVreme != null) {
          final cacheKey = '$grad|$normalizedVreme|$dan';
          _cache[cacheKey] = vozacIme;
        }
      }
      // print('✅ Učitano ${_cache.length} vreme_vozac zapisa');
    } catch (e) {
      // print('⚠️ Greška pri učitavanju vreme_vozac: $e');
    }
  }

  /// ✏️ Dodeli vozača celom vremenu
  /// [grad] - 'Bela Crkva' ili 'Vršac'
  /// [vreme] - '18:00', '5:00', itd.
  /// [dan] - 'pon', 'uto', 'sre', 'cet', 'pet'
  /// [vozacIme] - 'Ivan', 'Bilevski', 'Goran'
  Future<void> setVozacZaVreme(String grad, String vreme, String dan, String vozacIme) async {
    // Normalize vreme to ensure consistent HH:MM format
    final normalizedVreme = _normalizeTime(vreme);
    if (normalizedVreme == null) {
      throw Exception('Nevalidan format vremena: "$vreme"');
    }

    // Validacija
    if (!VozacBoja.isValidDriver(vozacIme)) {
      throw Exception('Nevalidan vozač: "$vozacIme". Dozvoljeni: ${VozacBoja.validDrivers.join(", ")}');
    }

    try {
      // Upsert - ako postoji ažuriraj, ako ne postoji dodaj
      await supabase.from('vreme_vozac').upsert({
        'grad': grad,
        'vreme': normalizedVreme,
        'dan': dan,
        'vozac_ime': vozacIme,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'grad,vreme,dan');

      // Ažuriraj keš
      final cacheKey = '$grad|$normalizedVreme|$dan';
      _cache[cacheKey] = vozacIme;

      // Obavesti listenere
      _changesController.add(null);
    } catch (e) {
      throw Exception('Greška pri dodeljivanju vozača vremenu: $e');
    }
  }

  /// 🗑️ Ukloni vozača sa vremena
  Future<void> removeVozacZaVreme(String grad, String vreme, String dan) async {
    final normalizedVreme = _normalizeTime(vreme);
    if (normalizedVreme == null) {
      throw Exception('Nevalidan format vremena: "$vreme"');
    }

    try {
      await supabase.from('vreme_vozac').delete().eq('grad', grad).eq('vreme', normalizedVreme).eq('dan', dan);

      // Ažuriraj keš
      final cacheKey = '$grad|$normalizedVreme|$dan';
      _cache.remove(cacheKey);

      // Obavesti listenere
      _changesController.add(null);
    } catch (e) {
      throw Exception('Greška pri uklanjanju vozača sa vremena: $e');
    }
  }

  /// 📋 Dobij sve dodelјene vozače za dan
  /// Vraća mapu: { "Bela Crkva|18:00": "Ivan", "Vršac|13:00": "Bilevski" }
  Map<String, String> getVozaciZaDanSync(String dan) {
    final result = <String, String>{};
    for (final entry in _cache.entries) {
      final parts = entry.key.split('|');
      if (parts.length == 3 && parts[2] == dan && entry.value != null) {
        final displayKey = '${parts[0]}|${parts[1]}'; // "Bela Crkva|18:00"
        result[displayKey] = entry.value!;
      }
    }
    return result;
  }

  /// 🧹 Očisti keš (koristi se pri logout-u)
  void clearCache() {
    _cache.clear();
  }

  /// 🔄 Dispose
  void dispose() {
    _changesController.close();
  }

  /// 🕒 Helper: Normalize time to HH:MM format
  String? _normalizeTime(String time) {
    // Simple normalization: ensure HH:MM format
    final parts = time.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null && minute != null && hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
        return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      }
    }
    return null;
  }
}
