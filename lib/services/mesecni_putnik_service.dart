import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/action_log.dart';
import '../models/mesecni_putnik.dart';
import 'realtime_service.dart'; // 🔄 DODATO za refresh nakon brisanja
import 'vozac_mapping_service.dart';

/// Servis za upravljanje mesečnim putnicima (normalizovana šema)
class MesecniPutnikService {
  MesecniPutnikService({SupabaseClient? supabaseClient}) : _supabase = supabaseClient ?? Supabase.instance.client;
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
      final response =
          await supabase.from('mesecni_putnici').select().eq('putnik_ime', ime).eq('obrisan', false).single();

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

              final filtered = listRaw.where((row) {
                final map = row as Map<String, dynamic>;
                return (map['aktivan'] == true) && (map['obrisan'] != true);
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
                    (json) => MesecniPutnik.fromMap(Map<String, dynamic>.from(json)),
                  )
                  .toList(),
            ),
      );
    }
  }

  /// Kreira novog mesečnog putnika
  Future<MesecniPutnik> createMesecniPutnik(MesecniPutnik putnik) async {
    final response = await _supabase.from('mesecni_putnici').insert(putnik.toMap()).select('''
          *
        ''').single();

    // Očisti cache nakon kreiranja da se novi putnik odmah vidi
    clearCache();

    return MesecniPutnik.fromMap(response);
  }

  /// Ažurira mesečnog putnika
  Future<MesecniPutnik> updateMesecniPutnik(
    String id,
    Map<String, dynamic> updates,
  ) async {
    updates['updated_at'] = DateTime.now().toIso8601String();

    final response = await _supabase.from('mesecni_putnici').update(updates).eq('id', id).select('''
          *
        ''').single();

    // Očisti cache nakon update-a da se promene odmah vide
    clearCache();

    return MesecniPutnik.fromMap(response);
  }

  /// Deaktivira mesečnog putnika
  Future<void> deactivateMesecniPutnik(String id) async {
    await _supabase.from('mesecni_putnici').update({
      'aktivan': false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);

    // Očisti cache nakon deaktivacije da se promene odmah vide
    clearCache();
  }

  /// Toggle aktivnost mesečnog putnika
  Future<bool> toggleAktivnost(String id, bool aktivnost) async {
    try {
      await _supabase.from('mesecni_putnici').update({
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
  Future<MesecniPutnik?> azurirajMesecnogPutnika(MesecniPutnik putnik) async {
    try {
      final result = await updateMesecniPutnik(putnik.id, putnik.toMap());
      return result;
    } catch (e) {
      rethrow; // Prebaci grešku da caller može da je uhvati
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

      // Očisti cache nakon sinhronizacije da se promene odmah vide
      clearCache();

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

      // Očisti cache nakon sinhronizacije da se promene odmah vide
      clearCache();

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
    String? validVozacId; // Declare outside try block for access in catch

    try {
      // Validacija UUID-a pre slanja u bazu
      if (vozacId.isNotEmpty && vozacId != 'Nepoznat vozač') {
        // Provjeri da li je već valid UUID
        if (_isValidUuid(vozacId)) {
          validVozacId = vozacId;
        } else {
          // Ako nije UUID, pokušaj konverziju kroz VozacMappingService
          try {
            await VozacMappingService.initialize(); // Osiguraj da je inicijalizovan
            final converted = VozacMappingService.getVozacUuidSync(vozacId);
            if (converted != null && _isValidUuid(converted)) {
              validVozacId = converted;
            } else {
              // 🆘 HARDCODED FALLBACK AKO MAPIRANJE NE RADI
              if (vozacId == 'Bojan') {
                validVozacId = '6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e';
              } else if (vozacId == 'Svetlana') {
                validVozacId = '5b379394-084e-1c7d-76bf-fc193a5b6c7d';
              } else if (vozacId == 'Bruda') {
                validVozacId = '7d59b5b6-2a4a-3e9f-98e1-1e3b4c7d8e9f';
              } else if (vozacId == 'Bilevski') {
                validVozacId = '8e68c6c7-3b8b-4f8a-a9d2-2f4b5c8d9e0f';
              } else if (vozacId == 'Vlajic') {
                validVozacId = '67ea0a22-689c-41b8-b576-5b27145e8e5e';
              } else {
                validVozacId = null;
              }
            }
          } catch (e) {
            // 🆘 HARDCODED FALLBACK I ZA EXCEPTION
            if (vozacId == 'Vlajic') {
              validVozacId = '67ea0a22-689c-41b8-b576-5b27145e8e5e';
            } else if (vozacId == 'Bojan') {
              validVozacId = '6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e';
            } else if (vozacId == 'Svetlana') {
              validVozacId = '5b379394-084e-1c7d-76bf-fc193a5b6c7d';
            } else if (vozacId == 'Bruda') {
              validVozacId = '7d59b5b6-2a4a-3e9f-98e1-1e3b4c7d8e9f';
            } else if (vozacId == 'Bilevski') {
              validVozacId = '8e68c6c7-3b8b-4f8a-a9d2-2f4b5c8d9e0f';
            } else {
              validVozacId = null;
            }
          }
        }
      }

      // 1. UVEK DODAJ NOVI ZAPIS ZA PLAĆANJE (omogućava višestruka plaćanja za isti mesec)
      final putnik = await getMesecniPutnikById(putnikId);
      if (putnik != null) {
        // Odaberi adresu za putovanje (prioritet Bela Crkva)
        String? adresaId = putnik.adresaBelaCrkvaId ?? putnik.adresaVrsacId;

        // Kreiraj ActionLog za plaćanje sa created_by

        // Osiguraj da vozacId nije null ili prazan
        final effectiveVozacId = validVozacId ?? '';

        // Uvek kreiraj zapis u putovanja_istorija - čuvaj informaciju o vozaču
        final actionLog = ActionLog(
          createdBy: effectiveVozacId.isNotEmpty ? effectiveVozacId : 'sistem',
          createdAt: DateTime.now(),
        ).addAction(
          ActionType.paid,
          effectiveVozacId.isNotEmpty ? effectiveVozacId : 'sistem',
          'Mesečno plaćanje za ${pocetakMeseca.month}/${pocetakMeseca.year}',
        );

        // Kreiraj napomenu sa informacijom o vozaču
        final vozacIme = effectiveVozacId.isNotEmpty
            ? await VozacMappingService.getVozacIme(effectiveVozacId) ?? 'Nepoznat vozač'
            : 'Sistem';
        final napomena = 'Mesečno plaćanje za ${pocetakMeseca.month}/${pocetakMeseca.year} - Naplatio: $vozacIme';

        try {
          await _supabase.from('putovanja_istorija').insert({
            'mesecni_putnik_id': putnikId,
            'putnik_ime': putnik.putnikIme,
            'tip_putnika': 'mesecni',
            'datum_putovanja': DateTime.now().toIso8601String().split('T')[0],
            'vreme_polaska': 'mesecno_placanje',
            'status': 'placeno',
            'vozac_id': effectiveVozacId.isNotEmpty ? effectiveVozacId : null, // null ako nema validnog UUID-a
            'created_by': effectiveVozacId.isNotEmpty ? effectiveVozacId : null,
            'adresa_id': adresaId,
            'cena': iznos,
            'napomene': napomena, // Čuva informaciju o tome ko je naplatio
            'action_log': actionLog.toJson(),
            // UKLONJENA vozac_ime kolona jer ne postoji u tabeli
          });
        } catch (insertError) {
          // Ako insert ne uspe zbog foreign key, pokušaj bez vozac_id
          await _supabase.from('putovanja_istorija').insert({
            'mesecni_putnik_id': putnikId,
            'putnik_ime': putnik.putnikIme,
            'tip_putnika': 'mesecni',
            'datum_putovanja': DateTime.now().toIso8601String().split('T')[0],
            'vreme_polaska': 'mesecno_placanje',
            'status': 'placeno',
            'vozac_id': null, // Ne koristi foreign key
            'created_by': null,
            'adresa_id': adresaId,
            'cena': iznos,
            'napomene': napomena, // I dalje čuva ko je naplatio
            'action_log': actionLog.toJson(),
            // UKLONJENA vozac_ime kolona jer ne postoji u tabeli
          });
        }
      }

      // 2. AŽURIRAJ MESEČNOG PUTNIKA - izračunaj ukupnu sumu svih plaćanja za mesec
      // VAŽNO: Ovo se uvek izvršava, bez obzira na insert u putovanja_istorija
      final ukupanIznos = await _izracunajUkupnuSumuZaMesec(
        putnikId,
        pocetakMeseca,
        krajMeseca,
      );

      await updateMesecniPutnik(putnikId, {
        'vreme_placanja': DateTime.now().toIso8601String(),
        'cena': ukupanIznos, // ukupna suma svih plaćanja
        'placeni_mesec': pocetakMeseca.month,
        'placena_godina': pocetakMeseca.year,
        'ukupna_cena_meseca': ukupanIznos, // ukupna suma svih plaćanja
        'vozac_id': validVozacId, // ✅ FIX: Dodaj vozac_id koji je naplatio
      });

      return true;
    } catch (e) {
      // Log greška za debugging
      // Dodaj specifične informacije o grešci za debugging
      if (e.toString().contains('violates foreign key constraint')) {}

      return false;
    }
  }

  /// Helper funkcija za validaciju UUID formata
  bool _isValidUuid(String str) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(str);
  }

  /// Izračunava ukupnu sumu svih plaćanja za mesec iz tabele putovanja_istorija
  Future<double> _izracunajUkupnuSumuZaMesec(
    String putnikId,
    DateTime pocetakMeseca,
    DateTime krajMeseca,
  ) async {
    try {
      final placanja = await _supabase
          .from('putovanja_istorija')
          .select('cena')
          .eq('mesecni_putnik_id', putnikId)
          .eq('tip_putnika', 'mesecni')
          .gte('datum_putovanja', pocetakMeseca.toIso8601String().split('T')[0])
          .lte('datum_putovanja', krajMeseca.toIso8601String().split('T')[0])
          .eq('status', 'placeno');

      double ukupno = 0.0;
      for (final placanje in placanja) {
        final iznos = (placanje['cena'] as num?)?.toDouble() ?? 0.0;
        ukupno += iznos;
      }

      return ukupno;
    } catch (e) {
      return 0.0;
    }
  }

  /// Briše mesečnog putnika (soft delete)
  Future<bool> obrisiMesecniPutnik(String id) async {
    try {
      await _supabase.from('mesecni_putnici').update({
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
  Future<List<MesecniPutnik>> searchMesecniPutnici(String query) async {
    final response = await _supabase.from('mesecni_putnici').select('''
          *
        ''').eq('obrisan', false).or('putnik_ime.ilike.%$query%,broj_telefona.ilike.%$query%').order('putnik_ime');

    return response.map((json) => MesecniPutnik.fromMap(json)).toList();
  }

  /// Dohvata mesečne putnike za datu rutu
  Future<List<MesecniPutnik>> getMesecniPutniciZaRutu(String rutaId) async {
    final response = await _supabase.from('mesecni_putnici').select('''
          *
        ''').eq('ruta_id', rutaId).eq('aktivan', true).eq('obrisan', false).order('putnik_ime');

    return response.map((json) => MesecniPutnik.fromMap(json)).toList();
  }

  /// Ažurira broj putovanja za putnika
  Future<void> azurirajBrojPutovanja(String id, {bool povecaj = true}) async {
    final putnik = await getMesecniPutnikById(id);
    if (putnik == null) return;

    final noviBroj = povecaj ? putnik.brojPutovanja + 1 : putnik.brojPutovanja - 1;

    await updateMesecniPutnik(id, {
      'broj_putovanja': noviBroj,
      'poslednje_putovanje': DateTime.now().toIso8601String(),
    });
  }

  /// Ažurira broj otkazivanja za putnika
  Future<void> azurirajBrojOtkazivanja(String id, {bool povecaj = true}) async {
    final putnik = await getMesecniPutnikById(id);
    if (putnik == null) return;

    final noviBroj = povecaj ? putnik.brojOtkazivanja + 1 : putnik.brojOtkazivanja - 1;

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
          'vozac_ime': await _getVozacImeByUuid(placanje['vozac_id'] as String?),
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
            'vozac_ime': await _getVozacImeByUuid(mesecno['vozac_id'] as String?),
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
      return response.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
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
                  final aktivan = map['aktivan'] ?? true; // default true ako nema vrednost
                  final obrisan = map['obrisan'] ?? false; // default false ako nema vrednost
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
    return DateTime.now().difference(_lastCacheUpdate!).inMinutes < _cacheDuration.inMinutes;
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
    List<MesecniPutnik> putnici,
  ) async {
    final results = <MesecniPutnik>[];

    for (final putnik in putnici) {
      try {
        final created = await createMesecniPutnik(putnik);
        results.add(created);
      } catch (e) {
        // Log error but continue with other passengers
      }
    }

    clearCache(); // Clear cache after batch operation
    return results;
  }

  /// Batch operacija za ažuriranje više putnika
  Future<List<MesecniPutnik>> updateMesecniPutniciBatch(
    Map<String, Map<String, dynamic>> updates,
  ) async {
    final results = <MesecniPutnik>[];

    for (final entry in updates.entries) {
      try {
        final updated = await updateMesecniPutnik(entry.key, entry.value);
        results.add(updated);
      } catch (e) {
        // Silently ignore individual update errors
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
      'placeni_ovaj_mesec': putnici.where((p) => p.isPlacenZaTrenutniMesec).length,
      'prosecna_cena':
          putnici.where((p) => p.cena != null).map((p) => p.cena!).fold(0.0, (a, b) => a + b) / putnici.length,
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
      results = results.where((p) => p.isPlacenZaTrenutniMesec == placen).toList();
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
    return putniciDanas.where((p) => p.isUcenik && p.trebaPokupiti(vreme)).toList();
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
      final existing =
          await _supabase.from('mesecni_putnici').select('id').eq('putnik_ime', putnik.putnikIme).eq('obrisan', false);

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
      'ID,Ime,Tip,Tip Škole,Aktivan,Status,Cena,Radni Dani,Broj Putovanja,Datum Početka,Datum Kraja',
    );

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

  /// 🔍 Dobija vozača iz poslednjeg plaćanja za mesečnog putnika
  // 🔥 REALTIME STREAM: Dobija vozača poslednjeg plaćanja za putnika
  static Stream<String?> streamVozacPoslednjegPlacanja(String putnikId) {
    return Supabase.instance.client.from('putovanja_istorija').stream(primaryKey: ['id']).map((data) {
      try {
        if (data.isEmpty) return null;

        // Filtriraj po mesecni_putnik_id, tip_putnika i status
        final filtered = data.where((item) {
          return item['mesecni_putnik_id'] == putnikId &&
              item['tip_putnika'] == 'mesecni' &&
              item['status'] == 'placeno';
        }).toList();

        if (filtered.isEmpty) return null;

        // Sortiraj po created_at da dobijemo poslednje plaćanje
        final sortedData = List<Map<String, dynamic>>.from(filtered);
        sortedData.sort((a, b) {
          final aTime = a['created_at'] as String?;
          final bTime = b['created_at'] as String?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime); // Descending (najnovije prvo)
        });

        final vozacId = sortedData.first['vozac_id'] as String?;
        final napomene = sortedData.first['napomene'] as String?;

        // 1. PRIORITET: Pokušaj sa vozac_id preko UUID mapiranja
        if (vozacId != null && vozacId.isNotEmpty) {
          final vozacIme = VozacMappingService.getVozacImeWithFallbackSync(vozacId);
          if (vozacIme != null && vozacIme != 'Nepoznat') {
            return vozacIme;
          }
        }

        // 2. FALLBACK: Izvuci ime vozača iz napomena
        if (napomene != null && napomene.contains('Naplatio:')) {
          try {
            final startIndex = napomene.indexOf('Naplatio:') + 'Naplatio:'.length;
            // Nova logika - direktno ime vozača bez UUID dela
            final vozacIme = napomene.substring(startIndex).trim();
            if (vozacIme.isNotEmpty) {
              return vozacIme;
            }
          } catch (e) {
            // Ako parsing ne uspe, samo nastavi
          }
        }

        return 'Nepoznat vozač';
      } catch (e) {
        return null;
      }
    });
  }

  static Future<String?> getVozacPoslednjegPlacanja(String putnikId) async {
    try {
      final placanja = await Supabase.instance.client
          .from('putovanja_istorija')
          .select('vozac_id, napomene')
          .eq('mesecni_putnik_id', putnikId)
          .eq('tip_putnika', 'mesecni')
          .eq('status', 'placeno')
          .order('created_at', ascending: false)
          .limit(1) as List<dynamic>;

      if (placanja.isNotEmpty) {
        final vozacId = placanja.first['vozac_id'] as String?;
        final napomene = placanja.first['napomene'] as String?;

        // 1. PRIORITET: Pokušaj sa vozac_id preko UUID mapiranja
        if (vozacId != null && vozacId.isNotEmpty) {
          final vozacIme = VozacMappingService.getVozacImeWithFallbackSync(vozacId);
          if (vozacIme != null && vozacIme != 'Nepoznat') {
            return vozacIme;
          }
        }

        // 2. FALLBACK: Izvuci ime vozača iz napomena
        if (napomene != null && napomene.contains('Naplatio:')) {
          try {
            final startIndex = napomene.indexOf('Naplatio:') + 'Naplatio:'.length;
            // Nova logika - direktno ime vozača bez UUID dela
            final vozacIme = napomene.substring(startIndex).trim();
            if (vozacIme.isNotEmpty) {
              return vozacIme;
            }
          } catch (e) {
            // Ako parsing ne uspe, samo nastavi
          }
        }

        return 'Nepoznat vozač';
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 🔍 Dobija vozača iz poslednjeg plaćanja po imenu putnika (fallback)
  static Future<String?> getVozacPoslednjegPlacanjaPoImenu(
    String putnikIme,
  ) async {
    try {
      final placanja = await Supabase.instance.client
          .from('putovanja_istorija')
          .select('vozac_id, napomene')
          .eq('putnik_ime', putnikIme)
          .eq('tip_putnika', 'mesecni')
          .eq('status', 'placeno')
          .order('created_at', ascending: false)
          .limit(1) as List<dynamic>;

      if (placanja.isNotEmpty) {
        final vozacId = placanja.first['vozac_id'] as String?;
        final napomene = placanja.first['napomene'] as String?;

        // 1. PRIORITET: Pokušaj sa vozac_id preko UUID mapiranja
        if (vozacId != null && vozacId.isNotEmpty) {
          final vozacIme = VozacMappingService.getVozacImeWithFallbackSync(vozacId);
          if (vozacIme != null && vozacIme != 'Nepoznat') {
            return vozacIme;
          }
        }

        // 2. FALLBACK: Izvuci ime vozača iz napomena
        if (napomene != null && napomene.contains('Naplatio:')) {
          try {
            final startIndex = napomene.indexOf('Naplatio:') + 'Naplatio:'.length;
            // Nova logika - direktno ime vozača bez UUID dela
            final vozacIme = napomene.substring(startIndex).trim();
            if (vozacIme.isNotEmpty) {
              return vozacIme;
            }
          } catch (e) {
            // Ako parsing ne uspe, samo nastavi
          }
        }

        return 'Nepoznat vozač';
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
