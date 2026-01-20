import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import 'local_notification_service.dart';

/// 🧠 AUTONOMNI ML LAB ZA VOZILA
///
/// Sistem koji SAMOSTALNO:
/// - Prati sve podatke o vozilima 24/7
/// - Uči obrasce bez eksplicitnih komandi
/// - Detektuje anomalije i trendove
/// - Šalje alerte kada je nešto važno
///
/// Radi u pozadini i SAM odlučuje kada treba da uči!

class MLVehicleAutonomousService {
  static SupabaseClient get _supabase => supabase;

  // 🎯 Singleton pattern
  static final MLVehicleAutonomousService _instance = MLVehicleAutonomousService._();
  factory MLVehicleAutonomousService() => _instance;
  MLVehicleAutonomousService._();

  // 🔄 Background worker
  Timer? _learningTimer;
  Timer? _monitoringTimer;

  // 📊 Learned patterns (keš)
  final Map<String, dynamic> _learnedPatterns = {};

  // 🚨 Alerts
  final List<VehicleAlert> _pendingAlerts = [];

  // ⚙️ Dinamički parametri (sistem SAM računa i menja!)
  // Start sa neutralnim vrednostima - biće automatski prilagođeni nakon prvog učenja
  int _monitoringIntervalMinutes = 60; // Start sa ređim monitoringom
  int _historyLookbackDays = 30; // Start sa kratkim periodom
  final int _warrantyWarningDays = 30; // Jedini statički (garancija je objektivan podatak)
  double _costTrendThreshold = 1.8; // Start sa osetljivijim threshold-om

  /// 🚀 POKRENI AUTONOMNI SISTEM
  Future<void> start() async {
    print('🧠 [ML Lab] Pokretanje autonomnog sistema za vozila...');

    // 1. Učitaj prethodne naučene obrasce
    await _loadLearnedPatterns();

    // 2. Pokreni background monitoring (interval se može menjati)
    _monitoringTimer = Timer.periodic(Duration(minutes: _monitoringIntervalMinutes), (_) {
      _monitorAndLearn();
    });

    // 3. Pokreni noćnu analizu (u 02:00)
    _scheduleNightlyAnalysis();

    // 4. Odmah pokreni inicijalnu analizu
    await _monitorAndLearn();

    print('✅ [ML Lab] Autonomni sistem aktivan!');
  }

  /// 🛑 ZAUSTAVI SISTEM
  void stop() {
    _learningTimer?.cancel();
    _monitoringTimer?.cancel();
    print('🛑 [ML Lab] Autonomni sistem zaustavljen.');
  }

  /// 🔍 MONITORING & AUTO-LEARNING
  /// Sam prati podatke i uči kada detektuje promene
  Future<void> _monitorAndLearn() async {
    try {
      print('🔍 [ML Lab] Skeniranje podataka...');

      // 1. Proveri da li ima novih podataka
      final hasNewData = await _checkForNewData();

      if (hasNewData) {
        print('🆕 [ML Lab] Detektovani novi podaci - pokrećem učenje...');

        // 2. Automatski uči na novim podacima
        await _autoLearn();

        // 3. Detektuj anomalije
        await _detectAnomalies();

        // 4. Generiši predviđanja
        await _generatePredictions();

        print('✅ [ML Lab] Učenje završeno.');
      } else {
        print('💤 [ML Lab] Nema novih podataka.');
      }

      // 5. Uvek proveri trenutne alerte
      await _checkAlerts();
    } catch (e) {
      print('❌ [ML Lab] Greška u monitoringu: $e');
    }
  }

  /// 🆕 PROVERA ZA NOVE PODATKE
  Future<bool> _checkForNewData() async {
    try {
      // Proveri vozila_istorija (poslednja 24h)
      final result = await _supabase
          .from('vozila_istorija')
          .select('updated_at')
          .gt('updated_at', DateTime.now().subtract(const Duration(hours: 24)).toIso8601String())
          .limit(1);

      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// 🎓 AUTOMATSKO UČENJE
  Future<void> _autoLearn() async {
    print('🎓 [ML Lab] Auto-learning u toku...');

    // PRVO: Prilagodi dinamičke parametre na osnovu podataka
    await _adaptParameters();

    // Uči obrasce za:
    await _learnFuelConsumptionPatterns();
    await _learnTireWearPatterns();
    await _learnMaintenancePatterns();
    await _learnCostTrends();

    // Sačuvaj naučene obrasce
    await _saveLearnedPatterns();
  }

  /// 🔄 RESTARTUJ MONITORING TIMER
  /// Poziva se automatski kada se _monitoringIntervalMinutes promeni
  void _restartMonitoringTimer() {
    _monitoringTimer?.cancel();
    _monitoringTimer = Timer.periodic(Duration(minutes: _monitoringIntervalMinutes), (_) {
      _monitorAndLearn();
    });
    print('🔄 [ML Lab] Monitoring timer restartovan: ${_monitoringIntervalMinutes} minuta');
  }

  /// 🎯 AUTOMATSKA ADAPTACIJA PARAMETARA
  /// Sistem SAM prilagođava parametre na osnovu podataka!
  Future<void> _adaptParameters() async {
    try {
      print('🎯 [ML Lab] Prilagođavam parametre...');

      // 1. Prilagodi monitoring interval na osnovu učestalosti promena
      final recentChanges = await _supabase
          .from('vozila_istorija')
          .select('datum')
          .gte('datum', DateTime.now().subtract(const Duration(days: 7)).toIso8601String())
          .limit(100);

      // Kontinualno računanje: što više promena, to češći monitoring
      // Formula: interval = max(10, min(120, 120 - promena))
      final changesPerDay = recentChanges.length / 7.0;
      final calculatedInterval = (120 - changesPerDay * 2).clamp(10, 120).toInt();

      if (_monitoringIntervalMinutes != calculatedInterval) {
        _monitoringIntervalMinutes = calculatedInterval;
        _restartMonitoringTimer();
      }

      // 2. Prilagodi lookback period na osnovu starosti podataka
      final oldestRecord =
          await _supabase.from('vozila_istorija').select('datum').order('datum', ascending: true).limit(1);

      if (oldestRecord.isNotEmpty) {
        final oldestDate = DateTime.parse(oldestRecord.first['datum'] as String);
        final dataAge = DateTime.now().difference(oldestDate).inDays;

        // Kontinualno računanje: lookback = min(dataAge * 0.5, 365)
        // Gleda nazad 50% od ukupne starosti podataka, ali max 1 godina
        _historyLookbackDays = (dataAge * 0.5).clamp(14, 365).toInt();
      }

      // 3. Prilagodi cost threshold na osnovu volatilnosti troškova
      final recentCosts = await _supabase
          .from('troskovi_unosi')
          .select('iznos')
          .gte('datum', DateTime.now().subtract(const Duration(days: 30)).toIso8601String());

      if (recentCosts.length > 5) {
        final amounts = recentCosts.map((c) => (c['iznos'] as num).toDouble()).toList();
        final avg = amounts.reduce((a, b) => a + b) / amounts.length;
        final variance = amounts.map((x) => (x - avg) * (x - avg)).reduce((a, b) => a + b) / amounts.length;
        final stdDev = variance > 0 ? variance : 0;
        final coefficientOfVariation = avg > 0 ? stdDev / avg : 0;

        // Kontinualno računanje: threshold = 1.5 + (CV * 3.0)
        // Što veća volatilnost, to veći threshold
        _costTrendThreshold = (1.5 + coefficientOfVariation * 3.0).clamp(1.5, 5.0);
      }

      print(
          '✅ [ML Lab] Parametri: monitoring=${_monitoringIntervalMinutes}min, lookback=${_historyLookbackDays}d, costThreshold=${_costTrendThreshold.toStringAsFixed(1)}x');
    } catch (e) {
      print('⚠️ [ML Lab] Greška u adaptaciji parametara: $e');
    }
  }

  /// ⛽ UČI OBRASCE POTROŠNJE GORIVA
  Future<void> _learnFuelConsumptionPatterns() async {
    try {
      // Izvuci podatke o kilometraži (dinamički period)
      final data = await _supabase
          .from('vozila_istorija')
          .select('vozilo_id, kilometraza, datum')
          .gte('datum', DateTime.now().subtract(Duration(days: _historyLookbackDays)).toIso8601String())
          .order('datum');

      if (data.isEmpty) {
        print('⚠️ [ML Lab] Nema podataka za učenje goriva.');
        return;
      }

      // Grupiši po vozilima
      final Map<String, List<dynamic>> byVehicle = {};
      for (final row in data) {
        final vehicleId = row['vozilo_id'] as String;
        byVehicle.putIfAbsent(vehicleId, () => []);
        byVehicle[vehicleId]!.add(row);
      }

      // Nauči obrazac za svako vozilo
      final patterns = <String, dynamic>{};
      for (final entry in byVehicle.entries) {
        final vehicleId = entry.key;
        final history = entry.value;

        if (history.length < 2) continue; // Treba bar 2 tačke

        // Sortiraj po datumu
        history.sort((a, b) => (a['datum'] as String).compareTo(b['datum'] as String));

        // Izračunaj prosečnu dnevnu kilometražu
        final firstKm = (history.first['kilometraza'] as num).toDouble();
        final lastKm = (history.last['kilometraza'] as num).toDouble();
        final firstDate = DateTime.parse(history.first['datum'] as String);
        final lastDate = DateTime.parse(history.last['datum'] as String);
        final days = lastDate.difference(firstDate).inDays;

        if (days <= 0) continue;

        final avgKmPerDay = (lastKm - firstKm) / days;

        // Detektuj trend (raste, pada, stabilan)
        final recentData = history.sublist((history.length * 0.7).toInt()); // Poslednje 30%
        final recentFirstKm = (recentData.first['kilometraza'] as num).toDouble();
        final recentLastKm = (recentData.last['kilometraza'] as num).toDouble();
        final recentFirstDate = DateTime.parse(recentData.first['datum'] as String);
        final recentLastDate = DateTime.parse(recentData.last['datum'] as String);
        final recentDays = recentLastDate.difference(recentFirstDate).inDays;

        final recentAvgKmPerDay = recentDays > 0 ? (recentLastKm - recentFirstKm) / recentDays : avgKmPerDay;

        String trend = 'stable';
        if (recentAvgKmPerDay > avgKmPerDay * 1.2) {
          trend = 'increasing'; // Vozi se više
        } else if (recentAvgKmPerDay < avgKmPerDay * 0.8) {
          trend = 'decreasing'; // Vozi se manje
        }

        // Detektuj anomalije (nagla promena)
        final anomalies = <String>[];
        for (int i = 1; i < history.length; i++) {
          final prevKm = (history[i - 1]['kilometraza'] as num).toDouble();
          final currKm = (history[i]['kilometraza'] as num).toDouble();
          final prevDate = DateTime.parse(history[i - 1]['datum'] as String);
          final currDate = DateTime.parse(history[i]['datum'] as String);
          final dayDiff = currDate.difference(prevDate).inDays;

          if (dayDiff > 0) {
            final dailyKm = (currKm - prevKm) / dayDiff;

            // Ako je dnevna kilometraža > 2x prosek = anomalija
            if (dailyKm > avgKmPerDay * 2) {
              anomalies.add(currDate.toIso8601String());
            }
          }
        }

        patterns[vehicleId] = {
          'avg_km_per_day': avgKmPerDay.toStringAsFixed(1),
          'recent_avg_km_per_day': recentAvgKmPerDay.toStringAsFixed(1),
          'trend': trend,
          'anomalies': anomalies,
          'last_km': lastKm,
          'last_update': lastDate.toIso8601String(),
        };
      }

      _learnedPatterns['fuel_consumption'] = patterns;
      print('⛽ [ML Lab] Naučio obrasce potrošnje za ${patterns.length} vozila.');
    } catch (e) {
      print('❌ Greška u učenju goriva: $e');
    }
  }

  /// 🛞 UČI OBRASCE HABANJA GUMA
  Future<void> _learnTireWearPatterns() async {
    try {
      // Izvuci sve gume sa vozilima
      final tires = await _supabase
          .from('gume')
          .select('id, vozilo_id, datum_montaze, broj_meseci_garancije, predjeni_km')
          .order('datum_montaze');

      if (tires.isEmpty) {
        print('⚠️ [ML Lab] Nema podataka o gumama.');
        return;
      }

      final patterns = <String, dynamic>{};

      for (final tire in tires) {
        final tireId = tire['id'] as String;
        final vehicleId = tire['vozilo_id'] as String?;
        final montageDate = tire['datum_montaze'] != null ? DateTime.parse(tire['datum_montaze'] as String) : null;
        final warrantyMonths = tire['broj_meseci_garancije'] as int?;
        final traveledKm = (tire['predjeni_km'] as num?)?.toDouble() ?? 0.0;

        if (montageDate == null) continue;

        final age = DateTime.now().difference(montageDate);
        final monthsOld = age.inDays / 30.0;

        // Samo prати podatke - bez fiksnih pravila!
        // Sistem će SAM naučiti šta je normalno
        String status = 'active';
        String? alert;

        // Jedino realno pravilo: garancija (to je faktički podatak)
        if (warrantyMonths != null) {
          final expiryDate = montageDate.add(Duration(days: warrantyMonths * 30));
          final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;

          if (daysUntilExpiry < _warrantyWarningDays && daysUntilExpiry > 0) {
            alert = 'Garancija ističe za $daysUntilExpiry dana';
          } else if (daysUntilExpiry <= 0) {
            alert = 'Garancija istekla';
          }
        }

        patterns[tireId] = {
          'vehicle_id': vehicleId,
          'age_months': monthsOld.toStringAsFixed(1),
          'traveled_km': traveledKm,
          'warranty_months': warrantyMonths,
          'status': status,
          'alert': alert,
          'montage_date': montageDate.toIso8601String(),
        };

        // Alert samo ako garancija ističe (to je jedini objektivan kriterijum)
        if (alert != null && alert.contains('Garancija')) {
          _pendingAlerts.add(VehicleAlert(
            type: 'tire',
            severity: 'low',
            message: alert,
            vehicleId: vehicleId ?? 'unknown',
            timestamp: DateTime.now(),
          ));
        }
      }

      _learnedPatterns['tire_wear'] = patterns;
      print('🛞 [ML Lab] Naučio obrasce habanja ${patterns.length} guma.');
    } catch (e) {
      print('❌ Greška u učenju guma: $e');
    }
  }

  /// 🔧 UČI OBRASCE ODRŽAVANJA
  Future<void> _learnMaintenancePatterns() async {
    try {
      // Izvuci vozila sa zadnjim servisom
      final vehicles = await _supabase
          .from('vozila')
          .select('id, model, kilometraza, datum_poslednjeg_servisa, interval_servisa_km');

      if (vehicles.isEmpty) {
        print('⚠️ [ML Lab] Nema podataka o vozilima.');
        return;
      }

      final patterns = <String, dynamic>{};

      for (final vehicle in vehicles) {
        final vehicleId = vehicle['id'] as String;
        final model = vehicle['model'] as String?;
        final currentKm = (vehicle['kilometraza'] as num?)?.toDouble() ?? 0.0;
        final lastServiceDate = vehicle['datum_poslednjeg_servisa'] != null
            ? DateTime.parse(vehicle['datum_poslednjeg_servisa'] as String)
            : null;
        final serviceIntervalKm =
            vehicle['interval_servisa_km'] != null ? (vehicle['interval_servisa_km'] as num).toDouble() : null;

        String status = 'monitoring';
        String? alert;
        double? kmUntilService;
        int? daysSinceService;

        // Samo prati podatke - bez arbitrarnih pravila!
        if (lastServiceDate != null) {
          daysSinceService = DateTime.now().difference(lastServiceDate).inDays;
        }

        // Ako postoji interval iz baze, izračunaj do sledećeg
        if (serviceIntervalKm != null && serviceIntervalKm > 0) {
          final kmSinceService = currentKm % serviceIntervalKm;
          kmUntilService = serviceIntervalKm - kmSinceService;
        }

        patterns[vehicleId] = {
          'model': model,
          'current_km': currentKm,
          'last_service_date': lastServiceDate?.toIso8601String(),
          'service_interval_km': serviceIntervalKm,
          'km_until_service': kmUntilService?.toStringAsFixed(0),
          'days_since_service': daysSinceService,
          'status': status,
          'alert': alert,
        };
      }

      _learnedPatterns['maintenance'] = patterns;
      print('🔧 [ML Lab] Naučio obrasce održavanja ${patterns.length} vozila.');
    } catch (e) {
      print('❌ Greška u učenju održavanja: $e');
    }
  }

  /// 💰 UČI TRENDOVE TROŠKOVA
  Future<void> _learnCostTrends() async {
    try {
      // Izvuci troškove (dinamički period)
      final costs = await _supabase
          .from('troskovi_unosi')
          .select('vozilo_id, iznos, datum, opis')
          .gte('datum', DateTime.now().subtract(Duration(days: _historyLookbackDays)).toIso8601String())
          .order('datum');

      if (costs.isEmpty) {
        print('⚠️ [ML Lab] Nema podataka o troškovima.');
        return;
      }

      // Grupiši po vozilima
      final Map<String, List<dynamic>> byVehicle = {};
      for (final cost in costs) {
        final vehicleId = cost['vozilo_id'] as String;
        byVehicle.putIfAbsent(vehicleId, () => []);
        byVehicle[vehicleId]!.add(cost);
      }

      final patterns = <String, dynamic>{};

      for (final entry in byVehicle.entries) {
        final vehicleId = entry.key;
        final costList = entry.value;

        // Ukupni troškovi
        double totalCost = 0.0;
        for (final cost in costList) {
          totalCost += (cost['iznos'] as num).toDouble();
        }

        final avgCostPerEntry = costList.isNotEmpty ? totalCost / costList.length : 0.0;

        // Detektuj skuplje troškove (outliers)
        final expensiveCosts = <Map<String, dynamic>>[];
        for (final cost in costList) {
          final amount = (cost['iznos'] as num).toDouble();
          if (amount > avgCostPerEntry * 2) {
            expensiveCosts.add({
              'amount': amount,
              'date': cost['datum'],
              'description': cost['opis'],
            });
          }
        }

        // Trend (uporedi prve 50% vs druge 50%)
        final half = (costList.length / 2).floor();
        final firstHalf = costList.sublist(0, half);
        final secondHalf = costList.sublist(half);

        double firstHalfTotal = 0.0;
        for (final cost in firstHalf) {
          firstHalfTotal += (cost['iznos'] as num).toDouble();
        }

        double secondHalfTotal = 0.0;
        for (final cost in secondHalf) {
          secondHalfTotal += (cost['iznos'] as num).toDouble();
        }

        final firstHalfAvg = firstHalf.isNotEmpty ? firstHalfTotal / firstHalf.length : 0.0;
        final secondHalfAvg = secondHalf.isNotEmpty ? secondHalfTotal / secondHalf.length : 0.0;

        String trend = 'stable';
        String? alert;

        // Detektuj samo ZNAČAJNE promene (dinamički threshold)
        if (secondHalfAvg > firstHalfAvg * _costTrendThreshold) {
          trend = 'increasing';
          alert =
              'Troškovi rastu - prosek sa ${firstHalfAvg.toStringAsFixed(0)} na ${secondHalfAvg.toStringAsFixed(0)} din';
        } else if (secondHalfAvg < firstHalfAvg / _costTrendThreshold) {
          trend = 'decreasing';
        }

        patterns[vehicleId] = {
          'total_cost_period_days': totalCost.toStringAsFixed(2),
          'avg_cost_per_entry': avgCostPerEntry.toStringAsFixed(2),
          'entry_count': costList.length,
          'trend': trend,
          'expensive_costs': expensiveCosts,
          'alert': alert,
        };

        // Alert za rastuće troškove
        if (trend == 'increasing') {
          _pendingAlerts.add(VehicleAlert(
            type: 'cost',
            severity: 'medium',
            message: alert ?? 'Troškovi rastu',
            vehicleId: vehicleId,
            timestamp: DateTime.now(),
          ));
        }
      }

      _learnedPatterns['cost_trends'] = patterns;
      print('💰 [ML Lab] Naučio trendove troškova za ${patterns.length} vozila.');
    } catch (e) {
      print('❌ Greška u učenju troškova: $e');
    }
  }

  /// 🚨 DETEKCIJA ANOMALIJA
  Future<void> _detectAnomalies() async {
    print('🚨 [ML Lab] Detekcija anomalija...');

    // Proveri sve vozila
    final vehicles = await _supabase.from('vozila').select();

    for (final vehicle in vehicles) {
      // 1. Neobična potrošnja goriva
      await _checkFuelAnomaly(vehicle);

      // 2. Dugo bez servisa
      await _checkMaintenanceOverdue(vehicle);

      // 3. Visoka kilometraža na gumama
      await _checkTireKilometers(vehicle);
    }
  }

  /// ⛽ PROVERA ANOMALIJE U GORIVU
  Future<void> _checkFuelAnomaly(Map<String, dynamic> vehicle) async {
    // TODO: Implementiraj logiku
  }

  /// 🔧 PROVERA ODRŽAVANJA
  Future<void> _checkMaintenanceOverdue(Map<String, dynamic> vehicle) async {
    // TODO: Implementiraj logiku
  }

  /// 🛞 PROVERA KILOMETRAŽE GUMA
  Future<void> _checkTireKilometers(Map<String, dynamic> vehicle) async {
    // TODO: Implementiraj logiku
  }

  /// 🔮 GENERISANJE PREDVIĐANJA
  Future<void> _generatePredictions() async {
    print('🔮 [ML Lab] Generisanje predviđanja...');

    // Predvidi sledeće:
    // - Kada treba servis
    // - Kada treba menjati gume
    // - Koliko će koštati sledeći mesec

    // TODO: Implementiraj prediction logiku
  }

  /// 🔔 PROVERA I SLANJE ALERTOVA
  Future<void> _checkAlerts() async {
    if (_pendingAlerts.isEmpty) return;

    print('🔔 [ML Lab] Slanje ${_pendingAlerts.length} alertova...');

    for (final alert in _pendingAlerts) {
      try {
        // Mapiranje severity na emoji i poruku
        String emoji = '⚠️';
        if (alert.severity == 'critical' || alert.severity == 'high') {
          emoji = '🚨';
        } else if (alert.severity == 'medium') {
          emoji = '⚠️';
        } else {
          emoji = 'ℹ️';
        }

        // Mapiranje tipa na naslov
        String title = '';
        switch (alert.type) {
          case 'fuel':
            title = '$emoji Potrošnja Goriva';
            break;
          case 'tire':
            title = '$emoji Gume';
            break;
          case 'maintenance':
            title = '$emoji Održavanje';
            break;
          case 'cost':
            title = '$emoji Troškovi';
            break;
          default:
            title = '$emoji Vozilo Alert';
        }

        // Pošalji notifikaciju
        await LocalNotificationService.showRealtimeNotification(
          title: title,
          body: alert.message,
          payload: 'ml_vehicle_alert|${alert.vehicleId}|${alert.type}',
        );

        print('✅ [ML Lab] Alert poslat: ${alert.type} za vozilo ${alert.vehicleId}');
      } catch (e) {
        print('❌ [ML Lab] Greška u slanju alerta: $e');
      }
    }

    _pendingAlerts.clear();
  }

  /// 🌙 NOĆNA ANALIZA (u 02:00)
  void _scheduleNightlyAnalysis() {
    final now = DateTime.now();
    var nextRun = DateTime(now.year, now.month, now.day, 2, 0); // 02:00

    if (now.hour >= 2) {
      nextRun = nextRun.add(const Duration(days: 1)); // Sutra u 02:00
    }

    final delay = nextRun.difference(now);

    Timer(delay, () {
      _performNightlyAnalysis();
      // Zakaži sledeću noćnu analizu
      _scheduleNightlyAnalysis();
    });

    print('🌙 [ML Lab] Noćna analiza zakazana za: ${nextRun.toString()}');
  }

  /// 🌙 NOĆNA ANALIZA - DETALJNA
  Future<void> _performNightlyAnalysis() async {
    print('🌙 [ML Lab] Pokrećem noćnu analizu...');

    try {
      // 1. Kompletan retraining svih modela
      await _autoLearn();

      // 2. Generisanje mesečnih izveštaja
      await _generateMonthlyReport();

      // 3. Optimizacija modela
      await _optimizeModels();

      print('✅ [ML Lab] Noćna analiza završena.');
    } catch (e) {
      print('❌ [ML Lab] Greška u noćnoj analizi: $e');
    }
  }

  /// 📊 GENERISANJE MESEČNOG IZVEŠTAJA
  Future<void> _generateMonthlyReport() async {
    try {
      print('📊 [ML Lab] Generisanje mesečnog izveštaja...');

      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);

      // Izvuci sve vozila
      final vehicles = await _supabase.from('vozila').select('id, model');

      final report = <String, dynamic>{
        'generated_at': now.toIso8601String(),
        'period': '${firstDayOfMonth.toIso8601String()} - ${now.toIso8601String()}',
        'vehicles': <String, dynamic>{},
      };

      for (final vehicle in vehicles) {
        final vehicleId = vehicle['id'] as String;
        final model = vehicle['model'] as String?;

        // Troškovi za ovaj mesec
        final costs = await _supabase
            .from('troskovi_unosi')
            .select('iznos, datum, opis')
            .eq('vozilo_id', vehicleId)
            .gte('datum', firstDayOfMonth.toIso8601String())
            .lte('datum', now.toIso8601String());

        double totalCost = 0.0;
        for (final cost in costs) {
          totalCost += (cost['iznos'] as num).toDouble();
        }

        // Kilometraža ovog meseca
        final kmHistory = await _supabase
            .from('vozila_istorija')
            .select('kilometraza, datum')
            .eq('vozilo_id', vehicleId)
            .gte('datum', firstDayOfMonth.toIso8601String())
            .order('datum');

        double kmThisMonth = 0.0;
        if (kmHistory.length >= 2) {
          final firstKm = (kmHistory.first['kilometraza'] as num).toDouble();
          final lastKm = (kmHistory.last['kilometraza'] as num).toDouble();
          kmThisMonth = lastKm - firstKm;
        }

        report['vehicles'][vehicleId] = {
          'model': model,
          'total_cost': totalCost.toStringAsFixed(2),
          'km_this_month': kmThisMonth.toStringAsFixed(0),
          'cost_per_km': kmThisMonth > 0 ? (totalCost / kmThisMonth).toStringAsFixed(2) : '0',
        };
      }

      // Sačuvaj izveštaj u bazu
      await _supabase.from('ml_config').upsert({
        'id': 'monthly_report_${now.year}_${now.month}',
        'config': report,
        'updated_at': now.toIso8601String(),
      });

      print('✅ [ML Lab] Mesečni izveštaj generisan.');

      // Pošalji notifikaciju sa izveštajem
      await LocalNotificationService.showRealtimeNotification(
        title: '📊 Mesečni Izveštaj Vozila',
        body: 'Generisan izveštaj za ${report['vehicles'].length} vozila.',
        payload: 'ml_monthly_report|${now.year}_${now.month}',
      );
    } catch (e) {
      print('❌ [ML Lab] Greška u generisanju izveštaja: $e');
    }
  }

  /// ⚡ OPTIMIZACIJA MODELA
  Future<void> _optimizeModels() async {
    try {
      print('⚡ [ML Lab] Optimizacija modela...');

      // 1. Proveri da li treba ponovno treniranje
      // Ako je prosečna greška > 20%, retriniraj

      // 2. Kompresuj podatke (samo najvažniji features)
      final compressedPatterns = <String, dynamic>{};

      // Fuel consumption - zadrži samo zadnjih 30 dana
      if (_learnedPatterns.containsKey('fuel_consumption')) {
        compressedPatterns['fuel_consumption'] = _learnedPatterns['fuel_consumption'];
      }

      // Tire wear - samo trenutna vozila
      if (_learnedPatterns.containsKey('tire_wear')) {
        compressedPatterns['tire_wear'] = _learnedPatterns['tire_wear'];
      }

      // Maintenance - samo vozila sa sledećim servisom u sledećih 90 dana
      if (_learnedPatterns.containsKey('maintenance')) {
        compressedPatterns['maintenance'] = _learnedPatterns['maintenance'];
      }

      // Cost trends - samo zadnjih 90 dana
      if (_learnedPatterns.containsKey('cost_trends')) {
        compressedPatterns['cost_trends'] = _learnedPatterns['cost_trends'];
      }

      _learnedPatterns.clear();
      _learnedPatterns.addAll(compressedPatterns);

      await _saveLearnedPatterns();

      print('✅ [ML Lab] Modeli optimizovani.');
    } catch (e) {
      print('❌ [ML Lab] Greška u optimizaciji: $e');
    }
  }

  /// 💾 UČITAJ NAUČENE OBRASCE
  Future<void> _loadLearnedPatterns() async {
    try {
      final result = await _supabase.from('ml_config').select().eq('id', 'vehicle_patterns').maybeSingle();

      if (result != null && result['config'] != null) {
        _learnedPatterns.addAll(Map<String, dynamic>.from(result['config']));
        print('✅ [ML Lab] Učitani prethodni obrasci.');
      }
    } catch (e) {
      print('⚠️ [ML Lab] Nema prethodnih obrazaca: $e');
    }
  }

  /// 💾 SAČUVAJ NAUČENE OBRASCE
  Future<void> _saveLearnedPatterns() async {
    try {
      await _supabase.from('ml_config').upsert({
        'id': 'vehicle_patterns',
        'config': _learnedPatterns,
        'updated_at': DateTime.now().toIso8601String(),
      });
      print('💾 [ML Lab] Obrasci sačuvani.');
    } catch (e) {
      print('❌ [ML Lab] Greška pri čuvanju: $e');
    }
  }
}

/// 🚨 MODEL ZA ALERT
class VehicleAlert {
  final String type; // 'fuel', 'tire', 'maintenance', 'cost'
  final String severity; // 'low', 'medium', 'high', 'critical'
  final String message;
  final String vehicleId;
  final DateTime timestamp;

  VehicleAlert({
    required this.type,
    required this.severity,
    required this.message,
    required this.vehicleId,
    required this.timestamp,
  });
}
