import 'package:supabase_flutter/supabase_flutter.dart';

/// 🔮 PREDIKCIJA SERVICE
/// Predviđa raspored putnika za sledeću nedelju na osnovu istorije
class PredikcijaService {
  static final _supabase = Supabase.instance.client;

  /// Dohvati predikciju za sledeću nedelju
  /// Vraća mapu: { 'pon': { '06:00': [PutnikPredikcija], '14:00': [...] }, ... }
  static Future<Map<String, Map<String, List<PutnikPredikcija>>>> getPredikcijaZaNedelju() async {
    try {
      // 1. Dohvati sve aktivne učenike i radnike (ne dnevne - oni su nepredvidivi)
      final putnici = await _supabase
          .from('registrovani_putnici')
          .select('id, putnik_ime, tip, polasci_po_danu, grad')
          .eq('aktivan', true)
          .eq('obrisan', false)
          .inFilter('tip', ['ucenik', 'radnik']);

      if (putnici.isEmpty) {
        return {};
      }

      // 2. Dohvati voznje_log za poslednjih 8 nedelja (56 dana)
      final pre8Nedelja = DateTime.now().subtract(const Duration(days: 56));
      final voznjeLogs = await _supabase
          .from('voznje_log')
          .select('putnik_id, datum, tip')
          .gte('datum', pre8Nedelja.toIso8601String().split('T')[0])
          .inFilter('tip', ['voznja', 'otkazivanje']);

      // 3. Grupiši vožnje po putniku i danu u nedelji
      final Map<String, Map<int, List<String>>> istorijaPoPutniku = {};
      // putnik_id -> weekday (1-7) -> lista vremena kada se vozio

      for (final log in voznjeLogs) {
        final putnikId = log['putnik_id'] as String?;
        final datumStr = log['datum'] as String?;
        final tip = log['tip'] as String?;

        if (putnikId == null || datumStr == null || tip != 'voznja') continue;

        final datum = DateTime.tryParse(datumStr);
        if (datum == null) continue;

        istorijaPoPutniku.putIfAbsent(putnikId, () => {});
        istorijaPoPutniku[putnikId]!.putIfAbsent(datum.weekday, () => []);
        istorijaPoPutniku[putnikId]![datum.weekday]!.add(datumStr);
      }

      // 4. Izračunaj predikciju za svakog putnika
      final Map<String, Map<String, List<PutnikPredikcija>>> rezultat = {
        'pon': {},
        'uto': {},
        'sre': {},
        'cet': {},
        'pet': {},
      };

      final daniMapa = {
        'pon': 1,
        'uto': 2,
        'sre': 3,
        'cet': 4,
        'pet': 5,
      };

      for (final putnik in putnici) {
        final id = putnik['id']?.toString() ?? '';
        final ime = putnik['putnik_ime'] as String? ?? 'Nepoznato';
        final tip = putnik['tip'] as String? ?? '';
        final grad = putnik['grad'] as String? ?? '';

        // Parsiraj polasci_po_danu
        Map<String, dynamic> polasci = {};
        final polasciRaw = putnik['polasci_po_danu'];
        if (polasciRaw is String) {
          try {
            polasci = Map<String, dynamic>.from((polasciRaw.startsWith('{')) ? _parseJson(polasciRaw) : {});
          } catch (_) {}
        } else if (polasciRaw is Map) {
          polasci = Map<String, dynamic>.from(polasciRaw);
        }

        // Za svaki dan izračunaj verovatnoću
        for (final dan in daniMapa.keys) {
          final weekday = daniMapa[dan]!;

          // Trenutno zakazano vreme za taj dan
          String? zakazanoVreme;
          final gradKey = grad.toLowerCase() == 'bc' ? 'bc' : 'vs';

          if (polasci[dan] is Map) {
            final dayData = polasci[dan] as Map;
            final vreme = dayData[gradKey];
            if (vreme != null && vreme != '/' && vreme != '0' && vreme != '') {
              zakazanoVreme = vreme.toString();
            }
          } else if (polasci[dan] is String) {
            final vreme = polasci[dan] as String;
            if (vreme != '/' && vreme != '0' && vreme.isNotEmpty) {
              zakazanoVreme = vreme;
            }
          }

          // Ako nema zakazano vreme, preskoči
          if (zakazanoVreme == null) continue;

          // Izračunaj verovatnoću na osnovu istorije
          final istorija = istorijaPoPutniku[id]?[weekday] ?? [];
          final brojVoznji = istorija.length;

          // Verovatnoća: broj vožnji / 8 nedelja * 100
          // Ako nema istorije, koristi 70% kao default za zakazane
          int verovatnoca;
          if (brojVoznji == 0) {
            verovatnoca = 70; // Default za nove putnike
          } else {
            verovatnoca = ((brojVoznji / 8) * 100).round().clamp(0, 99);
          }

          // Dodaj u rezultat
          rezultat[dan]!.putIfAbsent(zakazanoVreme, () => []);
          rezultat[dan]![zakazanoVreme]!.add(PutnikPredikcija(
            putnikId: id,
            ime: ime,
            tip: tip,
            grad: grad,
            vreme: zakazanoVreme,
            verovatnoca: verovatnoca,
            brojVoznjiU8Nedelja: brojVoznji,
          ));
        }
      }

      // 5. Sortiraj po verovatnoći (najviša prva)
      for (final dan in rezultat.keys) {
        for (final vreme in rezultat[dan]!.keys) {
          rezultat[dan]![vreme]!.sort((a, b) => b.verovatnoca.compareTo(a.verovatnoca));
        }
      }

      return rezultat;
    } catch (e) {
      return {};
    }
  }

  /// Pomoćna funkcija za parsiranje JSON-a
  static Map<String, dynamic> _parseJson(String json) {
    // Jednostavan parser za naš format
    try {
      // Ukloni whitespace
      json = json.trim();
      if (!json.startsWith('{') || !json.endsWith('}')) return {};

      // Koristi dart:convert
      return Map<String, dynamic>.from(Uri.splitQueryString(
          json.substring(1, json.length - 1).replaceAll('"', '').replaceAll(':', '=').replaceAll(',', '&')));
    } catch (_) {
      return {};
    }
  }

  /// Dohvati sumarnu statistiku za sledeću nedelju
  static Future<Map<String, PredikcijaStats>> getStatistikaZaNedelju() async {
    final predikcija = await getPredikcijaZaNedelju();
    final Map<String, PredikcijaStats> stats = {};

    for (final dan in predikcija.keys) {
      int ukupnoPutnika = 0;
      int sigurnihPutnika = 0; // verovatnoća >= 80%
      int neizvesnihPutnika = 0; // verovatnoća 50-79%
      String? najpunijeTermo;
      int maxPutnikaUTerminu = 0;

      for (final vreme in predikcija[dan]!.keys) {
        final putnici = predikcija[dan]![vreme]!;
        ukupnoPutnika += putnici.length;

        for (final p in putnici) {
          if (p.verovatnoca >= 80) {
            sigurnihPutnika++;
          } else if (p.verovatnoca >= 50) {
            neizvesnihPutnika++;
          }
        }

        if (putnici.length > maxPutnikaUTerminu) {
          maxPutnikaUTerminu = putnici.length;
          najpunijeTermo = vreme;
        }
      }

      stats[dan] = PredikcijaStats(
        ukupnoPutnika: ukupnoPutnika,
        sigurnihPutnika: sigurnihPutnika,
        neizvesnihPutnika: neizvesnihPutnika,
        najpunijeVreme: najpunijeTermo,
        maxPutnikaUTerminu: maxPutnikaUTerminu,
      );
    }

    return stats;
  }
}

/// Predikcija za jednog putnika
class PutnikPredikcija {
  final String putnikId;
  final String ime;
  final String tip;
  final String grad;
  final String vreme;
  final int verovatnoca; // 0-100%
  final int brojVoznjiU8Nedelja;

  PutnikPredikcija({
    required this.putnikId,
    required this.ime,
    required this.tip,
    required this.grad,
    required this.vreme,
    required this.verovatnoca,
    required this.brojVoznjiU8Nedelja,
  });

  /// Status emoji na osnovu verovatnoće
  String get statusEmoji {
    if (verovatnoca >= 80) return '✓'; // Siguran
    if (verovatnoca >= 50) return '?'; // Neizvestan
    return '✗'; // Malo verovatno
  }

  /// Boja na osnovu verovatnoće
  String get statusBoja {
    if (verovatnoca >= 80) return 'green';
    if (verovatnoca >= 50) return 'orange';
    return 'red';
  }
}

/// Statistika predikcije za jedan dan
class PredikcijaStats {
  final int ukupnoPutnika;
  final int sigurnihPutnika;
  final int neizvesnihPutnika;
  final String? najpunijeVreme;
  final int maxPutnikaUTerminu;

  PredikcijaStats({
    required this.ukupnoPutnika,
    required this.sigurnihPutnika,
    required this.neizvesnihPutnika,
    required this.najpunijeVreme,
    required this.maxPutnikaUTerminu,
  });

  /// Da li ima potencijalni problem sa kapacitetom (8+ putnika u terminu)
  bool get imaProblemKapaciteta => maxPutnikaUTerminu >= 8;
}
