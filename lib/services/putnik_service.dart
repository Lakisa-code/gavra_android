import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/putnik.dart';
import '../utils/grad_adresa_validator.dart';
import '../utils/vozac_boja.dart'; // DODATO za validaciju vozača
import 'realtime_notification_service.dart';
import 'mesecni_putnik_service.dart'; // DODANO za automatsku sinhronizaciju

// 🔄 UNDO STACK - Stack za čuvanje poslednih akcija
class UndoAction {
  final String
      type; // 'delete', 'pickup', 'payment', 'cancel', 'odsustvo', 'reset'
  final dynamic putnikId; // ✅ dynamic umesto int
  final Map<String, dynamic> oldData;
  final DateTime timestamp;

  UndoAction({
    required this.type,
    required this.putnikId, // ✅ dynamic umesto int
    required this.oldData,
    required this.timestamp,
  });
}

class PutnikService {
  final supabase = Supabase.instance.client;

  // 📚 UNDO STACK - Čuva poslednje akcije (max 10)
  static final List<UndoAction> _undoStack = [];
  static const int maxUndoActions = 10;

  // 🚫 DUPLICATE PREVENTION - Čuva poslednje akcije po putnik ID
  static final Map<String, DateTime> _lastActionTime = {};
  static const Duration _duplicatePreventionDelay = Duration(milliseconds: 500);

  /// 🚫 DUPLICATE PREVENTION HELPER
  static bool _isDuplicateAction(String actionKey) {
    final now = DateTime.now();
    final lastAction = _lastActionTime[actionKey];

    if (lastAction != null) {
      final timeDifference = now.difference(lastAction);
      if (timeDifference < _duplicatePreventionDelay) {
        debugPrint('🚫 [DUPLICATE PREVENTION] Blokiran duplikat: $actionKey');
        return true;
      }
    }

    _lastActionTime[actionKey] = now;
    return false;
  }

  // 📝 DODAJ U UNDO STACK
  void _addToUndoStack(
      String type, dynamic putnikId, Map<String, dynamic> oldData) {
    _undoStack.add(UndoAction(
      type: type,
      putnikId: putnikId,
      oldData: oldData,
      timestamp: DateTime.now(),
    ));

    // Ograniči stack na max broj akcija
    if (_undoStack.length > maxUndoActions) {
      _undoStack.removeAt(0);
    }
  }

  // 🔍 HELPER - Određi tabelu na osnovu putnika
  Future<String> _getTableForPutnik(dynamic id) async {
    debugPrint('🔍 DEBUG _getTableForPutnik - ID=$id (tip: ${id.runtimeType})');

    try {
      // Pokušaj prvo putovanja_istorija (int ili string ID)
      await supabase
          .from('putovanja_istorija')
          .select('id')
          .eq('id', id)
          .single();
      debugPrint('🔍 DEBUG _getTableForPutnik - pronašao u putovanja_istorija');
      return 'putovanja_istorija';
    } catch (e) {
      debugPrint(
          '🔍 DEBUG _getTableForPutnik - nije u putovanja_istorija, vraćam mesecni_putnici');
      return 'mesecni_putnici';
    }
  }

  // 🆕 UČITAJ PUTNIKA IZ BILO KOJE TABELE (po imenu)
  Future<Putnik?> getPutnikByName(String imePutnika) async {
    try {
      // Prvo pokušaj iz mesecni_putnici
      final mesecniResponse = await supabase
          .from('mesecni_putnici')
          .select('*')
          .eq('putnik_ime', imePutnika)
          .maybeSingle();

      if (mesecniResponse != null) {
        return Putnik.fromMesecniPutnici(mesecniResponse);
      }

      // Ako nije u mesecni_putnici, pokušaj iz putovanja_istorija za danas
      final danas = DateTime.now().toIso8601String().split('T')[0];
      final putovanjaResponse = await supabase
          .from('putovanja_istorija')
          .select('*')
          .eq('putnik_ime', imePutnika)
          .eq('datum', danas)
          .maybeSingle();

      if (putovanjaResponse != null) {
        return Putnik.fromPutovanjaIstorija(putovanjaResponse);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // 🆕 UČITAJ PUTNIKA IZ BILO KOJE TABELE (po ID)
  Future<Putnik?> getPutnikFromAnyTable(dynamic id) async {
    debugPrint(
        '🔍 DEBUG getPutnikFromAnyTable - ID=$id (tip: ${id.runtimeType})');

    try {
      // Prvo pokušaj iz putovanja_istorija
      final response = await supabase
          .from('putovanja_istorija')
          .select('*')
          .eq('id', id)
          .limit(1);

      if (response.isNotEmpty) {
        debugPrint(
            '🔍 DEBUG getPutnikFromAnyTable - pronašao u putovanja_istorija');
        return Putnik.fromPutovanjaIstorija(response.first);
      }

      // Ako nije u putovanja_istorija, pokušaj iz mesecni_putnici
      final mesecniResponse = await supabase
          .from('mesecni_putnici')
          .select('*')
          .eq('id', id)
          .limit(1);

      if (mesecniResponse.isNotEmpty) {
        debugPrint(
            '🔍 DEBUG getPutnikFromAnyTable - pronašao u mesecni_putnici');
        return Putnik.fromMesecniPutnici(mesecniResponse.first);
      }

      debugPrint('❌ DEBUG getPutnikFromAnyTable - nije pronašao nigde');
      return null;
    } catch (e) {
      return null;
    }
  }

  // 🆕 NOVI: Učitaj sve putnike iz obe tabele
  Future<List<Putnik>> getAllPutniciFromBothTables() async {
    List<Putnik> allPutnici = [];

    try {
      // Učitaj dnevne putnike iz putovanja_istorija
      final dnevniResponse = await supabase
          .from('putovanja_istorija')
          .select('*')
          .eq('tip_putnika', 'dnevni')
          .order('created_at', ascending: false);

      for (final data in dnevniResponse) {
        allPutnici.add(Putnik.fromPutovanjaIstorija(data));
      }

      // 🔧 ISPRAVKA: Učitaj i mesečne putnike kreirane kao dnevna putovanja
      final mesecniDnevniResponse = await supabase
          .from('putovanja_istorija')
          .select('*')
          .eq('tip_putnika', 'mesecni')
          .order('created_at', ascending: false);

      for (final data in mesecniDnevniResponse) {
        allPutnici.add(Putnik.fromPutovanjaIstorija(data));
      }

      // 🗓️ SAMO DANAŠNJI DAN: Učitaj mesečne putnike iz mesecni_putnici SAMO za današnji dan
      // Ovo sprečava duplikate kada se kreiraju dnevna putovanja za buduće dane
      final danas = DateTime.now();
      final danasKratica = _getDayAbbreviation(danas.weekday);

      final mesecniResponse = await supabase
          .from('mesecni_putnici')
          .select('*')
          // UKLONJEN FILTER za aktivan - sada prikazuje SVE putnike (aktivne i otkazane)
          .like('radni_dani', '%$danasKratica%')
          .order('created_at', ascending: false);

      for (final data in mesecniResponse) {
        // NOVA LOGIKA: Koristi fromMesecniPutniciMultiple da kreira više objekata
        final mesecniPutnici = Putnik.fromMesecniPutniciMultiple(data);
        // Filtriraj samo za današnji dan
        for (final putnik in mesecniPutnici) {
          if (putnik.dan.toLowerCase().contains(danasKratica.toLowerCase())) {
            allPutnici.add(putnik);
          }
        }
      }

      return allPutnici;
    } catch (e) {
      return [];
    }
  }

  // Helper funkcija za konverziju weekday u kraticu
  String _getDayAbbreviation(int weekday) {
    const dani = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
    return dani[weekday - 1];
  }

  // ✅ NOVA FUNKCIJA - vikendom vraća ponedeljak kao home_screen
  String _getFilterDayAbbreviation(int weekday) {
    // Vikend (subota=6, nedelja=7) -> prebaci na ponedeljak (1)
    if (weekday == 6 || weekday == 7) {
      return 'pon'; // ponedeljak
    }
    return _getDayAbbreviation(weekday);
  }

  // 🆕 NOVI: Sačuvaj putnika u odgovarajuću tabelu (workaround - sve u mesecni_putnici)
  Future<bool> savePutnikToCorrectTable(Putnik putnik) async {
    try {
      // SVI PUTNICI - koristi mesecni_putnici tabelu kao workaround za RLS
      final data = putnik.toMesecniPutniciMap();

      if (putnik.id != null) {
        await supabase
            .from('mesecni_putnici')
            .update(data)
            .eq('id', putnik.id!);
      } else {
        await supabase.from('mesecni_putnici').insert(data);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // ↩️ UNDO POSLEDNJU AKCIJU
  Future<String?> undoLastAction() async {
    if (_undoStack.isEmpty) {
      return 'Nema akcija za poništavanje';
    }

    final lastAction = _undoStack.removeLast();

    try {
      // Određi tabelu na osnovu ID-ja
      final tabela = await _getTableForPutnik(lastAction.putnikId);

      switch (lastAction.type) {
        case 'delete':
          if (tabela == 'mesecni_putnici') {
            await supabase.from(tabela).update({
              'status': lastAction.oldData['status'],
              'aktivan': true, // Vraća na aktivan umesto obrisan: false
            }).eq('id', lastAction.putnikId);
          } else {
            // putovanja_istorija - koristi novu 'status' kolonu
            await supabase.from(tabela).update({
              'status': lastAction.oldData['status'] ?? 'nije_se_pojavio',
              'pokupljen': false, // ✅ RESETUJ pokupljen flag
            }).eq('id', lastAction.putnikId);
          }
          return 'Poništeno brisanje putnika';

        case 'pickup':
          if (tabela == 'mesecni_putnici') {
            await supabase.from(tabela).update({
              'broj_putovanja': lastAction.oldData['broj_putovanja'],
              'poslednje_putovanje':
                  lastAction.oldData['poslednje_putovanje'], // ✅ ISPRAVKA
            }).eq('id', lastAction.putnikId);
          } else {
            await supabase.from(tabela).update({
              'status': lastAction.oldData['status'],
              // 'vreme_akcije': null, // UKLONITI - kolona ne postoji
            }).eq('id', lastAction.putnikId);
          }
          return 'Poništeno pokupljanje';

        case 'payment':
          if (tabela == 'mesecni_putnici') {
            await supabase.from(tabela).update({
              // 'iznos': null // lastAction.oldData['iznos'] // UKLONJEN, // UKLONJEN - kolona ne postoji
              // 'datum_placanja': lastAction.oldData['datum_placanja'], // UKLONJEN - kolona ne postoji
            }).eq('id', lastAction.putnikId);
          } else {
            await supabase.from(tabela).update({
              'placeno': false,
              'iznos_placanja': null,
              'vreme_placanja': null,
            }).eq('id', lastAction.putnikId);
          }
          return 'Poništeno plaćanje';

        case 'cancel':
          if (tabela == 'mesecni_putnici') {
            await supabase.from(tabela).update({
              'status': lastAction.oldData['status'],
            }).eq('id', lastAction.putnikId);
          } else {
            await supabase.from(tabela).update({
              'status': lastAction.oldData['status'],
              // 'vreme_akcije': lastAction.oldData['vreme_akcije'], // UKLONITI - kolona ne postoji
              'vozac': lastAction
                  .oldData['vozac'], // ✅ Koristi vozac umesto otkazao_vozac
            }).eq('id', lastAction.putnikId);
          }
          return 'Poništeno otkazivanje';

        default:
          return 'Nepoznata akcija za poništavanje';
      }
    } catch (e) {
      return 'Greška pri poništavanju: $e';
    }
  }

  // 📋 BROJ DOSTUPNIH UNDO AKCIJA
  int get undoActionsCount => _undoStack.length;

  // 🕒 POSLEDNJA AKCIJA INFO
  String? get lastActionInfo {
    if (_undoStack.isEmpty) return null;
    final action = _undoStack.last;
    final timeAgo = DateTime.now().difference(action.timestamp).inMinutes;
    return '${action.type} (pre ${timeAgo}min)';
  }

  /// ✅ DODAJ PUTNIKA (dnevni ili mesečni) - 🏘️ SA VALIDACIJOM GRADOVA
  Future<void> dodajPutnika(Putnik putnik) async {
    try {
      debugPrint('🚀 [DODAJ PUTNIKA] Početak dodavanja putnika: ${putnik.ime}');

      // 🚫 STRIKTNA VALIDACIJA VOZAČA
      if (!VozacBoja.isValidDriver(putnik.dodaoVozac)) {
        debugPrint('❌ [DODAJ PUTNIKA] Nevaljan vozač: ${putnik.dodaoVozac}');
        throw Exception(
            'NEVALJAN VOZAČ: "${putnik.dodaoVozac}". Dozvoljeni su samo: ${VozacBoja.validDrivers.join(", ")}');
      }
      debugPrint('✅ [DODAJ PUTNIKA] Vozač valjan: ${putnik.dodaoVozac}');

      // 🚫 VALIDACIJA GRADA
      if (GradAdresaValidator.isCityBlocked(putnik.grad)) {
        debugPrint('❌ [DODAJ PUTNIKA] Grad blokiran: ${putnik.grad}');
        throw Exception(
            'Grad "${putnik.grad}" nije dozvoljen. Dozvoljeni su samo Bela Crkva i Vršac.');
      }
      debugPrint('✅ [DODAJ PUTNIKA] Grad valjan: ${putnik.grad}');

      // 🏘️ VALIDACIJA ADRESE
      if (putnik.adresa != null && putnik.adresa!.isNotEmpty) {
        if (!GradAdresaValidator.validateAdresaForCity(
            putnik.adresa, putnik.grad)) {
          debugPrint(
              '❌ [DODAJ PUTNIKA] Adresa nije validna: ${putnik.adresa} za grad ${putnik.grad}');
          throw Exception(
              'Adresa "${putnik.adresa}" nije validna za grad "${putnik.grad}". Dozvoljene su samo adrese iz Bele Crkve i Vršca.');
        }
      }
      debugPrint('✅ [DODAJ PUTNIKA] Adresa validna: ${putnik.adresa}');

      if (putnik.mesecnaKarta == true) {
        debugPrint(
            '📊 [DODAJ PUTNIKA] Proveavam da li mesečni putnik već postoji...');

        // 🚫 PROVERAVA DA LI MESEČNI PUTNIK VEĆ POSTOJI - NE MOŽE SE KREIRATI NOVI IZ HOME SCREEN-A
        final existingPutnici = await supabase
            .from('mesecni_putnici')
            .select('id, putnik_ime, aktivan')
            .eq('putnik_ime', putnik.ime)
            .eq('aktivan', true);

        if (existingPutnici.isEmpty) {
          debugPrint('❌ [DODAJ PUTNIKA] Mesečni putnik ne postoji u bazi!');
          throw Exception(
              'NOVI MESEČNI PUTNIK SE NE MOŽE DODATI IZ HOME SCREEN-A!\n\n'
              'Putnik "${putnik.ime}" ne postoji u listi mesečnih putnika.\n'
              'Idite na: Meni → Mesečni putnici da kreirate novog mesečnog putnika.');
        }

        debugPrint(
            '✅ [DODAJ PUTNIKA] Mesečni putnik "${putnik.ime}" već postoji - samo dodajem putovanje...');

        // MESEČNI PUTNIK POSTOJI - DODAJ SAMO PUTOVANJE U putovanja_istorija
        final insertData = putnik.toPutovanjaIstorijaMap();
        // Dodaj mesecni_putnik_id reference
        final mesecniPutnikId = existingPutnici.first['id'];
        insertData['mesecni_putnik_id'] = mesecniPutnikId;

        debugPrint('📊 [DODAJ PUTNIKA] Insert putovanje data: $insertData');
        await supabase.from('putovanja_istorija').insert(insertData);
        debugPrint(
            '✅ [DODAJ PUTNIKA] Putovanje za postojećeg mesečnog putnika uspešno dodato');
      } else {
        debugPrint('📊 [DODAJ PUTNIKA] Dodajem DNEVNOG putnika...');
        // DNEVNI PUTNIK - dodaj u putovanja_istorija tabelu (RLS je sada rešen!)
        final insertData = putnik.toPutovanjaIstorijaMap();
        debugPrint('📊 [DODAJ PUTNIKA] Insert data: $insertData');
        await supabase.from('putovanja_istorija').insert(insertData);
        debugPrint('✅ [DODAJ PUTNIKA] Dnevni putnik uspešno dodat');
      }

      // 🔔 REAL-TIME NOTIFIKACIJA - Novi putnik dodat (samo za današnji dan)
      final now = DateTime.now();
      final dayNames = ['Pon', 'Uto', 'Sre', 'Čet', 'Pet', 'Sub', 'Ned'];
      final todayName = dayNames[now.weekday - 1];

      // Proverava da li je putnik za današnji dan u nedelji
      if (putnik.dan == todayName) {
        debugPrint('📡 [DODAJ PUTNIKA] Šaljem real-time notifikaciju...');
        RealtimeNotificationService.sendRealtimeNotification(
          'Novi putnik',
          'Dodjen je novi putnik ${putnik.ime}',
          {
            'type': 'novi_putnik',
            'putnik': {
              'ime': putnik.ime,
              'grad': putnik.grad,
              'vreme': putnik.polazak,
              'dan': putnik.dan,
            }
          },
        );
        debugPrint('✅ [DODAJ PUTNIKA] Real-time notifikacija poslata');
      } else {
        debugPrint(
            'ℹ️ [DODAJ PUTNIKA] Ne šaljem notifikaciju - putnik nije za danas (${putnik.dan} vs $todayName)');
      }

      debugPrint('🎉 [DODAJ PUTNIKA] SVE ZAVRŠENO USPEŠNO!');
    } catch (e) {
      debugPrint('💥 [DODAJ PUTNIKA] GREŠKA: $e');
      rethrow; // Ponovno baci grešku da je home_screen može uhvatiti
    }
  }

  /// ✅ KOMBINOVANI STREAM - MESEČNI + DNEVNI PUTNICI
  Stream<List<Putnik>> streamKombinovaniPutnici() {
    debugPrint(
        '🔄 [PUTNIK SERVICE] Pokretam KOMBINOVANI stream sa OBE tabele...');

    final danasKratica = _getFilterDayAbbreviation(DateTime.now().weekday);
    final danas = DateTime.now().toIso8601String().split('T')[0];

    debugPrint(
        '🗓️ [STREAM DEBUG] Danas je: ${DateTime.now().weekday} ($danasKratica)');

    return supabase
        .from('mesecni_putnici')
        .stream(primaryKey: ['id']).asyncMap((mesecniData) async {
      List<Putnik> sviPutnici = [];

      debugPrint(
          '📊 [STREAM] Dobio ${mesecniData.length} zapisa iz mesecni_putnici');

      // 1. MESEČNI PUTNICI - UKLJUČI I OTKAZANE
      for (final item in mesecniData) {
        try {
          // ✅ UKLONI FILTER za aktivan - prikaži SVE (aktivne i otkazane)
          final radniDani = item['radni_dani']?.toString() ?? '';
          debugPrint(
              '🔍 [STREAM DEBUG] Putnik ${item['putnik_ime']}: radni_dani="$radniDani", traži se="$danasKratica"');

          if (radniDani.toLowerCase().contains(danasKratica.toLowerCase())) {
            final mesecniPutnici = Putnik.fromMesecniPutniciMultiple(item);
            sviPutnici.addAll(mesecniPutnici);
            final status = item['aktivan'] == true ? 'AKTIVAN' : 'OTKAZAN';
            debugPrint(
                '✅ [STREAM] Dodao mesečnog putnika: ${item['putnik_ime']} ($status) - ${mesecniPutnici.length} polazaka');
          } else {
            debugPrint(
                '❌ [STREAM] Preskočen putnik ${item['putnik_ime']} - ne radi danas');
          }
        } catch (e) {
          debugPrint(
              '❌ [STREAM] Greška za mesečnog putnika ${item['putnik_ime']}: $e');
        }
      }

      // 2. DNEVNI PUTNICI - FETCH DANAS
      try {
        final dnevniResponse = await supabase
            .from('putovanja_istorija')
            .select('*')
            .eq('datum', danas)
            .eq('tip_putnika', 'dnevni');

        debugPrint(
            '📊 [STREAM] Dobio ${dnevniResponse.length} dnevnih putnika za $danas');

        for (final item in dnevniResponse) {
          try {
            final putnik = Putnik.fromPutovanjaIstorija(item);
            sviPutnici.add(putnik);
            debugPrint(
                '✅ [STREAM] Dodao dnevnog putnika: ${item['putnik_ime']}');
          } catch (e) {
            debugPrint(
                '❌ [STREAM] Greška za dnevnog putnika ${item['putnik_ime']}: $e');
          }
        }
      } catch (e) {
        debugPrint('❌ [STREAM] Greška pri učitavanju dnevnih putnika: $e');
      }

      debugPrint(
          '🎯 [STREAM] UKUPNO PUTNIKA: ${sviPutnici.length} (mesečni + dnevni)');

      // ✅ SORTIRANJE: Otkazani na dno liste
      sviPutnici.sort((a, b) {
        // Prvo sortiranje: aktivan vs otkazan
        if (a.jeOtkazan && !b.jeOtkazan) return 1; // a (otkazan) ide na dno
        if (!a.jeOtkazan && b.jeOtkazan) return -1; // b (otkazan) ide na dno

        // Ako su oba ista (oba aktivna ili oba otkazana), sortiraj po vremenu dodavanja
        return (b.vremeDodavanja ?? DateTime.now())
            .compareTo(a.vremeDodavanja ?? DateTime.now());
      });

      // 🔍 DEBUG: Prikaži status svih putnika
      debugPrint('📋 [STREAM] LISTA PUTNIKA:');
      for (int i = 0; i < sviPutnici.length; i++) {
        final p = sviPutnici[i];
        final statusIcon = p.jeOtkazan ? '❌' : '✅';
        debugPrint(
            '  ${i + 1}. $statusIcon ${p.ime} (otkazan: ${p.jeOtkazan})');
      }

      return sviPutnici;
    });
  }

  /// ✅ STREAM SVIH PUTNIKA (iz mesecni_putnici tabele - workaround za RLS)
  Stream<List<Putnik>> streamPutnici() {
    return supabase
        .from('mesecni_putnici')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) {
          final allPutnici = <Putnik>[];
          for (final item in data) {
            // NOVA LOGIKA: Koristi fromMesecniPutniciMultiple
            final mesecniPutnici = Putnik.fromMesecniPutniciMultiple(item);
            allPutnici.addAll(mesecniPutnici);
          }
          return allPutnici;
        });
  }

  /// 📊 NOVA METODA - Stream mesečnih putnika sa filterom po gradu
  Stream<List<Putnik>> streamMesecniPutnici(String grad) {
    return supabase
        .from('mesecni_putnici')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) {
          final Map<String, Putnik> uniquePutnici =
              {}; // Mapa po imenima da izbegnemo duplikate

          for (final item in data) {
            // Preskačemo obrisane putnike
            if (item['aktivan'] != true) continue;

            bool dodaj = false;
            String? adresa;

            // Filter po gradu - proveri odgovarajuće adresno polje
            if (grad == 'Bela Crkva') {
              if (item['adresa_bela_crkva'] != null &&
                  item['adresa_bela_crkva'].toString().trim().isNotEmpty) {
                dodaj = true;
                adresa = item['adresa_bela_crkva'];
              }
            } else if (grad == 'Vršac') {
              if (item['adresa_vrsac'] != null &&
                  item['adresa_vrsac'].toString().trim().isNotEmpty) {
                dodaj = true;
                adresa = item['adresa_vrsac'];
              }
            }

            if (dodaj) {
              final ime = item['ime']?.toString() ?? '';

              // Dodaj ili ažuriraj putnika u mapi (samo jedan po imenu)
              uniquePutnici[ime] = Putnik.fromMap({
                'id': item['id'],
                'ime': ime,
                'mesecna_karta': true,
                'status': item['status'],
                'tip_putnika': item['tip'],
                'aktivan': item['aktivan'],
                'iznos_placanja': null,
                'vreme_placanja': null,

                'adresa': adresa,
                'vreme_dodavanja': item['created_at'],
                'broj_putovanja': item['broj_putovanja'],
                'poslednja_voznja': item['poslednja_voznja'],
                // Meta podaci za mesečne putnike
                'grad': grad, // Eksplicitno postavljamo grad
                'polazak': '', // Prazan jer mesečni nemaju polazak
                'dan': item['dan'] ?? '', // Dan iz baze podataka
              });
            }
          }

          final List<Putnik> mesecniPutnici = uniquePutnici.values.toList();

          return mesecniPutnici;
        });
  }

  /// 📊 NOVA METODA - Stream mesečnih putnika sa filterom po gradu i danu
  Stream<List<Putnik>> streamMesecniPutniciPoGraduDanu(
      String grad, String dan) {
    return supabase
        .from('mesecni_putnici')
        .stream(primaryKey: ['id'])
        .eq('dan', dan) // Filtriranje po danu
        .order('created_at', ascending: false)
        .map((data) {
          final Map<String, Putnik> uniquePutnici =
              {}; // Mapa po imenima da izbegnemo duplikate

          for (final item in data) {
            // Preskačemo obrisane putnike
            if (item['aktivan'] != true) continue;

            bool dodaj = false;
            String? adresa;

            // Filter po gradu - proveri odgovarajuće adresno polje
            if (grad == 'Bela Crkva') {
              if (item['adresa_bela_crkva'] != null &&
                  item['adresa_bela_crkva'].toString().trim().isNotEmpty) {
                dodaj = true;
                adresa = item['adresa_bela_crkva'];
              }
            } else if (grad == 'Vršac') {
              if (item['adresa_vrsac'] != null &&
                  item['adresa_vrsac'].toString().trim().isNotEmpty) {
                dodaj = true;
                adresa = item['adresa_vrsac'];
              }
            }

            if (dodaj) {
              final ime = item['ime']?.toString() ?? '';

              // Dodaj ili ažuriraj putnika u mapi (samo jedan po imenu)
              uniquePutnici[ime] = Putnik.fromMap({
                'id': item['id'],
                'ime': ime,
                'mesecna_karta': true,
                'status': item['status'],
                'tip_putnika': item['tip'],
                'aktivan': item['aktivan'],
                'iznos_placanja': null,
                'vreme_placanja': null,

                'adresa': adresa,
                'vreme_dodavanja': item['created_at'],
                'broj_putovanja': item['broj_putovanja'],
                'poslednja_voznja': item['poslednja_voznja'],
                // Meta podaci za mesečne putnike
                'grad': grad, // Eksplicitno postavljamo grad
                'polazak': '', // Prazan jer mesečni nemaju polazak
                'dan': item['dan'] ?? '', // Dan iz baze podataka
              });
            }
          }

          final List<Putnik> mesecniPutnici = uniquePutnici.values.toList();

          return mesecniPutnici;
        });
  }

  /// ✅ OBRISI PUTNIKA (Soft Delete - čuva statistike)
  Future<void> obrisiPutnika(dynamic id) async {
    debugPrint('🗑️ [BRISANJE] Brišem putnika ID: $id');

    // Određi tabelu na osnovu ID-ja
    final tabela = await _getTableForPutnik(id);
    debugPrint('🗑️ [BRISANJE] Tabela: $tabela');

    // Prvo dohvati podatke putnika za undo stack
    final response = await supabase.from(tabela).select().eq('id', id).single();

    // 📝 DODAJ U UNDO STACK
    _addToUndoStack('delete', id, response);

    // ✅ KONZISTENTNO BRISANJE - obe tabele imaju obrisan kolonu
    await supabase.from(tabela).update({
      'obrisan': true, // ✅ Sada POSTOJI u obe tabele
      'status': 'obrisan', // Dodatno označavanje u status
      // 'vreme_akcije': DateTime.now().toIso8601String(), // UKLONITI - kolona ne postoji
    }).eq('id', id);

    debugPrint('🗑️ [BRISANJE] Putnik označen kao obrisan u tabeli: $tabela');
  }

  /// ✅ OZNAČI KAO POKUPLJEN
  Future<void> oznaciPokupljen(dynamic id, String currentDriver) async {
    debugPrint(
        '🔍 DEBUG oznaciPokupljen - ID=$id (tip: ${id.runtimeType}), vozač=$currentDriver');

    // 🚫 DUPLICATE PREVENTION
    final actionKey = 'pickup_$id';
    if (_isDuplicateAction(actionKey)) {
      debugPrint('🚫 Duplikat pokupljanja blokiran za ID: $id');
      return;
    }

    // STRIKTNA VALIDACIJA VOZAČA
    if (!VozacBoja.isValidDriver(currentDriver)) {
      throw ArgumentError(
          'NEVALJAN VOZAČ: "$currentDriver". Dozvoljeni su samo: ${VozacBoja.validDrivers.join(", ")}');
    }

    // Određi tabelu na osnovu ID-ja
    final tabela = await _getTableForPutnik(id);
    debugPrint('🔍 DEBUG oznaciPokupljen - tabela=$tabela');

    // Prvo dohvati podatke putnika za notifikaciju
    final response = await supabase.from(tabela).select().eq('id', id).single();
    final putnik = Putnik.fromMap(response);
    debugPrint(
        '🔍 DEBUG oznaciPokupljen - putnik.ime=${putnik.ime}, mesecnaKarta=${putnik.mesecnaKarta}');

    // 📝 DODAJ U UNDO STACK
    _addToUndoStack('pickup', id, response);

    if (tabela == 'mesecni_putnici') {
      // Za mesečne putnike ažuriraj SVE potrebne kolone za pokupljanje
      final now = DateTime.now();
      debugPrint(
          '🔍 DEBUG oznaciPokupljen - ažuriram mesečnog putnika sa now=$now (ISO: ${now.toIso8601String()})');

      await supabase.from(tabela).update({
        'poslednje_putovanje': now.toIso8601String(), // ✅ TIMESTAMP pokupljanja
        'vreme_pokupljenja':
            now.toIso8601String(), // ✅ DODATO za konzistentnost
        'pokupljen': true, // ✅ BOOLEAN flag
        'vozac':
            currentDriver, // ✅ VOZAČ koji je pokupil - koristi postojeću kolonu
        'pokupljanje_vozac':
            currentDriver, // ✅ NOVA KOLONA - vozač koji je pokupljanje izvršio
        'updated_at': now.toIso8601String(), // ✅ AŽURIRAJ timestamp
      }).eq('id', id);

      // 🔄 AUTOMATSKA SINHRONIZACIJA - ažuriraj brojPutovanja iz istorije
      try {
        await MesecniPutnikService.sinhronizujBrojPutovanjaSaIstorijom(id);
        debugPrint(
            '✅ AUTOMATSKI SINHRONIZOVAN brojPutovanja za mesečnog putnika: $id');
      } catch (e) {
        debugPrint(
            '⚠️ Greška pri automatskoj sinhronizaciji brojPutovanja: $e');
      }

      debugPrint('🔍 DEBUG oznaciPokupljen - mesečni putnik ažuriran!');
    } else {
      // Za putovanja_istorija koristi novu 'status' kolonu
      debugPrint('🔍 DEBUG oznaciPokupljen - ažuriram dnevnog putnika');

      await supabase.from(tabela).update({
        'status': 'pokupljen',
        'pokupljanje_vozac':
            currentDriver, // ✅ NOVA KOLONA - vozač koji je pokupljanje izvršio
        'vreme_pokupljenja':
            DateTime.now().toIso8601String(), // ✅ DODATO - vreme pokupljanja
      }).eq('id', id);

      debugPrint('🔍 DEBUG oznaciPokupljen - dnevni putnik ažuriran!');
    }

    // 📊 AUTOMATSKA SINHRONIZACIJA BROJA PUTOVANJA (NOVO za putovanja_istorija!)
    if (tabela == 'putovanja_istorija' &&
        response['mesecni_putnik_id'] != null) {
      try {
        debugPrint(
            '📊 [AUTO SYNC PICKUP] Sinhronizujem broj putovanja za mesečnog putnika ID: ${response['mesecni_putnik_id']}');
        await MesecniPutnikService.sinhronizujBrojPutovanjaSaIstorijom(
            response['mesecni_putnik_id']);
        debugPrint('✅ [AUTO SYNC PICKUP] Broj putovanja automatski ažuriran');
      } catch (syncError) {
        debugPrint(
            '❌ [AUTO SYNC PICKUP] Greška pri sinhronizaciji putovanja: $syncError');
        // Nastavi dalje - sinhronizacija nije kritična
      }
    }

    // 📊 AŽURIRAJ STATISTIKE ako je mesečni putnik i pokupljen je
    if (putnik.mesecnaKarta == true) {
      // Statistike se računaju dinamički kroz StatistikaService
      // bez potrebe za dodatnim ažuriranjem
    }

    // (Uklonjeno slanje notifikacije za pokupljenog putnika)
  }

  /// ✅ OZNAČI KAO PLAĆENO
  Future<void> oznaciPlaceno(
      dynamic id, double iznos, String naplatioVozac) async {
    debugPrint(
        '🚀 [OZNACI PLACENO] START - ID: $id, Iznos: $iznos, Vozač: $naplatioVozac');

    // 🚫 DUPLICATE PREVENTION
    final actionKey = 'payment_$id';
    if (_isDuplicateAction(actionKey)) {
      debugPrint('🚫 Duplikat plaćanja blokiran za ID: $id');
      return;
    }

    // ✅ dynamic umesto int
    // STRIKTNA VALIDACIJA VOZAČA
    if (!VozacBoja.isValidDriver(naplatioVozac)) {
      debugPrint('❌ [OZNACI PLACENO] NEVALJAN VOZAČ: $naplatioVozac');
      throw ArgumentError(
          'NEVALJAN VOZAČ: "$naplatioVozac". Dozvoljeni su samo: ${VozacBoja.validDrivers.join(", ")}');
    }

    // Određi tabelu na osnovu ID-ja
    debugPrint('🔍 [OZNACI PLACENO] Određujem tabelu za ID: $id');
    final tabela = await _getTableForPutnik(id);
    debugPrint('✅ [OZNACI PLACENO] Tabela: $tabela');

    // Prvo dohvati podatke putnika za notifikaciju
    debugPrint('📝 [OZNACI PLACENO] Dohvatam podatke putnika...');
    final response = await supabase.from(tabela).select().eq('id', id).single();
    debugPrint(
        '✅ [OZNACI PLACENO] Podaci: ${response['putnik_ime'] ?? response['ime']}');

    // 📝 DODAJ U UNDO STACK
    _addToUndoStack('payment', id, response);

    debugPrint('🔄 [OZNACI PLACENO] Ažuriram plaćanje...');
    if (tabela == 'mesecni_putnici') {
      // Za mesečne putnike ažuriraj SVE potrebne kolone za plaćanje
      final now = DateTime.now();
      debugPrint(
          '🔧 [OZNACI PLACENO] Ažuriram mesečnog putnika sa cena: $iznos');
      await supabase.from(tabela).update({
        'cena': iznos, // ✅ CENA mesečne karte
        'vreme_placanja': now.toIso8601String(), // ✅ TIMESTAMP plaćanja
        'vozac': naplatioVozac, // ✅ VOZAČ koji je naplatio
        'naplata_vozac':
            naplatioVozac, // ✅ NOVA KOLONA - vozač koji je naplatu izvršio
        'updated_at': now.toIso8601String(), // ✅ AŽURIRAJ timestamp
      }).eq('id', id);
      debugPrint('✅ [OZNACI PLACENO] Mesečni putnik uspešno plaćen');
    } else {
      // Za putovanja_istorija koristi cena kolonu
      debugPrint(
          '🔧 [OZNACI PLACENO] Ažuriram dnevnog putnika sa cena: $iznos');
      await supabase.from(tabela).update({
        'cena': iznos,
        'naplata_vozac':
            naplatioVozac, // ✅ NOVA KOLONA - vozač koji je naplatu izvršio
        // 'vreme_akcije': now.toIso8601String(), // UKLONITI - kolona ne postoji
        'status': 'placen', // ✅ DODAJ STATUS plaćanja
      }).eq('id', id);
      debugPrint('✅ [OZNACI PLACENO] Dnevni putnik uspešno plaćen');
    }

    debugPrint('🎉 [OZNACI PLACENO] ZAVRŠENO USPEŠNO');
    // (Uklonjeno slanje notifikacije za plaćanje)
  }

  /// ✅ OTKAZI PUTNIKA
  Future<void> otkaziPutnika(dynamic id, String otkazaoVozac,
      {String? selectedVreme, String? selectedGrad}) async {
    debugPrint('🚀 [OTKAZI PUTNIKA] START - ID: $id, Vozač: $otkazaoVozac');

    try {
      // ✅ dynamic umesto int
      // Određi tabelu na osnovu ID-ja
      debugPrint('🔍 [OTKAZI PUTNIKA] Određujem tabelu za ID: $id');
      final tabela = await _getTableForPutnik(id);
      debugPrint('✅ [OTKAZI PUTNIKA] Tabela: $tabela');

      // Prvo dohvati podatke putnika za notifikaciju
      debugPrint('📝 [OTKAZI PUTNIKA] Dohvatam podatke putnika...');
      final response =
          await supabase.from(tabela).select().eq('id', id).single();
      debugPrint(
          '✅ [OTKAZI PUTNIKA] Podaci: ${response['putnik_ime'] ?? response['ime']}');

      // 📝 DODAJ U UNDO STACK
      _addToUndoStack('cancel', id, response);

      debugPrint('🔄 [OTKAZI PUTNIKA] Ažuriram status na otkazan...');
      if (tabela == 'mesecni_putnici') {
        // 🆕 NOVI PRISTUP: Za mesečne putnike kreiraj zapis u putovanja_istorija za konkretan dan
        debugPrint(
            '🔧 [OTKAZI PUTNIKA] Kreiram otkazivanje u putovanja_istorija za konkretan dan...');

        final danas = DateTime.now().toIso8601String().split('T')[0];
        final polazak =
            selectedVreme ?? '5:00'; // Koristi proslijećeno vreme ili default
        final grad = selectedGrad ??
            'Bela Crkva'; // Koristi proslijećeni grad ili default

        debugPrint(
            '🔧 [OTKAZI PUTNIKA] Parametri: polazak=$polazak, grad=$grad, datum=$danas');

        // Kreiraj zapis otkazivanja za današnji dan
        await supabase.from('putovanja_istorija').upsert({
          'putnik_ime': response['putnik_ime'],
          'datum': danas,
          'vreme_polaska':
              polazak, // ✅ ISPRAVKA: koristi 'vreme_polaska' umesto 'polazak'
          'grad': grad,
          'status': 'otkazan', // Otkazan SAMO za ovaj konkretan dan/vreme
          'cena': 0,
          'vozac': null,
          'otkazao_vozac':
              otkazaoVozac, // ✅ NOVA KOLONA - vozač koji je otkazivanje izvršio
        });
        debugPrint(
            '✅ [OTKAZI PUTNIKA] Mesečni putnik otkazan SAMO za $danas $polazak $grad');
      } else {
        // Za putovanja_istorija koristi 'status' kolonu
        await supabase.from(tabela).update({
          'status': 'otkazan', // ✅ ORIGINALNO: 'otkazan' ne 'otkazano'
          'otkazao_vozac':
              otkazaoVozac, // ✅ NOVA KOLONA - vozač koji je otkazivanje izvršio
          // 'vreme_akcije': DateTime.now().toIso8601String(), // UKLONITI - kolona ne postoji
        }).eq('id', id);
        debugPrint('✅ [OTKAZI PUTNIKA] Dnevni putnik otkazan');
      }

      // 📬 POŠALJI NOTIFIKACIJU ZA OTKAZIVANJE (za tekući dan)
      debugPrint('📬 [OTKAZI PUTNIKA] Šaljem notifikaciju...');
      try {
        final now = DateTime.now();
        final dayNames = ['Pon', 'Uto', 'Sre', 'Čet', 'Pet', 'Sub', 'Ned'];
        final todayName = dayNames[now.weekday - 1];

        // Proverava da li je otkazani putnik za današnji dan u nedelji
        final putnikDan = response['dan'] ?? '';

        // ✅ POBOLJŠANA LOGIKA - proverava da li današnji dan sadrži u listi dana putnika
        // Za mesečne putnike dan može biti "pon,uto,sre,cet,pet", pa treba da proverava sadrži li današnji dan
        final danLowerCase = putnikDan.toLowerCase();
        final todayLowerCase = todayName.toLowerCase();

        if (danLowerCase.contains(todayLowerCase) || putnikDan == todayName) {
          debugPrint(
              '📬 Šaljem notifikaciju za otkazivanje putnika: ${response['putnik_ime']} za dan: $todayName (putnikDan: $putnikDan)');
          RealtimeNotificationService.sendRealtimeNotification(
            'Otkazan putnik',
            'Otkazan je putnik ${response['putnik_ime']}',
            {
              'type': 'otkazan_putnik',
              'putnik': {
                'ime': response['putnik_ime'],
                'grad': response['grad'],
                'vreme': response['vreme_polaska'] ?? response['polazak'],
                'dan': response['dan'],
              }
            },
          );
        } else {
          debugPrint(
              '📬 Ne šaljem notifikaciju - putnik nije za današnji dan. Putnik dan: $putnikDan, Današnji dan: $todayName');
        }
      } catch (notifError) {
        debugPrint('📬 Greška pri slanju notifikacije: $notifError');
        // Nastavi dalje - notifikacija nije kritična
      }

      // 📊 AUTOMATSKA SINHRONIZACIJA BROJA OTKAZIVANJA (NOVO!)
      if (tabela == 'putovanja_istorija' &&
          response['mesecni_putnik_id'] != null) {
        try {
          debugPrint(
              '📊 [AUTO SYNC] Sinhronizujem broj otkazivanja za mesečnog putnika ID: ${response['mesecni_putnik_id']}');
          await MesecniPutnikService.sinhronizujBrojOtkazivanjaSaIstorijom(
              response['mesecni_putnik_id']);
          debugPrint('✅ [AUTO SYNC] Broj otkazivanja automatski ažuriran');
        } catch (syncError) {
          debugPrint(
              '❌ [AUTO SYNC] Greška pri sinhronizaciji otkazivanja: $syncError');
          // Nastavi dalje - sinhronizacija nije kritična
        }
      }

      debugPrint('🎉 [OTKAZI PUTNIKA] ZAVRŠENO USPEŠNO');
    } catch (e) {
      debugPrint('❌ [OTKAZI PUTNIKA] GLAVNA GREŠKA: $e');
      rethrow;
    }
  }

  /// ✅ DOHVATI PO GRADU, DANU, VREMENU (iz putovanja_istorija)
  Future<List<Putnik>> getPutniciZaGradDanVreme(
    String grad,
    String dan,
    String vreme,
  ) async {
    final data = await supabase
        .from('putovanja_istorija')
        .select()
        .eq('tip_putnika', 'dnevni')
        .eq('adresa_polaska', grad) // koristimo adresa_polaska umesto grad
        .eq('vreme_polaska', vreme)
        .neq('status', 'otkazano') as List<dynamic>?;

    if (data == null) return [];
    return data.map((e) => Putnik.fromMap(e)).toList();
  }

  /// 📊 PREDVIĐANJE BROJ PUTNIKA (iz putovanja_istorija)
  Future<Map<String, dynamic>> getPredvidjanje() async {
    try {
      // Dohvati sve putnike iz putovanja_istorija iz poslednja 4 nedelje
      final fourWeeksAgo = DateTime.now().subtract(const Duration(days: 28));

      final data = await supabase
          .from('putovanja_istorija')
          .select()
          .eq('tip_putnika', 'dnevni')
          .gte('created_at', fourWeeksAgo.toIso8601String())
          .neq('status', 'otkazano') as List<dynamic>?;

      if (data == null || data.isEmpty) {
        return {
          'ukupno_prosek': 0.0,
          'po_danima': <String, double>{},
          'po_vremenima': <String, double>{},
          'po_gradovima': <String, double>{},
          'preporuke': <String>[],
        };
      }

      final putnici = data.map((e) => Putnik.fromMap(e)).toList();

      // Grupisanje po danima
      final poDanima = <String, List<Putnik>>{};
      final poVremenima = <String, List<Putnik>>{};
      final poGradovima = <String, List<Putnik>>{};

      for (final putnik in putnici) {
        // Po danima
        poDanima.putIfAbsent(putnik.dan, () => []).add(putnik);

        // Po vremenima
        final vreme = putnik.polazak;
        poVremenima.putIfAbsent(vreme, () => []).add(putnik);

        // Po gradovima
        final grad = putnik.grad;
        poGradovima.putIfAbsent(grad, () => []).add(putnik);
      }

      // Proseci
      final prosekPoDanima = <String, double>{};
      poDanima.forEach((dan, lista) {
        prosekPoDanima[dan] = lista.length / 4.0; // 4 nedelje
      });

      final prosekPoVremenima = <String, double>{};
      poVremenima.forEach((vreme, lista) {
        prosekPoVremenima[vreme] = lista.length / 4.0;
      });

      final prosekPoGradovima = <String, double>{};
      poGradovima.forEach((grad, lista) {
        prosekPoGradovima[grad] = lista.length / 4.0;
      });

      // Preporuke na osnovu podataka
      final preporuke = <String>[];

      // Najpopularniji dan
      if (prosekPoDanima.isNotEmpty) {
        final najpopularnijiDan =
            prosekPoDanima.entries.reduce((a, b) => a.value > b.value ? a : b);
        preporuke.add(
            'Najpopularniji dan: ${najpopularnijiDan.key} (${najpopularnijiDan.value.toStringAsFixed(1)} putnika/dan)');
      }

      // Najpopularnije vreme
      if (prosekPoVremenima.isNotEmpty) {
        final najpopularnijeVreme = prosekPoVremenima.entries
            .reduce((a, b) => a.value > b.value ? a : b);
        preporuke.add(
            'Najpopularnije vreme: ${najpopularnijeVreme.key} (${najpopularnijeVreme.value.toStringAsFixed(1)} putnika/dan)');
      }

      // Najpopularniji grad
      if (prosekPoGradovima.isNotEmpty) {
        final najpopularnijiGrad = prosekPoGradovima.entries
            .reduce((a, b) => a.value > b.value ? a : b);
        preporuke.add(
            'Najpopularniji grad: ${najpopularnijiGrad.key} (${najpopularnijiGrad.value.toStringAsFixed(1)} putnika/dan)');
      }

      // Dodatne preporuke
      if (prosekPoDanima['Pet'] != null && prosekPoDanima['Pet']! > 15) {
        preporuke.add(
            '⚠️ Petak je često preopterećen - razmisliti o dodatnim polascima');
      }

      if (prosekPoVremenima['7:00'] != null &&
          prosekPoVremenima['7:00']! > 12) {
        preporuke.add('🌅 Jutarnji polasci (7:00) su vrlo popularni');
      }

      return {
        'ukupno_prosek': putnici.length / 4.0,
        'po_danima': prosekPoDanima,
        'po_vremenima': prosekPoVremenima,
        'po_gradovima': prosekPoGradovima,
        'preporuke': preporuke,
        'period_analiza':
            '${fourWeeksAgo.day}/${fourWeeksAgo.month} - ${DateTime.now().day}/${DateTime.now().month}',
      };
    } catch (e) {
      return {
        'error': 'Greška pri analizi: $e',
        'ukupno_prosek': 0.0,
        'po_danima': <String, double>{},
        'po_vremenima': <String, double>{},
        'po_gradovima': <String, double>{},
        'preporuke': <String>[],
      };
    }
  }

  // 📊 Statistike po mesecima (kombinovano dnevni i mesečni putnici)
  Future<Map<String, int>> getBrojVoznjiPoMesecima(String imePutnika) async {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);

    // Dohvati iz putovanja_istorija
    final dnevniData = await supabase
        .from('putovanja_istorija')
        .select()
        .eq('putnik_ime', imePutnika)
        .eq('tip_putnika', 'dnevni')
        .gte('created_at', startOfYear.toIso8601String());

    final mesecniData = await supabase
        .from('mesecni_putnici')
        .select()
        .eq('putnik_ime', imePutnika)
        .eq('aktivan', true)
        .gte('created_at', startOfYear.toIso8601String());

    final List<Putnik> voznje = [
      ...(dnevniData as List).map((e) => Putnik.fromMap(e)),
      ...(mesecniData as List).map((e) => Putnik.fromMap({
            ...e,
            'created_at': e['created_at'],
            'status': e['status'] ?? 'radi', // ✅ JEDNOSTAVNO
          })),
    ];

    // Grupisanje po mesecu i danu
    final Map<String, Map<String, List<Putnik>>> poMesecuDanu = {};
    for (var v in voznje) {
      if (v.vremeDodavanja != null) {
        final mesec =
            '${v.vremeDodavanja!.month.toString().padLeft(2, '0')}.${v.vremeDodavanja!.year}';
        final dan =
            v.vremeDodavanja!.toIso8601String().substring(0, 10); // yyyy-MM-dd
        poMesecuDanu.putIfAbsent(mesec, () => {});
        poMesecuDanu[mesec]!.putIfAbsent(dan, () => []);
        poMesecuDanu[mesec]![dan]!.add(v);
      }
    }

    // Za svaki dan proveri: ako postoji bar jedan putnik koji NIJE otkazan, bolovanje ili godišnji, broji se kao vožnja
    final Map<String, int> brojPoMesecima = {};
    poMesecuDanu.forEach((mesec, daniMap) {
      int brojac = 0;
      daniMap.forEach((dan, listaPutnika) {
        final allExcluded = listaPutnika.every((p) => (p.status != null &&
            (p.status!.toLowerCase() == 'otkazano' ||
                p.status!.toLowerCase() == 'otkazan' ||
                p.status!.toLowerCase() == 'bolovanje' ||
                p.status!.toLowerCase() == 'godisnji')));
        if (!allExcluded) {
          brojac++;
        }
      });
      brojPoMesecima[mesec] = brojac;
    });
    return brojPoMesecima;
  }

  /// 🚫 OZNAČI KAO BOLOVANJE/GODIŠNJI (samo za admin)
  Future<void> oznaciBolovanjeGodisnji(
      dynamic id, String tipOdsustva, String currentDriver) async {
    // ✅ dynamic umesto int
    // Određi tabelu na osnovu ID-ja
    final tabela = await _getTableForPutnik(id);

    // Prvo dohvati podatke putnika za undo stack
    final response = await supabase.from(tabela).select().eq('id', id).single();

    // 📝 DODAJ U UNDO STACK
    _addToUndoStack('odsustvo', id, response);

    if (tabela == 'mesecni_putnici') {
      // ✅ JEDNOSTAVNO - samo setuj status na bolovanje/godisnji
      await supabase.from(tabela).update({
        'status': tipOdsustva.toLowerCase(), // 'bolovanje' ili 'godisnji'
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    } else {
      // Za putovanja_istorija koristi 'status' kolonu
      await supabase.from(tabela).update({
        'status': tipOdsustva.toLowerCase(), // 'bolovanje' ili 'godisnji'
        // 'vreme_akcije': DateTime.now().toIso8601String(), // UKLONITI - kolona ne postoji
      }).eq('id', id);
    }
  }

  /// 🔄 RESETUJ KARTICU U POČETNO STANJE (samo za validne vozače)
  Future<void> resetPutnikCard(String imePutnika, String currentDriver) async {
    try {
      debugPrint('🔄 RESET START - $imePutnika: vozač=$currentDriver');

      if (!VozacBoja.isValidDriver(currentDriver)) {
        debugPrint(
            '❌ RESET FAILED - $imePutnika: nevaljan vozač $currentDriver');
        throw Exception('Samo validni vozači mogu da resetuju kartice');
      }

      debugPrint('✅ RESET VOZAČ VALJAN - $imePutnika: nastavljam sa resetom');

      // Pokušaj reset u mesecni_putnici tabeli
      try {
        debugPrint('🔍 RESET - $imePutnika: tražim u mesecni_putnici');
        final mesecniResponse = await supabase
            .from('mesecni_putnici')
            .select()
            .eq('putnik_ime', imePutnika)
            .maybeSingle();

        if (mesecniResponse != null) {
          debugPrint(
              '🔄 RESET MESECNI PUTNIK - $imePutnika: resetujem SVE kolone na početno stanje');
          await supabase.from('mesecni_putnici').update({
            'aktivan': true, // ✅ KRITIČNO: VRATI na aktivan (jeOtkazan = false)
            'status': 'radi', // ✅ VRATI na radi
            'poslednje_putovanje': null, // ✅ UKLONI pokupljanje
            'vreme_pokupljenja': null, // ✅ UKLONI timestamp pokupljanja
            'vreme_placanja': null, // ✅ UKLONI timestamp plaćanja
            'pokupljen': false, // ✅ VRATI na false
            'cena': null, // ✅ UKLONI plaćanje
            'vozac': null, // ✅ UKLONI vozača
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('putnik_ime', imePutnika);

          // 📊 SINHRONIZUJ broj otkazivanja nakon reset-a (VAŽNO!)
          try {
            debugPrint(
                '📊 [RESET SYNC] Sinhronizujem broj otkazivanja za: $imePutnika');
            final putnikId = mesecniResponse['id'] as String;
            await MesecniPutnikService.sinhronizujBrojOtkazivanjaSaIstorijom(
                putnikId);
            debugPrint(
                '✅ [RESET SYNC] Broj otkazivanja sinhronizovan nakon reset-a');

            // 📊 TAKOĐE sinhronizuj broj putovanja (NOVO!)
            debugPrint(
                '📊 [RESET SYNC] Sinhronizujem broj putovanja za: $imePutnika');
            await MesecniPutnikService.sinhronizujBrojPutovanjaSaIstorijom(
                putnikId);
            debugPrint(
                '✅ [RESET SYNC] Broj putovanja sinhronizovan nakon reset-a');
          } catch (syncError) {
            debugPrint('❌ [RESET SYNC] Greška pri sinhronizaciji: $syncError');
          }

          debugPrint('✅ RESET MESECNI PUTNIK ZAVRŠEN - $imePutnika');
          return;
        }

        debugPrint('❌ RESET - $imePutnika: nije pronađen u mesecni_putnici');
      } catch (e) {
        debugPrint('❌ RESET MESECNI ERROR - $imePutnika: $e');
        // Ako nema u mesecni_putnici, nastavi sa putovanja_istorija
      }

      // Pokušaj reset u putovanja_istorija tabeli
      debugPrint('🔍 RESET - $imePutnika: tražim u putovanja_istorija');
      final danas = DateTime.now().toIso8601String().split('T')[0];
      final putovanjaResponse = await supabase
          .from('putovanja_istorija')
          .select()
          .eq('putnik_ime', imePutnika)
          .eq('datum', danas)
          .maybeSingle();

      if (putovanjaResponse != null) {
        debugPrint(
            '🔄 RESET DNEVNI PUTNIK - $imePutnika: resetujem SVE kolone na početno stanje');
        await supabase
            .from('putovanja_istorija')
            .update({
              'status': 'nije_se_pojavio', // ✅ POČETNO STANJE umesto null
              'cena': 0, // ✅ VRATI cenu na 0
              // 'vreme_akcije': DateTime.now().toIso8601String(), // UKLONITI - kolona ne postoji
              'vozac': null, // ✅ UKLONI vozača
            })
            .eq('putnik_ime', imePutnika)
            .eq('datum', danas);

        debugPrint('✅ RESET DNEVNI PUTNIK ZAVRŠEN - $imePutnika');
      } else {
        debugPrint(
            '❌ RESET - $imePutnika: nije pronađen ni u putovanja_istorija za danas');
      }
    } catch (e) {
      debugPrint('❌ RESET CARD ERROR - $imePutnika: $e');
      // Greška pri resetovanju kartice
      rethrow;
    }
  }

  /// 🔄 RESETUJ POKUPLJENE PUTNIKE KADA SE PROMENI VREME POLASKA
  Future<void> resetPokupljenjaNaPolazak(
      String novoVreme, String grad, String currentDriver) async {
    try {
      debugPrint(
          '🔄 RESET POKUPLJENJA - novo vreme: $novoVreme, grad: $grad, vozač: $currentDriver');

      if (!VozacBoja.isValidDriver(currentDriver)) {
        debugPrint(
            '❌ RESET POKUPLJENJA FAILED - nevaljan vozač $currentDriver');
        return;
      }

      // Resetuj mesečne putnike koji su pokupljeni van trenutnog vremena polaska
      try {
        final mesecniPutnici = await supabase
            .from('mesecni_putnici')
            .select(
                'id, putnik_ime, polazak_bela_crkva, polazak_vrsac, poslednje_putovanje')
            .eq('aktivan', true)
            .not('poslednje_putovanje', 'is', null);

        for (final putnik in mesecniPutnici) {
          final ime = putnik['putnik_ime'] as String;
          final vremePokupljenja =
              DateTime.tryParse(putnik['poslednje_putovanje'] as String);

          if (vremePokupljenja == null) continue;

          // Provjeri polazak za odgovarajući grad
          String? polazakVreme;
          if (grad == 'Bela Crkva') {
            polazakVreme = putnik['polazak_bela_crkva'] as String?;
          } else if (grad == 'Vršac') {
            polazakVreme = putnik['polazak_vrsac'] as String?;
          }

          if (polazakVreme == null ||
              polazakVreme.isEmpty ||
              polazakVreme == '00:00:00') {
            continue;
          }

          // Provjeri da li je pokupljen van vremenskog okvira novog polaska
          final novoPolazakSati = int.tryParse(novoVreme.split(':')[0]) ?? 0;
          final pokupljenSati = vremePokupljenja.hour;
          final razlika = (pokupljenSati - novoPolazakSati).abs();

          // Ako je pokupljen van tolerancije (±3 sata) od novog vremena polaska, resetuj ga
          if (razlika > 3) {
            debugPrint(
                '🔄 RESETUJEM $ime - pokupljen u $pokupljenSati:XX, novo vreme polaska $novoVreme (razlika: ${razlika}h)');

            await supabase.from('mesecni_putnici').update({
              'poslednje_putovanje': null,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', putnik['id']);

            debugPrint('✅ RESETOVAN $ime - status pokupljanja očišćen');
          }
        }

        debugPrint('✅ RESET MESEČNIH PUTNIKA ZAVRŠEN');
      } catch (e) {
        debugPrint('❌ RESET MESEČNIH PUTNIKA ERROR: $e');
      }

      // Resetuj dnevne putnike koji su pokupljeni van trenutnog vremena polaska
      try {
        final danas = DateTime.now().toIso8601String().split('T')[0];
        final dnevniPutnici = await supabase
            .from('putovanja_istorija')
            .select(
                'id, putnik_ime, vreme_polaska') // UKLONITI vreme_akcije - kolona ne postoji
            .eq('datum', danas)
            .eq('grad', grad)
            .eq('status', 'pokupljen');

        for (final putnik in dnevniPutnici) {
          final ime = putnik['putnik_ime'] as String;
          // UKLONITI - vreme_akcije kolona ne postoji, koristi created_at ili updated_at
          // final vremeAkcije = DateTime.tryParse(putnik['vreme_akcije'] as String);
          // if (vremeAkcije == null) continue;

          // Jednostavno resetuj sve pokupljene putnike kada se menja vreme
          debugPrint(
              '🔄 RESETUJEM DNEVNI $ime - pokupljen, resetujem zbog promene vremena');

          await supabase.from('putovanja_istorija').update({
            'status': 'nije_se_pojavio',
            'cena': 0,
            // 'vreme_akcije': DateTime.now().toIso8601String(), // UKLONITI - kolona ne postoji
          }).eq('id', putnik['id']);

          debugPrint('✅ RESETOVAN DNEVNI $ime - status pokupljanja očišćen');
        }

        debugPrint('✅ RESET DNEVNIH PUTNIKA ZAVRŠEN');
      } catch (e) {
        debugPrint('❌ RESET DNEVNIH PUTNIKA ERROR: $e');
      }

      debugPrint('✅ RESET POKUPLJENJA KOMPLETIRAN');
    } catch (e) {
      debugPrint('❌ RESET POKUPLJENJA ERROR: $e');
    }
  }

  /// 📊 DOHVATI SVA UKRCAVANJA ZA PUTNIKA
  static Future<List<Map<String, dynamic>>> dohvatiUkrcavanjaZaPutnika(
      String putnikIme) async {
    try {
      final supabase = Supabase.instance.client;

      final ukrcavanja = await supabase
          .from('putovanja_istorija')
          .select('*')
          .eq('putnik_ime', putnikIme)
          .eq('status', 'pokupljen')
          .order('created_at', ascending: false) as List<dynamic>;

      return ukrcavanja.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ Greška pri dohvatanju ukrcavanja: $e');
      return [];
    }
  }

  /// 📊 DOHVATI SVE OTKAZE ZA PUTNIKA
  static Future<List<Map<String, dynamic>>> dohvatiOtkazeZaPutnika(
      String putnikIme) async {
    try {
      final supabase = Supabase.instance.client;

      final otkazi = await supabase
          .from('putovanja_istorija')
          .select('*')
          .eq('putnik_ime', putnikIme)
          .eq('status', 'otkazano')
          .order('created_at', ascending: false) as List<dynamic>;

      return otkazi.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ Greška pri dohvatanju otkaza: $e');
      return [];
    }
  }

  /// 📊 DOHVATI SVA PLAĆANJA ZA PUTNIKA
  static Future<List<Map<String, dynamic>>> dohvatiPlacanjaZaPutnika(
      String putnikIme) async {
    try {
      final supabase = Supabase.instance.client;
      List<Map<String, dynamic>> svaPlacanja = [];

      // 1. REDOVNA PUTOVANJA iz putovanja_istorija
      final redovnaPlacanja = await supabase
          .from('putovanja_istorija')
          .select('*')
          .eq('putnik_ime', putnikIme)
          .gt('cena', 0)
          .order('created_at', ascending: false) as List<dynamic>;

      svaPlacanja.addAll(redovnaPlacanja.cast<Map<String, dynamic>>());

      // 2. MESEČNA PLAĆANJA iz mesecni_putnici
      final mesecnaPlacanja = await supabase
          .from('mesecni_putnici')
          .select(
              'cena, vreme_placanja, naplata_vozac, placeni_mesec, placena_godina')
          .eq('putnik_ime', putnikIme)
          .not('vreme_placanja', 'is', null)
          .order('vreme_placanja', ascending: false) as List<dynamic>;

      // Konvertuj mesečna plaćanja u isti format kao redovna
      for (var mesecno in mesecnaPlacanja) {
        svaPlacanja.add({
          'cena': mesecno['cena'],
          'created_at': mesecno['vreme_placanja'],
          'vozac_ime': mesecno['naplata_vozac'], // Za konsistentnost sa UI
          'putnik_ime': putnikIme,
          'tip': 'mesecna_karta',
          'placeniMesec': mesecno['placeni_mesec'],
          'placenaGodina': mesecno['placena_godina'],
        });
      }

      // Dodaj vozac_ime i za redovna plaćanja (mapiranje naplata_vozac -> vozac_ime)
      for (var redovno
          in svaPlacanja.where((p) => p['tip'] != 'mesecna_karta')) {
        redovno['vozac_ime'] = redovno['naplata_vozac'];
      }

      // Sortiraj sve po datumu, najnovije prvo
      svaPlacanja.sort((a, b) {
        final dateA = DateTime.parse(a['created_at']);
        final dateB = DateTime.parse(b['created_at']);
        return dateB.compareTo(dateA);
      });

      return svaPlacanja;
    } catch (e) {
      debugPrint('❌ Greška pri dohvatanju plaćanja: $e');
      return [];
    }
  }
}
