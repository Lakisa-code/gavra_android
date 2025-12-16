import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/registrovani_putnik.dart';
import 'realtime_service.dart'; // 🔄 DODATO za refresh nakon brisanja
import 'vozac_mapping_service.dart';
import 'voznje_log_service.dart'; // 🔄 DODATO za istoriju vožnji

/// Servis za upravljanje mesečnim putnicima (normalizovana šema)
class RegistrovaniPutnikService {
  RegistrovaniPutnikService({SupabaseClient? supabaseClient}) : _supabase = supabaseClient ?? Supabase.instance.client;
  final SupabaseClient _supabase;

  /// Dohvata sve mesečne putnike
  Future<List<RegistrovaniPutnik>> getAllRegistrovaniPutnici() async {
    final response = await _supabase.from('registrovani_putnici').select('''
          *
        ''').eq('obrisan', false).order('putnik_ime');

    return response.map((json) => RegistrovaniPutnik.fromMap(json)).toList();
  }

  /// Dohvata aktivne mesečne putnike
  Future<List<RegistrovaniPutnik>> getAktivniregistrovaniPutnici() async {
    final response = await _supabase.from('registrovani_putnici').select('''
          *
        ''').eq('aktivan', true).eq('obrisan', false).order('putnik_ime');

    return response.map((json) => RegistrovaniPutnik.fromMap(json)).toList();
  }

  /// Dohvata putnike kojima treba račun (treba_racun = true)
  Future<List<RegistrovaniPutnik>> getPutniciZaRacun() async {
    final response = await _supabase
        .from('registrovani_putnici')
        .select('*')
        .eq('aktivan', true)
        .eq('obrisan', false)
        .eq('treba_racun', true)
        .order('putnik_ime');

    return response.map((json) => RegistrovaniPutnik.fromMap(json)).toList();
  }

  /// Dohvata mesečnog putnika po ID-u
  Future<RegistrovaniPutnik?> getRegistrovaniPutnikById(String id) async {
    final response = await _supabase.from('registrovani_putnici').select('''
          *
        ''').eq('id', id).single();

    return RegistrovaniPutnik.fromMap(response);
  }

  /// Dohvata mesečnog putnika po imenu (legacy compatibility)
  static Future<RegistrovaniPutnik?> getRegistrovaniPutnikByIme(String ime) async {
    try {
      final supabase = Supabase.instance.client;
      final response =
          await supabase.from('registrovani_putnici').select().eq('putnik_ime', ime).eq('obrisan', false).single();

      return RegistrovaniPutnik.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  /// Stream za aktivne mesečne putnike (legacy compatibility)
  static Stream<List<RegistrovaniPutnik>> streamAktivniRegistrovaniPutnici() {
    try {
      final supabase = Supabase.instance.client;
      return supabase
          .from('registrovani_putnici')
          .stream(primaryKey: ['id'])
          .order('putnik_ime')
          .map((data) {
            try {
              final listRaw = data as List<dynamic>;

              final filtered = listRaw.where((row) {
                final map = row as Map<String, dynamic>;
                return (map['aktivan'] == true) && (map['obrisan'] != true);
              }).toList();

              return filtered
                  .map(
                    (json) => RegistrovaniPutnik.fromMap(
                      Map<String, dynamic>.from(json as Map),
                    ),
                  )
                  .toList();
            } catch (e) {
              return <RegistrovaniPutnik>[];
            }
          })
          .handleError((err) {
            return <RegistrovaniPutnik>[];
          });
    } catch (e) {
      // fallback to a one-time fetch if stream creation fails
      return Stream.fromFuture(
        Supabase.instance.client
            .from('registrovani_putnici')
            .select()
            .eq('aktivan', true)
            .eq('obrisan', false)
            .order('putnik_ime')
            .then(
              (response) => response
                  .map(
                    (json) => RegistrovaniPutnik.fromMap(Map<String, dynamic>.from(json)),
                  )
                  .toList(),
            ),
      );
    }
  }

  /// Kreira novog mesečnog putnika
  Future<RegistrovaniPutnik> createRegistrovaniPutnik(RegistrovaniPutnik putnik) async {
    final response = await _supabase.from('registrovani_putnici').insert(putnik.toMap()).select('''
          *
        ''').single();

    // Očisti cache nakon kreiranja da se novi putnik odmah vidi
    clearCache();

    return RegistrovaniPutnik.fromMap(response);
  }

  /// Ažurira mesečnog putnika
  Future<RegistrovaniPutnik> updateRegistrovaniPutnik(
    String id,
    Map<String, dynamic> updates,
  ) async {
    updates['updated_at'] = DateTime.now().toIso8601String();

    final response = await _supabase.from('registrovani_putnici').update(updates).eq('id', id).select('''
          *
        ''').single();

    // Očisti cache nakon update-a da se promene odmah vide
    clearCache();

    return RegistrovaniPutnik.fromMap(response);
  }

  /// Toggle aktivnost mesečnog putnika
  Future<bool> toggleAktivnost(String id, bool aktivnost) async {
    try {
      await _supabase.from('registrovani_putnici').update({
        'aktivan': aktivnost,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      // Očisti cache nakon promene aktivnosti da se promene odmah vide
      clearCache();

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Ažurira mesečnog putnika (legacy metoda name)
  Future<RegistrovaniPutnik?> azurirajMesecnogPutnika(RegistrovaniPutnik putnik) async {
    try {
      final result = await updateRegistrovaniPutnik(putnik.id, putnik.toMap());
      return result;
    } catch (e) {
      rethrow; // Prebaci grešku da caller može da je uhvati
    }
  }

  /// Dodaje novog mesečnog putnika (legacy metoda name)
  Future<RegistrovaniPutnik> dodajMesecnogPutnika(RegistrovaniPutnik putnik) async {
    return await createRegistrovaniPutnik(putnik);
  }

  /// Kreira dnevna putovanja iz mesečnih (placeholder - treba implementirati)
  Future<void> kreirajDnevnaPutovanjaIzRegistrovanih(
    RegistrovaniPutnik putnik,
    DateTime datum,
  ) async {
    // Implementacija će biti dodana kada bude potrebna za scheduling funkcionalnost
    // Trenutno se koristi direktno unošenje kroz glavnu logiku aplikacije
  }

  /// Sinhronizacija broja putovanja sa istorijom (placeholder)
  static Future<bool> sinhronizujBrojPutovanjaSaIstorijom(String id) async {
    try {
      final brojIzIstorije = await izracunajBrojPutovanjaIzIstorije(id);

      final supabase = Supabase.instance.client;
      await supabase.from('registrovani_putnici').update({
        'broj_putovanja': brojIzIstorije,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      // Očisti cache nakon sinhronizacije da se promene odmah vide
      clearCache();

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Ažurira plaćanje za mesec (vozacId je UUID)
  /// Koristi voznje_log za praćenje vožnji
  Future<bool> azurirajPlacanjeZaMesec(
    String putnikId,
    double iznos,
    String vozacId,
    DateTime pocetakMeseca,
    DateTime krajMeseca,
  ) async {
    String? validVozacId;

    try {
      // Validacija UUID-a pre slanja u bazu
      if (vozacId.isNotEmpty && vozacId != 'Nepoznat vozač') {
        if (_isValidUuid(vozacId)) {
          validVozacId = vozacId;
        } else {
          // Pokušaj konverziju kroz VozacMappingService
          try {
            await VozacMappingService.initialize();
            final converted = VozacMappingService.getVozacUuidSync(vozacId);
            if (converted != null && _isValidUuid(converted)) {
              validVozacId = converted;
            }
          } catch (_) {}
        }
      }

      // 1. Dodaj zapis u voznje_log
      await VoznjeLogService.dodajUplatu(
        putnikId: putnikId,
        datum: DateTime.now(),
        iznos: iznos,
        vozacId: validVozacId,
      );

      // 2. Ažuriraj registrovani_putnici
      await updateRegistrovaniPutnik(putnikId, {
        'vreme_placanja': DateTime.now().toIso8601String(),
        'cena': iznos,
        'placeno': true,
        'placeni_mesec': pocetakMeseca.month,
        'placena_godina': pocetakMeseca.year,
        'ukupna_cena_meseca': iznos,
        'vozac_id': validVozacId,
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Helper funkcija za validaciju UUID formata
  bool _isValidUuid(String str) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(str);
  }

  /// Briše mesečnog putnika (soft delete)
  Future<bool> obrisiRegistrovaniPutnik(String id) async {
    try {
      await _supabase.from('registrovani_putnici').update({
        'obrisan': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      // 🔄 FORSIRAJ REALTIME REFRESH NAKON BRISANJA
      await RealtimeService.instance.refreshNow();

      // Očisti cache nakon brisanja da se promene odmah vide
      clearCache();

      // ⏳ DODATNI REFRESH NAKON PAUZE
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await RealtimeService.instance.refreshNow();

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Traži mesečne putnike po imenu, prezimenu ili broju telefona
  Future<List<RegistrovaniPutnik>> searchregistrovaniPutnici(String query) async {
    final response = await _supabase.from('registrovani_putnici').select('''
          *
        ''').eq('obrisan', false).or('putnik_ime.ilike.%$query%,broj_telefona.ilike.%$query%').order('putnik_ime');

    return response.map((json) => RegistrovaniPutnik.fromMap(json)).toList();
  }

  /// Dohvata sva plaćanja za mesečnog putnika
  /// 🔄 POJEDNOSTAVLJENO: Koristi voznje_log + registrovani_putnici
  Future<List<Map<String, dynamic>>> dohvatiPlacanjaZaPutnika(
    String putnikIme,
  ) async {
    try {
      List<Map<String, dynamic>> svaPlacanja = [];

      // Prvo nađi putnik ID
      final putnik = await _supabase
          .from('registrovani_putnici')
          .select('id, cena, vreme_placanja, vozac_id, placeni_mesec, placena_godina')
          .eq('putnik_ime', putnikIme)
          .maybeSingle();

      if (putnik == null) return [];

      // 1. Plaćanja iz voznje_log
      final placanjaIzLoga = await _supabase
          .from('voznje_log')
          .select()
          .eq('putnik_id', putnik['id'])
          .eq('tip', 'uplata')
          .order('datum', ascending: false) as List<dynamic>;

      for (var placanje in placanjaIzLoga) {
        svaPlacanja.add({
          'cena': placanje['iznos'],
          'created_at': placanje['created_at'],
          'vozac_ime': await _getVozacImeByUuid(placanje['vozac_id'] as String?),
          'putnik_ime': putnikIme,
          'datum': placanje['datum'],
        });
      }

      // 2. Fallback: poslednje plaćanje iz registrovani_putnici
      if (svaPlacanja.isEmpty && putnik['vreme_placanja'] != null) {
        svaPlacanja.add({
          'cena': putnik['cena'],
          'created_at': putnik['vreme_placanja'],
          'vozac_ime': await _getVozacImeByUuid(putnik['vozac_id'] as String?),
          'putnik_ime': putnikIme,
          'placeniMesec': putnik['placeni_mesec'],
          'placenaGodina': putnik['placena_godina'],
        });
      }

      return svaPlacanja;
    } catch (e) {
      return [];
    }
  }

  /// Helper funkcija za dobijanje imena vozača iz UUID-a
  Future<String?> _getVozacImeByUuid(String? vozacUuid) async {
    if (vozacUuid == null || vozacUuid.isEmpty) return null;

    try {
      final response = await _supabase.from('vozaci').select('ime').eq('id', vozacUuid).single();
      return response['ime'] as String?;
    } catch (e) {
      // Fallback na mapping service
      return VozacMappingService.getVozacIme(vozacUuid);
    }
  }

  /// Dohvata zakupljene putnike za današnji dan
  /// 🔄 POJEDNOSTAVLJENO: Koristi registrovani_putnici direktno
  static Future<List<Map<String, dynamic>>> getZakupljenoDanas() async {
    try {
      final supabase = Supabase.instance.client;
      // Zakupljeno je sada status u registrovani_putnici
      final response = await supabase
          .from('registrovani_putnici')
          .select()
          .eq('status', 'zakupljeno')
          .eq('aktivan', true)
          .eq('obrisan', false)
          .order('putnik_ime');

      return response.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Stream za realtime ažuriranja mesečnih putnika
  Stream<List<RegistrovaniPutnik>> get registrovaniPutniciStream {
    try {
      return _supabase
          .from('registrovani_putnici')
          .stream(primaryKey: ['id'])
          .order('putnik_ime')
          .map((data) {
            try {
              final listRaw = data as List<dynamic>;
              final filtered = listRaw.where((row) {
                try {
                  final map = row as Map<String, dynamic>;
                  final aktivan = map['aktivan'] ?? true;
                  final obrisan = map['obrisan'] ?? false;
                  return (aktivan as bool) && !(obrisan as bool);
                } catch (_) {
                  return true;
                }
              }).toList();

              return filtered
                  .map(
                    (json) => RegistrovaniPutnik.fromMap(
                      Map<String, dynamic>.from(json as Map),
                    ),
                  )
                  .toList();
            } catch (e) {
              return <RegistrovaniPutnik>[];
            }
          })
          .handleError((err) {
            return <RegistrovaniPutnik>[];
          });
    } catch (e) {
      return getAktivniregistrovaniPutnici().asStream();
    }
  }

  /// Izračunava broj putovanja iz voznje_log
  static Future<int> izracunajBrojPutovanjaIzIstorije(
    String mesecniPutnikId,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      final response =
          await supabase.from('voznje_log').select('datum').eq('putnik_id', mesecniPutnikId).eq('tip', 'voznja');

      // Broji JEDINSTVENE datume
      final jedinstveniDatumi = <String>{};
      for (final red in response) {
        if (red['datum'] != null) {
          jedinstveniDatumi.add(red['datum'] as String);
        }
      }

      return jedinstveniDatumi.length;
    } catch (e) {
      return 0;
    }
  }

  /// Izračunava broj otkazivanja iz voznje_log
  static Future<int> izracunajBrojOtkazivanjaIzIstorije(
    String mesecniPutnikId,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      final response =
          await supabase.from('voznje_log').select('datum').eq('putnik_id', mesecniPutnikId).eq('tip', 'otkazivanje');

      // Broji JEDINSTVENE datume
      final jedinstveniDatumi = <String>{};
      for (final red in response) {
        if (red['datum'] != null) {
          jedinstveniDatumi.add(red['datum'] as String);
        }
      }

      return jedinstveniDatumi.length;
    } catch (e) {
      return 0;
    }
  }

  // ==================== ENHANCED CAPABILITIES ====================

  /// Cache za učestale upite
  static final Map<String, dynamic> _cache = {};

  /// Čisti cache
  static void clearCache() {
    _cache.clear();
  }

  /// 🔍 Dobija vozača iz poslednjeg plaćanja za mesečnog putnika
  /// 🔄 POJEDNOSTAVLJENO: Koristi voznje_log + registrovani_putnici
  static Stream<String?> streamVozacPoslednjegPlacanja(String putnikId) {
    // Koristi registrovani_putnici stream i vraća vozac_id
    return Supabase.instance.client
        .from('registrovani_putnici')
        .stream(primaryKey: ['id'])
        .eq('id', putnikId)
        .map((data) {
          try {
            if (data.isEmpty) return null;
            final vozacId = data.first['vozac_id'] as String?;
            if (vozacId != null && vozacId.isNotEmpty) {
              return VozacMappingService.getVozacImeWithFallbackSync(vozacId);
            }
            return null;
          } catch (e) {
            return null;
          }
        });
  }
}
