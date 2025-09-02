import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mesecni_putnik.dart';

class MesecniPutnikService {
  static final _supabase = Supabase.instance.client;

  // 📱 REALTIME STREAM svih mesečnih putnika
  static Stream<List<MesecniPutnik>> streamMesecniPutnici() {
    try {
      return _supabase
          .from('mesecni_putnici')
          .stream(primaryKey: ['id'])
          .order('putnik_ime')
          .map((data) => data
              .map((json) => MesecniPutnik.fromMap(json))
              .where((putnik) => !putnik.obrisan)
              .toList());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MESECNI PUTNIK SERVICE] Greška u stream: $e');
      }
      return Stream.value([]);
    }
  }

  // 📱 REALTIME STREAM aktivnih mesečnih putnika
  static Stream<List<MesecniPutnik>> streamAktivniMesecniPutnici() {
    try {
      return _supabase
          .from('mesecni_putnici')
          .stream(primaryKey: ['id'])
          .order('putnik_ime')
          .map((data) => data
              .map((json) => MesecniPutnik.fromMap(json))
              .where((putnik) => putnik.aktivan && !putnik.obrisan)
              .toList());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MESECNI PUTNIK SERVICE] Greška u stream aktivnih: $e');
      }
      return Stream.value([]);
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
      final response = await _supabase
          .from('mesecni_putnici')
          .insert(putnik.toMap())
          .select()
          .single();

      if (kDebugMode) {
        debugPrint(
            '✅ [MESECNI PUTNIK SERVICE] Dodat mesečni putnik: ${putnik.putnikIme}');
      }

      return MesecniPutnik.fromMap(response);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MESECNI PUTNIK SERVICE] Greška pri dodavanju: $e');
      }
      return null;
    }
  }

  // ✏️ AŽURIRAJ mesečnog putnika
  static Future<MesecniPutnik?> azurirajMesecnogPutnika(
      MesecniPutnik putnik) async {
    try {
      final response = await _supabase
          .from('mesecni_putnici')
          .update(putnik.toMap())
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

  // 📊 IZRAČUNAJ broj putovanja na osnovu istorije
  static Future<int> izracunajBrojPutovanjaIzIstorije(
      String mesecniPutnikId) async {
    try {
      final response = await _supabase
          .from('putovanja_istorija')
          .select('id')
          .eq('mesecni_putnik_id', mesecniPutnikId)
          .or('status_bela_crkva_vrsac.eq.pokupljen,status_vrsac_bela_crkva.eq.pokupljen');

      if (kDebugMode) {
        debugPrint(
            '📊 [MESECNI PUTNIK SERVICE] Broj putovanja iz istorije za $mesecniPutnikId: ${response.length}');
      }

      return response.length;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '❌ [MESECNI PUTNIK SERVICE] Greška pri računanju putovanja iz istorije: $e');
      }
      return 0;
    }
  }

  // � IZRAČUNAJ broj putovanja za određeni datum
  static Future<int> izracunajBrojPutovanjaZaDatum(
      String mesecniPutnikId, DateTime datum) async {
    try {
      final datumStr = datum.toIso8601String().split('T')[0];

      final response = await _supabase
          .from('putovanja_istorija')
          .select('id')
          .eq('mesecni_putnik_id', mesecniPutnikId)
          .eq('datum', datumStr)
          .or('status_bela_crkva_vrsac.eq.pokupljen,status_vrsac_bela_crkva.eq.pokupljen');

      if (kDebugMode) {
        debugPrint(
            '📊 [MESECNI PUTNIK SERVICE] Broj putovanja za datum $datumStr: ${response.length}');
      }

      return response.length;
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
          .select('status_bela_crkva_vrsac, status_vrsac_bela_crkva')
          .eq('mesecni_putnik_id', mesecniPutnikId)
          .eq('datum', datumStr);

      int ujutru = 0;
      int popodne = 0;
      int ukupno = 0;

      for (final red in response) {
        final statusBC = red['status_bela_crkva_vrsac'] as String?;
        final statusVS = red['status_vrsac_bela_crkva'] as String?;

        // Brojanje ujutru (Bela Crkva → Vršac)
        if (statusBC == 'pokupljen') {
          ujutru++;
          ukupno++;
        }

        // Brojanje popodne (Vršac → Bela Crkva)
        if (statusVS == 'pokupljen') {
          popodne++;
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

  // 📊 STATISTIKE - broj otkazivanja za putnika
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
          if (mesecniPutnik.polazakBelaCrkva != null &&
              mesecniPutnik.polazakBelaCrkva!.isNotEmpty) {
            final postojeciBC = await _supabase
                .from('putovanja_istorija')
                .select('id')
                .eq('putnik_ime', mesecniPutnik.putnikIme)
                .eq('datum', datumStr)
                .eq('vreme_polaska', mesecniPutnik.polazakBelaCrkva!)
                .like('adresa_polaska', '%Bela Crkva%');

            if (postojeciBC.isEmpty) {
              await _supabase.from('putovanja_istorija').insert({
                'datum': datumStr,
                'putnik_ime': mesecniPutnik.putnikIme,
                'tip_putnika': 'mesecni',
                'mesecni_putnik_id': mesecniPutnik.id,
                'vreme_polaska': mesecniPutnik.polazakBelaCrkva!,
                'adresa_polaska': mesecniPutnik.adresaBelaCrkva ??
                    'Bela Crkva', // Default adresa ako nema
                'status_bela_crkva_vrsac': 'nije_se_pojavio',
                'status_vrsac_bela_crkva': 'nije_se_pojavio',
                'cena': 0.0,
                // 'vreme_akcije': DateTime.now().toIso8601String(), // UKLONITI - kolona ne postoji
                'created_at': DateTime.now().toIso8601String(),
              });
              kreirano++;

              if (kDebugMode) {
                debugPrint(
                    '✅ Kreiran BC putnik: ${mesecniPutnik.putnikIme} ${mesecniPutnik.polazakBelaCrkva} na $datumStr');
              }
            }
          }

          // Kreiraj putovanje za Vršac polazak ako ima vreme
          if (mesecniPutnik.polazakVrsac != null &&
              mesecniPutnik.polazakVrsac!.isNotEmpty) {
            final postojeciVS = await _supabase
                .from('putovanja_istorija')
                .select('id')
                .eq('putnik_ime', mesecniPutnik.putnikIme)
                .eq('datum', datumStr)
                .eq('vreme_polaska', mesecniPutnik.polazakVrsac!)
                .like('adresa_polaska', '%Vršac%');

            if (postojeciVS.isEmpty) {
              await _supabase.from('putovanja_istorija').insert({
                'datum': datumStr,
                'putnik_ime': mesecniPutnik.putnikIme,
                'tip_putnika': 'mesecni',
                'mesecni_putnik_id': mesecniPutnik.id,
                'vreme_polaska': mesecniPutnik.polazakVrsac!,
                'adresa_polaska': mesecniPutnik.adresaVrsac ??
                    'Vršac', // Default adresa ako nema
                'status_bela_crkva_vrsac': 'nije_se_pojavio',
                'status_vrsac_bela_crkva': 'nije_se_pojavio',
                'cena': 0.0,
                // 'vreme_akcije': DateTime.now().toIso8601String(), // UKLONITI - kolona ne postoji
                'created_at': DateTime.now().toIso8601String(),
              });
              kreirano++;

              if (kDebugMode) {
                debugPrint(
                    '✅ Kreiran VS putnik: ${mesecniPutnik.putnikIme} ${mesecniPutnik.polazakVrsac} na $datumStr');
              }
            }
          }
        }
      }

      if (kDebugMode) {
        debugPrint(
            '✅ [MESECNI PUTNIK SERVICE] Kreirano $kreirano novih putovanja za period od $danaUnapred dana');
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
}
