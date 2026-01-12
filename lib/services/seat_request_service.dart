import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/registrovani_putnik.dart';
import 'kapacitet_service.dart';
import 'putnik_kvalitet_service.dart';
import 'realtime/realtime_manager.dart';
import 'realtime_notification_service.dart';

/// 🚐 SMART SEAT MANAGEMENT
/// Servis za upravljanje zahtevima fleksibilnih putnika za povratne vožnje
/// Kreiran: 11. januar 2026.

/// Status zahteva za mesto
enum SeatRequestStatus {
  pending, // Čeka obradu
  approved, // Odobreno
  confirmed, // Potvrđeno (automatski kad dobije traženo vreme)
  needsChoice, // Putnik treba da izabere alternativu
  waitlist, // Lista čekanja (nema mesta)
  cancelled, // Otkazano od strane putnika
  expired, // Isteklo (prošao termin)
}

/// Helper funkcije za SeatRequestStatus
SeatRequestStatus _statusFromString(String? status) {
  switch (status) {
    case 'pending':
      return SeatRequestStatus.pending;
    case 'approved':
      return SeatRequestStatus.approved;
    case 'confirmed':
      return SeatRequestStatus.confirmed;
    case 'waitlist':
      return SeatRequestStatus.waitlist;
    case 'needs_choice':
      return SeatRequestStatus.needsChoice;
    case 'cancelled':
      return SeatRequestStatus.cancelled;
    case 'expired':
      return SeatRequestStatus.expired;
    default:
      return SeatRequestStatus.pending;
  }
}

String _statusToString(SeatRequestStatus status) {
  switch (status) {
    case SeatRequestStatus.pending:
      return 'pending';
    case SeatRequestStatus.approved:
      return 'approved';
    case SeatRequestStatus.confirmed:
      return 'confirmed';
    case SeatRequestStatus.waitlist:
      return 'waitlist';
    case SeatRequestStatus.needsChoice:
      return 'needs_choice';
    case SeatRequestStatus.cancelled:
      return 'cancelled';
    case SeatRequestStatus.expired:
      return 'expired';
  }
}

/// Model za zahtev mesta
class SeatRequest {
  SeatRequest({
    this.id,
    required this.putnikId,
    required this.grad,
    required this.datum,
    required this.zeljenoVreme,
    this.dodeljenoVreme,
    this.status = SeatRequestStatus.pending,
    this.createdAt,
    this.updatedAt,
    this.processedAt,
    this.alternatives,
    // Dodatna polja iz JOIN-a
    this.putnikIme,
  });

  factory SeatRequest.fromMap(Map<String, dynamic> map) {
    // Dohvati ime iz JOIN-a ili direktno
    String? putnikIme;
    if (map['registrovani_putnici'] != null) {
      putnikIme = (map['registrovani_putnici'] as Map<String, dynamic>)['putnik_ime'] as String?;
    } else {
      putnikIme = map['putnik_ime'] as String?;
    }

    // Parsiraj alternative
    List<String>? alternatives;
    if (map['alternatives'] != null) {
      alternatives = (map['alternatives'] as List).map((e) => e.toString()).toList();
    }

    return SeatRequest(
      id: map['id'] as String?,
      putnikId: map['putnik_id'] as String,
      grad: map['grad'] as String,
      datum: DateTime.parse(map['datum'] as String),
      zeljenoVreme: map['zeljeno_vreme'] as String,
      dodeljenoVreme: map['dodeljeno_vreme'] as String?,
      status: _statusFromString(map['status'] as String?),
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : null,
      processedAt: map['processed_at'] != null ? DateTime.parse(map['processed_at'] as String) : null,
      alternatives: alternatives,
      putnikIme: putnikIme,
    );
  }

  final String? id;
  final String putnikId;
  final String grad; // 'BC' ili 'VS'
  final DateTime datum;
  final String zeljenoVreme;
  final String? dodeljenoVreme;
  final SeatRequestStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? processedAt;
  final List<String>? alternatives; // Alternative koje su ponuđene

  // Dodatna polja iz JOIN-a
  final String? putnikIme;

  /// Da li je zahtev aktivan (može se menjati)
  bool get isActive =>
      status == SeatRequestStatus.pending ||
      status == SeatRequestStatus.waitlist ||
      status == SeatRequestStatus.needsChoice;

  /// Da li je zahtev odobren
  bool get isApproved => status == SeatRequestStatus.approved;

  /// Finalno vreme (dodeljeno ili željeno ako je odobreno direktno)
  String? get finalnoVreme => dodeljenoVreme ?? (isApproved ? zeljenoVreme : null);

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'putnik_id': putnikId,
      'grad': grad,
      'datum': datum.toIso8601String().split('T')[0],
      'zeljeno_vreme': zeljenoVreme,
      'dodeljeno_vreme': dodeljenoVreme,
      'status': _statusToString(status),
      if (processedAt != null) 'processed_at': processedAt!.toIso8601String(),
    };
  }

  SeatRequest copyWith({
    String? id,
    String? putnikId,
    String? grad,
    DateTime? datum,
    String? zeljenoVreme,
    String? dodeljenoVreme,
    SeatRequestStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? processedAt,
    String? putnikIme,
  }) {
    return SeatRequest(
      id: id ?? this.id,
      putnikId: putnikId ?? this.putnikId,
      grad: grad ?? this.grad,
      datum: datum ?? this.datum,
      zeljenoVreme: zeljenoVreme ?? this.zeljenoVreme,
      dodeljenoVreme: dodeljenoVreme ?? this.dodeljenoVreme,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      processedAt: processedAt ?? this.processedAt,
      putnikIme: putnikIme ?? this.putnikIme,
    );
  }
}

/// Rezultat provere dostupnosti mesta
class SeatAvailabilityResult {
  SeatAvailabilityResult({
    required this.vreme,
    required this.maxMesta,
    required this.zauzetoFiksni,
    required this.zauzetoFleksibilni,
    required this.naListiCekanja,
  });

  final String vreme;
  final int maxMesta;
  final int zauzetoFiksni; // Fiksni putnici sa tim vremenom
  final int zauzetoFleksibilni; // Odobreni fleksibilni zahtevi
  final int naListiCekanja; // Na listi čekanja za to vreme

  /// Ukupno zauzeto
  int get ukupnoZauzeto => zauzetoFiksni + zauzetoFleksibilni;

  /// Slobodna mesta
  int get slobodnoMesta => maxMesta - ukupnoZauzeto;

  /// Da li ima slobodnih mesta
  bool get imaMesta => slobodnoMesta > 0;

  /// Procenat popunjenosti (0.0 - 1.0)
  double get popunjenost => maxMesta > 0 ? ukupnoZauzeto / maxMesta : 0.0;

  /// Broj potrebnih kombija (8 mesta po kombiju)
  int get brojKombija => (ukupnoZauzeto / 8).ceil();
}

/// 🤖 Rezultat batch processinga
class BatchProcessingResult {
  BatchProcessingResult({
    required this.batchId,
    required this.processedAt,
    required this.total,
    required this.approved,
    required this.waitlisted,
    required this.details,
    this.error,
  });

  final String batchId;
  final DateTime processedAt;
  final int total;
  final int approved;
  final int waitlisted;
  final List<String> details;
  final String? error;

  bool get hasError => error != null;
  bool get isEmpty => total == 0;

  @override
  String toString() {
    return 'Batch $batchId: $approved odobreno, $waitlisted na čekanju (od $total)';
  }
}

/// 🚐 SEAT REQUEST SERVICE
class SeatRequestService {
  static final _supabase = Supabase.instance.client;

  // ============================================================
  // 📥 CRUD OPERACIJE
  // ============================================================

  // ============================================================
  // ⚙️ BATCH PROCESSING KONFIGURACIJA
  // ============================================================

  /// Da li admin ručno upravlja (ako true, zahtevi čekaju admina)
  /// Default: false = algoritam radi automatski
  static bool _manualModeEnabled = false;

  /// Interval za automatski batch processing (u minutama)
  static int _batchIntervalMinutes = 5;

  /// Timer za automatski batch processing
  static Timer? _batchTimer;

  /// Admin preuzima kontrolu - zahtevi čekaju ručno procesiranje
  static void enableManualMode() {
    _manualModeEnabled = true;
    stopAutoBatchProcessing();
    print('👤 [SeatRequestService] MANUAL MODE: Admin preuzeo kontrolu');
  }

  /// Vrati na automatski režim - algoritam radi sam
  static void enableAutoMode() {
    _manualModeEnabled = false;
    print('🤖 [SeatRequestService] AUTO MODE: Algoritam radi automatski');
  }

  /// Da li je manual mode uključen
  static bool get isManualModeEnabled => _manualModeEnabled;

  /// Postavi interval za batch processing
  static void setBatchInterval(int minutes) {
    _batchIntervalMinutes = minutes;
    print('⏱️ [SeatRequestService] Batch interval: $minutes minuta');
  }

  /// Pokreni automatski batch processing (za pending ako ih ima)
  static void startAutoBatchProcessing({int? intervalMinutes}) {
    stopAutoBatchProcessing();
    final interval = intervalMinutes ?? _batchIntervalMinutes;
    _batchTimer = Timer.periodic(Duration(minutes: interval), (_) async {
      if (!_manualModeEnabled) {
        print('🤖 [SeatRequestService] Auto batch processing...');
        await processPendingBatch();
      }
      // Proveri i pošalji neposlate notifikacije
      await sendPendingNotifications();
    });
    print('▶️ [SeatRequestService] Auto batch started (svakih $interval min)');
  }

  /// Zaustavi automatski batch processing
  static void stopAutoBatchProcessing() {
    _batchTimer?.cancel();
    _batchTimer = null;
    print('⏹️ [SeatRequestService] Auto batch stopped');
  }

  // ============================================================
  // 📥 CRUD OPERACIJE
  // ============================================================

  /// Kreiraj novi zahtev za mesto
  /// Zahtev ide kao PENDING - algoritam optimizuje u pozadini
  /// i dodeljuje termine kad skupi sve zahteve
  static Future<SeatRequest?> createRequest({
    required String putnikId,
    String? putnikIme, // Opciono - koristi se samo za prikaz
    required String grad,
    required DateTime datum,
    required String zeljenoVreme,
    int? priority, // 0=normal, 1=redovan, 2=senior
  }) async {
    try {
      // Izračunaj prioritet ako nije prosleđen
      final calculatedPriority = priority ?? await _calculatePriority(putnikId);

      // Svi zahtevi idu kao PENDING
      // Algoritam optimizuje u pozadini i dodeljuje termine
      print('📥 [SeatRequestService] Novi zahtev: $zeljenoVreme (prioritet: $calculatedPriority)');

      final response = await _supabase
          .from('seat_requests')
          .upsert({
            'putnik_id': putnikId,
            'grad': grad,
            'datum': datum.toIso8601String().split('T')[0],
            'zeljeno_vreme': zeljenoVreme,
            'dodeljeno_vreme': null, // Algoritam će dodeliti
            'status': 'pending',
            'priority': calculatedPriority,
            'processed_at': null,
          }, onConflict: 'putnik_id,grad,datum')
          .select()
          .single();

      // 🤖 Pokreni optimizaciju u pozadini nakon svakog novog zahteva
      _triggerBackgroundOptimization(grad, datum);

      return SeatRequest.fromMap(response);
    } catch (e) {
      print('❌ [SeatRequestService] Greška pri kreiranju zahteva: $e');
      return null;
    }
  }

  /// Pokreni optimizaciju u pozadini (svakih 10 minuta)
  static Timer? _optimizationDebounceTimer;

  static void _triggerBackgroundOptimization(String grad, DateTime datum) {
    // Debounce - čekaj 10 minuta pre pokretanja optimizacije
    // Ovo smanjuje API pozive i skuplja više zahteva odjednom
    _optimizationDebounceTimer?.cancel();
    _optimizationDebounceTimer = Timer(const Duration(minutes: 10), () async {
      print('🤖 [SeatRequestService] Background optimizacija za $grad ${datum.day}.${datum.month}...');
      await runOptimization(grad: grad, datum: datum);
    });
  }

  /// Pokreni optimizaciju i primeni rezultate
  static Future<void> runOptimization({
    required String grad,
    required DateTime datum,
  }) async {
    try {
      // Importuj optimization service
      final result = await _optimizeAndApply(grad: grad, datum: datum);
      print('✅ [SeatRequestService] Optimizacija završena: ${result.approved} odobreno');
    } catch (e) {
      print('❌ [SeatRequestService] Greška pri optimizaciji: $e');
    }
  }

  /// Optimizuj sve pending zahteve i dodeli termine
  static Future<BatchProcessingResult> _optimizeAndApply({
    required String grad,
    required DateTime datum,
  }) async {
    final datumStr = datum.toIso8601String().split('T')[0];
    print('🤖 [Optimizacija] Pokrećem za $grad $datumStr...');

    // 1. Dohvati sve pending zahteve, sortirano po prioritetu
    final pendingResponse = await _supabase
        .from('seat_requests')
        .select('*, registrovani_putnici(putnik_ime)')
        .eq('grad', grad)
        .eq('datum', datumStr)
        .eq('status', 'pending')
        .order('priority', ascending: false)
        .order('created_at', ascending: true);

    final pendingRequests = (pendingResponse as List).map((r) => SeatRequest.fromMap(r)).toList();

    if (pendingRequests.isEmpty) {
      print('  ℹ️ Nema pending zahteva');
      return BatchProcessingResult(
        batchId: 'opt-${DateTime.now().millisecondsSinceEpoch}',
        processedAt: DateTime.now(),
        total: 0,
        approved: 0,
        waitlisted: 0,
        details: [],
      );
    }

    print('  📋 ${pendingRequests.length} pending zahteva');

    // 2. Dohvati kapacitet
    final kapacitet = await KapacitetService.getKapacitet();
    final terminiKapacitet = kapacitet[grad] ?? {};

    // 3. Izračunaj koliko je već zauzeto po terminima (fiksni + već odobreni)
    final zauzetoPoTerminu = <String, int>{};
    for (final vreme in terminiKapacitet.keys) {
      final fiksni = await getBrojFiksnihPutnika(grad: grad, datum: datum, vreme: vreme);
      final odobreni = await getBrojOdobrenihZahteva(grad: grad, datum: datum, vreme: vreme);
      zauzetoPoTerminu[vreme] = fiksni + odobreni;
    }

    // 4. Grupiši zahteve po željenom vremenu
    final zahtevPoTerminu = <String, List<SeatRequest>>{};
    for (final req in pendingRequests) {
      zahtevPoTerminu.putIfAbsent(req.zeljenoVreme, () => []).add(req);
    }

    // 5. OPTIMIZACIJA - Minimizuj broj polazaka
    // Sortiraj termine po broju zahteva (najviše zahteva prvo)
    final sortedTermini = zahtevPoTerminu.keys.toList()
      ..sort((a, b) => (zahtevPoTerminu[b]?.length ?? 0).compareTo(zahtevPoTerminu[a]?.length ?? 0));

    int approved = 0;
    int waitlisted = 0;
    final details = <String>[];

    // Prvo popuni termine koji imaju najviše zahteva
    for (final vreme in sortedTermini) {
      final requests = zahtevPoTerminu[vreme]!;
      final maxMesta = terminiKapacitet[vreme] ?? 16; // Default 2 kombija
      final zauzeto = zauzetoPoTerminu[vreme] ?? 0;
      final slobodno = maxMesta - zauzeto;

      print('  ⏰ $vreme: ${requests.length} zahteva, $slobodno slobodnih od $maxMesta');

      for (int i = 0; i < requests.length; i++) {
        final req = requests[i];

        if (i < slobodno) {
          // Ima mesta - odobri
          await _supabase.from('seat_requests').update({
            'status': 'approved',
            'dodeljeno_vreme': vreme,
            'processed_at': DateTime.now().toIso8601String(),
          }).eq('id', req.id!);

          zauzetoPoTerminu[vreme] = (zauzetoPoTerminu[vreme] ?? 0) + 1;
          approved++;
          details.add('✅ ${req.putnikIme ?? "Putnik"} → $vreme');

          // 🔔 Pošalji notifikaciju putniku
          await _sendApprovalNotification(
            putnikId: req.putnikId,
            putnikIme: req.putnikIme,
            dodeljenoVreme: vreme,
            zeljenoVreme: req.zeljenoVreme,
          );
        } else {
          // Nema mesta - pronađi alternative (raniji i kasniji termin)
          final reqMinute = _timeToMinutes(vreme);

          String? ranijaAlternativa;
          String? kasnijaAlternativa;
          int minRanijaRazlika = 999;
          int minKasnijaRazlika = 999;

          for (final altVreme in terminiKapacitet.keys) {
            if (altVreme == vreme) continue;

            final altMax = terminiKapacitet[altVreme] ?? 16;
            final altZauzeto = zauzetoPoTerminu[altVreme] ?? 0;

            if (altZauzeto < altMax) {
              final altMinute = _timeToMinutes(altVreme);
              final razlika = altMinute - reqMinute;

              if (razlika < 0 && razlika.abs() < minRanijaRazlika) {
                // Raniji termin (npr. 10:00 ako je tražio 11:00)
                minRanijaRazlika = razlika.abs();
                ranijaAlternativa = altVreme;
              } else if (razlika > 0 && razlika < minKasnijaRazlika) {
                // Kasniji termin (npr. 12:00 ako je tražio 11:00)
                minKasnijaRazlika = razlika;
                kasnijaAlternativa = altVreme;
              }
            }
          }

          // Postavi status na needs_choice i sačuvaj alternative
          final alternatives = <String>[];
          if (ranijaAlternativa != null) alternatives.add(ranijaAlternativa);
          if (kasnijaAlternativa != null) alternatives.add(kasnijaAlternativa);

          await _supabase.from('seat_requests').update({
            'status': 'needs_choice',
            'alternatives': alternatives,
            'processed_at': DateTime.now().toIso8601String(),
          }).eq('id', req.id!);

          waitlisted++;
          details.add('🔔 ${req.putnikIme ?? "Putnik"} → izbor: $alternatives ili čekaj $vreme');

          // 🔔 Pošalji notifikaciju putniku sa izborom
          await _sendChoiceNotification(
            putnikId: req.putnikId,
            putnikIme: req.putnikIme,
            zeljenoVreme: vreme,
            ranijaAlternativa: ranijaAlternativa,
            kasnijaAlternativa: kasnijaAlternativa,
            requestId: req.id!,
          );
        }
      }
    }

    print('✅ [Optimizacija] Gotovo: $approved odobreno, $waitlisted waitlist');

    return BatchProcessingResult(
      batchId: 'opt-${DateTime.now().millisecondsSinceEpoch}',
      processedAt: DateTime.now(),
      total: pendingRequests.length,
      approved: approved,
      waitlisted: waitlisted,
      details: details,
    );
  }

  /// Izračunaj prioritet putnika
  /// Kombinacija tipa putnika + kvaliteta
  ///
  /// TIP PUTNIKA (bazni prioritet):
  ///   radnik = 2, ucenik = 1, dnevni = 0
  ///
  /// KVALITET PUTNIKA (bonus):
  ///   zlatni = +2, dobar = +1, obican = 0, problematican = -1
  ///
  /// UKUPNO: 0-4 (max: radnik + zlatni = 4)
  static Future<int> _calculatePriority(String putnikId) async {
    try {
      // Dohvati tip putnika
      final response = await _supabase.from('registrovani_putnici').select('tip').eq('id', putnikId).maybeSingle();

      if (response == null) return 0;

      // 1. Bazni prioritet po tipu
      int bazniPrioritet = 0;
      final tip = (response['tip'] as String?)?.toLowerCase() ?? 'dnevni';
      switch (tip) {
        case 'radnik':
          bazniPrioritet = 2;
          break;
        case 'ucenik':
          bazniPrioritet = 1;
          break;
        case 'dnevni':
        default:
          bazniPrioritet = 0;
      }

      // 2. Bonus po kvalitetu putnika - koristi PutnikKvalitetService
      int kvalitetBonus = 0;
      try {
        final analiza = await PutnikKvalitetService.getKvalitetAnaliza(tipPutnika: 'svi');
        final putnikAnaliza = analiza.where((e) => e.putnikId == putnikId).firstOrNull;

        if (putnikAnaliza != null) {
          final kvalitetSkor = putnikAnaliza.kvalitetSkor;
          // Mapiranje skora (0-100) na kategorije
          if (kvalitetSkor >= 70) {
            kvalitetBonus = 2; // zlatni
          } else if (kvalitetSkor >= 40) {
            kvalitetBonus = 1; // dobar
          } else if (kvalitetSkor >= 20) {
            kvalitetBonus = 0; // obican
          } else {
            kvalitetBonus = -1; // problematican
          }
          print('⭐ [Kvalitet] $tip skor=$kvalitetSkor bonus=$kvalitetBonus');
        }
      } catch (e) {
        print('⚠️ [Kvalitet] Greška pri dohvatanju kvaliteta: $e');
      }

      final ukupniPrioritet = bazniPrioritet + kvalitetBonus;
      print('🎯 [Prioritet] $tip ($bazniPrioritet) + kvalitet ($kvalitetBonus) = $ukupniPrioritet');

      return ukupniPrioritet;
    } catch (e) {
      print('⚠️ [SeatRequestService] Greška pri računanju prioriteta: $e');
      return 0;
    }
  }

  // ============================================================
  // 🤖 BATCH PROCESSING
  // ============================================================

  /// Rezultat batch processinga
  static BatchProcessingResult? _lastBatchResult;
  static BatchProcessingResult? get lastBatchResult => _lastBatchResult;

  /// Procesiraj sve pending zahteve za tekući dan
  /// Sortira po prioritetu i optimalno raspoređuje
  static Future<BatchProcessingResult> processPendingBatch({
    DateTime? specificDate,
    String? specificGrad,
  }) async {
    final batchId = DateTime.now().millisecondsSinceEpoch.toString();
    print('🤖 [BatchProcessing] Započinjem batch $batchId...');

    int approved = 0;
    int waitlisted = 0;
    int total = 0;
    final details = <String>[];

    try {
      // Dohvati datum za obradu (samo tekući dan)
      final dates = specificDate != null ? [specificDate] : [DateTime.now()];

      final gradovi = specificGrad != null ? [specificGrad] : ['VS', 'BC'];

      for (final datum in dates) {
        for (final grad in gradovi) {
          final result = await _processBatchForDateAndGrad(
            datum: datum,
            grad: grad,
            batchId: batchId,
          );

          approved += result.approved;
          waitlisted += result.waitlisted;
          total += result.total;
          if (result.details.isNotEmpty) {
            details.addAll(result.details);
          }
        }
      }

      _lastBatchResult = BatchProcessingResult(
        batchId: batchId,
        processedAt: DateTime.now(),
        total: total,
        approved: approved,
        waitlisted: waitlisted,
        details: details,
      );

      print('✅ [BatchProcessing] Batch $batchId završen: $approved odobreno, $waitlisted na čekanju');
      return _lastBatchResult!;
    } catch (e) {
      print('❌ [BatchProcessing] Greška: $e');
      return BatchProcessingResult(
        batchId: batchId,
        processedAt: DateTime.now(),
        total: 0,
        approved: 0,
        waitlisted: 0,
        details: ['Greška: $e'],
        error: e.toString(),
      );
    }
  }

  /// Procesiraj batch za specifični datum i grad
  static Future<BatchProcessingResult> _processBatchForDateAndGrad({
    required DateTime datum,
    required String grad,
    required String batchId,
  }) async {
    final datumStr = datum.toIso8601String().split('T')[0];
    print('📅 [BatchProcessing] Obrađujem $grad za $datumStr...');

    // Dohvati sve pending zahteve, sortirano po prioritetu (DESC) pa po vremenu kreiranja (ASC)
    final pendingResponse = await _supabase
        .from('seat_requests')
        .select('*, registrovani_putnici(putnik_ime)')
        .eq('grad', grad)
        .eq('datum', datumStr)
        .eq('status', 'pending')
        .order('priority', ascending: false) // Viši prioritet prvi
        .order('created_at', ascending: true); // Stariji zahtevi prvi (FIFO unutar prioriteta)

    final pendingRequests = (pendingResponse as List).map((r) => SeatRequest.fromMap(r)).toList();

    if (pendingRequests.isEmpty) {
      print('  ℹ️ Nema pending zahteva');
      return BatchProcessingResult(
        batchId: batchId,
        processedAt: DateTime.now(),
        total: 0,
        approved: 0,
        waitlisted: 0,
        details: [],
      );
    }

    print('  📋 ${pendingRequests.length} pending zahteva');

    // Grupiši zahteve po željenom vremenu
    final requestsByTime = <String, List<SeatRequest>>{};
    for (final req in pendingRequests) {
      requestsByTime.putIfAbsent(req.zeljenoVreme, () => []).add(req);
    }

    int approved = 0;
    int waitlisted = 0;
    final details = <String>[];

    // Procesiraj svaki termin
    for (final vreme in requestsByTime.keys) {
      final requests = requestsByTime[vreme]!;

      // Proveri dostupnost za ovaj termin
      final availability = await checkAvailability(
        grad: grad,
        datum: datum,
        vreme: vreme,
      );

      final slobodnoMesta = availability?.slobodnoMesta ?? 0;
      print('  ⏰ $vreme: ${requests.length} zahteva, $slobodnoMesta slobodnih mesta');

      // Rasporedi po prioritetu (već sortirano)
      for (int i = 0; i < requests.length; i++) {
        final req = requests[i];
        final priorityLabel = _getPriorityLabel(req);

        if (i < slobodnoMesta) {
          // Ima mesta - odobri
          await _supabase.from('seat_requests').update({
            'status': 'approved',
            'dodeljeno_vreme': vreme,
            'processed_at': DateTime.now().toIso8601String(),
            'batch_id': batchId,
          }).eq('id', req.id!);

          approved++;
          details.add('✅ ${req.putnikIme ?? req.putnikId} → $vreme $priorityLabel');
          print('    ✅ ${req.putnikIme} odobren za $vreme $priorityLabel');
        } else {
          // Nema mesta - probaj alternativu ili stavi na waitlist
          final alternativa = await _findBestAlternative(
            grad: grad,
            datum: datum,
            originalVreme: vreme,
            excludeVremena: [], // Može bilo koji alternativni termin
          );

          if (alternativa != null) {
            // Ima alternativa - odobri sa drugim vremenom
            await _supabase.from('seat_requests').update({
              'status': 'approved',
              'dodeljeno_vreme': alternativa,
              'processed_at': DateTime.now().toIso8601String(),
              'batch_id': batchId,
            }).eq('id', req.id!);

            approved++;
            details.add('✅ ${req.putnikIme ?? req.putnikId} → $alternativa (tražio $vreme) $priorityLabel');
            print('    ✅ ${req.putnikIme} odobren za $alternativa (alternativa) $priorityLabel');
          } else {
            // Nema alternativa - waitlist
            await _supabase.from('seat_requests').update({
              'status': 'waitlist',
              'processed_at': DateTime.now().toIso8601String(),
              'batch_id': batchId,
            }).eq('id', req.id!);

            waitlisted++;
            details.add('⏳ ${req.putnikIme ?? req.putnikId} → lista čekanja (tražio $vreme) $priorityLabel');
            print('    ⏳ ${req.putnikIme} na listi čekanja $priorityLabel');
          }
        }
      }
    }

    return BatchProcessingResult(
      batchId: batchId,
      processedAt: DateTime.now(),
      total: pendingRequests.length,
      approved: approved,
      waitlisted: waitlisted,
      details: details,
    );
  }

  /// Oznaka prioriteta za prikaz
  static String _getPriorityLabel(SeatRequest req) {
    // Moramo dohvatiti prioritet iz baze jer nije u modelu
    // Za sada vraćamo prazan string, može se proširiti
    return '';
  }

  /// Pronađi najbolju alternativu (najbliži termin sa mestom)
  static Future<String?> _findBestAlternative({
    required String grad,
    required DateTime datum,
    required String originalVreme,
    required List<String> excludeVremena,
  }) async {
    // Svi VS termini
    const termini = ['6:00', '7:00', '8:00', '10:00', '11:00', '12:00', '13:00', '14:00', '15:30', '17:00', '19:00'];

    // Parsiraj originalno vreme
    final originalParts = originalVreme.split(':');
    final originalMinutes = int.parse(originalParts[0]) * 60 + int.parse(originalParts[1]);

    // Sortiraj termine po blizini originalnom vremenu
    final sortedTermini = termini.where((t) => !excludeVremena.contains(t)).toList()
      ..sort((a, b) {
        final aParts = a.split(':');
        final bParts = b.split(':');
        final aMin = int.parse(aParts[0]) * 60 + int.parse(aParts[1]);
        final bMin = int.parse(bParts[0]) * 60 + int.parse(bParts[1]);
        return (aMin - originalMinutes).abs().compareTo((bMin - originalMinutes).abs());
      });

    // Pronađi prvi sa slobodnim mestom
    for (final termin in sortedTermini) {
      if (termin == originalVreme) continue; // Preskoči original

      final availability = await checkAvailability(
        grad: grad,
        datum: datum,
        vreme: termin,
      );

      if (availability != null && availability.imaMesta) {
        return termin;
      }
    }

    return null; // Nema alternative
  }

  /// Dohvati zahtev po ID-u
  static Future<SeatRequest?> getRequestById(String id) async {
    try {
      final response = await _supabase
          .from('seat_requests')
          .select('*, registrovani_putnici(putnik_ime)')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return SeatRequest.fromMap(response);
    } catch (e) {
      print('❌ [SeatRequestService] Greška pri dohvatanju zahteva: $e');
      return null;
    }
  }

  /// Dohvati zahtev za putnika za određeni dan i grad
  static Future<SeatRequest?> getRequestForPutnik({
    required String putnikId,
    required String grad,
    required DateTime datum,
  }) async {
    try {
      final response = await _supabase
          .from('seat_requests')
          .select('*, registrovani_putnici(putnik_ime)')
          .eq('putnik_id', putnikId)
          .eq('grad', grad)
          .eq('datum', datum.toIso8601String().split('T')[0])
          .maybeSingle();

      if (response == null) return null;
      return SeatRequest.fromMap(response);
    } catch (e) {
      print('❌ [SeatRequestService] Greška pri dohvatanju zahteva putnika: $e');
      return null;
    }
  }

  /// Alias za getRequestForPutnik - koristi se u widgetu
  static Future<SeatRequest?> getExistingRequest({
    required String putnikId,
    required String grad,
    required DateTime datum,
  }) async {
    return getRequestForPutnik(putnikId: putnikId, grad: grad, datum: datum);
  }

  /// Dohvati sve zahteve za određeni dan i grad
  static Future<List<SeatRequest>> getRequestsForDate({
    required String grad,
    required DateTime datum,
    SeatRequestStatus? status,
  }) async {
    try {
      var query = _supabase
          .from('seat_requests')
          .select('*, registrovani_putnici(putnik_ime)')
          .eq('grad', grad)
          .eq('datum', datum.toIso8601String().split('T')[0]);

      if (status != null) {
        query = query.eq('status', _statusToString(status));
      }

      final response = await query.order('created_at');

      return (response as List).map((map) => SeatRequest.fromMap(map)).toList();
    } catch (e) {
      print('❌ [SeatRequestService] Greška pri dohvatanju zahteva za datum: $e');
      return [];
    }
  }

  /// Dohvati sve zahteve za određeno vreme
  static Future<List<SeatRequest>> getRequestsForTime({
    required String grad,
    required DateTime datum,
    required String vreme,
    SeatRequestStatus? status,
  }) async {
    try {
      var query = _supabase
          .from('seat_requests')
          .select('*, registrovani_putnici(putnik_ime)')
          .eq('grad', grad)
          .eq('datum', datum.toIso8601String().split('T')[0])
          .eq('zeljeno_vreme', vreme);

      if (status != null) {
        query = query.eq('status', _statusToString(status));
      }

      final response = await query.order('created_at');

      return (response as List).map((map) => SeatRequest.fromMap(map)).toList();
    } catch (e) {
      print('❌ [SeatRequestService] Greška pri dohvatanju zahteva za vreme: $e');
      return [];
    }
  }

  /// Ažuriraj status zahteva
  static Future<bool> updateRequestStatus({
    required String requestId,
    required SeatRequestStatus status,
    String? dodeljenoVreme,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': _statusToString(status),
        if (dodeljenoVreme != null) 'dodeljeno_vreme': dodeljenoVreme,
        if (status == SeatRequestStatus.approved ||
            status == SeatRequestStatus.waitlist ||
            status == SeatRequestStatus.confirmed)
          'processed_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('seat_requests').update(updateData).eq('id', requestId);

      // 🔔 Pošalji notifikaciju putniku ako je odobren
      if (status == SeatRequestStatus.approved || status == SeatRequestStatus.confirmed) {
        // Dohvati podatke o zahtevu za notifikaciju
        final request = await _supabase
            .from('seat_requests')
            .select('putnik_id, zeljeno_vreme, dodeljeno_vreme')
            .eq('id', requestId)
            .maybeSingle();

        if (request != null) {
          _sendApprovalNotification(
            putnikId: request['putnik_id'] as String,
            dodeljenoVreme: dodeljenoVreme ?? request['dodeljeno_vreme'] ?? request['zeljeno_vreme'],
            zeljenoVreme: request['zeljeno_vreme'] as String?,
          );
        }
      }

      return true;
    } catch (e) {
      print('❌ [SeatRequestService] Greška pri ažuriranju statusa: $e');
      return false;
    }
  }

  /// Pošalji push notifikaciju putniku da je zahtev odobren
  static Future<void> _sendApprovalNotification({
    required String putnikId,
    String? putnikIme,
    required String dodeljenoVreme,
    String? zeljenoVreme,
  }) async {
    try {
      // Dohvati token za putnika
      final tokens = await _supabase.from('push_tokens').select('token, provider').eq('putnik_id', putnikId);

      if (tokens.isEmpty) {
        print('⚠️ [SeatRequest] Nema tokena za putnika $putnikId');
        return;
      }

      final tokensList = (tokens as List)
          .map((t) => {
                'token': t['token'] as String,
                'provider': (t['provider'] as String?) ?? 'fcm',
              })
          .toList();

      String body;
      if (zeljenoVreme != null && zeljenoVreme != dodeljenoVreme) {
        body = 'Tvoj polazak je u $dodeljenoVreme (tražio/la si $zeljenoVreme). Vidimo se! 🚐';
      } else {
        body = 'Tvoj polazak je u $dodeljenoVreme. Vidimo se! 🚐';
      }

      await RealtimeNotificationService.sendPushNotification(
        title: 'Odobreno! ✅',
        body: body,
        tokens: tokensList,
        data: {'type': 'seat_request_approved', 'vreme': dodeljenoVreme},
      );

      print('🔔 [SeatRequest] Notifikacija poslata: Odobreno za $dodeljenoVreme');
    } catch (e) {
      print('❌ [SeatRequest] Greška pri slanju notifikacije: $e');
    }
  }

  /// Otkaži zahtev
  static Future<bool> cancelRequest(String requestId) async {
    return updateRequestStatus(
      requestId: requestId,
      status: SeatRequestStatus.cancelled,
    );
  }

  /// Obriši zahtev (hard delete)
  static Future<bool> deleteRequest(String requestId) async {
    try {
      await _supabase.from('seat_requests').delete().eq('id', requestId);
      return true;
    } catch (e) {
      print('❌ [SeatRequestService] Greška pri brisanju zahteva: $e');
      return false;
    }
  }

  /// 🔒 Proveri da li putnik ima PENDING zahtev za određeni datum
  /// Vraća zahtev ako postoji, null ako ne
  static Future<SeatRequest?> getPendingRequestForDay({
    required String putnikId,
    required DateTime datum,
  }) async {
    try {
      final response = await _supabase
          .from('seat_requests')
          .select()
          .eq('putnik_id', putnikId)
          .eq('datum', datum.toIso8601String().split('T')[0])
          .eq('status', 'pending')
          .maybeSingle();

      if (response == null) return null;
      return SeatRequest.fromMap(response);
    } catch (e) {
      print('❌ [SeatRequestService] Greška pri proveri pending zahteva: $e');
      return null;
    }
  }

  /// 🔒 Proveri da li putnik ima NEEDSCHOICE zahtev (čeka da izabere alternativu)
  static Future<SeatRequest?> getNeedsChoiceRequestForDay({
    required String putnikId,
    required DateTime datum,
  }) async {
    try {
      final response = await _supabase
          .from('seat_requests')
          .select()
          .eq('putnik_id', putnikId)
          .eq('datum', datum.toIso8601String().split('T')[0])
          .eq('status', 'needs_choice')
          .maybeSingle();

      if (response == null) return null;
      return SeatRequest.fromMap(response);
    } catch (e) {
      print('❌ [SeatRequestService] Greška pri proveri needsChoice zahteva: $e');
      return null;
    }
  }

  /// 🔒 Proveri da li putnik ima aktivni zahtev (pending ili needsChoice)
  /// Ako ima, ne može da menja vreme dok se ne reši
  static Future<({bool locked, String? reason, SeatRequest? request})> isLockedForChanges({
    required String putnikId,
    required DateTime datum,
  }) async {
    // Proveri pending
    final pending = await getPendingRequestForDay(putnikId: putnikId, datum: datum);
    if (pending != null) {
      return (
        locked: true,
        reason: '⏳ Čeka se raspored od algoritma za ${pending.zeljenoVreme}. Sačekaj potvrdu.',
        request: pending,
      );
    }

    // Proveri needsChoice
    final needsChoice = await getNeedsChoiceRequestForDay(putnikId: putnikId, datum: datum);
    if (needsChoice != null) {
      return (
        locked: true,
        reason: '📋 Imaš ponuđene alternative. Izaberi vreme pre nego što možeš da menjaš.',
        request: needsChoice,
      );
    }

    return (locked: false, reason: null, request: null);
  }

  // ============================================================
  // 📊 ANALIZA DOSTUPNOSTI
  // ============================================================

  /// Dohvati broj fiksnih putnika za određeno vreme
  /// (oni koji imaju vreme u polasci_po_danu)
  static Future<int> getBrojFiksnihPutnika({
    required String grad,
    required DateTime datum,
    required String vreme,
  }) async {
    try {
      // Odredi dan u nedelji (pon, uto, sre, cet, pet, sub, ned)
      const dani = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
      final dan = dani[datum.weekday - 1];

      // Odredi ključ za grad (bc ili vs)
      final gradKey = grad.toLowerCase() == 'bc' ? 'bc' : 'vs';

      // Dohvati sve aktivne putnike
      final response = await _supabase
          .from('registrovani_putnici')
          .select('polasci_po_danu')
          .eq('aktivan', true)
          .eq('obrisan', false);

      int count = 0;
      for (final row in response as List) {
        final polasci = row['polasci_po_danu'] as Map<String, dynamic>?;
        if (polasci == null) continue;

        final danData = polasci[dan] as Map<String, dynamic>?;
        if (danData == null) continue;

        final putnikVreme = danData[gradKey] as String?;
        if (putnikVreme != null && _normalizeTime(putnikVreme) == _normalizeTime(vreme)) {
          count++;
        }
      }

      return count;
    } catch (e) {
      print('❌ [SeatRequestService] Greška pri brojanju fiksnih: $e');
      return 0;
    }
  }

  /// Dohvati broj odobrenih fleksibilnih zahteva za vreme
  static Future<int> getBrojOdobrenihZahteva({
    required String grad,
    required DateTime datum,
    required String vreme,
  }) async {
    try {
      final response = await _supabase
          .from('seat_requests')
          .select('id')
          .eq('grad', grad)
          .eq('datum', datum.toIso8601String().split('T')[0])
          .eq('status', 'approved')
          .or('zeljeno_vreme.eq.$vreme,dodeljeno_vreme.eq.$vreme');

      return (response as List).length;
    } catch (e) {
      print('❌ [SeatRequestService] Greška pri brojanju odobrenih: $e');
      return 0;
    }
  }

  /// Dohvati broj na listi čekanja za vreme
  static Future<int> getBrojNaListiCekanja({
    required String grad,
    required DateTime datum,
    required String vreme,
  }) async {
    try {
      final response = await _supabase
          .from('seat_requests')
          .select('id')
          .eq('grad', grad)
          .eq('datum', datum.toIso8601String().split('T')[0])
          .eq('zeljeno_vreme', vreme)
          .eq('status', 'waitlist');

      return (response as List).length;
    } catch (e) {
      print('❌ [SeatRequestService] Greška pri brojanju liste čekanja: $e');
      return 0;
    }
  }

  /// Proveri dostupnost za sve termine u danu
  static Future<Map<String, SeatAvailabilityResult>> getAvailabilityForDate({
    required String grad,
    required DateTime datum,
  }) async {
    final results = <String, SeatAvailabilityResult>{};

    try {
      // Dohvati kapacitete
      final kapacitet = await KapacitetService.getKapacitet();
      final vremena = kapacitet[grad] ?? {};

      // Za svako vreme izračunaj dostupnost
      for (final entry in vremena.entries) {
        final vreme = entry.key;
        final maxMesta = entry.value;

        final fiksni = await getBrojFiksnihPutnika(
          grad: grad,
          datum: datum,
          vreme: vreme,
        );

        final odobreni = await getBrojOdobrenihZahteva(
          grad: grad,
          datum: datum,
          vreme: vreme,
        );

        final naCekanju = await getBrojNaListiCekanja(
          grad: grad,
          datum: datum,
          vreme: vreme,
        );

        results[vreme] = SeatAvailabilityResult(
          vreme: vreme,
          maxMesta: maxMesta,
          zauzetoFiksni: fiksni,
          zauzetoFleksibilni: odobreni,
          naListiCekanja: naCekanju,
        );
      }
    } catch (e) {
      print('❌ [SeatRequestService] Greška pri analizi dostupnosti: $e');
    }

    return results;
  }

  /// Proveri da li ima mesta za određeno vreme
  static Future<SeatAvailabilityResult?> checkAvailability({
    required String grad,
    required DateTime datum,
    required String vreme,
  }) async {
    try {
      // Dohvati max kapacitet
      final kapacitet = await KapacitetService.getKapacitet();
      final maxMesta = kapacitet[grad]?[vreme] ?? 8;

      final fiksni = await getBrojFiksnihPutnika(
        grad: grad,
        datum: datum,
        vreme: vreme,
      );

      final odobreni = await getBrojOdobrenihZahteva(
        grad: grad,
        datum: datum,
        vreme: vreme,
      );

      final naCekanju = await getBrojNaListiCekanja(
        grad: grad,
        datum: datum,
        vreme: vreme,
      );

      return SeatAvailabilityResult(
        vreme: vreme,
        maxMesta: maxMesta,
        zauzetoFiksni: fiksni,
        zauzetoFleksibilni: odobreni,
        naListiCekanja: naCekanju,
      );
    } catch (e) {
      print('❌ [SeatRequestService] Greška pri proveri dostupnosti: $e');
      return null;
    }
  }

  // ============================================================
  // 🎯 PREDLAGANJE ALTERNATIVA
  // ============================================================

  /// Pronađi najbliže slobodne termine
  static Future<List<SeatAvailabilityResult>> findAlternatives({
    required String grad,
    required DateTime datum,
    required String zeljenoVreme,
    int maxAlternativa = 3,
  }) async {
    final alternatives = <SeatAvailabilityResult>[];

    try {
      final availability = await getAvailabilityForDate(
        grad: grad,
        datum: datum,
      );

      // Parsiraj željeno vreme u minute
      final zeljenoMinute = _timeToMinutes(zeljenoVreme);

      // Sortiraj po udaljenosti od željenog vremena
      final sorted = availability.entries.toList()
        ..sort((a, b) {
          final diffA = (_timeToMinutes(a.key) - zeljenoMinute).abs();
          final diffB = (_timeToMinutes(b.key) - zeljenoMinute).abs();
          return diffA.compareTo(diffB);
        });

      // Filtriraj samo one sa slobodnim mestima (bez željenog vremena)
      for (final entry in sorted) {
        if (entry.key != zeljenoVreme && entry.value.imaMesta) {
          alternatives.add(entry.value);
          if (alternatives.length >= maxAlternativa) break;
        }
      }
    } catch (e) {
      print('❌ [SeatRequestService] Greška pri traženju alternativa: $e');
    }

    return alternatives;
  }

  // ============================================================
  // 🔄 REALTIME STREAM
  // ============================================================

  /// Stream zahteva za određeni dan i grad
  static Stream<List<SeatRequest>> streamRequestsForDate({
    required String grad,
    required DateTime datum,
  }) {
    final controller = StreamController<List<SeatRequest>>.broadcast();
    StreamSubscription? subscription;

    // Inicijalno učitavanje
    getRequestsForDate(grad: grad, datum: datum).then((requests) {
      if (!controller.isClosed) {
        controller.add(requests);
      }
    });

    // Realtime subscription
    subscription = RealtimeManager.instance.subscribe('seat_requests').listen((payload) {
      // Proveri da li je promena za naš grad/datum
      final newGrad = payload.newRecord['grad'] as String?;
      final newDatum = payload.newRecord['datum'] as String?;
      final datumStr = datum.toIso8601String().split('T')[0];

      if (newGrad == grad && newDatum == datumStr) {
        // Reload svih zahteva
        getRequestsForDate(grad: grad, datum: datum).then((requests) {
          if (!controller.isClosed) {
            controller.add(requests);
          }
        });
      }
    });

    controller.onCancel = () {
      subscription?.cancel();
    };

    return controller.stream;
  }

  // ============================================================
  // 🛠️ HELPER METODE
  // ============================================================

  /// Normalizuj vreme (npr. "5:00" -> "05:00")
  static String _normalizeTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return time;

    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  /// Konvertuj vreme u minute (za sortiranje)
  static int _timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;

    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;

    return hours * 60 + minutes;
  }

  /// Proveri da li je deadline prošao (10 min pre polaska)
  static bool isDeadlinePassed({
    required DateTime datum,
    required String vreme,
    int deadlineMinutes = 10,
  }) {
    final now = DateTime.now();
    final timeMinutes = _timeToMinutes(vreme);
    final polazakDateTime = DateTime(
      datum.year,
      datum.month,
      datum.day,
      timeMinutes ~/ 60,
      timeMinutes % 60,
    );

    final deadline = polazakDateTime.subtract(Duration(minutes: deadlineMinutes));
    return now.isAfter(deadline);
  }

  /// Dohvati sve fleksibilne putnike za određeni dan
  /// (oni koji nemaju vreme za povratak u polasci_po_danu)
  static Future<List<RegistrovaniPutnik>> getFleksibilniPutnici({
    required String grad,
    required DateTime datum,
  }) async {
    try {
      // Odredi dan u nedelji
      const dani = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
      final dan = dani[datum.weekday - 1];
      final gradKey = grad.toLowerCase() == 'bc' ? 'bc' : 'vs';

      // Dohvati sve aktivne putnike
      final response = await _supabase.from('registrovani_putnici').select().eq('aktivan', true).eq('obrisan', false);

      final fleksibilni = <RegistrovaniPutnik>[];

      for (final row in response as List) {
        final polasci = row['polasci_po_danu'] as Map<String, dynamic>?;

        // Proveri da li ima polazak za suprotni grad (BC->VS znači da mora nazad)
        // i da li NEMA fiksno vreme za povratak
        if (polasci != null) {
          final danData = polasci[dan] as Map<String, dynamic>?;
          if (danData != null) {
            // Suprotni grad - ako ide IZ BC, onda polazak je 'bc', povratak je 'vs'
            final suprotniGrad = gradKey == 'bc' ? 'vs' : 'bc';
            final polazakVreme = danData[suprotniGrad] as String?;
            final povratakVreme = danData[gradKey] as String?;

            // Fleksibilan = ima polazak ALI nema povratak
            if (polazakVreme != null && povratakVreme == null) {
              fleksibilni.add(RegistrovaniPutnik.fromMap(row));
            }
          }
        }
      }

      return fleksibilni;
    } catch (e) {
      print('❌ [SeatRequestService] Greška pri dohvatanju fleksibilnih: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔔 NOTIFIKACIJE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Pošalji notifikaciju sa izborom alternativa
  static Future<void> _sendChoiceNotification({
    required String putnikId,
    String? putnikIme,
    required String zeljenoVreme,
    String? ranijaAlternativa,
    String? kasnijaAlternativa,
    required String requestId,
  }) async {
    try {
      const title = '⚠️ Termin popunjen - izaberi opciju';

      // Napravi tekst sa opcijama
      final opcije = <String>[];
      if (ranijaAlternativa != null) opcije.add(ranijaAlternativa);
      if (kasnijaAlternativa != null) opcije.add(kasnijaAlternativa);

      String body;
      if (opcije.isNotEmpty) {
        body = 'Termin $zeljenoVreme je popunjen. Slobodni: ${opcije.join(" ili ")}';
      } else {
        body = 'Termin $zeljenoVreme je popunjen. Možeš sačekati da se oslobodi.';
      }

      // Dohvati token za putnika
      final tokens = await _supabase.from('push_tokens').select('token, provider').eq('putnik_id', putnikId);

      if (tokens.isEmpty) {
        print('⚠️ [SeatRequest] Nema tokena za putnika $putnikId');
        return;
      }

      final tokensList = (tokens as List)
          .map((t) => {
                'token': t['token'] as String,
                'provider': (t['provider'] as String?) ?? 'fcm',
              })
          .toList();

      await RealtimeNotificationService.sendPushNotification(
        title: title,
        body: body,
        tokens: tokensList,
        data: {
          'type': 'seat_choice',
          'request_id': requestId,
          'zeljeno_vreme': zeljenoVreme,
          'ranija': ranijaAlternativa ?? '',
          'kasnija': kasnijaAlternativa ?? '',
        },
      );

      print('🔔 [SeatRequest] Push poslat: izbor za ${putnikIme ?? putnikId}');
    } catch (e) {
      print('❌ [SeatRequest] Greška pri slanju choice notifikacije: $e');
    }
  }

  /// Putnik bira alternativu ili waitlist
  static Future<bool> chooseAlternative({
    required String requestId,
    required String? izabranoVreme, // null = čekaj originalni termin
  }) async {
    try {
      if (izabranoVreme != null) {
        // Putnik je izabrao alternativni termin
        await _supabase.from('seat_requests').update({
          'status': 'approved',
          'dodeljeno_vreme': izabranoVreme,
          'processed_at': DateTime.now().toIso8601String(),
        }).eq('id', requestId);

        print('✅ [SeatRequest] Putnik izabrao alternativu: $izabranoVreme');
      } else {
        // Putnik želi da čeka originalni termin
        await _supabase.from('seat_requests').update({
          'status': 'waitlist',
          'processed_at': DateTime.now().toIso8601String(),
        }).eq('id', requestId);

        print('⏳ [SeatRequest] Putnik izabrao da čeka originalni termin');
      }

      return true;
    } catch (e) {
      print('❌ [SeatRequest] Greška pri izboru: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🚫 LIMIT PROMENA - Max 1 promena dnevno
  // ═══════════════════════════════════════════════════════════════════════════

  /// Proveri koliko promena je putnik napravio danas
  static Future<int> getChangesCount(String putnikId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      final response = await _supabase
          .from('user_daily_changes')
          .select('changes_count')
          .eq('putnik_id', putnikId)
          .eq('datum', today)
          .maybeSingle();

      return (response?['changes_count'] as int?) ?? 0;
    } catch (e) {
      print('❌ [SeatRequest] Greška pri proveri promena: $e');
      return 0;
    }
  }

  /// Da li putnik može da napravi promenu?
  /// Vraća: (možePromenu, brojPreostalih, poruka)
  static Future<({bool allowed, int remaining, String message})> canMakeChange(String putnikId) async {
    final count = await getChangesCount(putnikId);
    const maxChanges = 1;

    if (count >= maxChanges) {
      return (
        allowed: false,
        remaining: 0,
        message: '🚫 Već ste izvršili promenu danas.\nNije moguće više menjati raspored do sutra.',
      );
    } else if (count == maxChanges - 1) {
      return (
        allowed: true,
        remaining: 0,
        message: '⚠️ Već ste izvršili jednu promenu danas.\nDa li ste sigurni? Ovo je vaša POSLEDNJA promena za danas!',
      );
    } else {
      return (
        allowed: true,
        remaining: maxChanges - count,
        message: '',
      );
    }
  }

  /// Zabeleži promenu za putnika
  static Future<void> recordChange(String putnikId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      await _supabase.rpc('increment_user_changes', params: {
        'p_putnik_id': putnikId,
        'p_datum': today,
      });

      print('📝 [SeatRequest] Zabeležena promena za $putnikId');
    } catch (e) {
      print('❌ [SeatRequest] Greška pri beleženju promene: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔔 NOTIFIKACIJE ZA SEAT REQUESTS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Pošalji sve neposlate notifikacije za seat requests
  /// Ovu funkciju pozovi periodično (npr. svakih 30 sekundi) ili nakon procesiranja
  static Future<void> sendPendingNotifications() async {
    try {
      // Dohvati neposlate notifikacije
      final notifications =
          await _supabase.from('seat_request_notifications').select().eq('sent', false).order('created_at');

      if (notifications.isEmpty) {
        return;
      }

      // ignore: avoid_print
      print('🔔 [SeatRequest] Šaljem ${notifications.length} notifikacija...');

      for (final notif in notifications) {
        final title = notif['title'] as String;
        final body = notif['body'] as String;
        final notifId = notif['id'] as String;
        final putnikId = notif['putnik_id'] as String;

        // Dohvati tokene za ovog putnika
        final tokens = await _supabase.from('push_tokens').select('token, provider').eq('putnik_id', putnikId);

        if (tokens.isEmpty) {
          // Nema tokena za ovog putnika, markiraj kao poslato
          await _supabase
              .from('seat_request_notifications')
              .update({'sent': true, 'sent_at': DateTime.now().toIso8601String()}).eq('id', notifId);
          continue;
        }

        // Pošalji push notifikaciju
        final tokensList = tokens
            .map((t) => {
                  'token': t['token'],
                  'provider': t['provider'] ?? 'fcm',
                })
            .toList();

        final success = await RealtimeNotificationService.sendPushNotification(
          title: title,
          body: body,
          tokens: tokensList,
          data: {'type': 'seat_request_confirmed'},
        );

        // Markiraj kao poslato
        await _supabase
            .from('seat_request_notifications')
            .update({'sent': true, 'sent_at': DateTime.now().toIso8601String()}).eq('id', notifId);

        // ignore: avoid_print
        print('🔔 [SeatRequest] Notifikacija poslata: $title (success=$success)');
      }
    } catch (e) {
      // ignore: avoid_print
      print('❌ [SeatRequest] Greška pri slanju notifikacija: $e');
    }
  }

  /// Pošalji notifikaciju za specifičnog putnika
  static Future<void> sendNotificationToPutnik({
    required String putnikId,
    required String title,
    required String body,
  }) async {
    try {
      // Dohvati token za putnika
      final tokens = await _supabase.from('push_tokens').select('token, provider').eq('putnik_id', putnikId);

      if (tokens.isEmpty) {
        // ignore: avoid_print
        print('⚠️ [SeatRequest] Nema tokena za putnika $putnikId');
        return;
      }

      final tokensList = (tokens as List)
          .map((t) => {
                'token': t['token'] as String,
                'provider': (t['provider'] as String?) ?? 'fcm',
              })
          .toList();

      await RealtimeNotificationService.sendPushNotification(
        title: title,
        body: body,
        tokens: tokensList,
        data: {'type': 'seat_request'},
      );

      // ignore: avoid_print
      print('🔔 [SeatRequest] Notifikacija poslata putniku $putnikId');
    } catch (e) {
      // ignore: avoid_print
      print('❌ [SeatRequest] Greška pri slanju notifikacije: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📊 KVALITET PUTNIKA
  // ═══════════════════════════════════════════════════════════════════════════
  // NAPOMENA: Kvalitet putnika se računa kroz PutnikKvalitetService
  // koji koristi postojeće tabele: voznje_log, promene_vremena_log
  // ═══════════════════════════════════════════════════════════════════════════
}
