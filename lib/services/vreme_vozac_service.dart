import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import '../utils/vozac_boja.dart';

/// 🚐 VREME VOZAC SERVICE
/// Servis za dodeljivanje vozača celom vremenu/terminu
/// Npr: BC 18:00 ponedeljak -> Voja (svi putnici na tom terminu idu sa Vojom)
class VremeVozacService {
  // Singleton pattern
  static final VremeVozacService _instance = VremeVozacService._internal();
  factory VremeVozacService() => _instance;
  VremeVozacService._internal();

  // Supabase client
  SupabaseClient get _supabase => supabase;

  // Cache za sync pristup
  final Map<String, String> _cache = {};

  // Stream controller za obaveštavanje o promenama
  final _changesController = StreamController<void>.broadcast();
  Stream<void> get onChanges => _changesController.stream;

  // Realtime subscription
  RealtimeChannel? _realtimeChannel;

  /// 🔍 Dobij vozača za specifično vreme
  /// [grad] - 'Bela Crkva' ili 'Vršac'
  /// [vreme] - '18:00', '5:00', itd.
  /// [dan] - 'pon', 'uto', 'sre', 'cet', 'pet'
  /// Vraća ime vozača ili null ako nije dodeljen
  Future<String?> getVozacZaVreme(String grad, String vreme, String dan) async {
    final normalizedVreme = _normalizeTime(vreme);
    if (normalizedVreme == null) return null;

    try {
      final response = await _supabase
          .from('vreme_vozac')
          .select('vozac_ime')
          .eq('grad', grad)
          .eq('vreme', normalizedVreme)
          .eq('dan', dan)
          .maybeSingle();

      final vozacIme = response?['vozac_ime'] as String?;
      return vozacIme;
    } catch (e) {
      // print('⚠️ Greška pri čitanju vreme_vozac: $e');
      return null;
    }
  }

  /// ✏️ Dodeli vozača celom vremenu
  /// [grad] - 'Bela Crkva' ili 'Vršac'
  /// [vreme] - '18:00', '5:00', itd.
  /// [dan] - 'pon', 'uto', 'sre', 'cet', 'pet'
  /// [vozacIme] - 'Voja', 'Bilevski', 'Goran'
  Future<void> setVozacZaVreme(String grad, String vreme, String dan, String vozacIme) async {
    // Normalize vreme to ensure consistent HH:MM format
    final normalizedVreme = _normalizeTime(vreme);
    if (normalizedVreme == null) {
      throw Exception('Nevalidan format vremena: "$vreme"');
    }

    // Validacija
    if (!(VozacBoja.isValidDriverSync(vozacIme))) {
      final validDrivers = VozacBoja.validDriversSync;
      throw Exception('Nevalidan vozač: "$vozacIme". Dozvoljeni: ${validDrivers.join(", ")}');
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

      // Ažuriraj cache
      final key = '$grad|$normalizedVreme|$dan';
      _cache[key] = vozacIme;

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

      // Ažuriraj cache
      final key = '$grad|$normalizedVreme|$dan';
      _cache.remove(key);

      // Obavesti listenere
      _changesController.add(null);
    } catch (e) {
      throw Exception('Greška pri uklanjanju vozača sa vremena: $e');
    }
  }

  /// 🔍 Dobij vozača za specifično vreme (SYNC verzija)
  /// [grad] - 'Bela Crkva' ili 'Vršac'
  /// [vreme] - '18:00', '5:00', itd.
  /// [dan] - 'pon', 'uto', 'sre', 'cet', 'pet'
  /// Vraća ime vozača ili null ako nije dodeljen
  String? getVozacZaVremeSync(String grad, String vreme, String dan) {
    final normalizedVreme = _normalizeTime(vreme);
    if (normalizedVreme == null) return null;

    final key = '$grad|$normalizedVreme|$dan';
    return _cache[key];
  }

  /// 🔍 Dobij vozače za ceo dan (SYNC verzija)
  /// [dan] - 'pon', 'uto', 'sre', 'cet', 'pet'
  /// Vraća mapu 'grad|vreme' -> vozac_ime
  Map<String, String> getVozaciZaDanSync(String dan) {
    final result = <String, String>{};
    _cache.forEach((key, vozac) {
      final parts = key.split('|');
      if (parts.length == 3 && parts[2] == dan) {
        final gradVreme = '${parts[0]}|${parts[1]}';
        result[gradVreme] = vozac;
      }
    });
    return result;
  }

  /// 🔄 Učitaj sve vreme-vozač mapiranja (SYNC verzija)
  Future<void> loadAllVremeVozac() async {
    try {
      final response = await _supabase.from('vreme_vozac').select('grad, vreme, dan, vozac_ime');
      _cache.clear();
      for (final row in response) {
        final grad = row['grad'] as String;
        final vreme = row['vreme'] as String;
        final dan = row['dan'] as String;
        final vozacIme = row['vozac_ime'] as String;
        final key = '$grad|$vreme|$dan';
        _cache[key] = vozacIme;
      }
      // Pokreni realtime listener samo prvi put nakon inicijalnog učitavanja
      if (_realtimeChannel == null) {
        _setupRealtimeListener();
      }
    } catch (e) {
      // print('⚠️ Greška pri učitavanju vreme_vozac cache: $e');
    }
  }

  /// 📡 Postavi realtime listener na vreme_vozac tabelu
  void _setupRealtimeListener() {
    _realtimeChannel = _supabase.channel('public:vreme_vozac');

    _realtimeChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'vreme_vozac',
          callback: (payload) async {
            // Refresh cache kada se bilo šta promijeni u tabeli
            print('📡 VremeVozacService: Detektovana promjena, osvežavam cache...');
            // NE pozivaj loadAllVremeVozac() jer bi to pokrenulo listener ponovo
            await _refreshCacheFromDatabase();
            // Obavesti slušaoce o promjeni
            _changesController.add(null);
          },
        )
        .subscribe();
  }

  /// 🔄 Osvěži cache iz baze bez pokretanja novog listener-a
  Future<void> _refreshCacheFromDatabase() async {
    try {
      final response = await _supabase.from('vreme_vozac').select('grad, vreme, dan, vozac_ime');
      _cache.clear();
      for (final row in response) {
        final grad = row['grad'] as String;
        final vreme = row['vreme'] as String;
        final dan = row['dan'] as String;
        final vozacIme = row['vozac_ime'] as String;
        final key = '$grad|$vreme|$dan';
        _cache[key] = vozacIme;
      }
    } catch (e) {
      // print('⚠️ Greška pri osvežavanju cache-a: $e');
    }
  }

  /// 🛑 Zatvori realtime listener
  void dispose() {
    if (_realtimeChannel != null) {
      _supabase.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
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
