import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/putnik.dart';
import '../utils/grad_adresa_validator.dart';
import '../utils/text_utils.dart';
import 'kapacitet_service.dart';
import 'putnik_service.dart';

/// 🎫 Model za slobodna mesta po polasku
class SlobodnaMesta {
  final String grad;
  final String vreme;
  final int maxMesta;
  final int zauzetaMesta;
  final bool aktivan;

  SlobodnaMesta({
    required this.grad,
    required this.vreme,
    required this.maxMesta,
    required this.zauzetaMesta,
    required this.aktivan,
  });

  /// Broj slobodnih mesta
  int get slobodna => (maxMesta - zauzetaMesta).clamp(0, maxMesta);

  /// Da li je pun kapacitet
  bool get jePuno => slobodna <= 0;

  /// Status boja: zelena (>3), žuta (1-3), crvena (0)
  String get statusBoja {
    if (!aktivan) return 'grey';
    if (slobodna > 3) return 'green';
    if (slobodna > 0) return 'yellow';
    return 'red';
  }
}

/// 🎫 Servis za računanje slobodnih mesta (kapacitet - zauzeto)
class SlobodnaMestaService {
  static final _supabase = Supabase.instance.client;
  static final _putnikService = PutnikService();

  /// Izračunaj broj zauzetih mesta za određeni grad/vreme/datum
  static int _countPutniciZaPolazak(List<Putnik> putnici, String grad, String vreme, String isoDate) {
    final normalizedGrad = grad.toLowerCase();
    final targetDayAbbr = _isoDateToDayAbbr(isoDate);

    int count = 0;
    for (final p in putnici) {
      // Preskoči neaktivne
      if (!TextUtils.isStatusActive(p.status)) continue;

      // Proveri datum/dan
      final dayMatch = p.datum != null ? p.datum == isoDate : p.dan.toLowerCase().contains(targetDayAbbr.toLowerCase());
      if (!dayMatch) continue;

      // Proveri vreme
      final normVreme = GradAdresaValidator.normalizeTime(p.polazak);
      if (normVreme != vreme) continue;

      // Proveri grad
      final putnikGrad = p.grad.toLowerCase();
      final jeBC = putnikGrad.contains('bela') || putnikGrad.contains('bc') || putnikGrad == 'bela crkva';
      final jeVS = putnikGrad.contains('vrsac') || putnikGrad.contains('vršac') || putnikGrad == 'vs';

      if ((normalizedGrad == 'bc' && jeBC) || (normalizedGrad == 'vs' && jeVS)) {
        // ✅ FIX: Broji broj mesta (brojMesta), ne samo broj putnika
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

  /// Stream slobodnih mesta za oba grada - osvežava svakih 2 minuta
  /// Vraća: {'BC': [SlobodnaMesta, ...], 'VS': [SlobodnaMesta, ...]}
  static Stream<Map<String, List<SlobodnaMesta>>> streamSlobodnaMesta({String? datum}) {
    final isoDate = datum ?? DateTime.now().toIso8601String().split('T')[0];

    // Kreiraj StreamController koji emituje podatke
    final controller = StreamController<Map<String, List<SlobodnaMesta>>>();
    Timer? refreshTimer;
    StreamSubscription? kapacitetSub;

    // Funkcija za dohvatanje podataka
    Future<void> fetchData(Map<String, Map<String, int>> kapacitet) async {
      try {
        final danName = _isoDateToDayName(isoDate);
        final putnici = await _putnikService.getAllPutnici(targetDay: danName);

        final result = <String, List<SlobodnaMesta>>{
          'BC': [],
          'VS': [],
        };

        // Bela Crkva
        for (final vreme in KapacitetService.bcVremena) {
          final maxMesta = kapacitet['BC']?[vreme] ?? 8;
          final zauzeto = _countPutniciZaPolazak(putnici, 'BC', vreme, isoDate);

          result['BC']!.add(SlobodnaMesta(
            grad: 'BC',
            vreme: vreme,
            maxMesta: maxMesta,
            zauzetaMesta: zauzeto,
            aktivan: true,
          ));
        }

        // Vršac
        for (final vreme in KapacitetService.vsVremena) {
          final maxMesta = kapacitet['VS']?[vreme] ?? 8;
          final zauzeto = _countPutniciZaPolazak(putnici, 'VS', vreme, isoDate);

          result['VS']!.add(SlobodnaMesta(
            grad: 'VS',
            vreme: vreme,
            maxMesta: maxMesta,
            zauzetaMesta: zauzeto,
            aktivan: true,
          ));
        }

        if (!controller.isClosed) {
          controller.add(result);
        }
      } catch (e) {
        // 🔇 Ignore
      }
    }

    // Cache za poslednji kapacitet (za timer refresh)
    Map<String, Map<String, int>> lastKapacitet = {'BC': {}, 'VS': {}};

    // Sluša kapacitet stream
    kapacitetSub = KapacitetService.streamKapacitet().listen((kapacitet) {
      lastKapacitet = kapacitet;
      fetchData(kapacitet);
    });

    // Timer koji osvežava svakih 2 minuta
    refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      fetchData(lastKapacitet);
    });

    // Cleanup kad se stream zatvori
    controller.onCancel = () {
      refreshTimer?.cancel();
      kapacitetSub?.cancel();
      controller.close();
    };

    return controller.stream;
  }

  /// Jednokratno dohvatanje slobodnih mesta
  static Future<Map<String, List<SlobodnaMesta>>> getSlobodnaMesta({String? datum}) async {
    final isoDate = datum ?? DateTime.now().toIso8601String().split('T')[0];

    // Dohvati kapacitet
    final kapacitet = await KapacitetService.getKapacitet();

    // Dohvati putnike
    final danName = _isoDateToDayName(isoDate);
    final putnici = await _putnikService.getAllPutnici(targetDay: danName);

    final result = <String, List<SlobodnaMesta>>{
      'BC': [],
      'VS': [],
    };

    // Bela Crkva
    for (final vreme in KapacitetService.bcVremena) {
      final maxMesta = kapacitet['BC']?[vreme] ?? 8;
      final zauzeto = _countPutniciZaPolazak(putnici, 'BC', vreme, isoDate);

      result['BC']!.add(SlobodnaMesta(
        grad: 'BC',
        vreme: vreme,
        maxMesta: maxMesta,
        zauzetaMesta: zauzeto,
        aktivan: true,
      ));
    }

    // Vršac
    for (final vreme in KapacitetService.vsVremena) {
      final maxMesta = kapacitet['VS']?[vreme] ?? 8;
      final zauzeto = _countPutniciZaPolazak(putnici, 'VS', vreme, isoDate);

      result['VS']!.add(SlobodnaMesta(
        grad: 'VS',
        vreme: vreme,
        maxMesta: maxMesta,
        zauzetaMesta: zauzeto,
        aktivan: true,
      ));
    }

    return result;
  }

  /// Proveri da li ima slobodnih mesta za određeni polazak
  static Future<bool> imaSlobodnihMesta(String grad, String vreme, {String? datum}) async {
    final slobodna = await getSlobodnaMesta(datum: datum);
    final lista = slobodna[grad.toUpperCase()];
    if (lista == null) return false;

    for (final s in lista) {
      if (s.vreme == vreme) {
        return !s.jePuno;
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
  /// Tipovi 'radnik' i 'dnevni' nemaju ograničenja.
  static Future<Map<String, dynamic>> promeniVremePutnika({
    required String putnikId,
    required String novoVreme,
    required String grad, // 'BC' ili 'VS'
    required String dan, // 'pon', 'uto', itd.
    bool zaCeluNedelju = false,
  }) async {
    try {
      final sada = DateTime.now();
      final danas = sada.toIso8601String().split('T')[0];
      final danasDan = _isoDateToDayAbbr(danas);
      final jeZaDanas = dan.toLowerCase() == danasDan.toLowerCase();

      // Dohvati tip putnika
      final putnikResponse = await _supabase
          .from('registrovani_putnici')
          .select('id, putnik_ime, tip, polasci_po_danu')
          .eq('id', putnikId)
          .maybeSingle();

      if (putnikResponse == null) {
        return {'success': false, 'message': 'Putnik nije pronađen'};
      }

      final tipPutnika = (putnikResponse['tip'] as String?)?.toLowerCase() ?? 'radnik';

      // ═══════════════════════════════════════════════════════════════
      // 🎓 OGRANIČENJA ZA UČENIKE
      // ═══════════════════════════════════════════════════════════════
      if (tipPutnika == 'ucenik' && !zaCeluNedelju) {
        // Proveri da li je pre 16h
        if (sada.hour >= 16) {
          return {
            'success': false,
            'message': 'Promene su dozvoljene samo do 16:00h',
          };
        }

        // Brojač promena za ciljni dan
        final brojPromena = await _brojPromenaZaDan(putnikId, danas, dan);

        if (jeZaDanas) {
          // Za DANAŠNJI dan: max 1 promena
          if (brojPromena >= 1) {
            return {
              'success': false,
              'message': 'Za današnji dan možete promeniti vreme samo jednom.',
            };
          }
        } else {
          // Za BUDUĆE dane: max 3 promene
          if (brojPromena >= 3) {
            return {
              'success': false,
              'message': 'Za $dan ste već napravili 3 promene danas.',
            };
          }
        }
      }

      // Proveri da li ima slobodnih mesta
      final imaMesta = await imaSlobodnihMesta(grad, novoVreme, datum: danas);
      if (!imaMesta) {
        return {
          'success': false,
          'message': 'Nema slobodnih mesta za $novoVreme',
        };
      }

      // Dohvati trenutne polaske
      final polasciRaw = putnikResponse['polasci_po_danu'];
      Map<String, dynamic> polasci = {};

      if (polasciRaw is String) {
        polasci = Map<String, dynamic>.from(jsonDecode(polasciRaw));
      } else if (polasciRaw is Map) {
        polasci = Map<String, dynamic>.from(polasciRaw);
      }

      // Sačuvaj staro vreme za notifikaciju
      final gradKey = grad.toLowerCase() == 'bc' ? 'bc' : 'vs';

      // Ažuriraj vreme
      if (zaCeluNedelju) {
        // Promeni za sve dane
        for (final d in ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned']) {
          if (polasci[d] == null) polasci[d] = {};
          if (polasci[d] is Map) {
            (polasci[d] as Map)[gradKey] = novoVreme;
          }
        }
      } else {
        // Promeni samo za određeni dan
        if (polasci[dan] == null) polasci[dan] = {};
        if (polasci[dan] is Map) {
          (polasci[dan] as Map)[gradKey] = novoVreme;
        }
      }

      // Sačuvaj u bazu
      await _supabase.from('registrovani_putnici').update({'polasci_po_danu': jsonEncode(polasci)}).eq('id', putnikId);

      // Zapiši promenu za učenike (za ograničenje)
      if (tipPutnika == 'ucenik' && !zaCeluNedelju) {
        await _zapisiPromenuVremena(putnikId, danas, dan);
      }

      return {
        'success': true,
        'message': zaCeluNedelju ? 'Vreme promenjeno za celu nedelju na $novoVreme' : 'Vreme promenjeno na $novoVreme',
      };
    } catch (e) {
      return {'success': false, 'message': 'Greška: $e'};
    }
  }

  /// Broji koliko puta je putnik menjao vreme za određeni ciljni dan (danas)
  /// Javna metoda za korišćenje iz drugih ekrana
  static Future<int> brojPromenaZaDan(String putnikId, String ciljniDan) async {
    final danas = DateTime.now().toIso8601String().split('T')[0];
    return _brojPromenaZaDan(putnikId, danas, ciljniDan);
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
  static Future<void> _zapisiPromenuVremena(String putnikId, String datum, String ciljniDan) async {
    try {
      await _supabase.from('promene_vremena_log').insert({
        'putnik_id': putnikId,
        'datum': datum,
        'ciljni_dan': ciljniDan.toLowerCase(),
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Error writing change log
    }
  }
}
