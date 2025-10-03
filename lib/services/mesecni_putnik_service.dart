import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mesecni_putnik.dart';
import '../supabase_client.dart';
import '../utils/logging.dart';
import 'realtime_service.dart';

class MesecniPutnikService {
  static final _supabase = Supabase.instance.client;

  // Admin client with service role for operations that bypass RLS
  static final _supabaseAdmin = SupabaseClient(
    supabaseUrl,
    supabaseServiceRoleKey,
    headers: {'Authorization': 'Bearer $supabaseServiceRoleKey'},
  );

  // Fields to request from mesecni_putnici when selecting explicitly
  static const String _mesecniFields = '*,'
      'polasci_po_danu';

  // 📱 REALTIME STREAM svih mesečnih putnika - OTPORAN NA GREŠKE
  static Stream<List<MesecniPutnik>> streamMesecniPutnici() {
    try {
      return RealtimeService.instance
          .tableStream('mesecni_putnici')
          .map<List<MesecniPutnik>>((dynamic data) {
        try {
          final listRaw = data as List<dynamic>;
          dlog(
              '📊 [MESECNI PUTNIK STREAM] Dobio ${listRaw.length} putnika iz baze');
          final allPutnici =
              listRaw.map((json) => MesecniPutnik.fromMap(json)).toList();
          // ✅ ISPRAVLJENO: filtriraj i po aktivan statusu, ne samo obrisan
          final filteredPutnici = allPutnici
              .where((putnik) => !putnik.obrisan && putnik.aktivan)
              .toList();

          dlog(
              '🔍 [MESECNI PUTNIK STREAM] Filtriranje: ${allPutnici.length} ukupno → ${filteredPutnici.length} nakon filtriranja (aktivan && !obrisan)');
          for (final putnik in allPutnici) {
            final status = putnik.obrisan
                ? 'OBRISAN'
                : (putnik.aktivan ? 'AKTIVAN' : 'NEAKTIVAN');
            final placen = (putnik.cena != null && putnik.cena! > 0)
                ? 'PLAĆEN(${putnik.cena})'
                : 'NEPLAĆEN';
            dlog('   - ${putnik.putnikIme}: $status, $placen');
          }

          return filteredPutnici;
        } catch (e) {
          dlog('❌ [MESECNI PUTNIK SERVICE] Error mapping realtime data: $e');
          return <MesecniPutnik>[];
        }
      }).handleError((error) {
        dlog('❌ [MESECNI PUTNIK SERVICE] Stream error: $error');
        return <MesecniPutnik>[];
      });
    } catch (e) {
      dlog('❌ [MESECNI PUTNIK SERVICE] Greška u stream: $e');
      // Fallback na običan fetch ako stream ne radi
      return getAllMesecniPutnici().asStream();
    }
  }

  // 📱 REALTIME STREAM aktivnih mesečnih putnika - OTPORAN NA GREŠKE
  static Stream<List<MesecniPutnik>> streamAktivniMesecniPutnici() {
    try {
      return RealtimeService.instance
          .tableStream('mesecni_putnici')
          .map<List<MesecniPutnik>>((dynamic data) {
        try {
          final listRaw = data as List<dynamic>;
          final list = listRaw
              .map((json) => MesecniPutnik.fromMap(json))
              .where((putnik) => putnik.aktivan && !putnik.obrisan)
              .toList();
          list.sort((a, b) => a.putnikIme.compareTo(b.putnikIme));
          return list;
        } catch (e) {
          dlog(
              '❌ [MESECNI PUTNIK SERVICE] Error mapping realtime active data: $e');
          return <MesecniPutnik>[];
        }
      }).handleError((error) {
        dlog('❌ [MESECNI PUTNIK SERVICE] Stream error (aktivni): $error');
        return <MesecniPutnik>[];
      });
    } catch (e) {
      dlog('❌ [MESECNI PUTNIK SERVICE] Greška u stream aktivnih: $e');
      // Fallback na običan fetch ako stream ne radi
      return getAktivniMesecniPutnici().asStream();
    }
  }

  // 🔍 DOBIJ sve mesečne putnike
  static Future<List<MesecniPutnik>> getAllMesecniPutnici() async {
    try {
      final response = await _supabase
          .from('mesecni_putnici')
          .select(_mesecniFields)
          .order('putnik_ime');

      return response
          .map<MesecniPutnik>((json) => MesecniPutnik.fromMap(json))
          .toList();
    } catch (e) {
      dlog('❌ [MESECNI PUTNIK SERVICE] Greška pri dohvatanju svih: $e');
      return [];
    }
  }

  // 🔍 DOBIJ aktivne mesečne putnike
  static Future<List<MesecniPutnik>> getAktivniMesecniPutnici() async {
    try {
      // Umesto direktnog čitanja iz mesecni_putnici, koristimo putovanja_istorija
      // za današnje "zakupljeno" zapise i mapiramo nazad na MesecniPutnik gde je moguće.
      final zakupljeno = await getZakupljenoDanas();

      final List<MesecniPutnik> mapped = [];
      for (final row in zakupljeno) {
        try {
          final map = Map<String, dynamic>.from(row);
          if (map['mesecni_putnik_id'] != null) {
            final mp =
                await getMesecniPutnikById(map['mesecni_putnik_id'].toString());
            if (mp != null) {
              mapped.add(mp);
              continue;
            }
          }

          // Skip invalid records since we removed legacy compatibility
          continue;
        } catch (rowErr) {
          dlog('⚠️ [MESECNI PUTNIK SERVICE] Preskacem red: $rowErr');
        }
      }

      return mapped;
    } catch (e) {
      dlog(
          '❌ [MESECNI PUTNIK SERVICE] Greška pri dohvatanju aktivnih (zakupljeno danas): $e');
      return [];
    }
  }

  // 🔍 NOVO: Jednostavna metoda za dohvatanje svih aktivnih mesečnih putnika direktno iz tabele
  static Future<List<MesecniPutnik>> getAllAktivniMesecniPutnici() async {
    try {
      final response = await _supabase
          .from('mesecni_putnici')
          .select(_mesecniFields)
          .eq('aktivan', true)
          .eq('obrisan', false);

      final putnici = (response as List<dynamic>)
          .map((json) => MesecniPutnik.fromMap(json))
          .toList();

      dlog(
          '✅ [MESECNI PUTNIK SERVICE] Dobijeno ${putnici.length} aktivnih mesečnih putnika');
      return putnici;
    } catch (e) {
      dlog(
          '❌ [MESECNI PUTNIK SERVICE] Greška pri dohvatanju svih aktivnih: $e');
      return [];
    }
  }

  // 🔍 NOVO: Dobij "zakupljeno" putovanja za danas iz putovanja_istorija
  // Vraća listu mapi (raw rows) jer struktura putovanja_istorija se razlikuje
  static Future<List<Map<String, dynamic>>> getZakupljenoDanas() async {
    try {
      final danas = DateTime.now().toIso8601String().split('T')[0];
      final response = await _supabase
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
      dlog(
          '❌ [MESECNI PUTNIK SERVICE] Greška pri dohvatanju zakupljeno danas: $e');
      return [];
    }
  }

  // 🔍 DOBIJ mesečnog putnika po ID
  static Future<MesecniPutnik?> getMesecniPutnikById(String id) async {
    try {
      final response = await _supabase
          .from('mesecni_putnici')
          .select(_mesecniFields)
          .eq('id', id)
          .single();

      return MesecniPutnik.fromMap(response);
    } catch (e) {
      dlog('❌ [MESECNI PUTNIK SERVICE] Greška pri dohvatanju po ID: $e');
      return null;
    }
  }

  // 🔍 DOBIJ mesečnog putnika po TAČNOM IMENU
  static Future<MesecniPutnik?> getMesecniPutnikByIme(String ime) async {
    try {
      final response = await _supabase
          .from('mesecni_putnici')
          .select(_mesecniFields)
          .eq('putnik_ime', ime)
          .single();

      return MesecniPutnik.fromMap(response);
    } catch (e) {
      dlog('❌ [MESECNI PUTNIK SERVICE] Greška pri dohvatanju po imenu: $e');
      return null;
    }
  }

  // 🔍 PRETRAŽI mesečne putnike po imenu
  static Future<List<MesecniPutnik>> pretraziMesecnePutnike(String ime) async {
    try {
      final response = await _supabase
          .from('mesecni_putnici')
          .select(_mesecniFields)
          .ilike('ime', '%$ime%')
          .order('putnik_ime');

      return response
          .map<MesecniPutnik>((json) => MesecniPutnik.fromMap(json))
          .toList();
    } catch (e) {
      dlog('❌ [MESECNI PUTNIK SERVICE] Greška pri pretrazi: $e');
      return [];
    }
  }

  // ➕ DODAJ novog mesečnog putnika
  static Future<MesecniPutnik?> dodajMesecnogPutnika(
      MesecniPutnik putnik) async {
    try {
      dlog(
          '🔄 [MESECNI PUTNIK SERVICE] Pokušavam dodavanje: ${putnik.putnikIme}');
      dlog('📊 [DEBUG] Podaci: ${putnik.toMap()}');

      final response = await _supabaseAdmin
          .from('mesecni_putnici')
          .insert(putnik.toMap())
          .select()
          .single();

      dlog(
          '✅ [MESECNI PUTNIK SERVICE] Uspešno dodat mesečni putnik: ${putnik.putnikIme}');
      dlog('📊 [DEBUG] Response: $response');

      return MesecniPutnik.fromMap(response);
    } catch (e) {
      dlog(
          '❌ [MESECNI PUTNIK SERVICE] GREŠKA pri dodavanju putnika: ${putnik.putnikIme}');
      dlog('❌ [ERROR DETAILS] $e');
      dlog('📊 [DEBUG] Podaci koji su poslani: ${putnik.toMap()}');
      return null;
    }
  }

  // ✏️ AŽURIRAJ mesečnog putnika
  static Future<MesecniPutnik?> azurirajMesecnogPutnika(
      MesecniPutnik putnik) async {
    try {
      final dataToSend = putnik.toMap();
      dlog('🔧 [DEBUG] Ažuriranje putnika sa ID: ${putnik.id}');
      dlog('🔧 [DEBUG] Podaci koji se šalju u bazu:');
      dlog('  - polasci_po_danu: ${dataToSend['polasci_po_danu']}');
      dlog('  - svi podaci: $dataToSend');

      // Prvo proverim da li putnik postoji
      final existingCheck = await _supabase
          .from('mesecni_putnici')
          .select('id')
          .eq('id', putnik.id)
          .maybeSingle();

      if (existingCheck == null) {
        dlog(
            '❌ [MESECNI PUTNIK SERVICE] Putnik sa ID ${putnik.id} ne postoji u bazi');
        return null;
      }

      final response = await _supabase
          .from('mesecni_putnici')
          .update(dataToSend)
          .eq('id', putnik.id)
          .select()
          .single();

      dlog(
          '✅ [MESECNI PUTNIK SERVICE] Ažuriran mesečni putnik: ${putnik.putnikIme}');
      dlog('📤 [MESECNI PUTNIK SERVICE] Response od Supabase: $response');

      try {
        return MesecniPutnik.fromMap(response);
      } catch (parseErr, st) {
        dlog(
            '❌ [MESECNI PUTNIK SERVICE] Greška pri parsiranju response-a: $parseErr');
        dlog('❗ StackTrace: $st');
        return null;
      }
    } catch (e) {
      dlog('❌ [MESECNI PUTNIK SERVICE] Greška pri ažuriranju: $e');
      dlog('❗ StackTrace: ${StackTrace.current}');
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

      dlog('✅ [MESECNI PUTNIK SERVICE] Soft delete mesečnog putnika: $id');

      return true;
    } catch (e) {
      dlog('❌ [MESECNI PUTNIK SERVICE] Greška pri soft delete: $e');
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

      dlog('✅ [MESECNI PUTNIK SERVICE] Promenjena aktivnost ($id): $aktivan');

      return true;
    } catch (e) {
      dlog('❌ [MESECNI PUTNIK SERVICE] Greška pri promeni aktivnosti: $e');
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

      dlog(
          '✅ [MESECNI PUTNIK SERVICE] Označen kao pokupljen: $id od strane $vozac');

      return true;
    } catch (e) {
      dlog('❌ [MESECNI PUTNIK SERVICE] Greška pri označavanju pokupljenog: $e');
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

      dlog(
          '✅ [MESECNI PUTNIK SERVICE] Otkazano pokupljanje: $id od strane $vozac');

      return true;
    } catch (e) {
      dlog('❌ [MESECNI PUTNIK SERVICE] Greška pri otkazivanju pokupljanja: $e');
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
      dlog(
          '✅ [MESECNI PUTNIK SERVICE] Označeno plaćanje: $id - $iznos RSD od strane $vozac u ${DateTime.now()}');

      return true;
    } catch (e) {
      dlog('❌ [MESECNI PUTNIK SERVICE] Greška pri označavanju plaćanja: $e');
      return false;
    }
  }

  // 📊 STATISTIKE - broj putovanja za putnika
  static Future<bool> azurirajBrojPutovanja(String id, int noviBroj) async {
    try {
      await _supabase.from('mesecni_putnici').update({
        'broj_putovanja': noviBroj,
        'poslednji_putovanje': DateTime.now().toIso8601String().split('T')[0],
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', id);

      dlog(
          '✅ [MESECNI PUTNIK SERVICE] Ažuriran broj putovanja ($id): $noviBroj');

      return true;
    } catch (e) {
      dlog(
          '❌ [MESECNI PUTNIK SERVICE] Greška pri ažuriranju broja putovanja: $e');
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
          .or('pokupljen.eq.true,status.eq.pokupljeno');

      // Broji JEDINSTVENE datume (jedan dan = jedno putovanje)
      final jedinstveniDatumi = <String>{};
      for (final red in response) {
        if (red['datum'] != null) {
          jedinstveniDatumi.add(red['datum'] as String);
        }
      }

      final brojPutovanja = jedinstveniDatumi.length;

      dlog(
          '📊 [MESECNI PUTNIK SERVICE] Broj putovanja iz istorije za $mesecniPutnikId: $brojPutovanja (jedinstveni datumi: ${jedinstveniDatumi.toList()})');

      return brojPutovanja;
    } catch (e) {
      dlog(
          '❌ [MESECNI PUTNIK SERVICE] Greška pri računanju putovanja iz istorije: $e');
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
          .or('pokupljen.eq.true,status.eq.pokupljeno');

      // Za određeni datum: ima pokupljanja = 1 putovanje, nema = 0 putovanja
      final brojPutovanja = response.isNotEmpty ? 1 : 0;

      dlog(
          '📊 [MESECNI PUTNIK SERVICE] Broj putovanja za datum $datumStr: $brojPutovanja (pokupljanja: ${response.length})');

      return brojPutovanja;
    } catch (e) {
      dlog(
          '❌ [MESECNI PUTNIK SERVICE] Greška pri računanju putovanja za datum: $e');
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
        if (pokupljen || status == 'pokupljeno') {
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

      dlog(
          '📊 [MESECNI PUTNIK SERVICE] Za datum $datumStr: ujutru=$ujutru, popodne=$popodne, ukupno=$ukupno');

      return {
        'ujutru': ujutru,
        'popodne': popodne,
        'ukupno': ukupno,
        'dnevno': ujutru > 0 || popodne > 0
            ? 1
            : 0, // 1 ako je bilo bilo kakve vožnje
      };
    } catch (e) {
      dlog('❌ [MESECNI PUTNIK SERVICE] Greška pri detaljnom računanju: $e');
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

      dlog(
          '✅ [MESECNI PUTNIK SERVICE] Sinhronizovan broj putovanja ($id): $brojIzIstorije');

      return true;
    } catch (e) {
      dlog(
          '❌ [MESECNI PUTNIK SERVICE] Greška pri sinhronizaciji broja putovanja: $e');
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
          .or('status.eq.otkazano,status.eq.nije_se_pojavio');

      // Broji JEDINSTVENE datume (jedan dan = jedno otkazivanje)
      final jedinstveniDatumi = <String>{};
      for (final red in response) {
        if (red['datum'] != null) {
          jedinstveniDatumi.add(red['datum'] as String);
        }
      }

      final brojOtkazivanja = jedinstveniDatumi.length;

      dlog(
          '📊 [MESECNI PUTNIK SERVICE] Broj otkazivanja iz istorije za $mesecniPutnikId: $brojOtkazivanja (datumi: ${jedinstveniDatumi.toList()})');

      return brojOtkazivanja;
    } catch (e) {
      dlog(
          '❌ [MESECNI PUTNIK SERVICE] Greška pri računanju otkazivanja iz istorije: $e');
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

      dlog(
          '✅ [MESECNI PUTNIK SERVICE] Sinhronizovan broj otkazivanja ($id): $brojIzIstorije');

      return true;
    } catch (e) {
      dlog(
          '❌ [MESECNI PUTNIK SERVICE] Greška pri sinhronizaciji broja otkazivanja: $e');
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

      dlog(
          '✅ [MESECNI PUTNIK SERVICE] Ažuriran broj otkazivanja ($id): $noviBroj');

      return true;
    } catch (e) {
      dlog(
          '❌ [MESECNI PUTNIK SERVICE] Greška pri ažuriranju broja otkazivanja: $e');
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

      dlog(
          '✅ [MESECNI PUTNIK SERVICE] Postavljena odsutnost ($id): $statusOdsutnosti');

      return true;
    } catch (e) {
      dlog('❌ [MESECNI PUTNIK SERVICE] Greška pri postavljanju odsutnosti: $e');
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
      dlog('❌ [MESECNI PUTNIK SERVICE] Greška pri dohvatanju za danas: $e');
      return [];
    }
  }

  // 🚀 KREIRAJ DNEVNA PUTOVANJA iz mesečnih putnika za celu nedelju/mesec
  static Future<int> kreirajDnevnaPutovanjaIzMesecnih(
      {DateTime? datum, int danaUnapred = 30}) async {
    try {
      final pocetniDatum = datum ?? DateTime.now();

      dlog(
          '🚀 [MESECNI PUTNIK SERVICE] Kreiranje dnevnih putovanja za $danaUnapred dana od ${pocetniDatum.toIso8601String().split('T')[0]}');

      // Dobij sve aktivne mesečne putnike
      final mesecniPutnici = await _supabase
          .from('mesecni_putnici')
          .select()
          .eq('aktivan', true)
          .eq('obrisan', false)
          .eq('status', 'radi');

      dlog(
          '🔍 [DEBUG] Pronađeno ${mesecniPutnici.length} aktivnih mesečnih putnika');
      for (final putnik in mesecniPutnici) {
        dlog(
            '🔍 [DEBUG] Putnik: ${putnik['ime']}, polasci_po_danu: ${putnik['polasci_po_danu']}, radni_dani: ${putnik['radni_dani']}');
      }

      int kreirano = 0;

      // Prolazi kroz svaki dan u periodu
      for (int i = 0; i < danaUnapred; i++) {
        final ciljniDatum = pocetniDatum.add(Duration(days: i));
        final danUNedelji = _getDanUNedelji(ciljniDatum.weekday);
        final datumStr = ciljniDatum.toIso8601String().split('T')[0];

        dlog('📅 [DEBUG] Obrađujem datum: $datumStr ($danUNedelji)');

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
                'ime': mesecniPutnik.putnikIme,
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

              dlog(
                  '✅ Kreiran BC putnik: ${mesecniPutnik.putnikIme} $vremeBelaCrkva na $datumStr');
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
                'ime': mesecniPutnik.putnikIme,
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

              dlog(
                  '✅ Kreiran VS putnik: ${mesecniPutnik.putnikIme} $vremeVrsac na $datumStr');
            }
          }
        }
      }

      dlog(
          '✅ [MESECNI PUTNIK SERVICE] Kreirano $kreirano novih putovanja za period od $danaUnapred dana');

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

          dlog(
              '✅ [MESECNI PUTNIK SERVICE] Sinhronizacija brojPutovanja završena za ${sviMesecniPutnici.length} putnika');
        } catch (e) {
          dlog(
              '⚠️ [MESECNI PUTNIK SERVICE] Greška pri sinhronizaciji brojPutovanja: $e');
        }
      }

      return kreirano;
    } catch (e) {
      dlog(
          '❌ [MESECNI PUTNIK SERVICE] Greška pri kreiranju dnevnih putovanja: $e');
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

      dlog(
          '🎓 [DJACI STATISTIKE] Računam mesta za datum: $datumStr ($danUNedelji)');

      // 1. Dobij sve aktivne đake (tip = 'ucenik')
      final sviDjaci = await _supabase
          .from('mesecni_putnici')
          .select()
          .eq('tip', 'ucenik')
          .eq('aktivan', true)
          .eq('obrisan', false);

      dlog('🎓 [DJACI STATISTIKE] Ukupno aktivnih đaka: ${sviDjaci.length}');

      // 2. Filtriraj đake koji rade danas
      final djaciDanas = sviDjaci.where((djak) {
        final radniDani = djak['radni_dani'] as String? ?? '';
        return radniDani.toLowerCase().contains(danUNedelji.toLowerCase());
      }).toList();

      dlog(
          '🎓 [DJACI STATISTIKE] Đaci koji rade danas ($danUNedelji): ${djaciDanas.length}');

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
          .select('ime')
          .eq('datum', datumStr)
          .eq('tip_putnika', 'mesecni')
          .inFilter('ime', djaciDanas.map((d) => d['ime']).toList())
          .gte('vreme_polaska', '14:00') // Popodnevni termini
          .neq('status', 'otkazano'); // Nisu otkazali

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

      dlog('🎓 [DJACI STATISTIKE] Rezultat: $rezultat');

      return rezultat;
    } catch (e) {
      dlog('❌ [DJACI STATISTIKE] Greška: $e');
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

      dlog('✅ [MESECNI PUTNIK SERVICE] Ažurirano plaćanje ($id): $iznos din');

      return true;
    } catch (e) {
      dlog('❌ [MESECNI PUTNIK SERVICE] Greška pri ažuriranju plaćanja: $e');
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

      String mesecGodina = "${pocetakMeseca.month}/${pocetakMeseca.year}";
      dlog(
          '✅ [MESECNI PUTNIK SERVICE] Ažurirano plaćanje za $mesecGodina ($id): $iznos din');

      return true;
    } catch (e) {
      dlog(
          '❌ [MESECNI PUTNIK SERVICE] Greška pri ažuriranju plaćanja za mesec: $e');
      return false;
    }
  }

  /// Filtrira mesečne putnike po više različitih polazaka (mesta ili vremena).
  /// [polasci] je lista stringova (npr. vremena ili mesta polaska) po kojoj se filtrira.
  /// [tipPolaska] može biti 'bc' (Bela Crkva) ili 'vs' (Vršac) ili oba.
  /// Novi filter: filtrira po polasciPoDanu (JSON map)
  /// [dan] je npr. 'pon', 'uto', ...
  /// [polasci] je lista stringova ("6 VS", "13 BC"...)
  static List<MesecniPutnik> filterByPolasci(
    List<MesecniPutnik> putnici, {
    required String dan,
    required List<String> polasci,
  }) {
    return putnici.where((putnik) {
      final polasciZaDan = putnik.polasciPoDanu[dan] ?? [];
      // Ako bar jedan polazak iz liste postoji kod putnika za taj dan
      return polasci.any((p) => polasciZaDan.contains(p));
    }).toList();
  }
}
