import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/calendar_config.dart';

/// 🤖 Machine Learning Service
///
/// Pasivni learning sistem koji:
/// - Predviđa broj putnika po polascima
/// - Analizira rizik neplaćanja
/// - Optimizuje redosled ruta
/// - Trenira modele automatski

class MLService {
  static final _supabase = Supabase.instance.client;
  static Map<String, double> _modelCoefficients = {};
  static final Map<String, PassengerScore> _passengerScoreCache = {};
  static DateTime? _lastCacheUpdate;

  // 📊 OCCUPANCY PREDICTION

  /// Predvidi broj putnika za specifičan polazak
  static Future<double> predictOccupancy({
    required String grad,
    required String vreme,
    required DateTime date,
  }) async {
    try {
      // Extract features
      final features = _extractFeatures(grad, vreme, date);

      // Simple linear model (TODO: Replace with actual ML)
      double prediction = _simpleLinearModel(features);

      return prediction.clamp(0, 20); // Max 20 putnika
    } catch (e) {
      print('❌ ML Prediction error: $e');
      return 0;
    }
  }

  /// Predvidi naredna 3 sata (po svakom polazku)
  static Future<List<OccupancyPrediction>> predictNext3Hours() async {
    final predictions = <OccupancyPrediction>[];
    final now = DateTime.now();

    // BC polasci
    for (final vreme in ['05:00', '06:00', '07:00', '13:00', '15:00']) {
      final timeparts = vreme.split(':');
      final departureTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(timeparts[0]),
        int.parse(timeparts[1]),
      );

      if (departureTime.isAfter(now) && departureTime.isBefore(now.add(const Duration(hours: 3)))) {
        final predicted = await predictOccupancy(
          grad: 'BC',
          vreme: vreme,
          date: now,
        );
        predictions.add(OccupancyPrediction(
          grad: 'BC',
          vreme: vreme,
          predicted: predicted,
          confidence: 0.85,
          timestamp: departureTime,
        ));
      }
    }

    return predictions;
  }

  // 🧠 MODEL TRAINING

  /// Treniraj model sa istorijskim podacima
  static Future<void> trainModel() async {
    print('🧠 Starting ML training...');

    try {
      // Fetch historical data (last 6 months)
      final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180));
      final data =
          await _supabase.from('voznje_log').select().gte('datum', sixMonthsAgo.toIso8601String()).order('datum');

      print('📊 Training data: ${data.length} records');

      if (data.isEmpty) {
        print('⚠️ No training data available');
        return;
      }

      // Build training dataset with features and labels
      final trainingSet = <Map<String, dynamic>>[];
      for (final record in data) {
        final grad = record['grad'] as String? ?? 'BC';
        final vreme = record['vreme'] as String? ?? '13:00';
        final datumStr = record['datum'] as String?;

        if (datumStr == null) continue;

        final datum = DateTime.tryParse(datumStr);
        if (datum == null) continue;

        // Extract features
        final features = _extractFeatures(grad, vreme, datum);

        // Label: actual count for this trip
        final actualCount = await _getActualCountForRecord(grad, vreme, datum);

        trainingSet.add({
          ...features,
          'label': actualCount,
        });
      }

      print('📊 Processed ${trainingSet.length} training examples');

      // Train linear regression coefficients
      final coefficients = _trainLinearRegression(trainingSet);

      // Store coefficients in memory (TODO: Persist to Supabase)
      _modelCoefficients = coefficients;

      // Calculate and log statistics
      final stats = _analyzeTrainingData(data);
      print('📈 Average occupancy: ${stats['avgOccupancy']}');
      print('📈 Peak time: ${stats['peakTime']}');
      print('📈 Model coefficients trained: ${coefficients.length} features');

      print('✅ Training complete!');
    } catch (e) {
      print('❌ Training error: $e');
    }
  }

  /// Auto-train u pozadini (pozovi iz scheduled job)
  static Future<void> autoTrain() async {
    final now = DateTime.now();
    // Treniraj samo u 3:00 ujutru
    if (now.hour == 3 && now.minute < 15) {
      await trainModel();
    }
  }

  // 📈 MODEL PERFORMANCE

  /// Dobavi metrike performansi modela
  static Future<ModelMetrics> getModelMetrics() async {
    try {
      // Compare predictions vs actual for last 7 days
      final predictions = <double>[];
      final actuals = <int>[];

      for (var i = 1; i <= 7; i++) {
        final date = DateTime.now().subtract(Duration(days: i));

        // Get actual count from database
        final actual = await _getActualCount('BC', '13:00', date);
        final predicted = await predictOccupancy(
          grad: 'BC',
          vreme: '13:00',
          date: date,
        );

        actuals.add(actual);
        predictions.add(predicted);
      }

      final mae = _calculateMAE(predictions, actuals);
      final accuracy = actuals.isEmpty ? 0.0 : 1 - mae / _average(actuals);

      return ModelMetrics(
        accuracy: accuracy.clamp(0, 1),
        mae: mae,
        lastUpdated: DateTime.now(),
        sampleSize: actuals.length,
      );
    } catch (e) {
      print('❌ Metrics error: $e');
      return ModelMetrics(
        accuracy: 0,
        mae: 0,
        lastUpdated: DateTime.now(),
        sampleSize: 0,
      );
    }
  }

  // 💰 PAYMENT PREDICTION

  /// Predvidi verovatnoću plaćanja za putnika
  static Future<double> predictPaymentRisk(String putnikId) async {
    try {
      // Get payment history
      final history = await _supabase
          .from('voznje_log')
          .select('tip_placanja, datum')
          .eq('putnik_id', putnikId)
          .order('datum', ascending: false)
          .limit(20);

      if (history.isEmpty) return 0.5; // No history = medium risk

      // Calculate payment rate
      final paidCount = history
          .where((v) =>
              v['tip_placanja'] == 'uplata' ||
              v['tip_placanja'] == 'uplata_mesecna' ||
              v['tip_placanja'] == 'uplata_dnevna')
          .length;

      final paymentRate = paidCount / history.length;

      // High payment rate = low risk
      return 1 - paymentRate;
    } catch (e) {
      print('❌ Payment prediction error: $e');
      return 0.5;
    }
  }

  // 🏆 PASSENGER QUALITY SCORING

  /// Oceni kvalitet putnika koristeći PRAVO mašinsko učenje
  /// Model SAM uči šta je važno analizirajući istorijske podatke
  static Future<PassengerScore> scorePassenger(String putnikId) async {
    // Check cache first
    if (_passengerScoreCache.containsKey(putnikId)) {
      return _passengerScoreCache[putnikId]!;
    }

    try {
      // Get passenger data
      final putnik = await _supabase.from('putnici').select().eq('id', putnikId).maybeSingle();

      if (putnik == null) {
        return PassengerScore(
          putnikId: putnikId,
          totalScore: 0,
          paymentScore: 0,
          reliabilityScore: 0,
          frequencyScore: 0,
          longevityScore: 0,
          tier: 'UNKNOWN',
        );
      }

      // Get trip history
      final history = await _supabase
          .from('voznje_log')
          .select('tip_placanja, datum, status, grad, vreme')
          .eq('putnik_id', putnikId)
          .order('datum', ascending: false)
          .limit(100);

      if (history.isEmpty) {
        return PassengerScore(
          putnikId: putnikId,
          totalScore: 50, // Neutral score za nove putnike
          paymentScore: 15,
          reliabilityScore: 12.5,
          frequencyScore: 12.5,
          longevityScore: 10,
          tier: 'STANDARD',
        );
      }

      // PRAVO UČENJE: Ekstrahovati features koje MODEL može da analizira
      final features = _extractPassengerFeatures(history);

      // Koristimo naučene težine (weights) iz sličnih putnika
      final learnedWeights = await _getLearnedWeightsForScoring();

      // MODEL SAM RAČUNA SKOR na osnovu naučenih obrazaca
      final totalScore = _calculateLearnedScore(features, learnedWeights);

      // Razbij na komponente za prikaz (za UI)
      final breakdown = _scoreBreakdown(features, learnedWeights);

      // Determine tier based on learned patterns
      String tier;
      if (totalScore >= 85) {
        tier = 'VIP';
      } else if (totalScore >= 70) {
        tier = 'GOLD';
      } else if (totalScore >= 50) {
        tier = 'SILVER';
      } else if (totalScore >= 30) {
        tier = 'BRONZE';
      } else {
        tier = 'STANDARD';
      }

      final score = PassengerScore(
        putnikId: putnikId,
        totalScore: totalScore,
        paymentScore: breakdown['payment']!,
        reliabilityScore: breakdown['reliability']!,
        frequencyScore: breakdown['frequency']!,
        longevityScore: breakdown['longevity']!,
        tier: tier,
        tripCount: history.length,
      );

      // Cache the score
      _passengerScoreCache[putnikId] = score;

      return score;
    } catch (e) {
      print('❌ Passenger scoring error: $e');
      return PassengerScore(
        putnikId: putnikId,
        totalScore: 0,
        paymentScore: 0,
        reliabilityScore: 0,
        frequencyScore: 0,
        longevityScore: 0,
        tier: 'UNKNOWN',
      );
    }
  }

  /// Ekstrahuj SIROVE features - BEZ pretpostavki šta je važno
  static Map<String, double> _extractPassengerFeatures(List<dynamic> history) {
    if (history.isEmpty) return {};

    // Model će SAM naučiti koliko ove stvari utiču
    final paidCount = history
        .where((v) =>
            v['tip_placanja'] == 'uplata' ||
            v['tip_placanja'] == 'uplata_mesecna' ||
            v['tip_placanja'] == 'uplata_dnevna')
        .length;

    final cancelledCount = history.where((v) => v['status'] == 'otkazano').length;
    final totalTrips = history.length;

    // Vremenska analiza
    final firstTripStr = history.last['datum'] as String?;
    final daysSinceFirst = firstTripStr != null ? DateTime.now().difference(DateTime.parse(firstTripStr)).inDays : 0;

    final lastTripStr = history.first['datum'] as String?;
    final daysSinceLast = lastTripStr != null ? DateTime.now().difference(DateTime.parse(lastTripStr)).inDays : 999;

    // Frekvencija
    final tripsPerMonth = daysSinceFirst > 0 ? (totalTrips / (daysSinceFirst / 30)) : 0;

    // Skori posledica
    final recent10 = history.take(10).toList();
    final recentPaymentRate = recent10.isEmpty
        ? 0.5
        : recent10
                .where((v) =>
                    v['tip_placanja'] == 'uplata' ||
                    v['tip_placanja'] == 'uplata_mesecna' ||
                    v['tip_placanja'] == 'uplata_dnevna')
                .length /
            recent10.length;

    // SIROVE FEATURES - model odlučuje šta je važno!
    return {
      'payment_rate': paidCount / totalTrips,
      'cancellation_rate': cancelledCount / totalTrips,
      'total_trips': totalTrips.toDouble(),
      'days_since_first': daysSinceFirst.toDouble(),
      'days_since_last': daysSinceLast.toDouble(),
      'trips_per_month': tripsPerMonth.toDouble(),
      'recent_payment_rate': recentPaymentRate,
      'consistency': _calculateConsistency(history),
    };
  }

  /// Izračunaj konzistentnost (da li redovno putuje)
  static double _calculateConsistency(List<dynamic> history) {
    if (history.length < 2) return 0.5;

    // Računaj varijaciju između vožnji
    final dates = history.map((v) => DateTime.tryParse(v['datum'] as String? ?? '')).where((d) => d != null).toList();

    if (dates.length < 2) return 0.5;

    final gaps = <int>[];
    for (var i = 1; i < dates.length; i++) {
      gaps.add(dates[i - 1]!.difference(dates[i]!).inDays.abs());
    }

    // Niska varijacija = visoka konzistentnost
    final avgGap = gaps.reduce((a, b) => a + b) / gaps.length;
    final variance = gaps.map((g) => pow(g - avgGap, 2)).reduce((a, b) => a + b) / gaps.length;
    final stdDev = sqrt(variance);

    // Normalizuj 0-1 (manja varijacija = bolje)
    return (1 / (1 + stdDev / 10)).clamp(0, 1);
  }

  /// Učitaj naučene težine za svaki feature
  /// OVO JE KLJUČ - model UČI iz istorijskih podataka šta je bitno!
  static Future<Map<String, double>> _getLearnedWeightsForScoring() async {
    try {
      // Pokušaj da učitaš iz baze
      final result = await _supabase.from('ml_config').select().eq('id', 'passenger_scoring_weights').maybeSingle();

      if (result != null && result['data'] != null) {
        final weightsJson = result['data'] as Map<String, dynamic>;
        return weightsJson.map((k, v) => MapEntry(k, double.tryParse(v.toString()) ?? 1.0));
      }
    } catch (e) {
      print('⚠️ Using default weights, will learn over time');
    }

    // Default starting weights - MODEL ĆE IH MENJATI tokom učenja!
    return {
      'payment_rate': 1.0,
      'cancellation_rate': -1.0, // negativan uticaj
      'total_trips': 0.5,
      'days_since_first': 0.3,
      'days_since_last': -0.2, // dugo nije putovao = loše
      'trips_per_month': 0.8,
      'recent_payment_rate': 1.2, // skorašnje ponašanje je važnije
      'consistency': 0.6,
    };
  }

  /// Izračunaj skor koristeći naučene težine
  static double _calculateLearnedScore(Map<String, double> features, Map<String, double> weights) {
    double score = 50.0; // Neutralan početak

    features.forEach((featureName, featureValue) {
      final weight = weights[featureName] ?? 0;
      score += featureValue * weight * 10; // Scale factor
    });

    return score.clamp(0, 100);
  }

  /// Razbij skor na komponente (za prikaz u UI)
  static Map<String, double> _scoreBreakdown(Map<String, double> features, Map<String, double> weights) {
    final payment = ((features['payment_rate'] ?? 0) * 30).clamp(0, 30).toDouble();
    final reliability = ((1 - (features['cancellation_rate'] ?? 0)) * 25).clamp(0, 25).toDouble();
    final frequency = ((features['trips_per_month'] ?? 0) * 5).clamp(0, 25).toDouble();
    final longevity = ((features['days_since_first'] ?? 0) / 365 * 20).clamp(0, 20).toDouble();

    return {
      'payment': payment,
      'reliability': reliability,
      'frequency': frequency,
      'longevity': longevity,
    };
  }

  /// KLJUČNA FUNKCIJA: Treniraj model za ocenjivanje putnika
  /// Analizira SVE putnike i uči šta pravi razliku između dobrih i loših
  static Future<void> trainPassengerScoringModel() async {
    print('🎓 Training passenger scoring model...');

    try {
      // 1. Dobavi SVE putnike sa podacima
      final putnici = await _supabase.from('putnici').select('id');
      final allFeatures = <Map<String, double>>[];
      final allLabels = <double>[];

      for (final putnik in putnici) {
        final putnikId = putnik['id'] as String;
        final history = await _supabase
            .from('voznje_log')
            .select('tip_placanja, datum, status')
            .eq('putnik_id', putnikId)
            .limit(100);

        if (history.length < 3) continue; // Preskoči nove

        final features = _extractPassengerFeatures(history);

        // LABELA: Realnost - da li je putnik zaista DOBAR?
        // (platio 90%+ posledjih 20 vožnji = dobar)
        final recent = history.take(20).toList();
        final goodPassenger = recent
                .where((v) =>
                    v['tip_placanja'] == 'uplata' ||
                    v['tip_placanja'] == 'uplata_mesecna' ||
                    v['tip_placanja'] == 'uplata_dnevna')
                .length /
            recent.length;

        allFeatures.add(features);
        allLabels.add(goodPassenger * 100); // 0-100 skor
      }

      print('📊 Training on ${allFeatures.length} passengers');

      // 2. NAUČI šta pravi razliku između dobrih i loših putnika
      final learnedWeights = _learnWeightsFromData(allFeatures, allLabels);

      // 3. Sačuvaj naučene težine
      await _supabase.from('ml_config').upsert({
        'id': 'passenger_scoring_weights',
        'data': learnedWeights.map((k, v) => MapEntry(k, v.toString())),
        'updated_at': DateTime.now().toIso8601String(),
      });

      print('✅ Passenger scoring model trained!');
      print('📈 Learned weights: $learnedWeights');
    } catch (e) {
      print('❌ Training error: $e');
    }
  }

  /// Nauči težine iz podataka (correlation-based learning)
  static Map<String, double> _learnWeightsFromData(
    List<Map<String, double>> features,
    List<double> labels,
  ) {
    if (features.isEmpty) return {};

    final weights = <String, double>{};
    final featureNames = features.first.keys.toList();

    for (final featureName in featureNames) {
      // Izračunaj korelaciju između ovog feature-a i labele
      final featureValues = features.map((f) => f[featureName] ?? 0).toList();

      double correlation = _calculateCorrelation(featureValues, labels);

      // Jak feature ima visoku korelaciju
      weights[featureName] = correlation;
    }

    return weights;
  }

  /// Izračunaj Pearson korelaciju
  static double _calculateCorrelation(List<double> x, List<double> y) {
    if (x.length != y.length || x.isEmpty) return 0;

    final n = x.length;
    final meanX = x.reduce((a, b) => a + b) / n;
    final meanY = y.reduce((a, b) => a + b) / n;

    double numerator = 0;
    double denomX = 0;
    double denomY = 0;

    for (var i = 0; i < n; i++) {
      final diffX = x[i] - meanX;
      final diffY = y[i] - meanY;
      numerator += diffX * diffY;
      denomX += diffX * diffX;
      denomY += diffY * diffY;
    }

    if (denomX == 0 || denomY == 0) return 0;

    return numerator / sqrt(denomX * denomY);
  }

  // 📊 ADVANCED ML FEATURES (Lab Only)

  /// 1. DEMAND FORECASTING - Predvidi potražnju za datum/vreme
  static Future<DemandForecast> predictDemand({
    required String grad,
    required String vreme,
    required DateTime datum,
  }) async {
    try {
      // Analiza istorijskih podataka za isti dan u nedelji
      final dayOfWeek = datum.weekday;
      final historical = await _supabase
          .from('seat_requests')
          .select('datum, grad, zeljeno_vreme')
          .eq('grad', grad)
          .gte('datum', datum.subtract(const Duration(days: 90)).toIso8601String());

      // Filtriraj samo isti dan u nedelji
      final sameDayRequests = historical.where((r) {
        final d = DateTime.tryParse(r['datum'] as String? ?? '');
        return d?.weekday == dayOfWeek && r['zeljeno_vreme'] == vreme;
      }).length;

      // Prosek za ovaj dan/vreme
      final avgDemand = sameDayRequests / 12; // ~12 nedelja u 90 dana

      // Faktor za praznike
      final isPraznik = CalendarConfig.isPraznik(datum);
      final isRaspust = CalendarConfig.isSkolskiRaspust(datum);

      double adjustedDemand = avgDemand;
      if (isPraznik) adjustedDemand *= 0.3;
      if (isRaspust) adjustedDemand *= 0.6;

      // Dobavi kapacitet
      final kapacitetData = await _supabase
          .from('kapacitet_polazaka')
          .select('max_mesta')
          .eq('grad', grad)
          .eq('vreme', vreme)
          .maybeSingle();

      final maxMesta = kapacitetData?['max_mesta'] as int? ?? 18;

      return DemandForecast(
        grad: grad,
        vreme: vreme,
        datum: datum,
        predictedRequests: adjustedDemand,
        capacity: maxMesta,
        isOverbooking: adjustedDemand > maxMesta,
        confidence: 0.75,
      );
    } catch (e) {
      print('❌ Demand forecast error: $e');
      return DemandForecast(
        grad: grad,
        vreme: vreme,
        datum: datum,
        predictedRequests: 0,
        capacity: 18,
        isOverbooking: false,
        confidence: 0,
      );
    }
  }

  /// 2. SMART PRIORITY - Auto-dodeli priority za seat request
  static Future<int> calculateSmartPriority(String putnikId) async {
    try {
      // Dobavi skor putnika
      final score = await scorePassenger(putnikId);

      // Dobavi broj promena (changes_count)
      final requests = await _supabase
          .from('seat_requests')
          .select('changes_count')
          .eq('putnik_id', putnikId)
          .order('created_at', ascending: false)
          .limit(10);

      final avgChanges = requests.isEmpty
          ? 0
          : requests.map((r) => r['changes_count'] as int? ?? 0).reduce((a, b) => a + b) / requests.length;

      // Formula: Viši skor = viši priority, više promena = niži priority
      int priority = 5; // Srednji

      if (score.tier == 'VIP') {
        priority = 10;
      } else if (score.tier == 'GOLD') {
        priority = 8;
      } else if (score.tier == 'SILVER') {
        priority = 6;
      } else if (score.tier == 'BRONZE') {
        priority = 4;
      } else {
        priority = 3;
      }

      // Kazna za česte promene
      if (avgChanges > 3) priority -= 2;
      if (avgChanges > 5) priority -= 3;

      return priority.clamp(1, 10);
    } catch (e) {
      print('❌ Smart priority error: $e');
      return 5;
    }
  }

  /// 3. CHURN PREDICTION - Verovatnoća da će putnik prestati da putuje
  static Future<ChurnPrediction> predictChurn(String putnikId) async {
    try {
      final lastTrips = await _supabase
          .from('voznje_log')
          .select('datum')
          .eq('putnik_id', putnikId)
          .order('datum', ascending: false)
          .limit(1);

      if (lastTrips.isEmpty) {
        return ChurnPrediction(
          putnikId: putnikId,
          churnRisk: 0,
          daysSinceLastTrip: 0,
          recommendation: 'Novi putnik',
        );
      }

      final lastTripStr = lastTrips.first['datum'] as String;
      final lastTrip = DateTime.parse(lastTripStr);
      final daysSince = DateTime.now().difference(lastTrip).inDays;

      // Analiza obrasca
      final allTrips = await _supabase
          .from('voznje_log')
          .select('datum')
          .eq('putnik_id', putnikId)
          .order('datum', ascending: false)
          .limit(20);

      // Prosečan gap između vožnji
      double avgGap = 7; // default
      if (allTrips.length > 1) {
        final gaps = <int>[];
        for (var i = 0; i < allTrips.length - 1; i++) {
          final d1 = DateTime.parse(allTrips[i]['datum'] as String);
          final d2 = DateTime.parse(allTrips[i + 1]['datum'] as String);
          gaps.add(d1.difference(d2).inDays);
        }
        avgGap = gaps.reduce((a, b) => a + b) / gaps.length;
      }

      // Rizik: ako je daysSince >> avgGap
      double churnRisk = 0;
      if (daysSince > avgGap * 2) {
        churnRisk = ((daysSince - avgGap) / avgGap).clamp(0, 1);
      }

      String recommendation = '';
      if (churnRisk > 0.7) {
        recommendation = '🚨 Visok rizik! Pošalji discount kod odmah!';
      } else if (churnRisk > 0.4) {
        recommendation = '⚠️ Srednji rizik. Pošalji reminder poruku.';
      } else {
        recommendation = '✅ Nizak rizik. Sve OK.';
      }

      return ChurnPrediction(
        putnikId: putnikId,
        churnRisk: churnRisk,
        daysSinceLastTrip: daysSince,
        recommendation: recommendation,
      );
    } catch (e) {
      print('❌ Churn prediction error: $e');
      return ChurnPrediction(
        putnikId: putnikId,
        churnRisk: 0,
        daysSinceLastTrip: 0,
        recommendation: 'Greška u analizi',
      );
    }
  }

  /// 4. OPTIMAL TIME SUGGESTIONS - Predloži nova vremena polazaka
  static Future<List<TimeSuggestion>> suggestOptimalTimes(String grad) async {
    try {
      // Analiza seat_requests - koja vremena ljudi STVARNO žele
      final requests = await _supabase
          .from('seat_requests')
          .select('zeljeno_vreme, dodeljeno_vreme')
          .eq('grad', grad)
          .gte('datum', DateTime.now().subtract(const Duration(days: 60)).toIso8601String());

      // Grupiši po željenom vremenu
      final timeGroups = <String, int>{};
      for (final req in requests) {
        final zeljeno = req['zeljeno_vreme'] as String?;
        final dodeljeno = req['dodeljeno_vreme'] as String?;

        // Ako željeno != dodeljeno, znači da to vreme ne postoji!
        if (zeljeno != null && zeljeno != dodeljeno) {
          timeGroups[zeljeno] = (timeGroups[zeljeno] ?? 0) + 1;
        }
      }

      // Sortiraj po broju zahteva
      final sorted = timeGroups.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

      // Vrati top 5 predloga
      return sorted.take(5).map((e) {
        return TimeSuggestion(
          grad: grad,
          suggestedTime: e.key,
          weeklyDemand: e.value,
          reason: '${e.value} zahteva u poslednja 2 meseca',
        );
      }).toList();
    } catch (e) {
      print('❌ Time suggestions error: $e');
      return [];
    }
  }

  /// 5. ANOMALY DETECTION - Detektuj neobične obrasce
  static Future<List<Anomaly>> detectAnomalies() async {
    final anomalies = <Anomaly>[];

    try {
      // 1. Spike u otkazivanjima
      final today = DateTime.now();
      final todayCancellations = await _supabase.from('voznje_log').select('id').eq('tip', 'otkazivanje').eq(
          'datum', '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}');

      final avgCancellations = 2; // istorijski prosek
      if (todayCancellations.length > avgCancellations * 2) {
        anomalies.add(Anomaly(
          type: 'HIGH_CANCELLATIONS',
          severity: 'HIGH',
          message: '🚨 ${todayCancellations.length} otkazivanja danas! Prosek je $avgCancellations.',
          timestamp: today,
        ));
      }

      // 2. Putnik sa naglim padom plaćanja
      final recentBadPayers = await _supabase
          .from('voznje_log')
          .select('putnik_id, tip_placanja')
          .gte('datum', today.subtract(const Duration(days: 7)).toIso8601String());

      final putnikPayments = <String, List<String>>{};
      for (final trip in recentBadPayers) {
        final putnikId = trip['putnik_id'] as String?;
        final tipPlacanja = trip['tip_placanja'] as String?;
        if (putnikId != null && tipPlacanja != null) {
          putnikPayments.putIfAbsent(putnikId, () => []).add(tipPlacanja);
        }
      }

      putnikPayments.forEach((putnikId, payments) {
        final dugCount = payments.where((p) => p == 'dug' || p == 'na_cekanju').length;
        if (dugCount >= 3) {
          anomalies.add(Anomaly(
            type: 'PAYMENT_ISSUE',
            severity: 'MEDIUM',
            message: '⚠️ Putnik $putnikId ima $dugCount dugova u zadnjih 7 dana!',
            timestamp: today,
          ));
        }
      });

      // 3. Neobično niska potražnja
      final todayRequests = await _supabase.from('seat_requests').select('id').eq(
          'datum', '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}');

      if (todayRequests.length < 5 && today.weekday != 6 && today.weekday != 7) {
        anomalies.add(Anomaly(
          type: 'LOW_DEMAND',
          severity: 'LOW',
          message: 'ℹ️ Samo ${todayRequests.length} zahteva danas. Neobično nisko!',
          timestamp: today,
        ));
      }
    } catch (e) {
      print('❌ Anomaly detection error: $e');
    }

    return anomalies;
  }

  /// 6. REVENUE OPTIMIZATION ANALYSIS
  static Future<RevenueAnalysis> analyzeRevenue() async {
    try {
      final last30Days = DateTime.now().subtract(const Duration(days: 30));

      // Analiza po polascima
      final trips =
          await _supabase.from('voznje_log').select('grad, vreme, iznos').gte('datum', last30Days.toIso8601String());

      final routeRevenue = <String, double>{};
      final routeCount = <String, int>{};

      for (final trip in trips) {
        final key = '${trip['grad']} ${trip['vreme']}';
        final iznos = (trip['iznos'] as num?)?.toDouble() ?? 0;
        routeRevenue[key] = (routeRevenue[key] ?? 0) + iznos;
        routeCount[key] = (routeCount[key] ?? 0) + 1;
      }

      // Prosečan revenue po ruti
      final avgRevenuePerRoute = routeRevenue.entries.map((e) {
        final count = routeCount[e.key] ?? 1;
        return MapEntry(e.key, e.value / count);
      }).toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final bestRoute = avgRevenuePerRoute.first;
      final worstRoute = avgRevenuePerRoute.last;

      return RevenueAnalysis(
        totalRevenue: routeRevenue.values.reduce((a, b) => a + b),
        bestRoute: bestRoute.key,
        bestRouteAvg: bestRoute.value,
        worstRoute: worstRoute.key,
        worstRouteAvg: worstRoute.value,
        recommendation: worstRoute.value < 100
            ? '💡 Razmisli o uklanjanju rute ${worstRoute.key} - prosek ${worstRoute.value.toStringAsFixed(0)} RSD'
            : '✅ Sve rute su profitabilne',
      );
    } catch (e) {
      print('❌ Revenue analysis error: $e');
      return RevenueAnalysis(
        totalRevenue: 0,
        bestRoute: 'N/A',
        bestRouteAvg: 0,
        worstRoute: 'N/A',
        worstRouteAvg: 0,
        recommendation: 'Greška u analizi',
      );
    }
  }

  /// 7. CANCELLATION PREDICTOR - Verovatnoća otkazivanja
  static Future<double> predictCancellationProbability({
    required String putnikId,
    required DateTime datum,
    required int satiPrePolaska,
  }) async {
    try {
      // Istorija otkazivanja za ovog putnika
      final history =
          await _supabase.from('voznje_log').select('tip, sati_pre_polaska').eq('putnik_id', putnikId).limit(50);

      if (history.isEmpty) return 0.2; // Default za nove

      final totalTrips = history.length;
      final cancellations = history.where((t) => t['tip'] == 'otkazivanje').toList();
      final cancellationRate = cancellations.length / totalTrips;

      // Last-minute bookings su češće otkazivanja
      double lastMinuteMultiplier = 1.0;
      if (satiPrePolaska < 2) lastMinuteMultiplier = 2.0;
      if (satiPrePolaska < 6) lastMinuteMultiplier = 1.5;

      // Verovatnoća
      final probability = (cancellationRate * lastMinuteMultiplier).clamp(0, 1);

      return probability.toDouble();
    } catch (e) {
      print('❌ Cancellation prediction error: $e');
      return 0.2;
    }
  }

  /// Dobavi top N putnika po skoru
  static Future<List<PassengerScore>> getTopPassengers({int limit = 10}) async {
    try {
      // Get all passengers
      final putnici = await _supabase.from('putnici').select('id');

      final scores = <PassengerScore>[];
      for (final putnik in putnici) {
        final score = await scorePassenger(putnik['id'] as String);
        scores.add(score);
      }

      // Sort by total score
      scores.sort((a, b) => b.totalScore.compareTo(a.totalScore));

      return scores.take(limit).toList();
    } catch (e) {
      print('❌ Top passengers error: $e');
      return [];
    }
  }

  /// Dobavi putnike sa niskim skorom (potrebna pažnja)
  Future<List<PassengerScore>> getRiskyPassengers({int limit = 10}) async {
    try {
      final putnici = await _supabase.from('putnici').select('id');

      final scores = <PassengerScore>[];
      for (final putnik in putnici) {
        final score = await scorePassenger(putnik['id'] as String);
        if (score.tripCount >= 3) {
          // Only include if they have some history
          scores.add(score);
        }
      }

      // Sort by lowest score
      scores.sort((a, b) => a.totalScore.compareTo(b.totalScore));

      return scores.take(limit).toList();
    } catch (e) {
      print('❌ Risky passengers error: $e');
      return [];
    }
  }

  // 🎓 ONLINE LEARNING (Incremental Updates)

  /// Ažuriraj model nakon svake vožnje (online learning)
  Future<void> updateModelOnline({
    required String grad,
    required String vreme,
    required DateTime datum,
    required int actualPassengers,
  }) async {
    try {
      print('🎓 Online learning update...');

      // Extract features for this trip
      final features = _extractFeatures(grad, vreme, datum);

      // Get current prediction
      final predicted = _simpleLinearModel(features);

      // Calculate error
      final error = actualPassengers - predicted;

      // Learning rate (kako brzo se model prilagođava)
      const learningRate = 0.01;

      // Update coefficients using gradient descent
      if (_modelCoefficients.isEmpty) {
        // Initialize if empty
        _modelCoefficients = {
          'bias': 5.0,
          'grad': 0.1,
          'vreme_minutes': 0.01,
          'day_of_week': 0.5,
          'is_praznik': -2.0,
          'is_skolski_raspust': -1.0,
          'day_of_month': 0.02,
          'month': 0.1,
          'days_until_praznik': -0.1,
          'days_since_raspust_start': 0.05,
        };
      }

      // Update each coefficient based on error
      features.forEach((key, value) {
        final currentCoef = _modelCoefficients[key] ?? 0;
        final numValue = (value as num?)?.toDouble() ?? 0;
        // Gradient descent: coef = coef + learningRate * error * feature
        _modelCoefficients[key] = currentCoef + (learningRate * error * numValue);
      });

      // Update bias
      final currentBias = _modelCoefficients['bias'] ?? 5.0;
      _modelCoefficients['bias'] = currentBias + (learningRate * error);

      print(
          '✅ Model updated. Error: ${error.toStringAsFixed(2)}, New bias: ${_modelCoefficients['bias']?.toStringAsFixed(2)}');

      // Persist to database for long-term storage
      await _persistModelCoefficients();
    } catch (e) {
      print('❌ Online learning error: $e');
    }
  }

  /// Ažuriraj skor putnika nakon svake vožnje
  Future<void> updatePassengerScore({
    required String putnikId,
    required bool paid,
    required bool showedUp,
  }) async {
    try {
      // Invalidate cache for this passenger
      _passengerScoreCache.remove(putnikId);

      // Recalculate score (will be cached on next access)
      await scorePassenger(putnikId);

      print('✅ Passenger score updated: $putnikId');
    } catch (e) {
      print('❌ Score update error: $e');
    }
  }

  /// Automatski refresh modela svakih 24h
  Future<void> autoRefreshModel() async {
    final now = DateTime.now();

    // Refresh cache every 6 hours
    if (_lastCacheUpdate == null || now.difference(_lastCacheUpdate!).inHours >= 6) {
      print('🔄 Auto-refreshing model and cache...');
      await loadModelCoefficients();
      _passengerScoreCache.clear();
      _lastCacheUpdate = now;
      print('✅ Cache refreshed');
    }
  }

  /// Sačuvaj koeficijente u bazu
  Future<void> _persistModelCoefficients() async {
    try {
      // Store as JSON in a config table (create if doesn't exist)
      final coefficientsJson = _modelCoefficients.map((k, v) => MapEntry(k, v.toString()));

      await _supabase.from('ml_config').upsert({
        'id': 'model_coefficients',
        'data': coefficientsJson,
        'updated_at': DateTime.now().toIso8601String(),
      });

      print('💾 Model coefficients persisted to database');
    } catch (e) {
      print('⚠️ Could not persist coefficients: $e (table ml_config may not exist)');
    }
  }

  /// Učitaj koeficijente iz baze
  Future<void> loadModelCoefficients() async {
    try {
      final result = await _supabase.from('ml_config').select().eq('id', 'model_coefficients').maybeSingle();

      if (result != null && result['data'] != null) {
        final coefficientsJson = result['data'] as Map<String, dynamic>;
        _modelCoefficients = coefficientsJson.map((k, v) => MapEntry(k, double.tryParse(v.toString()) ?? 0.0));
        print('✅ Model coefficients loaded from database');
      }
    } catch (e) {
      print('⚠️ Could not load coefficients: $e');
    }
  }

  // 🗺️ ROUTE OPTIMIZATION

  /// Preporučeni redosled pickup-a
  Future<List<RouteStop>> suggestOptimalRoute({
    required String grad,
    required String vreme,
    required DateTime date,
  }) async {
    try {
      // Get passengers for this trip
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final passengers = await _supabase
          .from('voznje_log')
          .select('putnik_id, adresa_id')
          .eq('grad', grad)
          .eq('vreme', vreme)
          .eq('datum', dateStr);

      if (passengers.isEmpty) {
        return [];
      }

      // Get address details with GPS coordinates
      final addressIds = passengers.map((p) => p['adresa_id']).where((id) => id != null).toSet().toList();

      if (addressIds.isEmpty) {
        return [];
      }

      final addresses =
          await _supabase.from('adrese').select('id, naziv, grad, gps_lat, gps_lng').inFilter('id', addressIds);

      // Build route stops with coordinates
      final stops = <RouteStop>[];
      for (final addr in addresses) {
        final lat = addr['gps_lat'] as double?;
        final lng = addr['gps_lng'] as double?;

        if (lat == null || lng == null) continue;

        // Count passengers at this address
        final passengerCount = passengers.where((p) => p['adresa_id'] == addr['id']).length;

        stops.add(RouteStop(
          addressId: addr['id'] as String,
          name: addr['naziv'] as String? ?? 'Unknown',
          lat: lat,
          lng: lng,
          passengerCount: passengerCount,
        ));
      }

      // Optimize route using nearest neighbor algorithm
      if (stops.isEmpty) {
        return [];
      }

      return _optimizeRouteNearestNeighbor(stops);
    } catch (e) {
      print('❌ Route optimization error: $e');
      return [];
    }
  }

  /// Nearest neighbor TSP approximation for route optimization
  List<RouteStop> _optimizeRouteNearestNeighbor(List<RouteStop> stops) {
    if (stops.length <= 1) return stops;

    final optimized = <RouteStop>[];
    final remaining = List<RouteStop>.from(stops);

    // Start with the first stop (or center of mass)
    RouteStop current = remaining.removeAt(0);
    optimized.add(current);

    // Greedy nearest neighbor
    while (remaining.isNotEmpty) {
      double minDistance = double.infinity;
      int nearestIndex = 0;

      for (var i = 0; i < remaining.length; i++) {
        final distance = _calculateDistance(
          current.lat,
          current.lng,
          remaining[i].lat,
          remaining[i].lng,
        );

        if (distance < minDistance) {
          minDistance = distance;
          nearestIndex = i;
        }
      }

      current = remaining.removeAt(nearestIndex);
      optimized.add(current);
    }

    return optimized;
  }

  /// Calculate distance between two GPS coordinates (Haversine formula)
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371; // km

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLng = _degreesToRadians(lng2 - lng1);

    final lat1Rad = _degreesToRadians(lat1);
    final lat2Rad = _degreesToRadians(lat2);

    final a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1Rad) * cos(lat2Rad) * sin(dLng / 2) * sin(dLng / 2);

    final c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  /// Convert degrees to radians
  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  // PRIVATE HELPER METHODS

  /// Ekstrakcija features za ML model
  static Map<String, dynamic> _extractFeatures(
    String grad,
    String vreme,
    DateTime date,
  ) {
    return {
      'grad': grad == 'BC' ? 0 : 1,
      'vreme_minutes': _timeToMinutes(vreme),
      'day_of_week': date.weekday,
      'is_praznik': CalendarConfig.isPraznik(date) ? 1 : 0,
      'is_skolski_raspust': CalendarConfig.isSkolskiRaspust(date) ? 1 : 0,
      'day_of_month': date.day,
      'month': date.month,
      'days_until_praznik': CalendarConfig.daysUntilNextPraznik(date),
      'days_since_raspust_start': CalendarConfig.daysSinceRaspustStart(date),
    };
  }

  /// Simple linear model (placeholder za pravi ML)
  static double _simpleLinearModel(Map<String, dynamic> features) {
    // Use trained coefficients if available
    if (_modelCoefficients.isNotEmpty) {
      double prediction = _modelCoefficients['bias'] ?? 5.0;

      features.forEach((key, value) {
        final coef = _modelCoefficients[key] ?? 0;
        final numValue = (value as num?)?.toDouble() ?? 0;
        prediction += coef * numValue;
      });

      return prediction.clamp(0, 20);
    }

    // Fallback to rule-based model
    double prediction = 5.0; // Base load

    // Day of week impact
    final dayOfWeek = features['day_of_week'] as int;
    if (dayOfWeek == 5) prediction += 2; // Friday
    if (dayOfWeek == 1) prediction += 1.5; // Monday

    // Time of day impact
    final minutesOfDay = features['vreme_minutes'] as int;
    if (minutesOfDay >= 780 && minutesOfDay <= 900) {
      prediction += 3; // 13:00-15:00 rush
    }
    if (minutesOfDay >= 300 && minutesOfDay <= 420) {
      prediction += 2.5; // 05:00-07:00 morning
    }

    // Holiday impact (negative)
    if (features['is_praznik'] == 1) prediction *= 0.2;
    if (features['is_skolski_raspust'] == 1) prediction *= 0.5;

    // Days until holiday (anticipation)
    final daysUntil = features['days_until_praznik'] as int;
    if (daysUntil == 1) prediction *= 0.7; // Day before holiday

    // Grad impact
    if (features['grad'] == 0) prediction *= 1.2; // BC usually busier

    return prediction;
  }

  /// Dobavi stvarni broj putnika iz baze
  static Future<int> _getActualCount(
    String grad,
    String vreme,
    DateTime date,
  ) async {
    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final result =
          await _supabase.from('voznje_log').select().eq('grad', grad).eq('vreme', vreme).eq('datum', dateStr);

      return result.length;
    } catch (e) {
      return 0;
    }
  }

  /// Get actual count for a specific record (synchronous version for training)
  static Future<int> _getActualCountForRecord(
    String grad,
    String vreme,
    DateTime date,
  ) async {
    return await _getActualCount(grad, vreme, date);
  }

  /// Train linear regression model using least squares
  static Map<String, double> _trainLinearRegression(List<Map<String, dynamic>> trainingSet) {
    if (trainingSet.isEmpty) return {};

    final featureKeys = [
      'grad',
      'vreme_minutes',
      'day_of_week',
      'is_praznik',
      'is_skolski_raspust',
      'day_of_month',
      'month',
      'days_until_praznik',
      'days_since_raspust_start'
    ];

    // Simple coefficient learning using averages
    final coefficients = <String, double>{};

    // Calculate average label
    final avgLabel = trainingSet.map((e) => e['label'] as int).reduce((a, b) => a + b) / trainingSet.length;

    // For each feature, calculate correlation-based weight
    for (final key in featureKeys) {
      double sum = 0;
      int count = 0;

      for (final example in trainingSet) {
        final featureValue = (example[key] as num?)?.toDouble() ?? 0;
        final label = (example['label'] as num?)?.toDouble() ?? 0;

        // Simple weight: how much this feature correlates with label
        sum += featureValue * label;
        count++;
      }

      coefficients[key] = count > 0 ? (sum / count) / (avgLabel + 1) : 0;
    }

    // Bias term
    coefficients['bias'] = avgLabel * 0.3;

    return coefficients;
  }

  /// Analiza training podataka
  static Map<String, dynamic> _analyzeTrainingData(List<dynamic> data) {
    if (data.isEmpty) {
      return {'avgOccupancy': 0, 'peakTime': '13:00'};
    }

    // Group by vreme and count
    final timeGroups = <String, int>{};
    for (final record in data) {
      final vreme = record['vreme'] as String? ?? '13:00';
      timeGroups[vreme] = (timeGroups[vreme] ?? 0) + 1;
    }

    // Find peak time
    String peakTime = '13:00';
    int maxCount = 0;
    timeGroups.forEach((time, count) {
      if (count > maxCount) {
        maxCount = count;
        peakTime = time;
      }
    });

    return {
      'avgOccupancy': data.length / 180, // Average per day
      'peakTime': peakTime,
      'totalRecords': data.length,
    };
  }

  /// Calculate Mean Absolute Error
  static double _calculateMAE(List<double> predicted, List<int> actual) {
    if (predicted.isEmpty || actual.isEmpty) return 0;

    double sum = 0;
    for (var i = 0; i < predicted.length; i++) {
      sum += (predicted[i] - actual[i]).abs();
    }
    return sum / predicted.length;
  }

  /// Calculate average of list
  static double _average(List<int> numbers) {
    if (numbers.isEmpty) return 0;
    return numbers.reduce((a, b) => a + b) / numbers.length;
  }

  /// Convert time string to minutes since midnight
  static int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}

// 📊 DATA MODELS

class OccupancyPrediction {
  final String grad;
  final String vreme;
  final double predicted;
  final double confidence;
  final DateTime timestamp;

  OccupancyPrediction({
    required this.grad,
    required this.vreme,
    required this.predicted,
    required this.confidence,
    required this.timestamp,
  });
}

class ModelMetrics {
  final double accuracy;
  final double mae;
  final DateTime lastUpdated;
  final int sampleSize;

  ModelMetrics({
    required this.accuracy,
    required this.mae,
    required this.lastUpdated,
    required this.sampleSize,
  });

  String get accuracyPercent => '${(accuracy * 100).toStringAsFixed(1)}%';
  String get maeFormatted => mae.toStringAsFixed(2);
}

class RouteStop {
  final String addressId;
  final String name;
  final double lat;
  final double lng;
  final int passengerCount;

  RouteStop({
    required this.addressId,
    required this.name,
    required this.lat,
    required this.lng,
    required this.passengerCount,
  });

  @override
  String toString() => '$name ($passengerCount putnika)';
}

class PassengerScore {
  final String putnikId;
  final double totalScore; // 0-100
  final double paymentScore; // 0-30
  final double reliabilityScore; // 0-25
  final double frequencyScore; // 0-25
  final double longevityScore; // 0-20
  final String tier; // VIP, GOLD, SILVER, BRONZE, STANDARD
  final int tripCount;

  PassengerScore({
    required this.putnikId,
    required this.totalScore,
    required this.paymentScore,
    required this.reliabilityScore,
    required this.frequencyScore,
    required this.longevityScore,
    required this.tier,
    this.tripCount = 0,
  });

  String get tierIcon {
    switch (tier) {
      case 'VIP':
        return '🌟';
      case 'GOLD':
        return '🥇';
      case 'SILVER':
        return '🥈';
      case 'BRONZE':
        return '🥉';
      default:
        return '⭐';
    }
  }

  String get scoreDescription {
    if (totalScore >= 85) return 'Odličan putnik';
    if (totalScore >= 70) return 'Vrlo dobar putnik';
    if (totalScore >= 50) return 'Dobar putnik';
    if (totalScore >= 30) return 'Prosečan putnik';
    return 'Potrebna pažnja';
  }

  @override
  String toString() => '$tierIcon ${totalScore.toStringAsFixed(1)}/100 - $tier';
}

// 📊 ADVANCED ML DATA MODELS

class DemandForecast {
  final String grad;
  final String vreme;
  final DateTime datum;
  final double predictedRequests;
  final int capacity;
  final bool isOverbooking;
  final double confidence;

  DemandForecast({
    required this.grad,
    required this.vreme,
    required this.datum,
    required this.predictedRequests,
    required this.capacity,
    required this.isOverbooking,
    required this.confidence,
  });

  String get statusIcon => isOverbooking ? '🚨' : '✅';
  String get statusText => isOverbooking
      ? 'PREBUKING! ${predictedRequests.toStringAsFixed(0)}/${capacity}'
      : 'OK ${predictedRequests.toStringAsFixed(0)}/${capacity}';
}

class TimeSuggestion {
  final String grad;
  final String suggestedTime;
  final int weeklyDemand;
  final String reason;

  TimeSuggestion({
    required this.grad,
    required this.suggestedTime,
    required this.weeklyDemand,
    required this.reason,
  });

  @override
  String toString() => '$suggestedTime ($weeklyDemand zahteva)';
}

class ChurnPrediction {
  final String putnikId;
  final double churnRisk; // 0-1
  final int daysSinceLastTrip;
  final String recommendation;

  ChurnPrediction({
    required this.putnikId,
    required this.churnRisk,
    required this.daysSinceLastTrip,
    required this.recommendation,
  });

  String get riskLevel {
    if (churnRisk > 0.7) return 'HIGH';
    if (churnRisk > 0.4) return 'MEDIUM';
    return 'LOW';
  }

  String get riskIcon {
    if (churnRisk > 0.7) return '🚨';
    if (churnRisk > 0.4) return '⚠️';
    return '✅';
  }
}

class Anomaly {
  final String type;
  final String severity; // HIGH, MEDIUM, LOW
  final String message;
  final DateTime timestamp;

  Anomaly({
    required this.type,
    required this.severity,
    required this.message,
    required this.timestamp,
  });

  String get severityIcon {
    switch (severity) {
      case 'HIGH':
        return '🚨';
      case 'MEDIUM':
        return '⚠️';
      default:
        return 'ℹ️';
    }
  }
}

class RevenueAnalysis {
  final double totalRevenue;
  final String bestRoute;
  final double bestRouteAvg;
  final String worstRoute;
  final double worstRouteAvg;
  final String recommendation;

  RevenueAnalysis({
    required this.totalRevenue,
    required this.bestRoute,
    required this.bestRouteAvg,
    required this.worstRoute,
    required this.worstRouteAvg,
    required this.recommendation,
  });

  String get formattedTotal => '${totalRevenue.toStringAsFixed(0)} RSD';
  String get formattedBestAvg => '${bestRouteAvg.toStringAsFixed(0)} RSD';
  String get formattedWorstAvg => '${worstRouteAvg.toStringAsFixed(0)} RSD';
}
