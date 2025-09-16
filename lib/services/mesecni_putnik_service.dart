import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mesecni_putnik.dart';

class MesecniPutnikService {
  static final _supabase = Supabase.instance.client;

  // 📱 REALTIME STREAM svih mesečnih putnika - OTPORAN NA GREŠKE
  static Stream<List<MesecniPutnik>> streamMesecniPutnici() {
    try {
      return _supabase
          .from('mesecni_putnici')
          .stream(primaryKey: ['id'])
          .order('putnik_ime')
          .map((data) {
            if (kDebugMode) {
              debugPrint(
                  '📊 [MESECNI PUTNIK STREAM] Dobio ${data.length} putnika iz baze');
            }
            final allPutnici =
                data.map((json) => MesecniPutnik.fromMap(json)).toList();
            final filteredPutnici =
                allPutnici.where((putnik) => !putnik.obrisan).toList();

            if (kDebugMode) {
              debugPrint(
                  '🔍 [MESECNI PUTNIK STREAM] Filtriranje: ${allPutnici.length} ukupno → ${filteredPutnici.length} nakon uklanjanja obrisanih');
              for (final putnik in allPutnici) {
                final status = putnik.obrisan
                    ? 'OBRISAN'
                    : (putnik.aktivan ? 'AKTIVAN' : 'NEAKTIVAN');
                final placen = (putnik.cena != null && putnik.cena! > 0)
                    ? 'PLAĆEN(${putnik.cena})'
                    : 'NEPLAĆEN';
                debugPrint('   - ${putnik.putnikIme}: $status, $placen');
              }
            }

            return filteredPutnici;
          })
          .handleError((error) {
            if (kDebugMode) {
              debugPrint('❌ [MESECNI PUTNIK SERVICE] Stream error: $error');
            }
            // Ne prekidaj stream, nastavi sa praznom listom
            return <MesecniPutnik>[];
          });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MESECNI PUTNIK SERVICE] Greška u stream: $e');
      }
      // Fallback na običan fetch ako stream ne radi
      return getAllMesecniPutnici().asStream();
    }
  }

  // 📱 REALTIME STREAM aktivnih mesečnih putnika - OTPORAN NA GREŠKE
  static Stream<List<MesecniPutnik>> streamAktivniMesecniPutnici() {
    try {
      return _supabase
          .from('mesecni_putnici')
          .stream(primaryKey: ['id'])
          .order('putnik_ime')
          .map((data) => data
              .map((json) => MesecniPutnik.fromMap(json))
              .where((putnik) => putnik.aktivan && !putnik.obrisan)
              .toList())
          .handleError((error) {
            if (kDebugMode) {
              debugPrint(
                  '❌ [MESECNI PUTNIK SERVICE] Stream error (aktivni): $error');
            }
            // Ne prekidaj stream, nastavi sa praznom listom
            return <MesecniPutnik>[];
          });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MESECNI PUTNIK SERVICE] Greška u stream aktivnih: $e');
      }
      // Fallback na običan fetch ako stream ne radi
      return getAktivniMesecniPutnici().asStream();
    }
  }

  // 🔍 DOBIJ sve mesečne putnike
  static Future<List<MesecniPutnik>> getAllMesecniPutnici() async {
    try {
      final response =
          await _supabase.from('mesecni_putnici').select().order('putnik_ime');

      return response
          .map<MesecniPutnik>((json) => MesecniPutnik.fromMap(json))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MESECNI PUTNIK SERVICE] Greška pri dohvatanju svih: $e');
      }
      return [];
    }
  }

  // 🔍 DOBIJ aktivne mesečne putnike
  static Future<List<MesecniPutnik>> getAktivniMesecniPutnici() async {
    try {
      final response = await _supabase
          .from('mesecni_putnici')
          .select()
          .eq('aktivan', true)
          .order('putnik_ime');

      return response
          .map<MesecniPutnik>((json) => MesecniPutnik.fromMap(json))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '❌ [MESECNI PUTNIK SERVICE] Greška pri dohvatanju aktivnih: $e');
      }
      return [];
    }
  }

  // 🔍 DOBIJ mesečnog putnika po ID
  static Future<MesecniPutnik?> getMesecniPutnikById(String id) async {
    try {
      final response = await _supabase
          .from('mesecni_putnici')
          .select()
          .eq('id', id)
          .single();

      return MesecniPutnik.fromMap(response);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '❌ [MESECNI PUTNIK SERVICE] Greška pri dohvatanju po ID: $e');
      }
      return null;
    }
  }

  // 🔍 DOBIJ mesečnog putnika po TAČNOM IMENU
  static Future<MesecniPutnik?> getMesecniPutnikByIme(String ime) async {
    try {
      final response = await _supabase
          .from('mesecni_putnici')
          .select()
          .eq('putnik_ime', ime)
          .single();

      return MesecniPutnik.fromMap(response);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '❌ [MESECNI PUTNIK SERVICE] Greška pri dohvatanju po imenu: $e');
      }
      return null;
    }
  }

  // 🔍 PRETRAŽI mesečne putnike po imenu
  static Future<List<MesecniPutnik>> pretraziMesecnePutnike(String ime) async {
    try {
      final response = await _supabase
          .from('mesecni_putnici')
          .select()
          .ilike('putnik_ime', '%$ime%')
          .order('putnik_ime');

      return response
          .map<MesecniPutnik>((json) => MesecniPutnik.fromMap(json))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MESECNI PUTNIK SERVICE] Greška pri pretrazi: $e');
      }
      return [];
    }
  }

  // ➕ DODAJ novog mesečnog putnika
  static Future<MesecniPutnik?> dodajMesecnogPutnika(
      MesecniPutnik putnik) async {
    try {
      if (kDebugMode) {
        debugPrint(
            '🔄 [MESECNI PUTNIK SERVICE] Pokušavam dodavanje: ${putnik.putnikIme}');
        debugPrint('📊 [DEBUG] Podaci: ${putnik.toMap()}');
      }

      final response = await _supabase
          .from('mesecni_putnici')
          .insert(putnik.toMap())
          .select()
          .single();

      if (kDebugMode) {
        debugPrint(
            '✅ [MESECNI PUTNIK SERVICE] Uspešno dodat mesečni putnik: ${putnik.putnikIme}');
        debugPrint('📊 [DEBUG] Response: $response');
      }

      return MesecniPutnik.fromMap(response);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '❌ [MESECNI PUTNIK SERVICE] GREŠKA pri dodavanju putnika: ${putnik.putnikIme}');
        debugPrint('❌ [ERROR DETAILS] $e');
        debugPrint('📊 [DEBUG] Podaci koji su poslani: ${putnik.toMap()}');
      }
      return null;
    }
  }

  // ✏️ AŽURIRAJ mesečnog putnika
  static Future<MesecniPutnik?> azurirajMesecnogPutnika(
      MesecniPutnik putnik) async {
    try {
      final dataToSend = putnik.toMap();
      if (kDebugMode) {
        debugPrint('🔧 [DEBUG] Podaci koji se šalju u bazu:');
        debugPrint(
            '  - polazak_bela_crkva: ${dataToSend['polazak_bela_crkva']}');
        debugPrint('  - polazak_vrsac: ${dataToSend['polazak_vrsac']}');
        debugPrint('  - polazak_bc_pon: ${dataToSend['polazak_bc_pon']}');
        debugPrint('  - polazak_bc_cet: ${dataToSend['polazak_bc_cet']}');
        debugPrint('  - polazak_vs_pon: ${dataToSend['polazak_vs_pon']}');
        debugPrint('  - polazak_vs_cet: ${dataToSend['polazak_vs_cet']}');
        debugPrint('  - svi podaci: $dataToSend');
      }

      final response = await _supabase
          .from('mesecni_putnici')
          .update(dataToSend)
          .eq('id', putnik.id)
          .select()
          .single();

      if (kDebugMode) {
        debugPrint(
            '✅ [MESECNI PUTNIK SERVICE] Ažuriran mesečni putnik: ${putnik.putnikIme}');
      }

      return MesecniPutnik.fromMap(response);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MESECNI PUTNIK SERVICE] Greška pri ažuriranju: $e');
      }
      return null;
    }
  }

  // 🗑️ OBRIŠI mesečnog putnika (SOFT DELETE - čuva istoriju)
  static Future<bool> obrisiMesecnogPutnika(String id) async {
    try {
      // Umesto potpunog brisanja, označava kao obrisan
      await _supabase.from('mesecni_putnici').update({
        'obrisan': true,
        'aktivan': false,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', id);

      if (kDebugMode) {
        debugPrint(
            '✅ [MESECNI PUTNIK SERVICE] Soft delete mesečnog putnika: $id');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MESECNI PUTNIK SERVICE] Greška pri soft delete: $e');
      }
      return false;
    }
  }

  // 🔄 AKTIVIRAJ/DEAKTIVIRAJ mesečnog putnika
  static Future<bool> toggleAktivnost(String id, bool aktivan) async {
    try {
      await _supabase.from('mesecni_putnici').update({
        'aktivan': aktivan,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', id);

      if (kDebugMode) {
        debugPrint(
            '✅ [MESECNI PUTNIK SERVICE] Promenjena aktivnost ($id): $aktivan');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '❌ [MESECNI PUTNIK SERVICE] Greška pri promeni aktivnosti: $e');
      }
      return false;
    }
  }

  // 🚗 OZNAČI MESEČNOG PUTNIKA KAO POKUPLJENOG
  static Future<bool> oznaciPokupljenog(String id, String vozac) async {
    try {
      await _supabase.from('mesecni_putnici').update({
        'pokupljen': true, // ✅ ISPRAVNO - kolona postoji
        'vozac': vozac, // ✅ ISPRAVNO - kolona 'vozac' postoji u tabeli
        'vreme_pokupljenja':
            DateTime.now().toIso8601String(), // ✅ ISPRAVNO - sa malim e!
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', id);

      if (kDebugMode) {
        debugPrint(
            '✅ [MESECNI PUTNIK SERVICE] Označen kao pokupljen: $id od strane $vozac');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '❌ [MESECNI PUTNIK SERVICE] Greška pri označavanju pokupljenog: $e');
      }
      return false;
    }
  }

  // 🚗 OTKAŽI POKUPLJANJE MESEČNOG PUTNIKA
  static Future<bool> otkaziPokupljanje(String id, String vozac) async {
    try {
      await _supabase.from('mesecni_putnici').update({
        'pokupljen': false,
        'vreme_pokupljenja': null, // ✅ ISPRAVNO - sa malim e!
        'vozac': vozac, // ✅ ISPRAVNO - kolona 'vozac' postoji u tabeli
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', id);

      if (kDebugMode) {
        debugPrint(
            '✅ [MESECNI PUTNIK SERVICE] Otkazano pokupljanje: $id od strane $vozac');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '❌ [MESECNI PUTNIK SERVICE] Greška pri otkazivanju pokupljanja: $e');
      }
      return false;
    }
  }

  // 💰 OZNAČI PLAĆANJE MESEČNOG PUTNIKA
  static Future<bool> oznaciPlacanje(
      String id, String vozac, double iznos) async {
    try {
      await _supabase.from('mesecni_putnici').update({
        'cena': iznos, // ✅ NOVA KOLONA - koristi novu cena kolonu
        'vozac': vozac, // ✅ ISPRAVNO - kolona 'vozac' postoji u tabeli
        'vreme_placanja':
            DateTime.now().toIso8601String(), // ✅ NOVO - timestamp plaćanja
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', id);
      if (kDebugMode) {
        debugPrint(
            '✅ [MESECNI PUTNIK SERVICE] Označeno plaćanje: $id - $iznos RSD od strane $vozac u ${DateTime.now()}');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '❌ [MESECNI PUTNIK SERVICE] Greška pri označavanju plaćanja: $e');
      }
      return false;
    }
  }

  // 📊 STATISTIKE - broj putovanja za putnika
  static Future<bool> azurirajBrojPutovanja(String id, int noviBroj) async {
    try {
      await _supabase.from('mesecni_putnici').update({
        'broj_putovanja': noviBroj,
        'poslednje_putovanje': DateTime.now().toIso8601String().split('T')[0],
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', id);

      if (kDebugMode) {
        debugPrint(
            '✅ [MESECNI PUTNIK SERVICE] Ažuriran broj putovanja ($id): $noviBroj');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '❌ [MESECNI PUTNIK SERVICE] Greška pri ažuriranju broja putovanja: $e');
      }
      return false;
    }
  }

  // 📊 IZRAČUNAJ broj putovanja na osnovu istorije (JEDNO PUTOVANJE PO DANU)
  static Future<int> izracunajBrojPutovanjaIzIstorije(
      String mesecniPutnikId) async {
    try {
      // Dobij sve JEDINSTVENE DATUME kada je putnik pokupljen
      final response = await _supabase
          .from('putovanja_istorija')
          .select('datum')
          .eq('mesecni_putnik_id', mesecniPutnikId)
          .or('pokupljen.eq.true,status.eq.pokupljen');

      // Broji JEDINSTVENE datume (jedan dan = jedno putovanje)
      final jedinstveniDatumi = <String>{};
      for (final red in response) {
        if (red['datum'] != null) {
          jedinstveniDatumi.add(red['datum'] as String);
        }
      }

      final brojPutovanja = jedinstveniDatumi.length;

      if (kDebugMode) {
        debugPrint(
            '📊 [MESECNI PUTNIK SERVICE] Broj putovanja iz istorije za $mesecniPutnikId: $brojPutovanja (jedinstveni datumi: ${jedinstveniDatumi.toList()})');
      }

      return brojPutovanja;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '❌ [MESECNI PUTNIK SERVICE] Greška pri računanju putovanja iz istorije: $e');
      }
      return 0;
    }
  }

  // 📊 IZRAČUNAJ broj putovanja za određeni datum (MAX 1 PO DANU)
  static Future<int> izracunajBrojPutovanjaZaDatum(
      String mesecniPutnikId, DateTime datum) async {
    try {
      final datumStr = datum.toIso8601String().split('T')[0];

      final response = await _supabase
          .from('putovanja_istorija')
          .select('id')
          .eq('mesecni_putnik_id', mesecniPutnikId)
          .eq('datum', datumStr)
          .or('pokupljen.eq.true,status.eq.pokupljen');

      // Za određeni datum: ima pokupljanja = 1 putovanje, nema = 0 putovanja
      final brojPutovanja = response.isNotEmpty ? 1 : 0;

      if (kDebugMode) {
        debugPrint(
            '📊 [MESECNI PUTNIK SERVICE] Broj putovanja za datum $datumStr: $brojPutovanja (pokupljanja: ${response.length})');
      }

      return brojPutovanja;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '❌ [MESECNI PUTNIK SERVICE] Greška pri računanju putovanja za datum: $e');
      }
      return 0;
    }
  }

  // 📊 IZRAČUNAJ broj putovanja za DANAS
  static Future<int> izracunajBrojPutovanjaZaDanas(
      String mesecniPutnikId) async {
    return await izracunajBrojPutovanjaZaDatum(mesecniPutnikId, DateTime.now());
  }

  // 📊 DETALJNO računanje putovanja (odvojeno ujutru/popodne)
  static Future<Map<String, int>> izracunajDetaljnaPutovanjaZaDatum(
      String mesecniPutnikId, DateTime datum) async {
    try {
      final datumStr = datum.toIso8601String().split('T')[0];

      final response = await _supabase
          .from('putovanja_istorija')
          .select('status, pokupljen, vreme_polaska, grad')
          .eq('mesecni_putnik_id', mesecniPutnikId)
          .eq('datum', datumStr);

      int ujutru = 0;
      int popodne = 0;
      int ukupno = 0;

      for (final red in response) {
        final status = red['status'] as String?;
        final pokupljen = red['pokupljen'] as bool? ?? false;
        final vremePolaska = red['vreme_polaska'] as String? ?? '';
        final grad = red['grad'] as String? ?? '';

        // Ako je pokupljen
        if (pokupljen || status == 'pokupljen') {
          // Odrediti ujutru ili popodne na osnovu grada i vremena
          if (grad.contains('Bela Crkva') ||
              vremePolaska.startsWith('6') ||
              vremePolaska.startsWith('7')) {
            ujutru++;
          } else if (grad.contains('Vršac') || vremePolaska.startsWith('1')) {
            popodne++;
          } else {
            // Fallback - ako nije jasno, broji kao ujutru
            ujutru++;
          }
          ukupno++;
        }
      }

      if (kDebugMode) {
        debugPrint(
            '📊 [MESECNI PUTNIK SERVICE] Za datum $datumStr: ujutru=$ujutru, popodne=$popodne, ukupno=$ukupno');
      }

      return {
        'ujutru': ujutru,
        'popodne': popodne,
        'ukupno': ukupno,
        'dnevno': ujutru > 0 || popodne > 0
            ? 1
            : 0, // 1 ako je bilo bilo kakve vožnje
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '❌ [MESECNI PUTNIK SERVICE] Greška pri detaljnom računanju: $e');
      }
      return {'ujutru': 0, 'popodne': 0, 'ukupno': 0, 'dnevno': 0};
    }
  }

  static Future<bool> sinhronizujBrojPutovanjaSaIstorijom(String id) async {
    try {
      final brojIzIstorije = await izracunajBrojPutovanjaIzIstorije(id);

      await _supabase.from('mesecni_putnici').update({
        'broj_putovanja': brojIzIstorije,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', id);

      if (kDebugMode) {
        debugPrint(
            '✅ [MESECNI PUTNIK SERVICE] Sinhronizovan broj putovanja ($id): $brojIzIstorije');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '❌ [MESECNI PUTNIK SERVICE] Greška pri sinhronizaciji broja putovanja: $e');
      }
      return false;
    }
  }

  // 📊 IZRAČUNAJ broj otkazivanja na osnovu istorije (STVARNI BROJ)
  static Future<int> izracunajBrojOtkazivanjaIzIstorije(
      String mesecniPutnikId) async {
    try {
      // Dobij sve JEDINSTVENE DATUME kada je putnik otkazan
      final response = await _supabase
          .from('putovanja_istorija')
          .select('datum')
          .eq('mesecni_putnik_id', mesecniPutnikId)
          .or('status.eq.otkazan,status.eq.otkazano,status.eq.nije_se_pojavio');

      // Broji JEDINSTVENE datume (jedan dan = jedno otkazivanje)
      final jedinstveniDatumi = <String>{};
      for (final red in response) {
        if (red['datum'] != null) {
          jedinstveniDatumi.add(red['datum'] as String);
        }
      }

      final brojOtkazivanja = jedinstveniDatumi.length;

      if (kDebugMode) {
        debugPrint(
            '📊 [MESECNI PUTNIK SERVICE] Broj otkazivanja iz istorije za $mesecniPutnikId: $brojOtkazivanja (datumi: ${jedinstveniDatumi.toList()})');
      }

      return brojOtkazivanja;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '❌ [MESECNI PUTNIK SERVICE] Greška pri računanju otkazivanja iz istorije: $e');
      }
      return 0;
    }
  }

  // 📊 SINHRONIZUJ broj otkazivanja sa istorijom (AUTOMATSKA EVIDENCIJA)
  static Future<bool> sinhronizujBrojOtkazivanjaSaIstorijom(String id) async {
    try {
      final brojIzIstorije = await izracunajBrojOtkazivanjaIzIstorije(id);

      await _supabase.from('mesecni_putnici').update({
        'broj_otkazivanja': brojIzIstorije,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', id);

      if (kDebugMode) {
        debugPrint(
            '✅ [MESECNI PUTNIK SERVICE] Sinhronizovan broj otkazivanja ($id): $brojIzIstorije');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '❌ [MESECNI PUTNIK SERVICE] Greška pri sinhronizaciji broja otkazivanja: $e');
      }
      return false;
    }
  }

  // 📊 STATISTIKE - broj otkazivanja za putnika (DEPRECATED - koristi sinhronizujBrojOtkazivanjaSaIstorijom)
  static Future<bool> azurirajBrojOtkazivanja(String id, int noviBroj) async {
    try {
      await _supabase.from('mesecni_putnici').update({
        'broj_otkazivanja': noviBroj,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', id);

      if (kDebugMode) {
        debugPrint(
            '✅ [MESECNI PUTNIK SERVICE] Ažuriran broj otkazivanja ($id): $noviBroj');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '❌ [MESECNI PUTNIK SERVICE] Greška pri ažuriranju broja otkazivanja: $e');
      }
      return false;
    }
  }

  // 🏥 UPRAVLJANJE ODSUTNOSTIMA
  static Future<bool> postaviOdsutnost(String id, String statusOdsutnosti,
      DateTime? datumPocetka, DateTime? datumKraja) async {
    try {
      await _supabase.from('mesecni_putnici').update({
        'status': statusOdsutnosti,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', id);

      if (kDebugMode) {
        debugPrint(
            '✅ [MESECNI PUTNIK SERVICE] Postavljena odsutnost ($id): $statusOdsutnosti');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '❌ [MESECNI PUTNIK SERVICE] Greška pri postavljanju odsutnosti: $e');
      }
      return false;
    }
  }

  // 🗓️ DOBIJ putnike koji rade danas
  static Future<List<MesecniPutnik>> getPutniciZaDanas() async {
    try {
      final danas = DateTime.now();
      final danUNedelji = _getDanUNedelji(danas.weekday);

      final response = await _supabase
          .from('mesecni_putnici')
          .select()
          .eq('aktivan', true)
          .eq('status', 'radi')
          .like('radni_dani', '%$danUNedelji%')
          .order('putnik_ime');

      return response
          .map<MesecniPutnik>((json) => MesecniPutnik.fromMap(json))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '❌ [MESECNI PUTNIK SERVICE] Greška pri dohvatanju za danas: $e');
      }
      return [];
    }
  }

  // 🚀 KREIRAJ DNEVNA PUTOVANJA iz mesečnih putnika za celu nedelju/mesec
  static Future<int> kreirajDnevnaPutovanjaIzMesecnih(
      {DateTime? datum, int danaUnapred = 30}) async {
    try {
      final pocetniDatum = datum ?? DateTime.now();

      if (kDebugMode) {
        debugPrint(
            '🚀 [MESECNI PUTNIK SERVICE] Kreiranje dnevnih putovanja za $danaUnapred dana od ${pocetniDatum.toIso8601String().split('T')[0]}');
      }

      // Dobij sve aktivne mesečne putnike
      final mesecniPutnici = await _supabase
          .from('mesecni_putnici')
          .select()
          .eq('aktivan', true)
          .eq('obrisan', false)
          .eq('status', 'radi');

      if (kDebugMode) {
        debugPrint(
            '🔍 [DEBUG] Pronađeno ${mesecniPutnici.length} aktivnih mesečnih putnika');
        for (final putnik in mesecniPutnici) {
          debugPrint(
              '🔍 [DEBUG] Putnik: ${putnik['putnik_ime']}, BC: ${putnik['polazak_bela_crkva']}, VS: ${putnik['polazak_vrsac']}, radni_dani: ${putnik['radni_dani']}');
        }
      }

      int kreirano = 0;

      // Prolazi kroz svaki dan u periodu
      for (int i = 0; i < danaUnapred; i++) {
        final ciljniDatum = pocetniDatum.add(Duration(days: i));
        final danUNedelji = _getDanUNedelji(ciljniDatum.weekday);
        final datumStr = ciljniDatum.toIso8601String().split('T')[0];

        if (kDebugMode) {
          debugPrint('📅 [DEBUG] Obrađujem datum: $datumStr ($danUNedelji)');
        }

        for (final mesecniData in mesecniPutnici) {
          final mesecniPutnik = MesecniPutnik.fromMap(mesecniData);

          // Proveri da li putnik radi taj dan
          if (!mesecniPutnik.radniDani.contains(danUNedelji)) {
            continue;
          }

          // Kreiraj putovanje za Bela Crkva polazak ako ima vreme
          final vremeBelaCrkva =
              mesecniPutnik.getPolazakBelaCrkvaZaDan(danUNedelji);
          if (vremeBelaCrkva != null && vremeBelaCrkva.isNotEmpty) {
            final postojeciBC = await _supabase
                .from('putovanja_istorija')
                .select('id')
                .eq('putnik_ime', mesecniPutnik.putnikIme)
                .eq('datum', datumStr)
                .eq('vreme_polaska', vremeBelaCrkva)
                .like('adresa_polaska', '%Bela Crkva%');

            if (postojeciBC.isEmpty) {
              await _supabase.from('putovanja_istorija').insert({
                'datum': datumStr,
                'putnik_ime': mesecniPutnik.putnikIme,
                'tip_putnika': 'mesecni',
                'mesecni_putnik_id': mesecniPutnik.id,
                'vreme_polaska': vremeBelaCrkva,
                'adresa_polaska': mesecniPutnik.adresaBelaCrkva ??
                    'Bela Crkva', // Default adresa ako nema
                'status': 'nije_se_pojavio', // ✅ NOVA KOLONA
                'pokupljen': false, // ✅ NOVA KOLONA
                'grad': 'Bela Crkva', // ✅ NOVA KOLONA
                'dan': danUNedelji, // ✅ NOVA KOLONA
                'cena': 0.0,
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(), // ✅ NOVA KOLONA
              });
              kreirano++;

              if (kDebugMode) {
                debugPrint(
                    '✅ Kreiran BC putnik: ${mesecniPutnik.putnikIme} $vremeBelaCrkva na $datumStr');
              }
            }
          }

          // Kreiraj putovanje za Vršac polazak ako ima vreme
          final vremeVrsac = mesecniPutnik.getPolazakVrsacZaDan(danUNedelji);
          if (vremeVrsac != null && vremeVrsac.isNotEmpty) {
            final postojeciVS = await _supabase
                .from('putovanja_istorija')
                .select('id')
                .eq('putnik_ime', mesecniPutnik.putnikIme)
                .eq('datum', datumStr)
                .eq('vreme_polaska', vremeVrsac)
                .like('adresa_polaska', '%Vršac%');

            if (postojeciVS.isEmpty) {
              await _supabase.from('putovanja_istorija').insert({
                'datum': datumStr,
                'putnik_ime': mesecniPutnik.putnikIme,
                'tip_putnika': 'mesecni',
                'mesecni_putnik_id': mesecniPutnik.id,
                'vreme_polaska': vremeVrsac,
                'adresa_polaska': mesecniPutnik.adresaVrsac ??
                    'Vršac', // Default adresa ako nema
                'status': 'nije_se_pojavio', // ✅ NOVA KOLONA
                'pokupljen': false, // ✅ NOVA KOLONA
                'grad': 'Vršac', // ✅ NOVA KOLONA
                'dan': danUNedelji, // ✅ NOVA KOLONA
                'cena': 0.0,
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(), // ✅ NOVA KOLONA
              });
              kreirano++;

              if (kDebugMode) {
                debugPrint(
                    '✅ Kreiran VS putnik: ${mesecniPutnik.putnikIme} $vremeVrsac na $datumStr');
              }
            }
          }
        }
      }

      if (kDebugMode) {
        debugPrint(
            '✅ [MESECNI PUTNIK SERVICE] Kreirano $kreirano novih putovanja za period od $danaUnapred dana');
      }

      // 🔄 SINHRONIZUJ brojPutovanja za sve mesečne putnike koji su imali nova putovanja
      if (kreirano > 0) {
        try {
          final sviMesecniPutnici = await _supabase
              .from('mesecni_putnici')
              .select('id')
              .eq('aktivan', true)
              .eq('obrisan', false);

          for (final putnikData in sviMesecniPutnici) {
            await sinhronizujBrojPutovanjaSaIstorijom(putnikData['id']);
          }

          if (kDebugMode) {
            debugPrint(
                '✅ [MESECNI PUTNIK SERVICE] Sinhronizacija brojPutovanja završena za ${sviMesecniPutnici.length} putnika');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
                '⚠️ [MESECNI PUTNIK SERVICE] Greška pri sinhronizaciji brojPutovanja: $e');
          }
        }
      }

      return kreirano;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '❌ [MESECNI PUTNIK SERVICE] Greška pri kreiranju dnevnih putovanja: $e');
      }
      return 0;
    }
  }

  // Helper metod za dan u nedelji
  static String _getDanUNedelji(int weekday) {
    switch (weekday) {
      case 1:
        return 'pon';
      case 2:
        return 'uto';
      case 3:
        return 'sre';
      case 4:
        return 'cet';
      case 5:
        return 'pet';
      case 6:
        return 'sub';
      case 7:
        return 'ned';
      default:
        return 'pon';
    }
  }

  // 🎓 FUNKCIJA ZA RAČUNANJE MESTA ZA ĐAKE
  static Future<Map<String, int>> izracunajMestaZaDjake(
      {DateTime? datum}) async {
    try {
      final ciljniDatum = datum ?? DateTime.now();
      final datumStr = ciljniDatum.toIso8601String().split('T')[0];
      final danUNedelji = _getDanUNedelji(ciljniDatum.weekday);

      if (kDebugMode) {
        debugPrint(
            '🎓 [DJACI STATISTIKE] Računam mesta za datum: $datumStr ($danUNedelji)');
      }

      // 1. Dobij sve aktivne đake (tip = 'ucenik')
      final sviDjaci = await _supabase
          .from('mesecni_putnici')
          .select()
          .eq('tip', 'ucenik')
          .eq('aktivan', true)
          .eq('obrisan', false);

      if (kDebugMode) {
        debugPrint(
            '🎓 [DJACI STATISTIKE] Ukupno aktivnih đaka: ${sviDjaci.length}');
      }

      // 2. Filtriraj đake koji rade danas
      final djaciDanas = sviDjaci.where((djak) {
        final radniDani = djak['radni_dani'] as String? ?? '';
        return radniDani.toLowerCase().contains(danUNedelji.toLowerCase());
      }).toList();

      if (kDebugMode) {
        debugPrint(
            '🎓 [DJACI STATISTIKE] Đaci koji rade danas ($danUNedelji): ${djaciDanas.length}');
      }

      // 3. Računaj upisane za školu (UJUTRU - bez obzira na pokupljanje)
      int upisanoZaSkolu = 0;
      for (final djak in djaciDanas) {
        // Kreiraj MesecniPutnik objekat da koristimo postojeće metode
        final mesecniPutnik = MesecniPutnik.fromMap(djak);

        // Proveri da li ima jutarnji polazak (BC ili VS) za današnji dan
        final polazakBC = mesecniPutnik.getPolazakBelaCrkvaZaDan(danUNedelji);
        final polazakVS = mesecniPutnik.getPolazakVrsacZaDan(danUNedelji);

        if ((polazakBC != null && polazakBC.isNotEmpty) ||
            (polazakVS != null && polazakVS.isNotEmpty)) {
          upisanoZaSkolu++;
        }
      }

      // 4. Računaj upisane za povratak (POPODNE)
      final upisaniZaPovratak = await _supabase
          .from('putovanja_istorija')
          .select('putnik_ime')
          .eq('datum', datumStr)
          .eq('tip_putnika', 'mesecni')
          .inFilter(
              'putnik_ime', djaciDanas.map((d) => d['putnik_ime']).toList())
          .gte('vreme_polaska', '14:00') // Popodnevni termini
          .neq('status', 'otkazan'); // Nisu otkazali

      final upisanoZaPovratak = upisaniZaPovratak.length;

      // 5. Računaj slobodna mesta
      final slobodnaMesta = upisanoZaSkolu - upisanoZaPovratak;

      final rezultat = {
        'ukupno_djaka': sviDjaci.length,
        'djaci_danas': djaciDanas.length,
        'upisano_za_skolu': upisanoZaSkolu,
        'upisano_za_povratak': upisanoZaPovratak,
        'slobodna_mesta': slobodnaMesta,
      };

      if (kDebugMode) {
        debugPrint('🎓 [DJACI STATISTIKE] Rezultat: $rezultat');
      }

      return rezultat;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [DJACI STATISTIKE] Greška: $e');
      }
      return {
        'ukupno_djaka': 0,
        'djaci_danas': 0,
        'upisano_za_skolu': 0,
        'upisano_za_povratak': 0,
        'slobodna_mesta': 0,
      };
    }
  }

  // 💰 UPRAVLJANJE PLAĆANJEM
  static Future<bool> azurirajPlacanje(
      String id, double iznos, String vozac) async {
    try {
      await _supabase.from('mesecni_putnici').update({
        'cena': iznos,
        'vreme_placanja': DateTime.now().toIso8601String(),
        'naplata_vozac': vozac, // Vozač koji je naplatio
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', id);

      if (kDebugMode) {
        debugPrint(
            '✅ [MESECNI PUTNIK SERVICE] Ažurirano plaćanje ($id): $iznos din');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '❌ [MESECNI PUTNIK SERVICE] Greška pri ažuriranju plaćanja: $e');
      }
      return false;
    }
  }

  // 💰 UPRAVLJANJE PLAĆANJEM ZA SPECIFIČAN MESEC
  static Future<bool> azurirajPlacanjeZaMesec(String id, double iznos,
      String vozac, DateTime pocetakMeseca, DateTime krajMeseca) async {
    try {
      // Postavi vreme plaćanja kao trenutni datum/vreme (kada je stvarno plaćeno)
      String vremePlace = DateTime.now().toIso8601String();

      await _supabase.from('mesecni_putnici').update({
        'cena': iznos,
        'vreme_placanja': vremePlace, // Stvarni datum plaćanja
        'naplata_vozac': vozac, // Vozač koji je naplatio
        'updated_at': DateTime.now().toIso8601String(),
        // Dodaj informacije o tome za koji mesec je plaćeno
        'placeni_mesec': pocetakMeseca.month,
        'placena_godina': pocetakMeseca.year,
      }).eq('id', id);

      if (kDebugMode) {
        String mesecGodina = "${pocetakMeseca.month}/${pocetakMeseca.year}";
        debugPrint(
            '✅ [MESECNI PUTNIK SERVICE] Ažurirano plaćanje za $mesecGodina ($id): $iznos din');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '❌ [MESECNI PUTNIK SERVICE] Greška pri ažuriranju plaćanja za mesec: $e');
      }
      return false;
    }
  }
}
