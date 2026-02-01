import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import '../models/putnik.dart';
import '../utils/grad_adresa_validator.dart';
import '../utils/putnik_helpers.dart';
import 'kapacitet_service.dart';
import 'putnik_service.dart';
import 'realtime/realtime_manager.dart';
import 'voznje_log_service.dart';

/// 🎫 Model za slobodna mesta po polasku
class SlobodnaMesta {
  final String grad;
  final String vreme;
  final int maxMesta;
  final int zauzetaMesta;
  final int waitingCount;
  final int uceniciCount;
  final bool aktivan;

  SlobodnaMesta({
    required this.grad,
    required this.vreme,
    required this.maxMesta,
    required this.zauzetaMesta,
    this.waitingCount = 0,
    this.uceniciCount = 0,
    this.aktivan = true,
  });

  int get slobodna => maxMesta - zauzetaMesta;
  bool get imaMesta => slobodna > 0;
  bool get jePuno => slobodna <= 0;
}

class SlobodnaMestaService {
  static SupabaseClient get _supabase => supabase;
  static final _putnikService = PutnikService();

  static StreamSubscription? _missingTransitSubscription;
  static final StreamController<List<Map<String, dynamic>>> _missingTransitController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  static StreamSubscription? _projectedStatsSubscription;
  static final StreamController<Map<String, dynamic>> _projectedStatsController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Izračunaj broj zauzetih mesta za određeni grad/vreme/datum
  static int _countPutniciZaPolazak(List<Putnik> putnici, String grad, String vreme, String isoDate,
      {String? excludePutnikId}) {
    final normalizedGrad = grad.toLowerCase();
    final targetDayAbbr = _isoDateToDayAbbr(isoDate);

    // 🛡️ NORMALIZUJ TARGET VREME (iz baze kapaciteta može biti npr. "6:00")
    final targetVreme = GradAdresaValidator.normalizeTime(vreme);

    int count = 0;
    for (final p in putnici) {
      // 🛡️ AKO RADIMO UPDATE: Isključi putnika koga menjamo da ne bi sam sebi zauzimao mesto
      if (excludePutnikId != null && p.id?.toString() == excludePutnikId.toString()) {
        continue;
      }

      // 🔧 REFAKTORISANO: Koristi PutnikHelpers za konzistentnu logiku
      // Ne računa: otkazane (jeOtkazan), odsustvo (jeOdsustvo)
      if (!PutnikHelpers.shouldCountInSeats(p)) continue;

      // Proveri datum/dan
      final dayMatch = p.datum != null ? p.datum == isoDate : p.dan.toLowerCase().contains(targetDayAbbr.toLowerCase());
      if (!dayMatch) continue;

      // Proveri vreme - OBA MORAJU BITI NORMALIZOVANA
      final normVreme = GradAdresaValidator.normalizeTime(p.polazak);
      if (normVreme != targetVreme) continue;

      // Proveri grad
      final jeBC = GradAdresaValidator.isBelaCrkva(p.grad);
      final jeVS = GradAdresaValidator.isVrsac(p.grad);

      if ((normalizedGrad == 'bc' && jeBC) || (normalizedGrad == 'vs' && jeVS)) {
        // ✅ NOVO: Brojimo sve putnike bez obzira na grad (BC i VS sada rade isto)
        count += p.brojMesta;
      }
    }

    return count;
  }

  /// 🆕 Izračunaj broj putnika na CEKANJU za određeni grad/vreme
  static int _countWaitingZaPolazak(List<Putnik> putnici, String grad, String vreme, String isoDate,
      {String? excludePutnikId}) {
    final normalizedGrad = grad.toLowerCase();
    final targetDayAbbr = _isoDateToDayAbbr(isoDate);

    int count = 0;
    for (final p in putnici) {
      if (excludePutnikId != null && p.id?.toString() == excludePutnikId.toString()) {
        continue;
      }

      // 🆕 Brojimo SAMO one koji su na čekanju
      if (p.status != 'ceka_mesto') continue;

      // Proveri datum/dan
      final dayMatch = p.datum != null ? p.datum == isoDate : p.dan.toLowerCase().contains(targetDayAbbr.toLowerCase());
      if (!dayMatch) continue;

      // Proveri vreme
      final normVreme = GradAdresaValidator.normalizeTime(p.polazak);
      if (normVreme != vreme) continue;

      // Proveri grad
      final jeBC = GradAdresaValidator.isBelaCrkva(p.grad);
      final jeVS = GradAdresaValidator.isVrsac(p.grad);

      if ((normalizedGrad == 'bc' && jeBC) || (normalizedGrad == 'vs' && jeVS)) {
        count += p.brojMesta;
      }
    }

    return count;
  }

  /// 🆕 Izračunaj broj UČENIKA za određeni grad/vreme
  static int _countUceniciZaPolazak(List<Putnik> putnici, String grad, String vreme, String isoDate,
      {String? excludePutnikId}) {
    final normalizedGrad = grad.toLowerCase();
    final targetDayAbbr = _isoDateToDayAbbr(isoDate);

    int count = 0;
    for (final p in putnici) {
      if (excludePutnikId != null && p.id?.toString() == excludePutnikId.toString()) {
        continue;
      }

      // 🔧 Isti filteri kao za putnike (bez otkazanih, itd)
      if (!PutnikHelpers.shouldCountInSeats(p)) continue;

      // Filter: SAMO UČENICI
      if (p.tipPutnika != 'ucenik') continue;

      // Proveri datum/dan
      final dayMatch = p.datum != null ? p.datum == isoDate : p.dan.toLowerCase().contains(targetDayAbbr.toLowerCase());
      if (!dayMatch) continue;

      // Proveri vreme
      final normVreme = GradAdresaValidator.normalizeTime(p.polazak);
      if (normVreme != vreme) continue;

      // Proveri grad
      final jeBC = GradAdresaValidator.isBelaCrkva(p.grad);
      final jeVS = GradAdresaValidator.isVrsac(p.grad);

      if ((normalizedGrad == 'bc' && jeBC) || (normalizedGrad == 'vs' && jeVS)) {
        count += p.brojMesta;
      }
    }

    return count;
  }

  /// Konvertuj ISO datum u skraćenicu dana
  static String _isoDateToDayAbbr(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      const dani = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
      return dani[date.weekday - 1];
    } catch (e) {
      return 'pon';
    }
  }

  /// Jednokratno dohvatanje slobodnih mesta
  static Future<Map<String, List<SlobodnaMesta>>> getSlobodnaMesta({String? datum, String? excludeId}) async {
    final isoDate = datum ?? DateTime.now().toIso8601String().split('T')[0];

    // Dohvati kapacitet
    final kapacitet = await KapacitetService.getKapacitet();

    // Dohvati putnike - KORISTI getPutniciByDayIso koji proverava uklonjeni_termini i otkazivanja
    final putnici = await _putnikService.getPutniciByDayIso(isoDate);

    final result = <String, List<SlobodnaMesta>>{'BC': [], 'VS': []};

    // Bela Crkva - Koristi SVA vremena iz kapaciteta (ne samo sezonska) za validaciju
    final bcKapaciteti = kapacitet['BC'] ?? {};
    final bcVremenaSorted = bcKapaciteti.keys.toList()..sort();

    for (final vreme in bcVremenaSorted) {
      final maxMesta = bcKapaciteti[vreme] ?? 8;
      final zauzeto = _countPutniciZaPolazak(putnici, 'BC', vreme, isoDate, excludePutnikId: excludeId);
      final waiting = _countWaitingZaPolazak(putnici, 'BC', vreme, isoDate, excludePutnikId: excludeId);
      final ucenici = _countUceniciZaPolazak(putnici, 'BC', vreme, isoDate, excludePutnikId: excludeId);

      result['BC']!.add(
        SlobodnaMesta(
          grad: 'BC',
          vreme: vreme,
          maxMesta: maxMesta,
          zauzetaMesta: zauzeto,
          aktivan: true,
          waitingCount: waiting,
          uceniciCount: ucenici,
        ),
      );
    }

    // Vršac - Koristi SVA vremena iz kapaciteta
    final vsKapaciteti = kapacitet['VS'] ?? {};
    final vsVremenaSorted = vsKapaciteti.keys.toList()..sort();

    for (final vreme in vsVremenaSorted) {
      final maxMesta = vsKapaciteti[vreme] ?? 8;
      final zauzeto = _countPutniciZaPolazak(putnici, 'VS', vreme, isoDate, excludePutnikId: excludeId);
      final waiting = _countWaitingZaPolazak(putnici, 'VS', vreme, isoDate, excludePutnikId: excludeId);
      final ucenici = _countUceniciZaPolazak(putnici, 'VS', vreme, isoDate, excludePutnikId: excludeId);

      result['VS']!.add(
        SlobodnaMesta(
          grad: 'VS',
          vreme: vreme,
          maxMesta: maxMesta,
          zauzetaMesta: zauzeto,
          aktivan: true,
          waitingCount: waiting,
          uceniciCount: ucenici,
        ),
      );
    }

    return result;
  }

  /// Proveri da li ima slobodnih mesta za određeni polazak
  static Future<bool> imaSlobodnihMesta(String grad, String vreme,
      {String? datum, String? tipPutnika, int brojMesta = 1, String? excludeId}) async {
    // 📦 POŠILJKE: Ne zauzimaju mesto, pa uvek ima "mesta" za njih
    if (tipPutnika == 'posiljka') {
      return true;
    }

    // 🎓 BC LOGIKA: Učenici u Beloj Crkvi se auto-prihvataju (bez provere kapaceta)
    if (grad.toUpperCase() == 'BC' && tipPutnika == 'ucenik') {
      return true;
    }

    // 🛡️ NORMALIZACIJA ULAZNOG VREMENA
    final targetVreme = GradAdresaValidator.normalizeTime(vreme);

    final slobodna = await getSlobodnaMesta(datum: datum, excludeId: excludeId);
    final lista = slobodna[grad.toUpperCase()];
    if (lista == null) return false;

    for (final s in lista) {
      // 🛡️ NORMALIZACIJA VREMENA IZ LISTE (Kapacitet table može imati "6:00" umesto "06:00")
      final currentVreme = GradAdresaValidator.normalizeTime(s.vreme);
      if (currentVreme == targetVreme) {
        return s.slobodna >= brojMesta;
      }
    }
    return false;
  }

  /// Promeni vreme polaska za putnika
  /// Vraća: {'success': bool, 'message': String}
  ///
  /// Ograničenja za tip 'ucenik' (do 16h):
  /// - Za DANAŠNJI dan: samo 1 promena
  /// - Za BUDUĆE dane: max 3 promene po danu
  ///
  /// Tip 'radnik' nema ograničenja.
  /// Tip 'dnevni' - admin kontroliše mogućnost zakazivanja putem dugmeta u Admin Screen.
  static Future<Map<String, dynamic>> promeniVremePutnika({
    required String putnikId,
    required String novoVreme,
    required String grad, // 'BC' ili 'VS'
    required String dan, // 'pon', 'uto', itd.
    bool skipKapacitetCheck = false, // 🆕 Admin bypass
  }) async {
    try {
      final sada = DateTime.now();
      final danas = sada.toIso8601String().split('T')[0];
      final danasDan = _isoDateToDayAbbr(danas);
      final jeZaDanas = dan.toLowerCase() == danasDan.toLowerCase();

      // 📅 Izračunaj ciljni datum (targetDate) za proveru kapaciteta
      String targetIsoDate = danas;
      if (!jeZaDanas) {
        const daniMap = {'pon': 1, 'uto': 2, 'sre': 3, 'cet': 4, 'pet': 5, 'sub': 6, 'ned': 7};
        final targetWeekday = daniMap[dan.toLowerCase()] ?? 1;
        int diff = targetWeekday - sada.weekday;
        if (diff <= 0) diff += 7; // Sledeća nedelja
        targetIsoDate = sada.add(Duration(days: diff)).toIso8601String().split('T')[0];
      }

      // Dohvati podatke putnika
      final putnikResponse = await _supabase
          .from('registrovani_putnici')
          .select('id, putnik_ime, tip, polasci_po_danu')
          .eq('id', putnikId)
          .maybeSingle();

      if (putnikResponse == null) {
        return {'success': false, 'message': 'Putnik nije pronađen'};
      }

      final tipPutnika = (putnikResponse['tip'] as String?)?.toLowerCase() ?? 'radnik';

      // Parsiraj polaske ODMAH, jer nam trebaju za ažuriranje kasnije
      final polasciRaw = putnikResponse['polasci_po_danu'];
      Map<String, dynamic> polasci = {};
      if (polasciRaw is String) {
        polasci = Map<String, dynamic>.from(jsonDecode(polasciRaw));
      } else if (polasciRaw is Map) {
        polasci = Map<String, dynamic>.from(polasciRaw);
      }

      bool performCapacityCheck = true;
      String successMessage = 'Vreme promenjeno na $novoVreme';

      // ═══════════════════════════════════════════════════════════════
      // 🎓 OGRANIČENJA ZA UČENIKE
      // ═══════════════════════════════════════════════════════════════
      if (tipPutnika == 'ucenik') {
        final limitSati = 16; // ✅ Vraćeno na 16h prema BC LOGIKA.md

        // 1. Provera roka (do 16h) za buduće dane
        if (sada.hour < limitSati && !jeZaDanas) {
          // Prihvati bez provere kapaceta
          performCapacityCheck = false;
          successMessage = 'Zakazivanje uspešno bez provere slobodnih mesta.';
        } else if (!jeZaDanas && sada.hour >= limitSati) {
          // Kasno zakazivanje za budućnost (posle 16h/24h)

          if (sada.hour < 20) {
            // 16h-20h: Prihvati ali "provera u 20h"
            // Ovde takodje ne proveravamo kapacitet SAD, vec se oslanjamo na naknadnu proveru
            performCapacityCheck = false;
            successMessage = 'Vaš zahtev je prihvaćen. Provera slobodnih mesta biće izvršena u 20:00.';
          } else {
            // Posle 20h: Mora provera kapaciteta
            performCapacityCheck = true;
            // Ako nema mesta, logika dole ce ponuditi alternativu
          }
        }

        // 2. Provera limita promena - UKLONJENO
        // Sistem sada dozvoljava neograničene promene jer korisnici ionako čekaju na proveru kapaciteta
      }

      // ═══════════════════════════════════════════════════════════════
      // 🎫 PROVERA SLOBODNIH MESTA
      // ═══════════════════════════════════════════════════════════════

      // Ako treba provera kapaciteta:
      if (performCapacityCheck && !skipKapacitetCheck) {
        final jeUcenikBC = tipPutnika == 'ucenik' && grad.toUpperCase() == 'BC';

        // Stari kod: if (!jeUcenikBC) { final imaMesta = ... }
        // Znaci ucenik iz BC ne proverava kapacitet nikad? (Pretpostavka: da)

        if (!jeUcenikBC) {
          final imaMesta = await imaSlobodnihMesta(grad, novoVreme, datum: targetIsoDate);

          if (!imaMesta) {
            // Ako je ucenik i zakazuje kasno (posle 20h za buducnost), nudi alternativu
            if (tipPutnika == 'ucenik' && !jeZaDanas && sada.hour >= 20) {
              final alternativnoVreme =
                  await nadjiAlternativnoVreme(grad, datum: targetIsoDate, zeljenoVreme: novoVreme);
              if (alternativnoVreme != null) {
                return {
                  'success': false,
                  'message':
                      'Nažalost, nema slobodnih mesta za traženo vreme. Predlažemo alternativno vreme: $alternativnoVreme.',
                };
              } else {
                return {
                  'success': false,
                  'message': 'Nažalost, nema slobodnih mesta za traženo vreme, niti imamo alternativu.',
                };
              }
            }

            return {'success': false, 'message': 'Nema slobodnih mesta za $novoVreme'};
          }
        }
      }

      // ═══════════════════════════════════════════════════════════════
      // 💾 AŽURIRANJE BAZE
      // ═══════════════════════════════════════════════════════════════

      final gradKey = grad.toLowerCase() == 'bc' ? 'bc' : 'vs';

      // Ažuriraj vreme i status (očisti pending status ako postoji)
      if (polasci[dan] == null || polasci[dan] is! Map) {
        polasci[dan] = {};
      }
      final danData = Map<String, dynamic>.from(polasci[dan] as Map);
      danData[gradKey] = novoVreme;

      // Resetuj status na 'confirmed' jer je admin/sistem upravo obradio zahtev
      danData['${gradKey}_status'] = 'confirmed';
      danData['${gradKey}_vreme_obrade'] = DateTime.now().toUtc().toIso8601String();

      polasci[dan] = danData;

      // Sačuvaj u bazu
      await _supabase.from('registrovani_putnici').update({'polasci_po_danu': polasci}).eq('id', putnikId);

      // Zapiši promenu - UKLONJENO
      // Sistem više ne ograničava broj promena

      // 📝 LOG POTVRDU U voznje_log (da se pojavi u Monitoru Zahteva)
      try {
        await VoznjeLogService.logPotvrda(
          putnikId: putnikId,
          dan: dan,
          vreme: novoVreme,
          grad: gradKey,
          tipPutnika: putnikResponse['tip']?.toString() ?? 'Putnik',
          detalji: 'Zahtev obrađen (Vreme promenjeno)',
        );
      } catch (logError) {
        debugPrint('Greška pri logovanju potvrde: $logError');
      }

      return {'success': true, 'message': successMessage};
    } catch (e) {
      return {'success': false, 'message': 'Greška: $e'};
    }
  }

  /// 🆕 Broji registrovane putnike sa statusom 'ceka_mesto' za VS Rush Hour termin
  /// Vraća broj putnika koji čekaju za određeni termin i dan
  static Future<int> brojCekaMestoZaVsTermin(String vreme, String dan) async {
    try {
      final response = await _supabase
          .from('registrovani_putnici')
          .select('id, polasci_po_danu')
          .eq('is_duplicate', false)
          .not('polasci_po_danu', 'is', null);

      int count = 0;
      for (final row in response) {
        final polasci = _getPolasciMap(row['polasci_po_danu']);
        if (polasci == null) continue;

        final danData = polasci[dan.toLowerCase()] as Map<String, dynamic>?;
        if (danData == null) continue;

        final vsVreme = danData['vs'] as String?;
        final vsStatus = danData['vs_status'] as String?;

        if (vsVreme == vreme && vsStatus == 'ceka_mesto') {
          count++;
        }
      }

      return count;
    } catch (e) {
      return 0;
    }
  }

  /// 🆕 Potvrdi sve putnike na listi čekanja za VS Rush Hour termin
  /// Koristi se kada se skupi 4+ zahteva za drugi kombi
  static Future<int> potvrdiSveCekaMestoZaVsTermin(String vreme, String dan) async {
    try {
      final response = await _supabase
          .from('registrovani_putnici')
          .select('id, polasci_po_danu, tip')
          .eq('is_duplicate', false)
          .not('polasci_po_danu', 'is', null);

      int confirmedCount = 0;
      for (final row in response) {
        final putnikId = row['id'] as String;
        final userType = row['tip'] ?? 'Putnik';
        final polasci = _getPolasciMap(row['polasci_po_danu']) ?? {};

        final danData = polasci[dan.toLowerCase()] as Map<String, dynamic>?;
        if (danData == null) continue;

        final vsVreme = danData['vs'] as String?;
        final vsStatus = danData['vs_status'] as String?;

        if (vsVreme == vreme && vsStatus == 'ceka_mesto') {
          // Potvrdi ovog putnika
          (polasci[dan.toLowerCase()] as Map<String, dynamic>)['vs_status'] = 'confirmed';

          await _supabase.from('registrovani_putnici').update({'polasci_po_danu': polasci}).eq('id', putnikId);

          // 📝 LOG U DNEVNIK
          try {
            await VoznjeLogService.logPotvrda(
              putnikId: putnikId,
              dan: dan,
              vreme: vreme,
              grad: 'vs',
              tipPutnika: userType,
              detalji: 'Lista čekanja potvrđena',
            );
          } catch (e) {
            debugPrint('⚠️ Error parsing capacity data: $e');
          }

          confirmedCount++;
        }
      }

      return confirmedCount;
    } catch (e) {
      return 0;
    }
  }

  /// 🆕 Dohvati listu putnik ID-jeva koji čekaju za VS Rush Hour termin
  /// Sortirano po FIFO - ko se prvi prijavio, prvi je na listi
  static Future<List<String>> dohvatiCekaMestoZaVsTermin(String vreme, String dan) async {
    try {
      final response = await _supabase
          .from('registrovani_putnici')
          .select('id, polasci_po_danu')
          .eq('is_duplicate', false)
          .not('polasci_po_danu', 'is', null);

      // Lista sa ID i timestamp za sortiranje
      final List<MapEntry<String, DateTime>> waitingList = [];

      for (final row in response) {
        final polasci = _getPolasciMap(row['polasci_po_danu']);
        if (polasci == null) continue;

        final danData = polasci[dan.toLowerCase()] as Map<String, dynamic>?;
        if (danData == null) continue;

        final vsVreme = danData['vs'] as String?;
        final vsStatus = danData['vs_status'] as String?;
        final vsCekaOd = danData['vs_ceka_od'] as String?;

        if (vsVreme == vreme && vsStatus == 'ceka_mesto') {
          // Parsiraj timestamp ili koristi davni datum ako nema
          final timestamp = vsCekaOd != null ? DateTime.tryParse(vsCekaOd) ?? DateTime(2000) : DateTime(2000);
          waitingList.add(MapEntry(row['id'] as String, timestamp));
        }
      }

      // Sortiraj po vremenu prijave (FIFO - najstariji prvi)
      waitingList.sort((a, b) => a.value.compareTo(b.value));

      return waitingList.map((e) => e.key).toList();
    } catch (e) {
      return [];
    }
  }

  /// Pronađi najbliže alternativno vreme za određeni grad i datum
  static Future<String?> nadjiAlternativnoVreme(
    String grad, {
    required String datum,
    required String zeljenoVreme,
  }) async {
    final slobodna = await getSlobodnaMesta(datum: datum);
    final lista = slobodna[grad.toUpperCase()];
    if (lista == null) return null;

    // Pretvori željeno vreme u DateTime za poređenje
    final zeljeno = DateTime.parse('$datum $zeljenoVreme:00');

    // Pronađi najbliže slobodno vreme
    String? najblizeVreme;
    Duration? najmanjaRazlika;

    for (final s in lista) {
      if (!s.jePuno) {
        final trenutno = DateTime.parse('$datum ${s.vreme}:00');
        final razlika = (trenutno.difference(zeljeno)).abs();

        if (najmanjaRazlika == null || razlika < najmanjaRazlika) {
          najmanjaRazlika = razlika;
          najblizeVreme = s.vreme;
        }
      }
    }

    return najblizeVreme;
  }

  /// 🎓 Broji koliko je učenika "krenulo u školu" (imalo jutarnji polazak iz BC) za dati dan
  /// Ovo je ključno za VS logiku povratka - znamo koliko ih OČEKUJEMO nazad.
  static Future<int> getBrojUcenikaKojiSuOtisliUSkolu(String dan) async {
    try {
      final response = await _supabase
          .from('registrovani_putnici')
          .select('id, tip, polasci_po_danu, radni_dani, status, broj_mesta') // Dodat broj_mesta
          .eq('is_duplicate', false)
          .not('polasci_po_danu', 'is', null);

      int count = 0;
      final normalizedDan = dan.toLowerCase();

      for (final row in response) {
        // 1. Proveri tip (mora biti učenik)
        final tip = (row['tip'] as String?)?.toLowerCase() ?? '';
        if (!tip.contains('ucenik')) continue;

        // 2. Proveri status (mora biti aktivan)
        final status = (row['status'] as String?)?.toLowerCase() ?? 'aktivan';
        if (status == 'obrisan' || status == 'neaktivan') continue;

        // 3. Proveri da li ide taj dan
        final radniDaniStr = row['radni_dani'] as String? ?? '';
        final radniDani = radniDaniStr.toLowerCase().split(',').map((s) => s.trim()).toList();
        if (!radniDani.contains(normalizedDan)) continue;

        // 4. Proveri da li ima JUTARNJI (BC) polazak
        final polasci = _getPolasciMap(row['polasci_po_danu']);
        if (polasci == null) continue;

        final danData = polasci[normalizedDan] as Map<String, dynamic>?;
        if (danData == null) continue;

        final bcVreme = danData['bc'] as String?;
        // Ako ima BC vreme (nije null i nije prazno), znači da je krenuo u školu
        if (bcVreme != null && bcVreme.isNotEmpty) {
          final int bm = (row['broj_mesta'] as num?)?.toInt() ?? 1;
          count += bm;
        }
      }

      return count;
    } catch (e) {
      return 0;
    }
  }

  /// 🎓 Broji koliko učenika ima UPISAN POVRATAK (VS) za dati dan (bilo confirmed ili pending)
  static Future<int> getBrojUcenikaKojiSeVracaju(String dan) async {
    try {
      final response = await _supabase
          .from('registrovani_putnici')
          .select('id, tip, polasci_po_danu, radni_dani, status, broj_mesta') // Dodat broj_mesta
          .eq('is_duplicate', false)
          .not('polasci_po_danu', 'is', null);

      int count = 0;
      final normalizedDan = dan.toLowerCase();

      for (final row in response) {
        final tip = (row['tip'] as String?)?.toLowerCase() ?? '';
        if (!tip.contains('ucenik')) continue;

        final status = (row['status'] as String?)?.toLowerCase() ?? 'aktivan';
        if (status == 'obrisan' || status == 'neaktivan') continue;

        final radniDaniStr = row['radni_dani'] as String? ?? '';
        final radniDani = radniDaniStr.toLowerCase().split(',').map((s) => s.trim()).toList();
        if (!radniDani.contains(normalizedDan)) continue;

        final polasci = _getPolasciMap(row['polasci_po_danu']);
        if (polasci == null) continue;

        final danData = polasci[normalizedDan] as Map<String, dynamic>?;
        if (danData == null) continue;

        final vsVreme = danData['vs'] as String?;
        if (vsVreme != null && vsVreme.isNotEmpty && vsVreme != 'null') {
          final int bm = (row['broj_mesta'] as num?)?.toInt() ?? 1;
          count += bm;
        }
      }

      return count;
    } catch (e) {
      return 0;
    }
  }

  /// Dohvati listu putnika koji su jutros došli u VS a nisu rezervisali povratak
  static Future<List<Map<String, dynamic>>> getMissingTransitPassengers() async {
    try {
      final now = DateTime.now();
      const dani = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
      final danDanas = dani[now.weekday - 1];

      // Vikendom nema standardne tranzitne logike za radnike/učenike obično
      if (now.weekday > 5) return [];

      final response = await _supabase
          .from('registrovani_putnici')
          .select('id, putnik_ime, tip, polasci_po_danu, broj_mesta') // Dodat broj_mesta
          .eq('aktivan', true)
          .eq('obrisan', false)
          .eq('is_duplicate', false)
          .inFilter('tip', ['ucenik', 'radnik']);

      final results = <Map<String, dynamic>>[];

      for (var row in response) {
        final polasci = _getPolasciMap(row['polasci_po_danu']);
        if (polasci == null || polasci[danDanas] == null) continue;

        final danas = polasci[danDanas] as Map<String, dynamic>;
        final bcStatus = danas['bc_status']?.toString();
        final vsVreme = danas['vs']?.toString();

        // Uslov: confirmed BC jutros AND (nema VS vremena OR VS status nije confirmed/pending)
        if (bcStatus == 'confirmed' && (vsVreme == null || vsVreme == '' || vsVreme == 'null')) {
          results.add({
            'id': row['id'],
            'ime': row['putnik_ime'],
            'tip': row['tip'],
            'broj_mesta': (row['broj_mesta'] as num?)?.toInt() ?? 1,
          });
        }
      }

      return results;
    } catch (e) {
      return [];
    }
  }

  /// Stream za missing transit passengers sa realtime osvežavanjem
  static Stream<List<Map<String, dynamic>>> streamMissingTransitPassengers() {
    if (_missingTransitSubscription == null) {
      _missingTransitSubscription = RealtimeManager.instance.subscribe('registrovani_putnici').listen((payload) {
        _refreshMissingTransitStream();
      });
      // Inicijalno učitavanje
      _refreshMissingTransitStream();
    }
    return _missingTransitController.stream;
  }

  static void _refreshMissingTransitStream() async {
    final missing = await getMissingTransitPassengers();
    if (!_missingTransitController.isClosed) {
      _missingTransitController.add(missing);
    }
  }

  /// Ručno okida slanje podsetnika svim tranzitnim putnicima koji nisu rezervisali povratak
  static Future<int> triggerTransitReminders() async {
    try {
      final response = await _supabase.rpc('notify_missing_transit_passengers');
      return response as int? ?? 0;
    } catch (e) {
      debugPrint('❌ Greška pri slanju podsetnika: $e');
      return 0;
    }
  }

  /// Izračunava projektovano opterećenje za grad i vreme, uključujući i one koji nisu rezervisali
  static Future<Map<String, dynamic>> getProjectedOccupancyStats() async {
    try {
      final missingList = await getMissingTransitPassengers();
      final stats = await getSlobodnaMesta();

      // 1. Zbir već potvrđenih i pending mesta za VS polaske (povratak)
      int totalReserved = 0;
      final vsStats = stats['VS'] ?? [];
      for (var s in vsStats) {
        totalReserved += s.zauzetaMesta;
      }

      // 2. Putnici koji su u VS a nemaju potvrđen povratak
      final int missingCount = missingList.length;

      return {
        'reservations_count': totalReserved,
        'missing_count': missingCount,
        'missing_total': missingCount,
        'missing_ucenici': missingList.where((p) => p['tip'] == 'ucenik').length,
        'missing_radnici': missingList.where((p) => p['tip'] == 'radnik').length,
      };
    } catch (e) {
      return {
        'reservations_count': 0,
        'missing_count': 0,
      };
    }
  }

  /// Stream za projected occupancy stats sa realtime osvežavanjem
  static Stream<Map<String, dynamic>> streamProjectedOccupancyStats() {
    if (_projectedStatsSubscription == null) {
      // Listen to both registrovani_putnici and kapacitet_polazaka
      _projectedStatsSubscription = RealtimeManager.instance.subscribe('registrovani_putnici').listen((payload) {
        _refreshProjectedStatsStream();
      });
      RealtimeManager.instance.subscribe('kapacitet_polazaka').listen((payload) {
        _refreshProjectedStatsStream();
      });
      // Inicijalno učitavanje
      _refreshProjectedStatsStream();
    }
    return _projectedStatsController.stream;
  }

  static void _refreshProjectedStatsStream() async {
    final stats = await getProjectedOccupancyStats();
    if (!_projectedStatsController.isClosed) {
      _projectedStatsController.add(stats);
    }
  }

  /// 🧹 Čisti realtime subscriptions
  static void dispose() {
    _missingTransitSubscription?.cancel();
    _missingTransitSubscription = null;
    _missingTransitController.close();

    _projectedStatsSubscription?.cancel();
    _projectedStatsSubscription = null;
    _projectedStatsController.close();
  }

  /// 🛡️ Sigurno parsira polasci_po_danu (Map ili String)
  static Map<String, dynamic>? _getPolasciMap(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String) {
      try {
        return json.decode(raw) as Map<String, dynamic>?;
      } catch (e) {
        debugPrint('Greška pri parsu polasci_po_danu: $e');
        return null;
      }
    }
    return null;
  }

  /// 🆕 Dohvati broj zauzetih mesta za VS za dati dan i vreme
  static Future<int> getOccupiedSeatsVs(String dan, String vreme) async {
    try {
      final response =
          await _supabase.from('registrovani_putnici').select('id, polasci_po_danu, tip').eq('is_duplicate', false);

      int count = 0;
      final targetVreme = GradAdresaValidator.normalizeTime(vreme);

      for (final row in response) {
        final polasci = _getPolasciMap(row['polasci_po_danu']);
        if (polasci == null) continue;

        final danData = polasci[dan.toLowerCase()] as Map<String, dynamic>?;
        if (danData == null) continue;

        final vsVreme = danData['vs'] as String?;
        final vsStatus = danData['vs_status'] as String?;

        // Proveri da li je zaista zauzeto mesto (status nije ceka_mesto)
        if (vsVreme == vreme && vsStatus != 'ceka_mesto') {
          count++;
        }
      }

      return count;
    } catch (e) {
      return 0;
    }
  }

  /// 🆕 Dohvati broj zauzetih mesta za BC za dati dan i vreme
  static Future<int> getOccupiedSeatsBc(String dan, String vreme) async {
    try {
      final response =
          await _supabase.from('registrovani_putnici').select('id, polasci_po_danu, tip').eq('is_duplicate', false);

      int count = 0;
      final targetVreme = GradAdresaValidator.normalizeTime(vreme);

      for (final row in response) {
        final polasci = _getPolasciMap(row['polasci_po_danu']);
        if (polasci == null) continue;

        final danData = polasci[dan.toLowerCase()] as Map<String, dynamic>?;
        if (danData == null) continue;

        final bcVreme = danData['bc'] as String?;
        final bcStatus = danData['bc_status'] as String?;

        // Proveri da li je zaista zauzeto mesto (status nije ceka_mesto)
        if (bcVreme == vreme && bcStatus != 'ceka_mesto') {
          count++;
        }
      }

      return count;
    } catch (e) {
      return 0;
    }
  }
}
