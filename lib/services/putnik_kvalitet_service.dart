import 'package:supabase_flutter/supabase_flutter.dart';

/// 📊 PUTNIK KVALITET SERVICE
/// Analiza kvaliteta putnika za admina/vlasnika
/// Identifikuje putnike koji zauzimaju mesto ali se retko voze
class PutnikKvalitetService {
  static final _supabase = Supabase.instance.client;

  /// Dohvati analizu kvaliteta za sve putnike određenog tipa
  /// Vraća listu sortiranu po kvalitetu (najgori prvi)
  static Future<List<PutnikKvalitetEntry>> getKvalitetAnaliza({
    required String tipPutnika, // 'ucenik', 'radnik', ili 'svi'
    int minVoznji = 0, // Minimalan broj vožnji za prikaz
  }) async {
    try {
      // 1. Dohvati sve aktivne putnike
      var query = _supabase
          .from('registrovani_putnici')
          .select('id, putnik_ime, tip, created_at')
          .eq('aktivan', true)
          .eq('obrisan', false);

      if (tipPutnika != 'svi') {
        query = query.eq('tip', tipPutnika);
      }

      final putnici = await query;

      if (putnici.isEmpty) {
        return [];
      }

      // 2. Dohvati SVE voznje_log zapise (ne samo tekući mesec)
      final voznjeLogs =
          await _supabase.from('voznje_log').select('putnik_id, tip, datum').inFilter('tip', ['voznja', 'otkazivanje']);

      // 3. Dohvati promene vremena log za praćenje odgovornosti zakazivanja
      final promeneLogs = await _supabase.from('promene_vremena_log').select('putnik_id, sati_unapred');

      // 4. Izračunaj statistiku za svakog putnika
      final Map<String, List<DateTime>> voznjePoPutniku = {};
      final Map<String, int> otkazivanjaPoPutniku = {};
      final Map<String, List<int>> satiUnapredPoPutniku = {};

      for (final log in voznjeLogs) {
        final putnikId = log['putnik_id'] as String?;
        final tip = log['tip'] as String?;
        final datumStr = log['datum'] as String?;
        if (putnikId == null || tip == null || datumStr == null) continue;

        if (tip == 'voznja') {
          final datum = DateTime.tryParse(datumStr);
          if (datum != null) {
            voznjePoPutniku.putIfAbsent(putnikId, () => []);
            voznjePoPutniku[putnikId]!.add(datum);
          }
        } else if (tip == 'otkazivanje') {
          otkazivanjaPoPutniku[putnikId] = (otkazivanjaPoPutniku[putnikId] ?? 0) + 1;
        }
      }

      // Prikupi sate unapred za svakog putnika
      for (final log in promeneLogs) {
        final putnikId = log['putnik_id'] as String?;
        final satiUnapred = log['sati_unapred'] as int?;
        if (putnikId == null || satiUnapred == null) continue;

        satiUnapredPoPutniku.putIfAbsent(putnikId, () => []);
        satiUnapredPoPutniku[putnikId]!.add(satiUnapred);
      }

      // 5. Kreiraj listu sa analizom kvaliteta
      final List<PutnikKvalitetEntry> entries = [];
      final now = DateTime.now();

      for (final putnik in putnici) {
        final id = putnik['id']?.toString() ?? '';
        final ime = putnik['putnik_ime'] as String? ?? 'Nepoznato';
        final tip = putnik['tip'] as String? ?? '';
        final createdAtStr = putnik['created_at'] as String?;

        // Datum registracije
        DateTime registrovan = now;
        if (createdAtStr != null) {
          registrovan = DateTime.tryParse(createdAtStr) ?? now;
        }

        // Koliko meseci je registrovan
        final mesecRegistrovan = _monthsDifference(registrovan, now);
        final meseciBrojac = mesecRegistrovan < 1 ? 1 : mesecRegistrovan; // Minimum 1 mesec

        // Statistika vožnji
        final voznjeList = voznjePoPutniku[id] ?? [];
        final ukupnoVoznji = voznjeList.length;
        final ukupnoOtkazivanja = otkazivanjaPoPutniku[id] ?? 0;

        // Prosečno vožnji mesečno
        final prosecnoMesecno = ukupnoVoznji / meseciBrojac;

        // Vožnje u poslednjih 30 dana
        final pre30Dana = now.subtract(const Duration(days: 30));
        final voznji30Dana = voznjeList.where((d) => d.isAfter(pre30Dana)).length;

        // Uspešnost (procenat vožnji vs otkazivanja)
        final ukupnoAkcija = ukupnoVoznji + ukupnoOtkazivanja;
        final uspesnost = ukupnoAkcija > 0 ? (ukupnoVoznji / ukupnoAkcija * 100).round() : 0;

        // 📊 ODGOVORNOST ZAKAZIVANJA - prosečno sati unapred (SAMO ZA UČENIKE)
        final satiList = satiUnapredPoPutniku[id] ?? [];
        double prosecnoSatiUnapred = 0;
        if (satiList.isNotEmpty) {
          prosecnoSatiUnapred = satiList.reduce((a, b) => a + b) / satiList.length;
        }

        // Odgovornost faktor (0-1) - SAMO ZA UČENIKE
        // 0 sati = 0 (bezobrazno), 24+ sati = 1 (odgovorno)
        // Optimalno: 48+ sati unapred
        final odgovornostFaktor = (prosecnoSatiUnapred / 48.0).clamp(0.0, 1.0);

        // KVALITET SKOR (0-100)
        // Formula zavisi od tipa putnika:
        // - Učenici: 50% aktivnost, 30% uspešnost, 20% odgovornost (zakazivanje unapred)
        // - Radnici/Dnevni: 70% aktivnost, 30% uspešnost (bez odgovornosti)
        final faktorizovanoVoznji = (prosecnoMesecno / 8.0).clamp(0.0, 1.0);
        final faktorizovanaUspesnost = uspesnost / 100.0;

        int kvalitetSkor;
        if (tip == 'ucenik') {
          // Učenici imaju faktor odgovornosti
          kvalitetSkor =
              ((faktorizovanoVoznji * 0.5 + faktorizovanaUspesnost * 0.3 + odgovornostFaktor * 0.2) * 100).round();
        } else {
          // Radnici i dnevni nemaju faktor odgovornosti
          kvalitetSkor = ((faktorizovanoVoznji * 0.7 + faktorizovanaUspesnost * 0.3) * 100).round();
        }

        // Status emoji
        String status;
        if (kvalitetSkor >= 70) {
          status = '🟢'; // Odličan
        } else if (kvalitetSkor >= 40) {
          status = '🟡'; // Srednji
        } else if (kvalitetSkor >= 20) {
          status = '🟠'; // Loš
        } else {
          status = '🔴'; // Kritičan - kandidat za zamenu
        }

        entries.add(PutnikKvalitetEntry(
          putnikId: id,
          ime: ime,
          tip: tip,
          registrovan: registrovan,
          mesecRegistrovan: meseciBrojac,
          ukupnoVoznji: ukupnoVoznji,
          ukupnoOtkazivanja: ukupnoOtkazivanja,
          prosecnoMesecno: prosecnoMesecno,
          voznji30Dana: voznji30Dana,
          uspesnost: uspesnost,
          prosecnoSatiUnapred: prosecnoSatiUnapred,
          kvalitetSkor: kvalitetSkor,
          status: status,
        ));
      }

      // 6. Filtriraj po minimalnom broju vožnji
      final filteredEntries = minVoznji > 0 ? entries.where((e) => e.ukupnoVoznji >= minVoznji).toList() : entries;

      // 7. Sortiraj po kvalitetu (najgori prvi)
      filteredEntries.sort((a, b) => a.kvalitetSkor.compareTo(b.kvalitetSkor));

      return filteredEntries;
    } catch (e) {
      return [];
    }
  }

  /// Dohvati samo "problematične" putnike (kvalitet < 30)
  static Future<List<PutnikKvalitetEntry>> getProblematicniPutnici({
    String tipPutnika = 'ucenik',
    int kvalitetPrag = 30,
    int minVoznji = 0,
  }) async {
    final svi = await getKvalitetAnaliza(tipPutnika: tipPutnika, minVoznji: minVoznji);
    return svi.where((e) => e.kvalitetSkor < kvalitetPrag).toList();
  }

  /// Računa razliku u mesecima između dva datuma
  static int _monthsDifference(DateTime from, DateTime to) {
    return (to.year - from.year) * 12 + to.month - from.month;
  }
}

/// Jedan unos u analizi kvaliteta
class PutnikKvalitetEntry {
  final String putnikId;
  final String ime;
  final String tip;
  final DateTime registrovan;
  final int mesecRegistrovan;
  final int ukupnoVoznji;
  final int ukupnoOtkazivanja;
  final double prosecnoMesecno;
  final int voznji30Dana;
  final int uspesnost; // 0-100%
  final double prosecnoSatiUnapred; // Prosečno sati unapred zakazano
  final int kvalitetSkor; // 0-100
  final String status; // 🟢🟡🟠🔴

  PutnikKvalitetEntry({
    required this.putnikId,
    required this.ime,
    required this.tip,
    required this.registrovan,
    required this.mesecRegistrovan,
    required this.ukupnoVoznji,
    required this.ukupnoOtkazivanja,
    required this.prosecnoMesecno,
    required this.voznji30Dana,
    required this.uspesnost,
    required this.prosecnoSatiUnapred,
    required this.kvalitetSkor,
    required this.status,
  });

  /// Formatirano vreme registracije
  String get registrovanFormatted {
    return '${registrovan.day}.${registrovan.month}.${registrovan.year}';
  }

  /// Prosečno mesečno formatirano
  String get prosecnoMesecnoFormatted {
    return prosecnoMesecno.toStringAsFixed(1);
  }

  /// Prosečno sati unapred formatirano
  String get prosecnoSatiUnapredFormatted {
    if (prosecnoSatiUnapred >= 24) {
      final dani = prosecnoSatiUnapred / 24;
      return '${dani.toStringAsFixed(1)} dana';
    }
    return '${prosecnoSatiUnapred.toStringAsFixed(0)}h';
  }

  /// Odgovornost emoji
  String get odgovornostStatus {
    if (prosecnoSatiUnapred >= 48) return '🟢'; // 2+ dana unapred
    if (prosecnoSatiUnapred >= 24) return '🟡'; // 1+ dan unapred
    if (prosecnoSatiUnapred >= 12) return '🟠'; // 12+ sati
    return '🔴'; // Zadnji minut
  }

  /// Da li je kandidat za zamenu
  bool get kandidatZaZamenu => kvalitetSkor < 20;
}
