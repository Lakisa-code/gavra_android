import 'kapacitet_service.dart';
import 'seat_request_service.dart';

/// 🚐 SMART SEAT OPTIMIZATION SERVICE
/// Algoritam za optimizaciju rasporeda fleksibilnih putnika
/// Cilj: Minimizovati broj kombija uz maksimalnu popunjenost
/// Kreiran: 11. januar 2026.

/// Predlog preraspodele putnika
class OptimizationSuggestion {
  OptimizationSuggestion({
    required this.requestId,
    required this.putnikIme,
    required this.originalnoVreme,
    required this.predlozenoVreme,
    required this.razlog,
  });

  final String requestId;
  final String? putnikIme;
  final String originalnoVreme;
  final String predlozenoVreme;
  final String razlog;

  @override
  String toString() {
    return '$putnikIme: $originalnoVreme → $predlozenoVreme ($razlog)';
  }
}

/// Rezultat optimizacije
class OptimizationResult {
  OptimizationResult({
    required this.grad,
    required this.datum,
    required this.suggestions,
    required this.preOptimizacije,
    required this.posleOptimizacije,
    required this.ustedaKombija,
  });

  final String grad;
  final DateTime datum;
  final List<OptimizationSuggestion> suggestions;
  final Map<String, TerminStats> preOptimizacije;
  final Map<String, TerminStats> posleOptimizacije;
  final int ustedaKombija;

  /// Da li ima predloga za optimizaciju
  bool get imaPredloga => suggestions.isNotEmpty;

  /// Ukupan broj predloženih preraspodela
  int get brojPreraspodela => suggestions.length;
}

/// Statistike za jedan termin
class TerminStats {
  TerminStats({
    required this.vreme,
    required this.maxMesta,
    required this.fiksniPutnici,
    required this.fleksibilniPutnici,
    required this.ukupno,
  });

  final String vreme;
  final int maxMesta;
  final int fiksniPutnici;
  final int fleksibilniPutnici;
  final int ukupno;

  /// Broj potrebnih kombija (8 mesta po kombiju)
  int get brojKombija => ukupno > 0 ? ((ukupno - 1) ~/ 8) + 1 : 0;

  /// Slobodna mesta do punog kombija
  int get slobodnoDoPopune {
    if (ukupno == 0) return 8;
    final popunjeniKombiji = brojKombija;
    final kapacitetKombija = popunjeniKombiji * 8;
    return kapacitetKombija - ukupno;
  }

  /// Da li je termin "nepopunjen" (ima puno praznih mesta u kombiju)
  bool get isNepopunjen => slobodnoDoPopune >= 4;

  /// Da li je termin "prepunjen" (prelazi kapacitet)
  bool get isPrepunjen => ukupno > maxMesta;
}

/// 🎯 SEAT OPTIMIZATION SERVICE
class SeatOptimizationService {
  // ============================================================
  // 📊 ANALIZA TRENUTNOG STANJA
  // ============================================================

  /// Analiziraj trenutno stanje za dan
  static Future<Map<String, TerminStats>> analyzeCurrentState({
    required String grad,
    required DateTime datum,
  }) async {
    final stats = <String, TerminStats>{};

    try {
      // Dohvati sve kapacitete
      final kapacitet = await KapacitetService.getKapacitet();
      final vremena = kapacitet[grad] ?? {};

      // Dohvati sve odobrene zahteve
      final requests = await SeatRequestService.getRequestsForDate(
        grad: grad,
        datum: datum,
        status: SeatRequestStatus.approved,
      );

      // Za svako vreme
      for (final entry in vremena.entries) {
        final vreme = entry.key;
        final maxMesta = entry.value;

        // Broj fiksnih putnika
        final fiksni = await SeatRequestService.getBrojFiksnihPutnika(
          grad: grad,
          datum: datum,
          vreme: vreme,
        );

        // Broj fleksibilnih (odobrenih zahteva za to vreme)
        final fleksibilni = requests.where((r) {
          final finalVreme = r.dodeljenoVreme ?? r.zeljenoVreme;
          return _normalizeTime(finalVreme) == _normalizeTime(vreme);
        }).length;

        stats[vreme] = TerminStats(
          vreme: vreme,
          maxMesta: maxMesta,
          fiksniPutnici: fiksni,
          fleksibilniPutnici: fleksibilni,
          ukupno: fiksni + fleksibilni,
        );
      }
    } catch (e) {
      print('❌ [SeatOptimization] Greška pri analizi: $e');
    }

    return stats;
  }

  /// Izračunaj ukupan broj potrebnih kombija
  static int calculateTotalKombija(Map<String, TerminStats> stats) {
    return stats.values.fold(0, (sum, s) => sum + s.brojKombija);
  }

  // ============================================================
  // 🎯 ALGORITAM OPTIMIZACIJE
  // ============================================================

  /// Optimizuj raspored - predloži preraspodele
  static Future<OptimizationResult> optimize({
    required String grad,
    required DateTime datum,
  }) async {
    final suggestions = <OptimizationSuggestion>[];

    // 1. Analiziraj trenutno stanje
    final preStats = await analyzeCurrentState(grad: grad, datum: datum);
    final preKombija = calculateTotalKombija(preStats);

    // 2. Dohvati sve PENDING i APPROVED fleksibilne zahteve
    final allRequests = await SeatRequestService.getRequestsForDate(
      grad: grad,
      datum: datum,
    );

    // Filtriraj samo one koji se mogu preraspodeliti
    final movableRequests = allRequests.where((r) =>
        r.status == SeatRequestStatus.approved ||
        r.status == SeatRequestStatus.pending).toList();

    // 3. Simuliraj optimizaciju
    final simulatedStats = Map<String, TerminStats>.from(preStats);
    final simulatedAssignments = <String, String>{}; // requestId -> vreme

    // Inicijalizuj dodele
    for (final req in movableRequests) {
      final vreme = req.dodeljenoVreme ?? req.zeljenoVreme;
      simulatedAssignments[req.id!] = vreme;
    }

    // 4. Pronađi "nepopunjene" termine i "prepunjene" termine
    bool improved = true;
    int iterations = 0;
    const maxIterations = 100;

    while (improved && iterations < maxIterations) {
      improved = false;
      iterations++;

      // Sortiraj termine po "nepopunjenosti" (najviše praznih mesta prvo)
      final sortedTermini = simulatedStats.entries.toList()
        ..sort((a, b) => b.value.slobodnoDoPopune.compareTo(a.value.slobodnoDoPopune));

      for (final terminEntry in sortedTermini) {
        final termin = terminEntry.value;

        // Preskoči ako je prazan ili pun
        if (termin.ukupno == 0 || termin.slobodnoDoPopune == 0) continue;

        // Pronađi termine koji imaju samo 1-2 putnika u poslednjem kombiju
        // i mogu se spojiti sa ovim terminom
        for (final otherEntry in simulatedStats.entries) {
          if (otherEntry.key == terminEntry.key) continue;

          final other = otherEntry.value;
          final otherViskak = other.ukupno % 8; // Koliko "viska" u poslednjem kombiju

          // Ako drugi termin ima 1-3 putnika u poslednjem kombiju
          // i ovaj termin ima dovoljno mesta da ih primi
          if (otherViskak > 0 &&
              otherViskak <= 3 &&
              termin.slobodnoDoPopune >= otherViskak) {
            // Pronađi fleksibilne putnike u drugom terminu koje možemo prebaciti
            final requestsInOther = movableRequests.where((r) {
              final assignedVreme = simulatedAssignments[r.id];
              return _normalizeTime(assignedVreme ?? '') ==
                  _normalizeTime(other.vreme);
            }).toList();

            // Prebaci do otherViskak putnika
            int moved = 0;
            for (final req in requestsInOther) {
              if (moved >= otherViskak) break;
              if (moved >= termin.slobodnoDoPopune) break;

              // Dodaj predlog
              suggestions.add(OptimizationSuggestion(
                requestId: req.id!,
                putnikIme: req.putnikIme,
                originalnoVreme: other.vreme,
                predlozenoVreme: termin.vreme,
                razlog: 'Popunjava kombi u ${termin.vreme}',
              ));

              simulatedAssignments[req.id!] = termin.vreme;
              moved++;
              improved = true;
            }

            if (improved) break;
          }
        }

        if (improved) break;
      }

      // Rekalkuliši statistike nakon promena
      if (improved) {
        _recalculateStats(
          simulatedStats,
          preStats,
          movableRequests,
          simulatedAssignments,
        );
      }
    }

    // 5. Izračunaj uštedu
    final posleKombija = calculateTotalKombija(simulatedStats);
    final usteda = preKombija - posleKombija;

    return OptimizationResult(
      grad: grad,
      datum: datum,
      suggestions: suggestions,
      preOptimizacije: preStats,
      posleOptimizacije: simulatedStats,
      ustedaKombija: usteda,
    );
  }

  /// Rekalkuliši statistike nakon simuliranih promena
  static void _recalculateStats(
    Map<String, TerminStats> stats,
    Map<String, TerminStats> originalStats,
    List<SeatRequest> requests,
    Map<String, String> assignments,
  ) {
    // Reset fleksibilnih na 0
    for (final key in stats.keys) {
      final original = originalStats[key]!;
      stats[key] = TerminStats(
        vreme: original.vreme,
        maxMesta: original.maxMesta,
        fiksniPutnici: original.fiksniPutnici,
        fleksibilniPutnici: 0,
        ukupno: original.fiksniPutnici,
      );
    }

    // Dodaj fleksibilne prema novim dodelama
    for (final entry in assignments.entries) {
      final vreme = _normalizeTime(entry.value);
      if (stats.containsKey(vreme)) {
        final current = stats[vreme]!;
        stats[vreme] = TerminStats(
          vreme: current.vreme,
          maxMesta: current.maxMesta,
          fiksniPutnici: current.fiksniPutnici,
          fleksibilniPutnici: current.fleksibilniPutnici + 1,
          ukupno: current.ukupno + 1,
        );
      }
    }
  }

  // ============================================================
  // 🔧 PRIMENA OPTIMIZACIJE
  // ============================================================

  /// Primeni predloženu optimizaciju (ažuriraj zahteve u bazi)
  static Future<bool> applyOptimization(OptimizationResult result) async {
    try {
      for (final suggestion in result.suggestions) {
        await SeatRequestService.updateRequestStatus(
          requestId: suggestion.requestId,
          status: SeatRequestStatus.approved,
          dodeljenoVreme: suggestion.predlozenoVreme,
        );
      }
      return true;
    } catch (e) {
      print('❌ [SeatOptimization] Greška pri primeni optimizacije: $e');
      return false;
    }
  }

  // ============================================================
  // 📈 IZVEŠTAJI
  // ============================================================

  /// Generiši tekstualni izveštaj optimizacije
  static String generateReport(OptimizationResult result) {
    final buffer = StringBuffer();

    buffer.writeln('═══════════════════════════════════════════');
    buffer.writeln('🚐 SMART SEAT OPTIMIZATION - IZVEŠTAJ');
    buffer.writeln('═══════════════════════════════════════════');
    buffer.writeln('Grad: ${result.grad}');
    buffer.writeln('Datum: ${result.datum.day}.${result.datum.month}.${result.datum.year}');
    buffer.writeln('');

    buffer.writeln('📊 PRE OPTIMIZACIJE:');
    buffer.writeln('───────────────────────────────────────────');
    for (final entry in result.preOptimizacije.entries) {
      final s = entry.value;
      if (s.ukupno > 0) {
        buffer.writeln(
            '  ${s.vreme.padRight(6)} │ ${s.ukupno.toString().padLeft(2)} putnika │ ${s.brojKombija} kombi(ja)');
      }
    }
    final preKombija = calculateTotalKombija(result.preOptimizacije);
    buffer.writeln('  ─────────────────────────────────────────');
    buffer.writeln('  UKUPNO: $preKombija kombija');
    buffer.writeln('');

    if (result.imaPredloga) {
      buffer.writeln('🔄 PREDLOŽENE PRERASPODELE:');
      buffer.writeln('───────────────────────────────────────────');
      for (final s in result.suggestions) {
        buffer.writeln('  • ${s.putnikIme ?? "Putnik"}');
        buffer.writeln('    ${s.originalnoVreme} → ${s.predlozenoVreme}');
        buffer.writeln('    Razlog: ${s.razlog}');
      }
      buffer.writeln('');

      buffer.writeln('📊 POSLE OPTIMIZACIJE:');
      buffer.writeln('───────────────────────────────────────────');
      for (final entry in result.posleOptimizacije.entries) {
        final s = entry.value;
        if (s.ukupno > 0) {
          buffer.writeln(
              '  ${s.vreme.padRight(6)} │ ${s.ukupno.toString().padLeft(2)} putnika │ ${s.brojKombija} kombi(ja)');
        }
      }
      final posleKombija = calculateTotalKombija(result.posleOptimizacije);
      buffer.writeln('  ─────────────────────────────────────────');
      buffer.writeln('  UKUPNO: $posleKombija kombija');
      buffer.writeln('');

      buffer.writeln('✅ UŠTEDA: ${result.ustedaKombija} kombija');
    } else {
      buffer.writeln('✅ Raspored je već optimalan - nema predloga za preraspodelu.');
    }

    buffer.writeln('═══════════════════════════════════════════');

    return buffer.toString();
  }

  // ============================================================
  // 🛠️ HELPER METODE
  // ============================================================

  /// Normalizuj vreme
  static String _normalizeTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return time;

    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }
}
