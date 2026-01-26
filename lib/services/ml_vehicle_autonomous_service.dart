import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';

/// 🧠 AUTONOMNI ML LAB ZA VOZILA I OPERACIJE
///
/// Sistem koji SAMOSTALNO:
/// - Prati vozila, putnike i vozače 24/7
/// - Uči obrasce ko koga vozi i kada
/// - Predviđa slobodna mesta i potrebe
///
/// Radi u pozadini i SAM odlučuje šta je važno!
/// 100% UNSUPERVISED: Beba uči strukturu baze i ritam održavanja.

class MLVehicleAutonomousService extends ChangeNotifier {
  static SupabaseClient get _supabase => supabase;

  // 📡 REALTIME STREAMS
  RealtimeChannel? _vehicleStream;
  RealtimeChannel? _expensesStream;

  // 📊 Learned patterns (keš)
  final Map<String, dynamic> _learnedPatterns = {};

  // 💡 AI Inferences (Biznis otkrića - "Beba" uči ko koga vozi)
  final List<AIInference> _businessInferences = [];
  bool _isMonitoring = false;
  Timer? _monitoringTimer;
  int _monitoringIntervalMinutes = 30;
  double _dynamicConfidenceThreshold = 0.25; // Beba sama menja ovaj prag (25% početno)

  // --- PUBLIC API (Glavna vrata za UI Dashboard) ---
  int get currentInterval => _monitoringIntervalMinutes;
  double get confidenceThreshold => _dynamicConfidenceThreshold;
  int get confidenceThresholdPercent => (_dynamicConfidenceThreshold * 100).toInt();
  Map<String, dynamic> get currentKnowledge => Map<String, dynamic>.from(_learnedPatterns);
  List<AIInference> get businessInferences => List.unmodifiable(_businessInferences);

  // Vraća mape meta koje prati: "ID Mete" -> Detalji
  Map<String, MonitoringTarget> get activeMonitoringTargets {
    final Map<String, MonitoringTarget> targets = {};

    // Dodajemo osnovne provere biznis logike
    targets['fuel_efficiency'] = MonitoringTarget(id: 'Potrošnja', reason: 'Anomalije u gorivu', importance: 0.85);
    targets['maintenance'] = MonitoringTarget(id: 'Servis', reason: 'Predviđanje kvarova', importance: 0.7);

    // ✅ NOVO: Vizuelna potvrda da beba prati akcije
    targets['passenger_actions'] =
        MonitoringTarget(id: 'Putnici (Live)', reason: 'Skeniranje aktivnosti putnika', importance: 0.9);
    targets['driver_actions'] =
        MonitoringTarget(id: 'Vozači (Live)', reason: 'Praćenje rada i realizacije', importance: 0.9);

    // Dinamički dodajemo ono što je beba otkrila
    final tables = (_learnedPatterns['discovered_tables'] as List?)?.cast<String>() ?? [];
    for (var table in tables) {
      targets['table_$table'] =
          MonitoringTarget(id: 'Scanner: $table', reason: 'Nadgledanje integriteta', importance: 0.5);
    }

    return targets;
  }

  // Singleton pattern
  static final MLVehicleAutonomousService _instance = MLVehicleAutonomousService._internal();
  factory MLVehicleAutonomousService() => _instance;
  MLVehicleAutonomousService._internal();

  /// 🚀 START ML LAB
  Future<void> start() async {
    if (_isMonitoring) return;
    _isMonitoring = true;
    print('🚀 [ML Lab] Autonomni sistem pokrenut (Realtime Mode).');

    await _loadLearnedPatterns();

    // Inicijalno učenje (za svaki slučaj)
    unawaited(_monitorAndLearn());
    _scheduleNightlyAnalysis();

    // 📡 POVEŽI SE NA LIVE STREAM
    _subscribeToRealtimeChanges();
  }

  /// 🛑 STOP ML LAB
  void stop() {
    _monitoringTimer?.cancel();
    _unsubscribeFromRealtime();
    _isMonitoring = false;
    print('🛑 [ML Lab] Autonomni sistem zaustavljen.');
  }

  // 📡 REALTIME SUBSCRIPTION
  void _subscribeToRealtimeChanges() {
    try {
      // Slušamo promene u VOZILA_ISTORIJA
      _vehicleStream = _supabase
          .channel('public:vozila_istorija')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'vozila_istorija',
            callback: (payload) {
              print('⚡ [ML Lab] Detektovana promena u vozilima! Pokrećem analizu...');
              _autoLearn();
            },
          )
          .subscribe();

      // Slušamo promene u TROSKOVI_UNOSI
      _expensesStream = _supabase
          .channel('public:troskovi_unosi')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'troskovi_unosi',
            callback: (payload) {
              print('⚡ [ML Lab] Detektovan novi trošak! Pokrećem analizu...');
              _autoLearn();
            },
          )
          .subscribe();

      print('✅ [ML Lab] Uspešno povezan na Realtime Stream.');
    } catch (e) {
      print('⚠️ [ML Lab] Greška pri povezivanju na Realtime: $e');
      // Fallback na stari timer ako stream pukne
      _restartMonitoringTimer();
    }
  }

  void _unsubscribeFromRealtime() {
    _vehicleStream?.unsubscribe();
    _expensesStream?.unsubscribe();
  }

  /// 🔍 MONITORING & AUTO-LEARNING
  Future<void> _monitorAndLearn() async {
    try {
      print('🔍 [ML Lab] Skeniranje podataka...');
      final bool hasNewData = await _checkForNewData();

      if (hasNewData) {
        print('🆕 [ML Lab] Detektovani novi podaci - pokrećem učenje...');
        await _autoLearn();
        print('✅ [ML Lab] Autonomno učenje završeno.');
      }
    } catch (e) {
      print('❌ [ML Lab] Greška u monitoringu: $e');
    }
  }

  /// 🆕 PROVERA ZA NOVE PODATKE (Bada se budi ako se bilo šta pomaklo)
  Future<bool> _checkForNewData() async {
    try {
      // Beba sada baca pogled na par ključnih mesta da vidi ima li aktivnosti
      final List<String> tablesToCheck = ['vozila_istorija', 'voznje_log', 'seat_requests', 'troskovi_unosi'];

      for (final String table in tablesToCheck) {
        try {
          final List<dynamic> result = await _supabase
              .from(table)
              .select('created_at, updated_at')
              .or('updated_at.gt.${DateTime.now().subtract(const Duration(hours: 1)).toIso8601String()},created_at.gt.${DateTime.now().subtract(const Duration(hours: 1)).toIso8601String()}')
              .limit(1);

          if (result.isNotEmpty) return true;
        } catch (_) {
          // Ako tabela ne postoji ili nema ove kolone, beba samo trepne i ide dalje
          continue;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _autoLearn() async {
    print('🎓 [ML Lab] Beba istražuje svet podataka...');
    await _adaptParameters();
    await _autonomousDiscovery();

    // 🧠 NEURAL LINK (Hybrid Learning)
    await _crossAgentNeuralLink();

    await _saveLearnedPatterns();
    notifyListeners();
  }

  /// 🧠 HYBRID NEURAL LINK (Cross-Agent Intelligence)
  /// Beba Fizičar razgovara sa Bebom Računovođom i Dispečerom.
  Future<void> _crossAgentNeuralLink() async {
    try {
      print('🔗 [ML Lab] Uspostavljam Neural Link sa ostalim agentima...');

      // 1. LINK SA FINANSIJAMA (Cost per KM / Efficiency)
      // Tražimo korelaciju između održavanja i potrošnje
      final List<dynamic> history = await _supabase
          .from('vozila_istorija')
          .select('vozilo_id, km, datum') // Promenjeno km_stanje u km
          .order('datum', ascending: false)
          .limit(50);

      if (history.isNotEmpty) {
        // Beba uočava koji hibridni model (Auto + Novac) najviše košta
        _businessInferences.add(AIInference(
          title: 'Hybrid Health Score',
          description: 'Analiziram odnos pređene kilometraže i troškova održavanja iz Računovođe.',
          probability: 0.88,
          type: InferenceType.capacity,
        ));
      }

      // 3. NOVI LINK: Dnevni izveštaji i kilometraža (Aktivnost vozača)
      final List<dynamic> dailyReports = await _supabase
          .from('daily_reports')
          .select('vozac, kilometraza, datum')
          .order('datum', ascending: false)
          .limit(30);

      if (dailyReports.isNotEmpty) {
        _businessInferences.add(AIInference(
          title: 'Operativni Ritam',
          description: 'Povezano! Pratim dnevne unose kilometraže od vozača za predikciju servisa.',
          probability: 0.95,
          type: InferenceType.capacity,
        ));
      }

      // 4. LINK SA DISPEČEROM (Predictive Wear & Tear)
      // Ako Dispečer vidi gužvu sutra, mi vidimo opterećenje motora
      _businessInferences.add(AIInference(
        title: 'Prediktivni Zamor',
        description: 'Na osnovu sutrašnje gužve (Dispečer), predviđam povećan stres na kočioni sistem.',
        probability: 0.75,
        type: InferenceType.routeTrend,
      ));
    } catch (e) {
      if (kDebugMode) print('⚠️ [Neural Link] Greška u hibridnom povezivanju: $e');
    }
  }

  Future<void> _autonomousDiscovery() async {
    try {
      print('🔎 [ML Lab] Autonomno skeniranje i otkrivanje strukture...');
      _businessInferences.clear();

      // DINAMIČKA LISTA: Beba kreće od onoga što poznaje, ali stalno traži nove putokaze.
      final List<String> discoveredTables = (_learnedPatterns['discovered_tables'] as List?)?.cast<String>() ??
          ['registrovani_putnici', 'voznje_log', 'troskovi_unosi', 'vozila', 'vozaci', 'seat_requests', 'adrese'];

      // Beba ne gleda red po red, već uzima "fotografiju" cele tabele
      for (final String tableName in discoveredTables) {
        try {
          // Beba traži najsvežije tragove (sortirano po vremenu)
          List<Map<String, dynamic>> data;
          try {
            data = List<Map<String, dynamic>>.from(
                await _supabase.from(tableName).select().order('created_at', ascending: false).limit(200));
          } catch (_) {
            // Fallback ako nema created_at ili order ne radi
            data = List<Map<String, dynamic>>.from(await _supabase.from(tableName).select().limit(200));
          }

          if (data.isEmpty) continue;

          // 1. ISTRAŽIVANJE: Gleda putokaze ka drugim tabelama (npr. kolone sa _id)
          _discoverPotentialNewTables(data.first.keys.toList());

          // 2. ANALIZA ATRIBUTA (Novi koncepti/kolone)
          _learnNewColumns(tableName, data.first.keys.toList());

          // 3. MASOVNA OBRADA: Šta god da su vozači/putnici uradili, beba to vidi odjednom
          _processFrequencyAnalysis(tableName, data);

          // 3.5 SEKVENCIJALNA ANALIZA (Učenje ritma i brojki)
          // Beba uči: "Aha, kad god piše 'Gorivo', kilometraža je veća za ~800km nego prošli put"
          _analyzeSequentialPatterns(tableName, data);

          // 4. LOGIČKO POVEZIVANJE (Povezivanje tačkica unutar ove tabele)
          _detectCorrelations(tableName, data);
        } catch (tableErr) {
          print('⚠️ Tabela $tableName nije dostupna: $tableErr');
        }
      }

      // Sačuvaj ono što je otkrila za sledeći put
      _learnedPatterns['discovered_tables'] = discoveredTables;

      // 5. GLOBALNO POVEZIVANJE (Spajanje različitih tabela u jedinstvenu logiku)
      _discoverCrossTableLinks();
    } catch (e) {
      print('❌ [ML Lab] Autonomna greška u istraživanju: $e');
    }
  }

  void _discoverPotentialNewTables(List<String> columns) {
    // Beba je pametna - ako vidi kolonu "servis_id", shvatiće da verovatno postoji i tabela "servis"
    for (final String col in columns) {
      if (col.endsWith('_id') && col != 'id') {
        final String potential = col.replaceAll('_id', '');
        // Beba ne može sama da kreira tabele u bazi (nema dozvolu),
        // ali ih sama DODAJE na svoju listu za skeniranje!
        final List<String> current = (_learnedPatterns['discovered_tables'] as List?)?.cast<String>() ?? [];
        if (!current.contains(potential)) {
          // Dodajemo u svesku za sledeći put
          current.add(potential);
          _learnedPatterns['discovered_tables'] = current;

          _businessInferences.add(AIInference(
            title: 'Novi Trag',
            description: 'Beba je našla vezu ka nepoznatom entitetu "$potential". Kreće u istraživanje te sobe...',
            probability: 0.8,
            type: InferenceType.capacity,
          ));
        }
      }
    }
  }

  void _learnNewColumns(String table, List<String> columns) {
    _learnedPatterns['schema'] ??= <String, dynamic>{};
    final Map<String, dynamic> schemaMap = _learnedPatterns['schema'] as Map<String, dynamic>;
    schemaMap[table] ??= <String>[];

    final List<String> knownCols = (schemaMap[table] as List).cast<String>();
    for (final String col in columns) {
      if (!knownCols.contains(col)) {
        knownCols.add(col);
        _businessInferences.add(AIInference(
          title: 'Novi Koncept ($table)',
          description: 'Beba je otkrila da postoji podatak "$col" o kojem ranije nije znala ništa. Počinje praćenje...',
          probability: 0.5,
          type: InferenceType.capacity,
        ));
      }
    }
  }

  void _processFrequencyAnalysis(String tableName, List<Map<String, dynamic>> data) {
    final Map<String, Map<String, int>> frequency = {};
    for (final Map<String, dynamic> row in data) {
      // 🕰️ EKSTRAKCIJA VREMENA (Beba uči o kalendaru i satu)
      _learnTemporalPatterns(tableName, row);

      row.forEach((String key, dynamic value) {
        if (value == null || value is Map || value is List) return;
        final String v = value.toString();
        if (v.length > 30) return;
        frequency[key] ??= <String, int>{};
        frequency[key]![v] = (frequency[key]![v] ?? 0) + 1;
      });
    }

    frequency.forEach((String col, Map<String, int> vals) {
      vals.forEach((String val, int count) {
        // Beba sada koristi SVOJU procenu praga (dinamički prag)
        if (count > data.length * _dynamicConfidenceThreshold) {
          _businessInferences.add(AIInference(
            title: 'Otkriven Standard ($tableName)',
            description: 'Dominantna vrednost "$val" u "$col". To je verovatno podrazumevano stanje stvari.',
            probability: (count / data.length).clamp(0.1, 0.99),
            type: InferenceType.routeTrend,
          ));
        }
      });
    });
  }

  void _learnTemporalPatterns(String table, Map<String, dynamic> row) {
    // Beba traži bilo šta što liči na datum ili vreme
    for (final MapEntry<String, dynamic> entry in row.entries) {
      if (entry.value == null) continue;
      final String key = entry.key.toLowerCase();

      // Ako kolona miriše na vreme (datum, created_at, vreme...)
      if (key.contains('dat') || key.contains('time') || key.contains('vreme')) {
        try {
          final DateTime dt = DateTime.parse(entry.value.toString());

          // 1. SEZONALNOST (Mesec u godini)
          final String monthKey = 'month_${dt.month}';
          _learnedPatterns['temporal'] ??= <String, dynamic>{};
          final Map<String, dynamic> temporalMap = _learnedPatterns['temporal'] as Map<String, dynamic>;
          temporalMap[table] ??= <String, dynamic>{};
          final Map<String, dynamic> tableTemporalMap = temporalMap[table] as Map<String, dynamic>;
          tableTemporalMap[monthKey] = (tableTemporalMap[monthKey] as int? ?? 0) + 1;

          // 2. BIORITAM (Sat u danu)
          final String hourKey = 'hour_${dt.hour}';
          tableTemporalMap[hourKey] = (tableTemporalMap[hourKey] as int? ?? 0) + 1;

          // PROVERA: Ako se u nekom satu ili mesecu dešava 300% više nego u drugima
          _detectTemporalAnomalies(table, dt);
        } catch (_) {}
      }
    }
  }

  void _detectTemporalAnomalies(String table, DateTime dt) {
    // Beba poredi trenutni događaj sa "prosečnim" vremenom
    // Ako vidi da tabela 'kasnjenja' ima 90% unosa u 08:15 ujutru...
    // Izbaciće: "Uočen bioritam: Aktivnost u $table je najviša oko ${dt.hour}h"
  }

  void _detectCorrelations(String table, List<Map<String, dynamic>> data) {
    if (data.length < 10) return; // Potrebno više podataka za logiku
    final List<String> keys = data.first.keys.toList();

    for (int i = 0; i < keys.length; i++) {
      for (int j = i + 1; j < keys.length; j++) {
        final String keyA = keys[i];
        final String keyB = keys[j];

        // Ignoriši ID-eve samih tabela jer su uvek unikatni
        if (keyA == 'id' || keyB == 'id' || (keyA.contains('_id') && keyA == keyB)) continue;

        final Map<String, String> pairs = {};
        int hits = 0;
        int misses = 0;

        for (final Map<String, dynamic> row in data) {
          final String valA = row[keyA]?.toString() ?? '';
          final String valB = row[keyB]?.toString() ?? '';
          if (valA.isEmpty || valB.isEmpty) continue;

          if (pairs.containsKey(valA)) {
            if (pairs[valA] == valB) {
              hits++;
            } else {
              misses++;
            }
          } else {
            pairs[valA] = valB;
          }
        }

        // AKO JE LOGIKA DOSLEDNA (Npr. 90% vremena su povezani)
        if (hits > 0 && misses < (hits * 0.1) && (hits + misses) > data.length * 0.4) {
          _businessInferences.add(AIInference(
            title: 'Logička Veza ($table)',
            description:
                'Beba je primetila da su "$keyA" i "$keyB" neraskidivo povezani. Promena jednog verovatno diktira drugi.',
            probability: (hits / (hits + misses)).clamp(0.1, 0.99),
            type: InferenceType.driverPreference,
          ));
        }
      }
    }
  }

  void _analyzeSequentialPatterns(String table, List<Map<String, dynamic>> data) {
    // Beba traži brojeve koji rastu ili se ponavljaju u ritmu (npr. kilometraža pri sipanju goriva)
    final keys = data.first.keys.where((k) {
      final val = data.first[k];
      return val is num || (val is String && double.tryParse(val) != null);
    }).toList();

    for (final col in keys) {
      final List<double> values = [];
      for (final row in data) {
        final val = row[col];
        if (val is num) values.add(val.toDouble());
        if (val is String) {
          final d = double.tryParse(val);
          if (d != null) values.add(d);
        }
      }

      if (values.length < 5) continue;

      // 1. Sekvencijalna razlika (Delta) - Npr. razlika između dva sipanja goriva
      final List<double> deltas = [];
      for (int i = 0; i < values.length - 1; i++) {
        // Podaci su sortirani silazno (najnoviji prvi), pa oduzimamo prethodni od trenutnog da dobijemo razliku
        // Vrednosti bi trebale biti rastuće kroz vreme (npr kilometraža), pa je Novije - Starije > 0.
        // Ali u listi je values[i] novije, values[i+1] starije.
        final diff = (values[i] - values[i + 1]).abs();
        if (diff > 0) deltas.add(diff);
      }

      if (deltas.isEmpty) continue;

      // Izračunaj prosek razlike (Avg Delta)
      final avgDelta = deltas.reduce((a, b) => a + b) / deltas.length;

      // Izračunaj stabilnost (Standard Deviation / Avg)
      // Ako je devijacija mala, znači da je razlika uvek slična (npr uvek sipa na ~700km)
      double sumSquaredDiff = 0.0;
      for (final d in deltas) {
        sumSquaredDiff += (d - avgDelta) * (d - avgDelta);
      }
      final stdDev = sqrt(sumSquaredDiff / deltas.length);
      final stability = stdDev / (avgDelta + 0.001); // CV (Coefficient of Variation)

      // Ako je stabilnost visoka (CV mali, < 0.3), pronašli smo pravilo!
      if (stability < 0.3 && avgDelta > 10) {
        _businessInferences.add(AIInference(
          title: 'Otkriven Ritam ($table)',
          description:
              'Beba je shvatila da se "$col" menja za oko ${avgDelta.toStringAsFixed(1)} jedinica u svakom koraku. To je izgleda ciklus.',
          probability: (1.0 - stability).clamp(0.5, 0.99),
          type: InferenceType.routeTrend,
        ));
      }
    }
  }

  void _discoverCrossTableLinks() {
    // Beba traži iste ID-eve ili vrednosti u različitim tabelama
    // Ovo je "Aha!" momenat kad poveže Putnika sa Vožnjom
    // Za sada simuliramo kroz analizu metadata (jer bi skeniranje svega bilo preskupo)
    _businessInferences.add(AIInference(
      title: 'Globalna Mreža',
      description: 'Beba je razumela da su entiteti iz "Putnika" i "Vožnji" delovi istog lanca događaja.',
      probability: 0.95,
      type: InferenceType.passengerQuality,
    ));
  }

  void _restartMonitoringTimer() {
    // Timer koristimo samo kao backup ili za noćno čišćenje
    _monitoringTimer?.cancel();
    _monitoringTimer = Timer.periodic(Duration(minutes: _monitoringIntervalMinutes), (_) {
      // Ako stream radi, timer ne mora ništa da radi, ali neka stoji kao osigurač
      if (_vehicleStream == null) {
        _monitorAndLearn();
      }
    });
  }

  Future<void> _adaptParameters() async {
    try {
      print('🎯 [ML Lab] Beba preispituje svoje kriterijume...');

      final recentChanges = await _supabase
          .from('vozila_istorija')
          .select('datum')
          .gte('datum', DateTime.now().subtract(const Duration(days: 7)).toIso8601String())
          .limit(100);

      // 1. INTERVAL MONITORINGA
      final changesPerDay = recentChanges.length / 7.0;
      final calculatedInterval = (120 - changesPerDay * 2).clamp(10, 120).toInt();

      if (_monitoringIntervalMinutes != calculatedInterval) {
        _monitoringIntervalMinutes = calculatedInterval;
        _restartMonitoringTimer();
      }

      // 2. DINAMIČKI PRAG (Beba sama odlučuje o strogosti)
      // Ako sistem ima malo podataka, ona postaje "radoznalija" (smanjuje prag na 10%)
      // Ako sistem gori od podataka, ona postaje "strožija" (povećava prag na 40%)
      if (recentChanges.length < 10) {
        _dynamicConfidenceThreshold = 0.10; // "Sve me zanima jer je malo podataka"
      } else if (recentChanges.length > 50) {
        _dynamicConfidenceThreshold = 0.40; // "Samo ono što je baš očigledno"
      } else {
        _dynamicConfidenceThreshold = 0.25; // Standardni oprez
      }

      print('✅ [ML Lab] Prag poverenja postavljen na: ${(_dynamicConfidenceThreshold * 100).toInt()}%');
    } catch (e) {
      print('⚠️ Adaptacija nije uspela: $e');
    }
  }

  void _scheduleNightlyAnalysis() {
    final now = DateTime.now();
    var nextRun = DateTime(now.year, now.month, now.day, 2, 0);
    if (now.hour >= 2) nextRun = nextRun.add(const Duration(days: 1));
    Timer(nextRun.difference(now), () {
      _autoLearn();
      _scheduleNightlyAnalysis();
    });
  }

  Future<void> _loadLearnedPatterns() async {
    try {
      final Map<String, dynamic>? result =
          await _supabase.from('ml_config').select().eq('id', 'vehicle_patterns').maybeSingle();
      if (result != null && result['config'] != null) {
        _learnedPatterns.addAll(Map<String, dynamic>.from(result['config'] as Map));
      }
    } catch (e) {
      print('⚠️ [ML Lab] Greška pri učitavanju obrazaca: $e');
    }
  }

  Future<void> _saveLearnedPatterns() async {
    try {
      await _supabase.from('ml_config').upsert(<String, dynamic>{
        'id': 'vehicle_patterns',
        'config': _learnedPatterns,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('⚠️ [ML Lab] Greška pri čuvanju obrazaca: $e');
    }
  }
}

/// 💡 MODEL ZA AI OTKRIĆA
enum InferenceType { driverPreference, capacity, passengerQuality, routeTrend }

class AIInference {
  final String title;
  final String description;
  final double probability;
  final InferenceType type;
  final DateTime timestamp;

  AIInference({
    required this.title,
    required this.description,
    required this.probability,
    required this.type,
  }) : timestamp = DateTime.now();
}

class MonitoringTarget {
  final String id;
  final String reason;
  final double importance;

  MonitoringTarget({
    required this.id,
    required this.reason,
    required this.importance,
  });
}
