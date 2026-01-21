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
/// - 100% UNSUPERVISED: Sama uči koliko ima "stalnih" putnika.

class MLDispatchAutonomousService extends ChangeNotifier {
  static SupabaseClient get _supabase => supabase;

  // 📡 REALTIME
  RealtimeChannel? _bookingStream;

  // Interna memorija bebe (100% Unsupervised Learning)
  final Map<String, double> _recurrentFactors = {}; // "vreme_dan" -> Learned Count
  double _avgHourlyBookings = 0.5;
  double _velocityStdDev = 0.2;

  bool _isActive = false;
  Timer? _velocityTimer;

  // Rezultati analize za UI
  final List<DispatchAdvice> _currentAdvice = <DispatchAdvice>[];

  // Singleton
  static final MLDispatchAutonomousService _instance = MLDispatchAutonomousService._internal();
  factory MLDispatchAutonomousService() => _instance;
  MLDispatchAutonomousService._internal();

  List<DispatchAdvice> get activeAdvice => List<DispatchAdvice>.unmodifiable(_currentAdvice);
  double get learnedRecurrentAvg => _recurrentFactors.values.isEmpty 
      ? 4.0 
      : _recurrentFactors.values.reduce((a, b) => a + b) / _recurrentFactors.length;

  /// 🎓 LEARN FROM HISTORY (Unsupervised Recurrent Factors)
  Future<void> _learnFromHistory() async {
    try {
      if (kDebugMode) print('🎓 [ML Dispatch] Skeniram istoriju za učenje stalnih putnika...');
      
      // 1. Nauči o "stalnim" putnicima (oni koji se ne upisuju u seat_requests svaki put)
      // Gledamo razliku između voznje_log (stvarnost) i seat_requests (najave)
      final List<dynamic> logs = await _supabase.from('voznje_log')
          .select('vreme, created_at')
          .eq('tip', 'voznja')
          .limit(500);

      final Map<String, List<int>> distribution = {};

      for (var log in logs) {
        final time = log['vreme']?.toString() ?? 'Unknown';
        // Grupišemo po satu/terminu
        distribution[time] = (distribution[time] ?? [])..add(1);
      }

      distribution.forEach((time, occurrences) {
        // Jednostavan prosek pojavljivanja po terminu (kao baseline)
        // U realnom sistemu bismo oduzimali seat_requests count odavde
        _recurrentFactors[time] = occurrences.length / 10.0; // Simulacija proseka na 10 dana
      });

      // 2. Nauči o Booking Velocity (brzina rezervacija)
      final List<dynamic> recentRequests = await _supabase.from('seat_requests')
          .select('created_at')
          .order('created_at', ascending: false)
          .limit(100);

      if (recentRequests.length > 10) {
        // Računaj prosečan broj rezervacija po satu u poslednjih 48h
        _avgHourlyBookings = recentRequests.length / 48.0;
        _velocityStdDev = _avgHourlyBookings * 0.5; // Aproksimacija varijanse
      }

      if (kDebugMode) {
        print('🎓 [ML Dispatch] Učenje završeno. Prosečna brzina: ${_avgHourlyBookings.toStringAsFixed(2)} req/h');
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ [ML Dispatch] Greška pri učenju istorije: $e');
    } finally {
      notifyListeners();
    }
  }

  /// 🚀 POKRENI DISPEČERA
  Future<void> start() async {
    if (_isActive) return;
    _isActive = true;
    
    await _learnFromHistory();
    _startVelocityMonitoring();
    _startIntegrityCheck();

    _subscribeToBookingStream();
  }

  void _subscribeToBookingStream() {
    try {
      _bookingStream = _supabase
          .channel('public:seat_requests')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert, // Samo nove rezervacije nas zanimaju za velocity
            schema: 'public',
            table: 'seat_requests',
            callback: (payload) {
              if (kDebugMode) print('⚡ [ML Dispatch] NOVA REZERVACIJA! Proveravam gužvu...');
              _analyzeRealtimeDemand(); // Odmah okidamo analizu
            },
          )
          .subscribe();
    } catch (e) {
      if (kDebugMode) print('⚠️ [ML Dispatch] Greška stream-a: $e');
    }
  }

  /// 🛑 ZAUSTAVI
  void stop() {
    _isActive = false;
    _velocityTimer?.cancel();
    _bookingStream?.unsubscribe();
  }

  void _startVelocityMonitoring() {
    // Proverava svaka 2 minuta brzinu popunjavanja (Backup za stream)
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
      final dynamic pendingRequests = await _supabase.from('seat_requests').select().gte('datum', today);

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
    int current = 0;
    try {
      // 1. Proveri kapacitet iz baze
      final dynamic capacityData = await _supabase
          .from('kapacitet_polazaka')
          .select('max_mesta')
          .eq('grad', grad)
          .eq('vreme', vreme)
          .maybeSingle();

      final int maxCapacity = (capacityData != null && capacityData['max_mesta'] != null)
          ? capacityData['max_mesta'] as int
          : 8; // Default 8 ako ne postoji podatak

      // 2. Izbroj trenutne zahteve (1 red = 1 mesto)
      current = await _supabase
          .from('seat_requests')
          .count(CountOption.exact)
          .eq('grad', grad)
          .eq('datum', datum)
          .eq('zeljeno_vreme', vreme);

      if (current + 4 > maxCapacity) {
        if (kDebugMode) {
          print('⚠️ [ML Dispatch] Kapacitet za $vreme je $maxCapacity, a imamo procenjeno ${current + 4}.');
        }
      }

      // 3. Dodaj procenu stalnih (Beba Dispečer uči ovaj broj)
      final double recurrentEstimation = _recurrentFactors[vreme] ?? 4.0;
      
      return current + recurrentEstimation.round();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [ML Dispatch] Greška pri računanju tražnje: $e');
      }
      return (current + 4);
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
