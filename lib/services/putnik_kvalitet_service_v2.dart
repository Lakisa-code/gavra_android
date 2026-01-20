import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';

/// 📊 PUTNIK KVALITET SERVICE V2
/// Jednostavna analiza kvaliteta putnika sa 5 nivoa boja
/// 🟢 Zelena = Odličan, 🟡 Žuta = Dobar, 🟠 Narandžasta = Srednji, 🔴 Crvena = Loš, ⚫ Crna = Kritičan
class PutnikKvalitetServiceV2 {
  static SupabaseClient get _supabase => supabase;

  /// Dohvati analizu kvaliteta za sve putnike
  static Future<List<PutnikKvalitetV2>> getKvalitetAnaliza({
    required String tipPutnika, // 'ucenik', 'radnik', 'dnevni' ili 'svi'
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
      if (putnici.isEmpty) return [];

      final putnikIds = putnici.map((p) => p['id'].toString()).toList();

      // 2. Dohvati voznje_log (voznja, otkazivanje, uplata)
      final voznjeLogs = await _supabase
          .from('voznje_log')
          .select('putnik_id, tip, datum, created_at, sati_pre_polaska')
          .inFilter('putnik_id', putnikIds);

      // 3. Dohvati promene_vremena_log
      final promeneLogs =
          await _supabase.from('promene_vremena_log').select('putnik_id, created_at').inFilter('putnik_id', putnikIds);

      // 4. Grupiši podatke po putniku
      final Map<String, _PutnikStats> statsMap = {};

      for (final putnik in putnici) {
        final id = putnik['id'].toString();
        statsMap[id] = _PutnikStats();
      }

      // Obradi voznje_log
      for (final log in voznjeLogs) {
        final putnikId = log['putnik_id']?.toString();
        if (putnikId == null || !statsMap.containsKey(putnikId)) continue;

        final tip = log['tip'] as String?;
        final stats = statsMap[putnikId]!;

        if (tip == 'voznja') {
          stats.brojVoznji++;
        } else if (tip == 'otkazivanje') {
          stats.brojOtkazivanja++;
          final satiPre = log['sati_pre_polaska'] as int?;
          if (satiPre != null) {
            stats.satiOtkazivanja.add(satiPre);
          }
        } else if (tip == 'uplata') {
          // Dan u mesecu kad je platio
          final createdAt = DateTime.tryParse(log['created_at']?.toString() ?? '');
          if (createdAt != null) {
            stats.daniPlacanja.add(createdAt.day);
          }
        }
      }

      // Obradi promene_vremena_log
      for (final log in promeneLogs) {
        final putnikId = log['putnik_id']?.toString();
        if (putnikId == null || !statsMap.containsKey(putnikId)) continue;

        statsMap[putnikId]!.brojPromenaVremena++;

        // Izvuci sat zakazivanja
        final createdAt = DateTime.tryParse(log['created_at']?.toString() ?? '');
        if (createdAt != null) {
          statsMap[putnikId]!.satiZakazivanja.add(createdAt.hour);
        }
      }

      // 5. Kreiraj rezultate
      final List<PutnikKvalitetV2> rezultati = [];

      for (final putnik in putnici) {
        final id = putnik['id'].toString();
        final ime = putnik['putnik_ime'] as String? ?? 'Nepoznato';
        final tip = putnik['tip'] as String? ?? '';
        final stats = statsMap[id]!;

        // Izračunaj skorove (1-5, 1=najbolje)
        final skorVoznji = _skorVoznji(stats.brojVoznji);
        final skorOtkazivanja = _skorOtkazivanja(stats.brojOtkazivanja, stats.brojVoznji);
        final skorPromena = _skorPromena(stats.brojPromenaVremena, stats.brojVoznji);
        final skorPlacanja = _skorPlacanja(stats.daniPlacanja);
        final skorZakazivanja = _skorZakazivanja(stats.satiZakazivanja);

        // Prosečni skor
        final prosek = (skorVoznji + skorOtkazivanja + skorPromena + skorPlacanja + skorZakazivanja) / 5;

        rezultati.add(PutnikKvalitetV2(
          putnikId: id,
          ime: ime,
          tip: tip,
          brojVoznji: stats.brojVoznji,
          brojOtkazivanja: stats.brojOtkazivanja,
          brojPromenaVremena: stats.brojPromenaVremena,
          prosecniDanPlacanja: stats.daniPlacanja.isEmpty
              ? 0
              : (stats.daniPlacanja.reduce((a, b) => a + b) / stats.daniPlacanja.length).round(),
          prosecniSatZakazivanja: stats.satiZakazivanja.isEmpty
              ? 0
              : (stats.satiZakazivanja.reduce((a, b) => a + b) / stats.satiZakazivanja.length).round(),
          skorVoznji: skorVoznji,
          skorOtkazivanja: skorOtkazivanja,
          skorPromena: skorPromena,
          skorPlacanja: skorPlacanja,
          skorZakazivanja: skorZakazivanja,
          ukupniSkor: prosek,
        ));
      }

      // Sortiraj po ukupnom skoru (najbolji gore, loši dole)
      rezultati.sort((a, b) => a.ukupniSkor.compareTo(b.ukupniSkor));

      return rezultati;
    } catch (e) {
      debugPrint('Greška pri dohvatanju kvaliteta: $e');
      return [];
    }
  }

  // === SKOROVI (1=najbolje, 5=najgore) ===

  /// Vožnji mesečno: 20=1, 16-19=2, 12-15=3, 8-11=4, <8=5
  static int _skorVoznji(int broj) {
    if (broj >= 20) return 1;
    if (broj >= 16) return 2;
    if (broj >= 12) return 3;
    if (broj >= 8) return 4;
    return 5;
  }

  /// Otkazivanja: 0%=1, 1-10%=2, 11-20%=3, 21-30%=4, >30%=5
  static int _skorOtkazivanja(int otkazivanja, int voznji) {
    if (voznji == 0) return 3; // Neutralno ako nema vožnji
    final procenat = (otkazivanja / (voznji + otkazivanja)) * 100;
    if (procenat == 0) return 1;
    if (procenat <= 10) return 2;
    if (procenat <= 20) return 3;
    if (procenat <= 30) return 4;
    return 5;
  }

  /// Promene vremena: 0%=1, 1-10%=2, 11-20%=3, 21-30%=4, >30%=5
  static int _skorPromena(int promene, int voznji) {
    if (voznji == 0) return 3; // Neutralno
    final procenat = (promene / voznji) * 100;
    if (procenat == 0) return 1;
    if (procenat <= 10) return 2;
    if (procenat <= 20) return 3;
    if (procenat <= 30) return 4;
    return 5;
  }

  /// Dan plaćanja: 1-10=1, 11-15=2, 16-20=3, 21-30=4, >30=5
  static int _skorPlacanja(List<int> dani) {
    if (dani.isEmpty) return 3; // Neutralno ako nema podataka
    final prosek = dani.reduce((a, b) => a + b) / dani.length;
    if (prosek <= 10) return 1;
    if (prosek <= 15) return 2;
    if (prosek <= 20) return 3;
    if (prosek <= 30) return 4;
    return 5;
  }

  /// Sat zakazivanja (deadline 16h): <12h=1, 12-13=2, 13-14=3, 14-15=4, 15-16=5
  static int _skorZakazivanja(List<int> sati) {
    if (sati.isEmpty) return 3; // Neutralno
    final prosek = sati.reduce((a, b) => a + b) / sati.length;
    if (prosek < 12) return 1;
    if (prosek < 13) return 2;
    if (prosek < 14) return 3;
    if (prosek < 15) return 4;
    return 5;
  }
}

/// Pomoćna klasa za skupljanje statistike
class _PutnikStats {
  int brojVoznji = 0;
  int brojOtkazivanja = 0;
  int brojPromenaVremena = 0;
  List<int> daniPlacanja = [];
  List<int> satiZakazivanja = [];
  List<int> satiOtkazivanja = [];
}

/// Rezultat analize kvaliteta putnika
class PutnikKvalitetV2 {
  final String putnikId;
  final String ime;
  final String tip;

  // Sirovi podaci
  final int brojVoznji;
  final int brojOtkazivanja;
  final int brojPromenaVremena;
  final int prosecniDanPlacanja;
  final int prosecniSatZakazivanja;

  // Skorovi (1-5)
  final int skorVoznji;
  final int skorOtkazivanja;
  final int skorPromena;
  final int skorPlacanja;
  final int skorZakazivanja;
  final double ukupniSkor;

  PutnikKvalitetV2({
    required this.putnikId,
    required this.ime,
    required this.tip,
    required this.brojVoznji,
    required this.brojOtkazivanja,
    required this.brojPromenaVremena,
    required this.prosecniDanPlacanja,
    required this.prosecniSatZakazivanja,
    required this.skorVoznji,
    required this.skorOtkazivanja,
    required this.skorPromena,
    required this.skorPlacanja,
    required this.skorZakazivanja,
    required this.ukupniSkor,
  });

  /// Boja na osnovu ukupnog skora
  /// 1.0-1.8 = Zelena, 1.9-2.6 = Žuta, 2.7-3.4 = Narandžasta, 3.5-4.2 = Crvena, 4.3-5.0 = Crna
  Color get boja {
    if (ukupniSkor <= 1.8) return Colors.green;
    if (ukupniSkor <= 2.6) return Colors.yellow.shade700;
    if (ukupniSkor <= 3.4) return Colors.orange;
    if (ukupniSkor <= 4.2) return Colors.red;
    return Colors.grey.shade900; // Crna
  }

  /// Emoji boja
  String get bojaEmoji {
    if (ukupniSkor <= 1.8) return '🟢';
    if (ukupniSkor <= 2.6) return '🟡';
    if (ukupniSkor <= 3.4) return '🟠';
    if (ukupniSkor <= 4.2) return '🔴';
    return '⚫';
  }

  /// Opis nivoa
  String get nivoOpis {
    if (ukupniSkor <= 1.8) return 'Odličan';
    if (ukupniSkor <= 2.6) return 'Dobar';
    if (ukupniSkor <= 3.4) return 'Srednji';
    if (ukupniSkor <= 4.2) return 'Loš';
    return 'Kritičan';
  }
}
