import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import '../models/putnik.dart';
import '../utils/grad_adresa_validator.dart';
import '../utils/putnik_helpers.dart';
import 'kapacitet_service.dart';
import 'putnik_service.dart';
import 'realtime/realtime_manager.dart';

/// 🎫 Model za slobodna mesta po polasku
class SlobodnaMesta {
  final String grad;
  final String vreme;
  final int maxMesta;
  final int zauzetaMesta;
  final int uceniciCount;
  final bool aktivan;

  SlobodnaMesta({
    required this.grad,
    required this.vreme,
    required this.maxMesta,
    required this.zauzetaMesta,
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

  static StreamSubscription? _projectedStatsSubscription;
  static StreamSubscription? _kapacitetStatsSubscription;
  static final StreamController<Map<String, dynamic>> _projectedStatsController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Izračunaj broj zauzetih mesta za određeni grad/vreme/datum
  static int _countPutniciZaPolazak(List<Putnik> putnici, String grad, String vreme, String isoDate,
      {String? excludePutnikId}) {
    final normalizedGrad = GradAdresaValidator.normalizeGrad(grad); // 'BC' ili 'VS'
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

      if ((normalizedGrad == 'BC' && jeBC) || (normalizedGrad == 'VS' && jeVS)) {
        // Brojimo sve putnike za ovaj grad
        count += p.brojMesta;
      }
    }

    return count;
  }

  static int _countUceniciZaPolazak(List<Putnik> putnici, String grad, String vreme, String isoDate,
      {String? excludePutnikId}) {
    final normalizedGrad = GradAdresaValidator.normalizeGrad(grad); // 'BC' ili 'VS'
    final targetDayAbbr = _isoDateToDayAbbr(isoDate);

    int count = 0;
    for (final p in putnici) {
      if (excludePutnikId != null && p.id?.toString() == excludePutnikId.toString()) {
        continue;
      }

      // Isti filteri kao za putnike (bez otkazanih, itd)
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

      if ((normalizedGrad == 'BC' && jeBC) || (normalizedGrad == 'VS' && jeVS)) {
        count += p.brojMesta;
      }
    }

    return count;
  }
      final ucenici = _countUceniciZaPolazak(putnici, 'BC', vreme, isoDate, excludePutnikId: excludeId);

      result['BC']!.add(
        SlobodnaMesta(
          grad = 'BC',
          vreme = vreme,
          maxMesta = maxMesta,
          zauzetaMesta = zauzeto,
          aktivan = true,
          uceniciCount = ucenici,
        ),
      );
    }

    // Vršac - Koristi SVA vremena iz kapaciteta
    final vsKapaciteti = kapacitet['VS'] ?? {};
    final vsVremenaSorted = vsKapaciteti.keys.toList()..sort();

    for (final vreme in vsVremenaSorted) {
      final maxMesta = vsKapaciteti[vreme] ?? 8;
      final zauzeto = _countPutniciZaPolazak(putnici, 'VS', vreme, isoDate, excludePutnikId: excludeId);
      final ucenici = _countUceniciZaPolazak(putnici, 'VS', vreme, isoDate, excludePutnikId: excludeId);

      result['VS']!.add(
        SlobodnaMesta(
          grad: 'VS',
          vreme: vreme,
          maxMesta: maxMesta,
          zauzetaMesta: zauzeto,
          aktivan: true,
          uceniciCount: ucenici,
        ),
      );
    }

    return result;
  }

  /// Proveri da li ima slobodnih mesta za određeni polazak
  Future<bool> imaSlobodnihMesta(String grad, String vreme,
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

  /// Promeni vreme polaska za putnika koristeci RPC funkciju update_putnik_polazak_v2
  Future<Map<String, dynamic>> promeniVremePutnika({
    required String putnikId,
    required String novoVreme,
    required String grad, // 'BC' ili 'VS'
    required String dan, // 'pon', 'uto', itd.
    bool skipKapacitetCheck = false, // 🆕 Admin bypass
  }) async {
    try {
      final gradKey = GradAdresaValidator.normalizeGrad(grad);

      // 🚀 POZIVAMO RPC FUNKCIJU koja jedina zna da radi sa seat_requests
      await _supabase.rpc('update_putnik_polazak_v2', params: {
        'p_id': putnikId,
        'p_dan': dan.toLowerCase(),
        'p_grad': gradKey,
        'p_vreme': novoVreme,
        'p_status': skipKapacitetCheck ? 'confirmed' : 'pending',
      });

      // Ako je admin, odmah možemo vratiti uspeh
      if (skipKapacitetCheck) {
        return {'success': true, 'message': 'Vreme potvrđeno na $novoVreme (Admin)'};
      }

      return {'success': true, 'message': 'Zahtev za $novoVreme poslat na obradu. Proverite profil za status.'};
    } catch (e) {
      debugPrint('❌ Greška u promeniVremePutnika: $e');
      return {'success': false, 'message': 'Greška: $e'};
    }
  }

  /// Pronađi najbliže alternativno vreme za određeni grad i datum
  Future<String?> nadjiAlternativnoVreme(
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
  Future<int> getBrojUcenikaKojiSuOtisliUSkolu(String dan) async {
    try {
      final isoDate = _getIsoDateForDay(dan);
      final putnici = await _putnikService.getPutniciByDayIso(isoDate);

      // Svi učenici koji idu IZ Bele Crkve
      int count = 0;
      for (final p in putnici) {
        if (p.tipPutnika == 'ucenik' && GradAdresaValidator.isBelaCrkva(p.grad)) {
          count += p.brojMesta;
        }
      }
      return count;
    } catch (e) {
      debugPrint('Error in getBrojUcenikaKojiSuOtisliUSkolu: $e');
      return 0;
    }
  }

  /// 🎓 Broji koliko učenika ima UPISAN POVRATAK (VS) za dati dan (bilo confirmed ili pending)
  Future<int> getBrojUcenikaKojiSeVracaju(String dan) async {
    try {
      final isoDate = _getIsoDateForDay(dan);
      final putnici = await _putnikService.getPutniciByDayIso(isoDate);

      // Svi učenici koji idu IZ Vršca (povratak)
      int count = 0;
      for (final p in putnici) {
        if (p.tipPutnika == 'ucenik' && GradAdresaValidator.isVrsac(p.grad)) {
          count += p.brojMesta;
        }
      }
      return count;
    } catch (e) {
      debugPrint('Error in getBrojUcenikaKojiSeVracaju: $e');
      return 0;
    }
  }

  /// Pomoćna funkcija za dobijanje datuma iz skraćenice dana
  String _getIsoDateForDay(String danAbbr) {
    final sada = DateTime.now();
    const daniMap = {'pon': 1, 'uto': 2, 'sre': 3, 'cet': 4, 'pet': 5, 'sub': 6, 'ned': 7};
    final targetWeekday = daniMap[danAbbr.toLowerCase()] ?? 1;

    int diff = targetWeekday - sada.weekday;
    if (diff < 0) diff += 7; // Ako je prošlo, gledamo sledeću nedelju

    return sada.add(Duration(days: diff)).toIso8601String().split('T')[0];
  }

  /// Izračunava projektovano opterećenje za grad i vreme
  Future<Map<String, dynamic>> getProjectedOccupancyStats() async {
    try {
      final stats = await getSlobodnaMesta();

      // 1. Zbir već potvrđenih i pending mesta za VS polaske (povratak)
      int totalReserved = 0;
      final vsStats = stats['VS'] ?? [];
      for (var s in vsStats) {
        totalReserved += s.zauzetaMesta;
      }

      return {
        'reservations_count': totalReserved,
        'missing_count': 0,
        'missing_list': [],
      };
    } catch (e) {
      return {
        'reservations_count': 0,
        'missing_count': 0,
        'missing_list': [],
      };
    }
  }

  /// Dohvati broj slobodnih mesta za određeni grad i vreme (Vršac)
  Future<int> getOccupiedSeatsVs(String dan, String vreme) async {
    try {
      final isoDate = _getIsoDateForDay(dan);
      final putnici = await _putnikService.getPutniciByDayIso(isoDate);

      int count = 0;
      final targetVreme = GradAdresaValidator.normalizeTime(vreme);

      for (final p in putnici) {
        if (!GradAdresaValidator.isVrsac(p.grad)) continue;
        if (GradAdresaValidator.normalizeTime(p.polazak) == targetVreme) {
          count += p.brojMesta;
        }
      }
      return count;
    } catch (e) {
      return 0;
    }
  }

  /// 🆕 Dohvati broj zauzetih mesta za BC za dati dan i vreme
  Future<int> getOccupiedSeatsBc(String dan, String vreme) async {
    try {
      final isoDate = _getIsoDateForDay(dan);
      final putnici = await _putnikService.getPutniciByDayIso(isoDate);

      int count = 0;
      final targetVreme = GradAdresaValidator.normalizeTime(vreme);

      for (final p in putnici) {
        if (!GradAdresaValidator.isBelaCrkva(p.grad)) continue;
        if (GradAdresaValidator.normalizeTime(p.polazak) == targetVreme) {
          count += p.brojMesta;
        }
      }
      return count;
    } catch (e) {
      return 0;
    }
  }

  /// 🧹 Čisti realtime subscriptions
  void dispose() {
    _projectedStatsSubscription?.cancel();
    _projectedStatsSubscription = null;
    _kapacitetStatsSubscription?.cancel();
    _kapacitetStatsSubscription = null;
    _projectedStatsController.close();

    // Otkaži realtime subscriptions
    RealtimeManager.instance.unsubscribe('registrovani_putnici');
    RealtimeManager.instance.unsubscribe('kapacitet_polazaka');
  }
}
