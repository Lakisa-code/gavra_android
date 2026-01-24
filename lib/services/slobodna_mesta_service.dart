import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import '../models/putnik.dart';
import '../utils/grad_adresa_validator.dart';
import '../utils/putnik_helpers.dart';
import 'kapacitet_service.dart';
import 'putnik_service.dart';

/// 🎫 Model za slobodna mesta po polasku
class SlobodnaMesta {
  final String grad;
  final String vreme;
  final int maxMesta;
  final int zauzetaMesta;
  final bool aktivan;
  final int waitingCount; // 🆕 Broj ljudi na listi čekanja
  final int uceniciCount; // 🆕 Broj učenika

  SlobodnaMesta({
    required this.grad,
    required this.vreme,
    required this.maxMesta,
    required this.zauzetaMesta,
    required this.aktivan,
    this.waitingCount = 0, // 🆕 Default 0
    this.uceniciCount = 0, // 🆕 Default 0
  });

  /// Broj slobodnih mesta
  int get slobodna => (maxMesta - zauzetaMesta).clamp(0, maxMesta);

  /// Da li je pun kapacitet
  bool get jePuno => slobodna <= 0;

  /// 🆕 Da li je ovo "Rush Hour" (špic) vreme kada se skupljaju zahtevi za drugi kombi
  bool get isRushHour => ['13:00', '14:00', '15:30'].contains(vreme);

  /// 🆕 Da li ima dovoljno ljudi na čekanju za drugi kombi (min 3)
  bool get shouldActivateSecondVan => waitingCount >= 3;

  /// Status boja: zelena (>3), žuta (1-3), crvena (0)
  /// Ako je PUNO ali ima waiting listu:
  /// - Ljubicasta: Drugi kombi se puni (waiting >= 1)
  String get statusBoja {
    if (!aktivan) return 'grey';
    if (jePuno && waitingCount > 0) return 'purple'; // 🆕 Indikator za waiting listu
    if (slobodna > 3) return 'green';
    if (slobodna > 0) return 'yellow';
    return 'red';
  }
}

/// 🎫 Servis za računanje slobodnih mesta (kapacitet - zauzeto)
class SlobodnaMestaService {
  static SupabaseClient get _supabase => supabase;
  static final _putnikService = PutnikService();

  /// Izračunaj broj zauzetih mesta za određeni grad/vreme/datum
  static int _countPutniciZaPolazak(List<Putnik> putnici, String grad, String vreme, String isoDate) {
    final normalizedGrad = grad.toLowerCase();
    final targetDayAbbr = _isoDateToDayAbbr(isoDate);

    int count = 0;
    for (final p in putnici) {
      // 🔧 REFAKTORISANO: Koristi PutnikHelpers za konzistentnu logiku
      // Ne računa: otkazane (jeOtkazan), odsustvo (jeOdsustvo)
      if (!PutnikHelpers.shouldCountInSeats(p)) continue;

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
        // ✅ FIX: Broji broj mesta (brojMesta), ne samo broj putnika
        count += p.brojMesta;
      }
    }

    return count;
  }

  /// 🆕 Izračunaj broj putnika na CEKANJU za određeni grad/vreme
  static int _countWaitingZaPolazak(List<Putnik> putnici, String grad, String vreme, String isoDate) {
    final normalizedGrad = grad.toLowerCase();
    final targetDayAbbr = _isoDateToDayAbbr(isoDate);

    int count = 0;
    for (final p in putnici) {
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
  static int _countUceniciZaPolazak(List<Putnik> putnici, String grad, String vreme, String isoDate) {
    final normalizedGrad = grad.toLowerCase();
    final targetDayAbbr = _isoDateToDayAbbr(isoDate);

    int count = 0;
    for (final p in putnici) {
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

  /// Konvertuj ISO datum u pun naziv dana
  static String _isoDateToDayName(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      const dani = ['Ponedeljak', 'Utorak', 'Sreda', 'Četvrtak', 'Petak', 'Subota', 'Nedelja'];
      return dani[date.weekday - 1];
    } catch (e) {
      return 'Ponedeljak';
    }
  }

  /// Jednokratno dohvatanje slobodnih mesta
  static Future<Map<String, List<SlobodnaMesta>>> getSlobodnaMesta({String? datum}) async {
    final isoDate = datum ?? DateTime.now().toIso8601String().split('T')[0];

    // Dohvati kapacitet
    final kapacitet = await KapacitetService.getKapacitet();

    // Dohvati putnike
    final danName = _isoDateToDayName(isoDate);
    final putnici = await _putnikService.getAllPutnici(targetDay: danName);

    final result = <String, List<SlobodnaMesta>>{'BC': [], 'VS': []};

    // Bela Crkva
    for (final vreme in KapacitetService.bcVremena) {
      final maxMesta = kapacitet['BC']?[vreme] ?? 8;
      final zauzeto = _countPutniciZaPolazak(putnici, 'BC', vreme, isoDate);
      final waiting = _countWaitingZaPolazak(putnici, 'BC', vreme, isoDate);
      final ucenici = _countUceniciZaPolazak(putnici, 'BC', vreme, isoDate); // 🆕

      // 🎓 BC LOGIKA: Učenici se ne broje u standardni kapacitet (vidi BC LOGIKA.md).
      // Kapacitet (maxMesta) za BC se odnosi na radnike i dnevne putnike.
      final regularnoZauzeto = (zauzeto - ucenici).clamp(0, zauzeto);

      result['BC']!.add(
        SlobodnaMesta(
          grad: 'BC',
          vreme: vreme,
          maxMesta: maxMesta,
          zauzetaMesta: regularnoZauzeto,
          aktivan: true,
          waitingCount: waiting,
          uceniciCount: ucenici, // 🆕
        ),
      );
    }

    // Vršac
    for (final vreme in KapacitetService.vsVremena) {
      final maxMesta = kapacitet['VS']?[vreme] ?? 8;
      final zauzeto = _countPutniciZaPolazak(putnici, 'VS', vreme, isoDate);
      final waiting = _countWaitingZaPolazak(putnici, 'VS', vreme, isoDate);
      final ucenici = _countUceniciZaPolazak(putnici, 'VS', vreme, isoDate); // 🆕

      result['VS']!.add(
        SlobodnaMesta(
          grad: 'VS',
          vreme: vreme,
          maxMesta: maxMesta,
          zauzetaMesta: zauzeto,
          aktivan: true,
          waitingCount: waiting,
          uceniciCount: ucenici, // 🆕
        ),
      );
    }

    return result;
  }

  /// Proveri da li ima slobodnih mesta za određeni polazak
  static Future<bool> imaSlobodnihMesta(String grad, String vreme,
      {String? datum, String? tipPutnika, int brojMesta = 1}) async {
    // 🎓 BC LOGIKA: Učenici se u Beloj Crkvi uvek primaju (oni su extra / ne zauzimaju radnicima mesta)
    if (grad.toUpperCase() == 'BC' && tipPutnika == 'ucenik') {
      return true;
    }

    final slobodna = await getSlobodnaMesta(datum: datum);
    final lista = slobodna[grad.toUpperCase()];
    if (lista == null) return false;

    for (final s in lista) {
      if (s.vreme == vreme) {
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
        final limitSati = 24; // TESTIRANJE: Bilo 16

        // 1. Provera roka (do 16h / 24h) za buduće dane
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

        // 2. Provera limita promena
        // Brojač promena za ciljni dan
        final brojPromena = await _brojPromenaZaDan(putnikId, danas, dan);

        if (jeZaDanas) {
          // Za DANAŠNJI dan: max 1 promena
          if (brojPromena >= 1) {
            return {'success': false, 'message': 'Za današnji dan možete promeniti vreme samo jednom.'};
          }
        } else {
          // Za BUDUĆE dane: max 3 promene
          if (brojPromena >= 3) {
            return {'success': false, 'message': 'Za $dan ste već napravili 3 promene danas.'};
          }
        }
      }

      // ═══════════════════════════════════════════════════════════════
      // 🎫 PROVERA SLOBODNIH MESTA
      // ═══════════════════════════════════════════════════════════════

      // Ako treba provera kapaciteta:
      if (performCapacityCheck) {
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

      // Ažuriraj vreme
      if (polasci[dan] == null || polasci[dan] is! Map) {
        polasci[dan] = {};
      }
      (polasci[dan] as Map)[gradKey] = novoVreme;

      // Sačuvaj u bazu
      await _supabase.from('registrovani_putnici').update({'polasci_po_danu': jsonEncode(polasci)}).eq('id', putnikId);

      // Zapiši promenu za učenike i dnevne
      if (tipPutnika == 'ucenik' || tipPutnika == 'dnevni') {
        await _zapisiPromenuVremena(putnikId, danas, dan);
      }

      return {'success': true, 'message': successMessage};
    } catch (e) {
      return {'success': false, 'message': 'Greška: $e'};
    }
  }

  /// Javna metoda za logovanje promene (koristi se iz RegistrovaniPutnikProfilScreen)
  static Future<void> logujPromenuVremena(String putnikId, String ciljniDan) async {
    final danas = DateTime.now().toIso8601String().split('T')[0];
    await _zapisiPromenuVremena(putnikId, danas, ciljniDan);
  }

  /// Broji koliko puta je putnik menjao vreme za određeni ciljni dan (danas)
  /// Javna metoda za korišćenje iz drugih ekrana
  static Future<int> brojPromenaZaDan(String putnikId, String ciljniDan) async {
    final danas = DateTime.now().toIso8601String().split('T')[0];
    return _brojPromenaZaDan(putnikId, danas, ciljniDan);
  }

  /// 🆕 Broji UKUPAN broj promena danas (svi dani zajedno)
  /// Za učenike: max 2 promene dnevno (BC + VS ukupno)
  static Future<int> ukupnoPromenaDanas(String putnikId) async {
    try {
      final danas = DateTime.now().toIso8601String().split('T')[0];
      final response =
          await _supabase.from('promene_vremena_log').select('id').eq('putnik_id', putnikId).eq('datum', danas);

      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  /// Privatna verzija koja prima datum
  static Future<int> _brojPromenaZaDan(String putnikId, String datum, String ciljniDan) async {
    try {
      final response = await _supabase
          .from('promene_vremena_log')
          .select('id')
          .eq('putnik_id', putnikId)
          .eq('datum', datum)
          .eq('ciljni_dan', ciljniDan.toLowerCase());

      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  /// Zapiši promenu vremena - javna verzija za korišćenje iz drugih ekrana
  static Future<void> zapisiPromenuVremena(String putnikId, String ciljniDan) async {
    final danas = DateTime.now().toIso8601String().split('T')[0];
    await _zapisiPromenuVremena(putnikId, danas, ciljniDan);
  }

  /// Zapiši promenu vremena (za ograničenje učenika) - privatna verzija
  /// Sada čuva i datum_polaska i sati_unapred za praćenje odgovornosti
  static Future<void> _zapisiPromenuVremena(String putnikId, String datum, String ciljniDan) async {
    try {
      final now = DateTime.now();

      // Izračunaj tačan datum polaska iz ciljnog dana
      final datumPolaska = _izracunajDatumPolaska(ciljniDan);

      // Izračunaj koliko sati unapred je zakazano
      int satiUnapred = 0;
      if (datumPolaska != null) {
        final razlika = datumPolaska.difference(now);
        satiUnapred = razlika.inHours;
        if (satiUnapred < 0) satiUnapred = 0; // Ako je već prošlo
      }

      await _supabase.from('promene_vremena_log').insert({
        'putnik_id': putnikId,
        'datum': datum,
        'ciljni_dan': ciljniDan.toLowerCase(),
        'created_at': now.toIso8601String(),
        'datum_polaska': datumPolaska?.toIso8601String().split('T')[0],
        'sati_unapred': satiUnapred,
      });
    } catch (e) {
      // Error writing change log
    }
  }

  /// Izračunaj tačan datum polaska iz imena dana (pon, uto, sre, cet, pet)
  static DateTime? _izracunajDatumPolaska(String danKratica) {
    final daniMapa = {
      'pon': DateTime.monday,
      'uto': DateTime.tuesday,
      'sre': DateTime.wednesday,
      'cet': DateTime.thursday,
      'pet': DateTime.friday,
      'sub': DateTime.saturday,
      'ned': DateTime.sunday,
    };

    final targetWeekday = daniMapa[danKratica.toLowerCase()];
    if (targetWeekday == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Računaj razliku u danima
    int daysUntilTarget = targetWeekday - today.weekday;

    // Ako je ciljni dan danas ili ranije u nedelji, to je ovaj dan
    // Ako je negativno, znači da je dan prošao - ali za naš slučaj
    // gledamo tekuću nedelju (putnik može zakazati samo za tekuću nedelju)
    if (daysUntilTarget < 0) {
      daysUntilTarget += 7; // Sledeća nedelja
    }

    return today.add(Duration(days: daysUntilTarget));
  }

  /// 🆕 Broji registrovane putnike sa statusom 'ceka_mesto' za VS Rush Hour termin
  /// Vraća broj putnika koji čekaju za određeni termin i dan
  static Future<int> brojCekaMestoZaVsTermin(String vreme, String dan) async {
    try {
      final response =
          await _supabase.from('registrovani_putnici').select('id, polasci_po_danu').not('polasci_po_danu', 'is', null);

      int count = 0;
      for (final row in response) {
        final polasci = row['polasci_po_danu'] as Map<String, dynamic>?;
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
      final response =
          await _supabase.from('registrovani_putnici').select('id, polasci_po_danu').not('polasci_po_danu', 'is', null);

      int confirmedCount = 0;
      for (final row in response) {
        final putnikId = row['id'] as String;
        final polasci = Map<String, dynamic>.from(row['polasci_po_danu'] as Map);

        final danData = polasci[dan.toLowerCase()] as Map<String, dynamic>?;
        if (danData == null) continue;

        final vsVreme = danData['vs'] as String?;
        final vsStatus = danData['vs_status'] as String?;

        if (vsVreme == vreme && vsStatus == 'ceka_mesto') {
          // Potvrdi ovog putnika
          (polasci[dan.toLowerCase()] as Map<String, dynamic>)['vs_status'] = 'confirmed';

          await _supabase.from('registrovani_putnici').update({'polasci_po_danu': polasci}).eq('id', putnikId);

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
      final response =
          await _supabase.from('registrovani_putnici').select('id, polasci_po_danu').not('polasci_po_danu', 'is', null);

      // Lista sa ID i timestamp za sortiranje
      final List<MapEntry<String, DateTime>> waitingList = [];

      for (final row in response) {
        final polasci = row['polasci_po_danu'] as Map<String, dynamic>?;
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
        final polasci = row['polasci_po_danu'] as Map<String, dynamic>?;
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

        final polasci = row['polasci_po_danu'] as Map<String, dynamic>?;
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
          .inFilter('tip', ['ucenik', 'radnik']);

      final results = <Map<String, dynamic>>[];

      for (var row in response) {
        final polasci = row['polasci_po_danu'] as Map<String, dynamic>?;
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
}
