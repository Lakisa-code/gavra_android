import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import 'local_notification_service.dart';

/// 👨‍✈️ BEBA DISPEČER (ML Dispatch Autonomous Service)
///
/// Treća beba u porodici. Njen posao je:
/// - Da te zamenjuje u razmišljanju o logistici.
/// - Da sama "oseti" kad se sprema gužva (booking velocity).
/// - Da predlaže prebacivanje putnika (load balancing).
/// - Da vrišti "Tata, tata!" kad vidi da 8 mesta nije dovoljno.

class MLDispatchAutonomousService {
  static SupabaseClient get _supabase => supabase;

  // Interna memorija bebe
  final Map<String, dynamic> _dispatchKnowledge = <String, dynamic>{};
  bool _isActive = false;
  Timer? _velocityTimer;

  // Rezultati analize za UI
  final List<DispatchAdvice> _currentAdvice = <DispatchAdvice>[];

  // Singleton
  static final MLDispatchAutonomousService _instance = MLDispatchAutonomousService._internal();
  factory MLDispatchAutonomousService() => _instance;
  MLDispatchAutonomousService._internal();

  List<DispatchAdvice> get activeAdvice => List<DispatchAdvice>.unmodifiable(_currentAdvice);

  /// 🚀 POKRENI DISPEČERA
  Future<void> start() async {
    if (_isActive) {
      return;
    }
    _isActive = true;
    if (kDebugMode) {
      print('👨‍✈️ [ML Dispatch] Beba Dispečer je budna i posmatra tablu...');
    }

    await _loadHistoricalDemand();
    _startVelocityMonitoring();
    _startIntegrityCheck(); // 🛡️ Nova zaštita "da niko ne bude zaboravljen"
  }

  void _startVelocityMonitoring() {
    // Proverava svaka 2 minuta brzinu popunjavanja
    _velocityTimer = Timer.periodic(const Duration(minutes: 2), (Timer timer) async {
      await _analyzeRealtimeDemand();
    });
  }

  void _startIntegrityCheck() {
    // Svakih 5 minuta beba proverava da li smo nekog zaboravili
    Timer.periodic(const Duration(minutes: 5), (timer) async {
      await _keepPassengersSafe();
    });
  }

  /// 🛡️ PROTECT PASSENGERS FROM BEING FORGOTTEN
  /// Ova metoda samo proverava bazu i "vrišti" ako vidi nešto sumnjivo u pesku.
  Future<void> _keepPassengersSafe() async {
    try {
      final String today = DateTime.now().toIso8601String().split('T')[0];

      // Gledamo sve aktivne zahteve za danas i sutra koji možda nisu procesuirani
      // (Beba samo gleda, ne menja ništa!)
      final dynamic pendingRequests =
          await _supabase.from('seat_requests').select().gte('datum', today).eq('obrisan', false);

      if (pendingRequests is List) {
        // Ako vidimo da ima zahteva a nema ih u logu vožnji ili nekoj kanti
        // Beba podiže zastavicu u Lab-u
        if (pendingRequests.length > 20 && _currentAdvice.every((a) => a.title != 'PREBUKING ALERT')) {
          _currentAdvice.add(DispatchAdvice(
            title: 'PREBUKING ALERT',
            description:
                'Tata, imamo ukupno ${pendingRequests.length} zahteva u sistemu. Proveri da li su svi u kombijima!',
            priority: AdvicePriority.critical,
            action: 'Proveri listu',
          ));
          if (kDebugMode) print('👶 [ML Dispatch] Tata, tata! Gledaj koliko putnika imamo! 📢');
        }
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ [ML Dispatch] Greška u integrity check-u: $e');
    }
  }

  /// 📈 ANALIZA BRZINE REZERVACIJA (Booking Velocity)
  Future<void> _analyzeRealtimeDemand() async {
    try {
      final DateTime now = DateTime.now();
      final DateTime oneHourAgo = now.subtract(const Duration(hours: 1));

      // Gledamo nove zahteve u poslednjih sat vremena
      final dynamic recentRequests =
          await _supabase.from('seat_requests').select().gt('created_at', oneHourAgo.toIso8601String());

      if (recentRequests is List && recentRequests.length >= 5) {
        _triggerAlert('BUĐENJE!',
            'Tata, tata! U zadnjih sat vremena je uletelo ${recentRequests.length} novih putnika. Sprema se gužva!');
      }

      // Provera za sutrašnje polaske
      await _predictTomorrowNeeds();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [ML Dispatch] Greška u analizi brzine: $e');
      }
    }
  }

  /// 🔮 PREDVIĐANJE ZA SUTRA (Potreba za 2 kombija)
  Future<void> _predictTomorrowNeeds() async {
    final DateTime tomorrow = DateTime.now().add(const Duration(days: 1));
    final String dateStr =
        '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';

    // Skeniramo sve polaske za sutra
    final List<String> departures = <String>['05:00', '06:00', '13:00', '14:00', '15:30'];

    _currentAdvice.clear();

    for (final String vreme in departures) {
      // Izbroj putnike (registrovani + novi zahtevi)
      final int count = await _calculateTotalDemand('BC', vreme, dateStr);

      if (count >= 12) {
        _currentAdvice.add(DispatchAdvice(
          title: 'DVA KOMBIJA ZA $vreme',
          description: 'Sutra će u $vreme biti bar $count putnika. Ne možeš jednim kombijem, planiraj drugi odmah!',
          priority: AdvicePriority.critical,
          action: 'Aktiviraj drugi kombi',
        ));
      } else if (count >= 7 && count <= 8) {
        // Balansiranje: Ako je 13h pun, a 14h ima mesta
        await _checkBalancingPossibility('BC', vreme, dateStr, count);
      }
    }
  }

  /// ⚖️ LOAD BALANCING (Prebacivanje putnika)
  Future<void> _checkBalancingPossibility(String grad, String vreme, String datum, int currentCount) async {
    if (vreme == '15:30') {
      final int earlierCount = await _calculateTotalDemand(grad, '14:00', datum);
      if (earlierCount < 5) {
        _currentAdvice.add(DispatchAdvice(
          title: 'PREBACI PUTNIKE (15:30 -> 14:00)',
          description:
              'U 15:30 je skoro puno ($currentCount), a u 14:00 imaš samo $earlierCount putnika. Probaj da nagovoriš dvoje da krenu ranije.',
          priority: AdvicePriority.smart,
          action: 'Nazovi putnike',
        ));
      }
    }
  }

  Future<int> _calculateTotalDemand(String grad, String vreme, String datum) async {
    try {
      // 1. Proveri kapacitet iz baze
      final dynamic capacityData = await _supabase
          .from('kapacitet_polazaka')
          .select('kapacitet, drugi_kombi')
          .eq('grad', grad)
          .eq('vreme', vreme)
          .maybeSingle();

      final int maxCapacity = (capacityData != null && capacityData['kapacitet'] != null)
          ? capacityData['kapacitet'] as int
          : 8; // Default 8 ako ne postoji podatak

      // 2. Izbroj trenutne заhteve
      final dynamic requests = await _supabase
          .from('seat_requests')
          .select('broj_mesta')
          .eq('grad', grad)
          .eq('datum', datum)
          .eq('zeljeno_vreme', vreme);

      int total = 0;
      if (requests is List) {
        for (final dynamic r in requests) {
          if (r is Map) {
            total += (r['broj_mesta'] as int? ?? 1);
          }
        }
      }

      if (total + 4 > maxCapacity) {
        if (kDebugMode) {
          print('⚠️ [ML Dispatch] Kapacitet za $vreme je $maxCapacity, a imamo procenjeno ${total + 4}.');
        }
      }

      // 3. Dodaj procenu stalnih (AI može kasnije da uči ovaj broj)
      // Za sada uzimamo 4 kao konstantu, ali beba će to uskoro sama računati
      return total + 4;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [ML Dispatch] Greška pri računanju tražnje: $e');
      }
      return 4;
    }
  }

  void _triggerAlert(String title, String body) {
    if (kDebugMode) {
      print('🚨 [NOTIFIKACIJA] $title: $body');
    }

    // 🔔 ŠALJI LOKALNU NOTIFIKACIJU TATU DA PROVERI
    try {
      LocalNotificationService.showRealtimeNotification(
        title: 'Beba Dispečer: $title',
        body: body,
        payload: 'ml_lab',
      );
    } catch (e) {
      if (kDebugMode) print('❌ [ML Dispatch] Slanje notifikacije nije uspelo: $e');
    }
  }

  Future<void> _loadHistoricalDemand() async {
    _dispatchKnowledge['last_sync'] = DateTime.now().toIso8601String();
  }

  void stop() {
    _velocityTimer?.cancel();
    _isActive = false;
  }
}

enum AdvicePriority { smart, critical }

class DispatchAdvice {
  final String title;
  final String description;
  final AdvicePriority priority;
  final String action;
  final String? originalStatus; // Šta je trenutno u sistemu
  final String? proposedChange; // Šta beba želi da uradi
  final DateTime timestamp;

  DispatchAdvice({
    required this.title,
    required this.description,
    required this.priority,
    required this.action,
    this.originalStatus,
    this.proposedChange,
  }) : timestamp = DateTime.now();
}
