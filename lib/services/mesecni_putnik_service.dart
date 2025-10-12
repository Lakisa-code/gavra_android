import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mesecni_putnik.dart';
import 'vozac_mapping_service.dart';

/// Servis za upravljanje mesečnim putnicima (normalizovana šema)
class MesecniPutnikService {
  MesecniPutnikService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;
  final SupabaseClient _supabase;

  /// Dohvata sve mesečne putnike
  Future<List<MesecniPutnik>> getAllMesecniPutnici() async {
    final response = await _supabase.from('mesecni_putnici').select('''
          *
        ''').eq('obrisan', false).order('putnik_ime');

    return response.map((json) => MesecniPutnik.fromMap(json)).toList();
  }

  /// Dohvata aktivne mesečne putnike
  Future<List<MesecniPutnik>> getAktivniMesecniPutnici() async {
    final response = await _supabase.from('mesecni_putnici').select('''
          *
        ''').eq('aktivan', true).eq('obrisan', false).order('putnik_ime');

    return response.map((json) => MesecniPutnik.fromMap(json)).toList();
  }

  /// Dohvata mesečnog putnika po ID-u
  Future<MesecniPutnik?> getMesecniPutnikById(String id) async {
    final response = await _supabase.from('mesecni_putnici').select('''
          *
        ''').eq('id', id).single();

    return MesecniPutnik.fromMap(response);
  }

  /// Dohvata mesečnog putnika po imenu (legacy compatibility)
  static Future<MesecniPutnik?> getMesecniPutnikByIme(String ime) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('mesecni_putnici')
          .select()
          .eq('putnik_ime', ime)
          .eq('obrisan', false)
          .single();

      return MesecniPutnik.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  /// Stream za aktivne mesečne putnike (legacy compatibility)
  static Stream<List<MesecniPutnik>> streamAktivniMesecniPutnici() {
    try {
      final supabase = Supabase.instance.client;
      return supabase
          .from('mesecni_putnici')
          .stream(primaryKey: ['id'])
          .order('putnik_ime')
          .map((data) {
            try {
              final listRaw = data as List<dynamic>;
              return listRaw
                  .where((row) {
                    final map = row as Map<String, dynamic>;
                    return (map['aktivan'] == true) && (map['obrisan'] != true);
                  })
                  .map(
                    (json) => MesecniPutnik.fromMap(
                      Map<String, dynamic>.from(json as Map),
                    ),
                  )
                  .toList();
            } catch (e) {
              return <MesecniPutnik>[];
            }
          })
          .handleError((err) {
            return <MesecniPutnik>[];
          });
    } catch (e) {
      // fallback to a one-time fetch if stream creation fails
      return Stream.fromFuture(
        Supabase.instance.client
            .from('mesecni_putnici')
            .select()
            .eq('aktivan', true)
            .eq('obrisan', false)
            .order('putnik_ime')
            .then(
              (response) => response
                  .map(
                    (json) =>
                        MesecniPutnik.fromMap(Map<String, dynamic>.from(json)),
                  )
                  .toList(),
            ),
      );
    }
  }

  /// Kreira novog mesečnog putnika
  Future<MesecniPutnik> createMesecniPutnik(MesecniPutnik putnik) async {
    final response = await _supabase
        .from('mesecni_putnici')
        .insert(putnik.toMap())
        .select('''
          *
        ''').single();

    return MesecniPutnik.fromMap(response);
  }

  /// Ažurira mesečnog putnika
  Future<MesecniPutnik> updateMesecniPutnik(
    String id,
    Map<String, dynamic> updates,
  ) async {
    updates['updated_at'] = DateTime.now().toIso8601String();

    final response = await _supabase
        .from('mesecni_putnici')
        .update(updates)
        .eq('id', id)
        .select('''
          *
        ''').single();

    return MesecniPutnik.fromMap(response);
  }

  /// Označava putnika kao plaćenog
  Future<void> oznaciKaoPlacen(String id, String vozacId) async {
    await updateMesecniPutnik(id, {
      'vreme_placanja': DateTime.now().toIso8601String(),
      'vozac_id': (vozacId.isEmpty)
          ? null
          : vozacId, // koristi postojeću vozac_id kolonu
    });
  }

  /// Deaktivira mesečnog putnika
  Future<void> deactivateMesecniPutnik(String id) async {
    await _supabase.from('mesecni_putnici').update({
      'aktivan': false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Toggle aktivnost mesečnog putnika
  Future<bool> toggleAktivnost(String id, bool aktivnost) async {
    try {
      await _supabase.from('mesecni_putnici').update({
        'aktivan': aktivnost,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Ažurira mesečnog putnika (legacy metoda name)
  Future<MesecniPutnik?> azurirajMesecnogPutnika(MesecniPutnik putnik) async {
    try {
      return await updateMesecniPutnik(putnik.id, putnik.toMap());
    } catch (e) {
      return null;
    }
  }

  /// Dodaje novog mesečnog putnika (legacy metoda name)
  Future<MesecniPutnik> dodajMesecnogPutnika(MesecniPutnik putnik) async {
    return await createMesecniPutnik(putnik);
  }

  /// Kreira dnevna putovanja iz mesečnih (placeholder - treba implementirati)
  Future<void> kreirajDnevnaPutovanjaIzMesecnih(
    MesecniPutnik putnik,
    DateTime datum,
  ) async {
    // ✅ Kreiranje dnevnih putovanja iz mesečnih putnika
    // Ova metoda kreira zapise u putovanja_istorija tabeli za svaki polazak

    // Implementacija će biti dodana kada bude potrebna za scheduling funkcionalnost
    // Trenutno se koristi direktno unošenje kroz glavnu logiku aplikacije
  }

  /// Sinhronizacija broja putovanja sa istorijom (placeholder)
  static Future<bool> sinhronizujBrojPutovanjaSaIstorijom(String id) async {
    try {
      final brojIzIstorije = await izracunajBrojPutovanjaIzIstorije(id);

      final supabase = Supabase.instance.client;
      await supabase.from('mesecni_putnici').update({
        'broj_putovanja': brojIzIstorije,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Sinhronizuje broj otkazivanja sa istorijom
  static Future<bool> sinhronizujBrojOtkazivanjaSaIstorijom(String id) async {
    try {
      final brojIzIstorije = await izracunajBrojOtkazivanjaIzIstorije(id);

      final supabase = Supabase.instance.client;
      await supabase.from('mesecni_putnici').update({
        'broj_otkazivanja': brojIzIstorije,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Ažurira plaćanje za mesec (vozacId je UUID)
  Future<bool> azurirajPlacanjeZaMesec(
    String putnikId,
    double iznos,
    String vozacId,
    DateTime pocetakMeseca,
    DateTime krajMeseca,
  ) async {
    try {
      print('🔍 [AZURIRAJ PLACANJE] Input vozacId: $vozacId');

      // Validacija UUID-a pre slanja u bazu
      String? validVozacId;
      if (vozacId.isNotEmpty && vozacId != 'Nepoznat vozač') {
        // Provjeri da li je već valid UUID
        if (_isValidUuid(vozacId)) {
          validVozacId = vozacId;
          print('✅ [AZURIRAJ PLACANJE] Valid UUID: $validVozacId');
        } else {
          // Ako nije UUID, pokušaj konverziju (fallback)
          print(
            '⚠️ [AZURIRAJ PLACANJE] Not a UUID, attempting conversion from: $vozacId',
          );
          final converted = VozacMappingService.getVozacUuidSync(vozacId);
          if (converted != null) {
            validVozacId = converted;
            print('✅ [AZURIRAJ PLACANJE] Converted to UUID: $validVozacId');
          } else {
            print(
              '❌ [AZURIRAJ PLACANJE] Failed to convert to UUID, using null',
            );
            validVozacId = null;
          }
        }
      }

      print('🔍 [AZURIRAJ PLACANJE] Final vozac_id: $validVozacId');

      // 1. PROVJERI DA LI JE VEĆ POSTOJI ZAPIS ZA OVAJ MESEC (sprečava duplikate)
      final existingPayment = await _supabase
          .from('putovanja_istorija')
          .select('id')
          .eq('mesecni_putnik_id', putnikId)
          .eq('tip_putnika', 'mesecni')
          .gte('datum_putovanja', pocetakMeseca.toIso8601String().split('T')[0])
          .lte('datum_putovanja', krajMeseca.toIso8601String().split('T')[0])
          .eq('status', 'placeno')
          .limit(1);

      if (existingPayment.isNotEmpty) {
        print(
          '⚠️ [DUPLIKAT] Plaćanje za mesec ${pocetakMeseca.month}/${pocetakMeseca.year} već postoji!',
        );
        // Ažuriraj postojeći zapis umesto kreiranja novog
        await _supabase.from('putovanja_istorija').update({
          'vozac_id': validVozacId,
          'cena': iznos,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', existingPayment.first['id'] as String);
        print('✅ [AŽURIRANJE] Ažurirani postojeći zapis plaćanja');
      } else {
        // 2. DODAJ NOVI ZAPIS U ISTORIJU PLAĆANJA (putovanja_istorija)
        final putnik = await getMesecniPutnikById(putnikId);
        if (putnik != null) {
          await _supabase.from('putovanja_istorija').insert({
            'mesecni_putnik_id': putnikId,
            'putnik_ime': putnik.putnikIme,
            'tip_putnika': 'mesecni',
            'datum_putovanja': DateTime.now().toIso8601String().split('T')[0],
            'vreme_polaska': 'mesecno_placanje',
            'status': 'placeno',
            'vozac_id': validVozacId,
            'cena': iznos,
            'napomene':
                'Mesečno plaćanje za ${pocetakMeseca.month}/${pocetakMeseca.year}',
          });
          print('✅ [NOVA ISTORIJA] Dodano u putovanja_istorija: $iznos din');
        }
      }

      // 2. AŽURIRAJ MESEČNOG PUTNIKA (za kompatibilnost)
      print(
        '🔍 [AZURIRAJ PLACANJE] Ažuriram mesečnog putnika ID: $putnikId sa iznosom: $iznos',
      );
      await updateMesecniPutnik(putnikId, {
        'vreme_placanja': DateTime.now().toIso8601String(),
        'vozac_id': validVozacId,
        'cena': iznos,
        'iznos_placanja': iznos, // 🔥 KLJUČNO: Ažuriraj i iznosPlacanja polje
        'placeni_mesec': pocetakMeseca.month,
        'placena_godina': pocetakMeseca.year,
        'ukupna_cena_meseca': iznos,
      });
      print('✅ [AZURIRAJ PLACANJE] Mesečni putnik uspešno ažuriran');

      return true;
    } catch (e) {
      print('Greška u azurirajPlacanjeZaMesec: $e');
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
  Future<bool> obrisiMesecniPutnik(String id) async {
    try {
      await _supabase.from('mesecni_putnici').update({
        'obrisan': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Traži mesečne putnike po imenu, prezimenu ili broju telefona
  Future<List<MesecniPutnik>> searchMesecniPutnici(String query) async {
    final response = await _supabase
        .from('mesecni_putnici')
        .select('''
          *
        ''')
        .eq('obrisan', false)
        .or('ime.ilike.%$query%,prezime.ilike.%$query%,broj_telefona.ilike.%$query%')
        .order('putnik_ime');

    return response.map((json) => MesecniPutnik.fromMap(json)).toList();
  }

  /// Dohvata mesečne putnike za datu rutu
  Future<List<MesecniPutnik>> getMesecniPutniciZaRutu(String rutaId) async {
    final response = await _supabase
        .from('mesecni_putnici')
        .select('''
          *
        ''')
        .eq('ruta_id', rutaId)
        .eq('aktivan', true)
        .eq('obrisan', false)
        .order('putnik_ime');

    return response.map((json) => MesecniPutnik.fromMap(json)).toList();
  }

  /// Ažurira broj putovanja za putnika
  Future<void> azurirajBrojPutovanja(String id, {bool povecaj = true}) async {
    final putnik = await getMesecniPutnikById(id);
    if (putnik == null) return;

    final noviBroj =
        povecaj ? putnik.brojPutovanja + 1 : putnik.brojPutovanja - 1;

    await updateMesecniPutnik(id, {
      'broj_putovanja': noviBroj,
      'poslednje_putovanje': DateTime.now().toIso8601String(),
    });
  }

  /// Ažurira broj otkazivanja za putnika
  Future<void> azurirajBrojOtkazivanja(String id, {bool povecaj = true}) async {
    final putnik = await getMesecniPutnikById(id);
    if (putnik == null) return;

    final noviBroj =
        povecaj ? putnik.brojOtkazivanja + 1 : putnik.brojOtkazivanja - 1;

    await updateMesecniPutnik(id, {
      'broj_otkazivanja': noviBroj,
    });
  }

  /// Dohvata sva ukrcavanja za mesečnog putnika
  Future<List<Map<String, dynamic>>> dohvatiUkrcavanjaZaPutnika(
    String putnikIme,
  ) async {
    try {
      final ukrcavanja = await _supabase
          .from('putovanja_istorija')
          .select()
          .eq('putnik_ime', putnikIme)
          .eq('status', 'pokupljen')
          .order('created_at', ascending: false) as List<dynamic>;

      return ukrcavanja.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Dohvata sve otkaze za mesečnog putnika
  Future<List<Map<String, dynamic>>> dohvatiOtkazeZaPutnika(
    String putnikIme,
  ) async {
    try {
      final otkazi = await _supabase
          .from('putovanja_istorija')
          .select()
          .eq('putnik_ime', putnikIme)
          .eq('status', 'otkazan')
          .order('created_at', ascending: false) as List<dynamic>;

      return otkazi.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Dohvata sva plaćanja za mesečnog putnika iz putovanja_istorija
  Future<List<Map<String, dynamic>>> dohvatiPlacanjaZaPutnika(
    String putnikIme,
  ) async {
    try {
      List<Map<String, dynamic>> svaPlacanja = [];

      // 1. SVA PLAĆANJA iz putovanja_istorija (i dnevna i mesečna)
      final placanjaIzIstorije = await _supabase
          .from('putovanja_istorija')
          .select()
          .eq('putnik_ime', putnikIme)
          .gt('cena', 0)
          .order('created_at', ascending: false) as List<dynamic>;

      // Konvertuj u standardizovan format
      for (var placanje in placanjaIzIstorije) {
        svaPlacanja.add({
          'cena': placanje['cena'],
          'created_at': placanje['created_at'],
          'vozac_ime':
              await _getVozacImeByUuid(placanje['vozac_id'] as String?),
          'putnik_ime': putnikIme,
          'tip': placanje['tip_putnika'] ?? 'dnevni',
          'placeniMesec': placanje['placeni_mesec'],
          'placenaGodina': placanje['placena_godina'],
          'status': placanje['status'],
          'napomene': placanje['napomene'],
          'datum_putovanja': placanje['datum_putovanja'],
        });
      }

      // FALLBACK: Ako nema plaćanja u istoriji, učitaj iz mesecni_putnici (za postojeće podatke)
      if (svaPlacanja.isEmpty) {
        final mesecnaPlacanja = await _supabase
            .from('mesecni_putnici')
            .select(
              'cena, vreme_placanja, vozac_id, placeni_mesec, placena_godina',
            )
            .eq('putnik_ime', putnikIme)
            .not('vreme_placanja', 'is', null)
            .order('vreme_placanja', ascending: false) as List<dynamic>;

        // Konvertuj mesečna plaćanja u isti format
        for (var mesecno in mesecnaPlacanja) {
          svaPlacanja.add({
            'cena': mesecno['cena'],
            'created_at': mesecno['vreme_placanja'],
            'vozac_ime':
                await _getVozacImeByUuid(mesecno['vozac_id'] as String?),
            'putnik_ime': putnikIme,
            'tip': 'mesecna_karta',
            'placeniMesec': mesecno['placeni_mesec'],
            'placenaGodina': mesecno['placena_godina'],
            'status': 'placeno',
            'napomene': 'Legacy plaćanje iz mesecni_putnici tabele',
          });
        }
      }

      return svaPlacanja;
    } catch (e) {
      print('❌ Greška pri dohvatanju plaćanja: $e');
      return [];
    }
  }

  /// Helper funkcija za dobijanje imena vozača iz UUID-a
  Future<String?> _getVozacImeByUuid(String? vozacUuid) async {
    if (vozacUuid == null || vozacUuid.isEmpty) return null;

    try {
      final response = await _supabase
          .from('vozaci')
          .select('ime')
          .eq('id', vozacUuid)
          .single();
      return response['ime'] as String?;
    } catch (e) {
      // Fallback na mapping service
      return VozacMappingService.getVozacIme(vozacUuid);
    }
  }

  /// Dohvata zakupljene putnike za današnji dan
  static Future<List<Map<String, dynamic>>> getZakupljenoDanas() async {
    try {
      final supabase = Supabase.instance.client;
      final danas = DateTime.now().toIso8601String().split('T')[0];
      final response = await supabase
          .from('putovanja_istorija')
          .select()
          .eq('datum', danas)
          .eq('status', 'zakupljeno')
          .order('vreme_polaska');

      // Supabase returns List<dynamic> of maps
      return response
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Stream za realtime ažuriranja mesečnih putnika
  Stream<List<MesecniPutnik>> get mesecniPutniciStream {
    try {
      return _supabase
          .from('mesecni_putnici')
          .stream(primaryKey: ['id'])
          .order('putnik_ime')
          .map((data) {
            try {
              final listRaw = data as List<dynamic>;
              final filtered = listRaw.where((row) {
                try {
                  final map = row as Map<String, dynamic>;
                  // ✅ ISPRAVLJENO: Filtriraj i po aktivan statusu i po obrisan statusu
                  final aktivan =
                      map['aktivan'] ?? true; // default true ako nema vrednost
                  final obrisan = map['obrisan'] ??
                      false; // default false ako nema vrednost
                  print(
                    '🔍 MESECNI STREAM DEBUG: ${map['putnik_ime']} - aktivan: $aktivan, obrisan: $obrisan',
                  );
                  return (aktivan as bool) && !(obrisan as bool);
                } catch (_) {
                  return true;
                }
              }).toList();

              return filtered
                  .map(
                    (json) => MesecniPutnik.fromMap(
                      Map<String, dynamic>.from(json as Map),
                    ),
                  )
                  .toList();
            } catch (e) {
              return <MesecniPutnik>[];
            }
          })
          .handleError((err) {
            return <MesecniPutnik>[];
          });
    } catch (e) {
      // fallback to a one-time fetch if stream creation fails
      return getAktivniMesecniPutnici().asStream();
    }
  }

  /// Izračunava broj putovanja iz istorije
  static Future<int> izracunajBrojPutovanjaIzIstorije(
    String mesecniPutnikId,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      // Dobij sve JEDINSTVENE DATUME kada je putnik pokupljen
      final response = await supabase
          .from('putovanja_istorija')
          .select('datum')
          .eq('mesecni_putnik_id', mesecniPutnikId)
          .or('pokupljen.eq.true,status.eq.pokupljeno');

      // Broji JEDINSTVENE datume (jedan dan = jedno putovanje)
      final jedinstveniDatumi = <String>{};
      for (final red in response) {
        if (red['datum'] != null) {
          jedinstveniDatumi.add(red['datum'] as String);
        }
      }

      final brojPutovanja = jedinstveniDatumi.length;

      return brojPutovanja;
    } catch (e) {
      return 0;
    }
  }

  /// Izračunava broj otkazivanja iz istorije
  static Future<int> izracunajBrojOtkazivanjaIzIstorije(
    String mesecniPutnikId,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      // Dobij sve JEDINSTVENE DATUME kada je putnik otkazan
      final response = await supabase
          .from('putovanja_istorija')
          .select('datum')
          .eq('mesecni_putnik_id', mesecniPutnikId)
          .or('status.eq.otkazano,status.eq.nije_se_pojavio');

      // Broji JEDINSTVENE datume (jedan dan = jedno otkazivanje)
      final jedinstveniDatumi = <String>{};
      for (final red in response) {
        if (red['datum'] != null) {
          jedinstveniDatumi.add(red['datum'] as String);
        }
      }

      final brojOtkazivanja = jedinstveniDatumi.length;

      return brojOtkazivanja;
    } catch (e) {
      return 0;
    }
  }

  // ==================== ENHANCED CAPABILITIES ====================

  /// Cache za učestale upite
  static final Map<String, dynamic> _cache = {};
  static DateTime? _lastCacheUpdate;
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Čisti cache
  static void clearCache() {
    _cache.clear();
    _lastCacheUpdate = null;
  }

  /// Da li je cache aktuelan
  bool get _isCacheValid {
    if (_lastCacheUpdate == null) return false;
    return DateTime.now().difference(_lastCacheUpdate!).inMinutes <
        _cacheDuration.inMinutes;
  }

  /// Dohvata putnika sa cache-iranjem
  Future<List<MesecniPutnik>> getAktivniMesecniPutniciCached() async {
    const cacheKey = 'aktivni_mesecni_putnici';

    if (_isCacheValid && _cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey] as List<dynamic>;
      return cached.cast<MesecniPutnik>();
    }

    final putnici = await getAktivniMesecniPutnici();
    _cache[cacheKey] = putnici;
    _lastCacheUpdate = DateTime.now();

    return putnici;
  }

  /// Batch operacija za kreiranje više putnika odjednom
  Future<List<MesecniPutnik>> createMesecniPutniciBatch(
      List<MesecniPutnik> putnici) async {
    final results = <MesecniPutnik>[];

    for (final putnik in putnici) {
      try {
        final created = await createMesecniPutnik(putnik);
        results.add(created);
      } catch (e) {
        // Log error but continue with other passengers
        print('Error creating putnik ${putnik.putnikIme}: $e');
      }
    }

    clearCache(); // Clear cache after batch operation
    return results;
  }

  /// Batch operacija za ažuriranje više putnika
  Future<List<MesecniPutnik>> updateMesecniPutniciBatch(
      Map<String, Map<String, dynamic>> updates) async {
    final results = <MesecniPutnik>[];

    for (final entry in updates.entries) {
      try {
        final updated = await updateMesecniPutnik(entry.key, entry.value);
        results.add(updated);
      } catch (e) {
        print('Error updating putnik ${entry.key}: $e');
      }
    }

    clearCache();
    return results;
  }

  /// Statistike o mesečnim putnicima
  Future<Map<String, dynamic>> getStatistike() async {
    final putnici = await getAllMesecniPutnici();

    return {
      'ukupno': putnici.length,
      'aktivni': putnici.where((p) => p.aktivan).length,
      'ucenici': putnici.where((p) => p.tip == 'ucenik').length,
      'radnici': putnici.where((p) => p.tip == 'radnik').length,
      'placeni_ovaj_mesec':
          putnici.where((p) => p.isPlacenZaTrenutniMesec).length,
      'prosecna_cena': putnici
              .where((p) => p.cena != null)
              .map((p) => p.cena!)
              .fold(0.0, (a, b) => a + b) /
          putnici.length,
    };
  }

  /// Pretraga putnika po različitim kriterijumima
  Future<List<MesecniPutnik>> searchPutnici({
    String? ime,
    String? tip,
    bool? aktivan,
    bool? placen,
    String? vozac,
  }) async {
    var query = _supabase.from('mesecni_putnici').select().eq('obrisan', false);

    if (ime != null && ime.isNotEmpty) {
      query = query.ilike('putnik_ime', '%$ime%');
    }

    if (tip != null) {
      query = query.eq('tip', tip);
    }

    if (aktivan != null) {
      query = query.eq('aktivan', aktivan);
    }

    if (vozac != null) {
      query = query.eq('vozac', vozac);
    }

    final response = await query.order('putnik_ime');
    var results = response.map((json) => MesecniPutnik.fromMap(json)).toList();

    // Filter for payment status (can't be done in SQL easily)
    if (placen != null) {
      results =
          results.where((p) => p.isPlacenZaTrenutniMesec == placen).toList();
    }

    return results;
  }

  /// Dobija putnika koji rade današnji dan
  Future<List<MesecniPutnik>> getPutniciZaDanas() async {
    final sviAktivni = await getAktivniMesecniPutnici();
    return sviAktivni.where((p) => p.radiDanas()).toList();
  }

  /// Dobija učenike koji trebaju da budu pokupljeni u određeno vreme
  Future<List<MesecniPutnik>> getUceniciZaVreme(String vreme) async {
    final putniciDanas = await getPutniciZaDanas();
    return putniciDanas
        .where((p) => p.isUcenik && p.trebaPokupiti(vreme))
        .toList();
  }

  /// Validira putnika pre čuvanja
  Future<Map<String, String>> validatePutnik(MesecniPutnik putnik) async {
    final errors = putnik.validateFull();

    // Additional database-level validations
    if (putnik.id.isNotEmpty) {
      // Check for duplicate name (excluding self)
      final existing = await _supabase
          .from('mesecni_putnici')
          .select('id')
          .eq('putnik_ime', putnik.putnikIme)
          .neq('id', putnik.id)
          .eq('obrisan', false);

      if (existing.isNotEmpty) {
        errors['putnikIme'] = 'Putnik sa ovim imenom već postoji';
      }
    } else {
      // Check for duplicate name for new records
      final existing = await _supabase
          .from('mesecni_putnici')
          .select('id')
          .eq('putnik_ime', putnik.putnikIme)
          .eq('obrisan', false);

      if (existing.isNotEmpty) {
        errors['putnikIme'] = 'Putnik sa ovim imenom već postoji';
      }
    }

    return errors;
  }

  /// Export putnika u CSV format
  String exportToCSV(List<MesecniPutnik> putnici) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln(
        'ID,Ime,Tip,Tip Škole,Aktivan,Status,Cena,Radni Dani,Broj Putovanja,Datum Početka,Datum Kraja');

    // Data rows
    for (final putnik in putnici) {
      buffer.writeln(
        [
          putnik.id,
          putnik.putnikIme,
          putnik.tip,
          putnik.tipSkole ?? '',
          putnik.aktivan,
          putnik.status,
          putnik.cena ?? 0,
          putnik.radniDani,
          putnik.brojPutovanja,
          putnik.datumPocetkaMeseca.toIso8601String(),
          putnik.datumKrajaMeseca.toIso8601String(),
        ].join(','),
      );
    }

    return buffer.toString();
  }
}
