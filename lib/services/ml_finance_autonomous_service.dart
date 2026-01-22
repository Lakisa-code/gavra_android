import 'dart:async';

import 'package:flutter/foundation.dart'; // Dodaj ponovo za kDebugMode
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import 'local_notification_service.dart';
import 'ml_vehicle_autonomous_service.dart'; // 🔗 Link ka Fizičaru

/// 📊 MODEL ZA STANJE GORIVA
class FuelInventory {
  double litersInStock; // Trenutno litara na stanju (u buretu/tanku)
  double totalDebt; // Ukupan dug za gorivo (u novcu)
  double fuelPrice; // Cena po litru
  double discount; // Popust po litru
  double avgConsumption; // Prosečna potrošnja flote

  FuelInventory({
    this.litersInStock = 0,
    this.totalDebt = 0,
    this.fuelPrice = 200,
    this.discount = 10,
    this.avgConsumption = 10.5,
  });
}

/// 📔 ISTORIJSKA MILESTONE TAČKA (Iz sveske)
class FinanceMilestone {
  final DateTime date;
  final double? debt;
  final double? meterReading; // Mehanicko brojilo (ukupno proteklo)
  final double? litersInStock; // Trenutne zalihe u tanku

  FinanceMilestone({required this.date, this.debt, this.meterReading, this.litersInStock});
}

/// 🧾 ISTORIJSKI RAČUN (Nabavka goriva)
class HistoricalBill {
  final DateTime date;
  final double liters;
  final double? price;

  HistoricalBill({required this.date, required this.liters, this.price});
}

/// 💸 ISTORIJSKA UPLATA (Otplata duga)
class HistoricalPayment {
  final DateTime date;
  final double amount;

  HistoricalPayment({required this.date, required this.amount});
}

/// 💰 BEBA RAČUNOVОĐA (ML Finance Autonomous Serivice)
///
/// Peta beba u porodici. Specijalizovana za:
/// - Praćenje goriva na veliko (Dug, zalihe, sipanje).
/// - Kalkulaciju isplata i popusta.
/// - Predviđanje kada će zalihe nestati.
/// - "Vrištanje" kad dug pređe kritičnu granicu.

class MLFinanceAutonomousService extends ChangeNotifier {
  static SupabaseClient get _supabase => supabase;

  Timer? _analysisTimer;
  RealtimeChannel? _financeStream;

  // Interna memorija bebe
  final FuelInventory _inventory = FuelInventory();
  final List<FinanceMilestone> _milestones = [];
  final List<HistoricalBill> _bills = [];
  final List<HistoricalPayment> _payments = [];
  bool _isActive = false;

  // Rezultati za UI
  final List<FinanceAdvice> _currentAdvice = <FinanceAdvice>[];

  static final MLFinanceAutonomousService _instance = MLFinanceAutonomousService._internal();
  factory MLFinanceAutonomousService() => _instance;
  MLFinanceAutonomousService._internal();

  FuelInventory get inventory => _inventory;
  List<FinanceAdvice> get activeAdvice => List.unmodifiable(_currentAdvice);
  List<FinanceMilestone> get milestones => List.unmodifiable(_milestones);

  /// 🚀 POKRENI RAČUNOVOĐU
  Future<void> start() async {
    if (_isActive) return;
    _isActive = true;
    if (kDebugMode) print('💰 [ML Finance] Beba Računovođa je budna i otvara knjige (Realtime)...');

    _loadHistoricalMemory(); // 🧠 Uči iz starih zapisa
    await reconstructFinancialState();
    _subscribeToTransactions();

    // Pokreni periodičnu proveru duga i stanja (backup)
    _analysisTimer = Timer.periodic(const Duration(minutes: 15), (timer) {
      reconstructFinancialState();
    });
  }

  /// 🧠 MEMORIJA IZ SVESKE (Hardkodovano znanje koje nam je korisnik dao)
  void _loadHistoricalMemory() {
    // 25.10.2024
    recordMilestone(
      date: DateTime(2024, 10, 25),
      debt: 1000000,
      meterReading: 90953,
    );

    // 29.11.2024
    recordMilestone(
      date: DateTime(2024, 11, 29),
      debt: 1008250,
      meterReading: 93555,
    );

    // 07.02.2025
    recordMilestone(
      date: DateTime(2025, 2, 7),
      debt: 1155115,
      meterReading: 97960,
    );

    // 01.03.2025
    recordMilestone(
      date: DateTime(2025, 3, 1),
      debt: 758115,
      meterReading: 100100,
    );

    // 08.04.2025
    recordMilestone(
      date: DateTime(2025, 4, 8),
      debt: 696000,
      meterReading: 102760,
    );

    // 07.06.2025
    recordMilestone(
      date: DateTime(2025, 6, 7),
      debt: 775000,
      meterReading: 106320,
    );

    // 29.11.2025
    recordMilestone(
      date: DateTime(2025, 11, 29),
      debt: 1067000,
      meterReading: 117460,
    );

    // 14.12.2025 (Korekcija godine sa 2026 na 2025)
    recordMilestone(
      date: DateTime(2025, 12, 14),
      meterReading: 117450, // Skoro isto kao 29.11, stabilan kraj godine
    );

    // 13.01.2026
    recordMilestone(
      date: DateTime(2026, 1, 13),
      meterReading: 118500,
    );

    // 19.01.2026
    recordMilestone(
      date: DateTime(2026, 1, 19),
      meterReading: 119000,
    );

    // 🧪 KALIBRACIJA ZA DANAS (22.01.2026)
    calibrate(liters: 2500);

    // 🧾 RAČUNI (Iz gomile računa)
    recordHistoricalBill(
      date: DateTime(2025, 10, 6),
      liters: 2500,
    );

    recordHistoricalBill(
      date: DateTime(2025, 10, 22),
      liters: 1000,
    );

    recordHistoricalBill(
      date: DateTime(2025, 11, 29),
      liters: 2500,
    );

    recordHistoricalBill(
      date: DateTime(2026, 1, 14),
      liters: 2926,
    );

    // 💸 UPLATE (Iz sveske/izvoda)
    recordHistoricalPayment(
      date: DateTime(2025, 10, 18),
      amount: 60000,
    );

    recordHistoricalPayment(
      date: DateTime(2025, 11, 3),
      amount: 150000,
    );

    recordHistoricalPayment(
      date: DateTime(2025, 11, 9),
      amount: 150000,
    );

    recordHistoricalPayment(
      date: DateTime(2025, 11, 22),
      amount: 140000,
    );

    recordHistoricalPayment(
      date: DateTime(2025, 12, 16),
      amount: 110000,
    );

    recordHistoricalPayment(
      date: DateTime(2026, 1, 13),
      amount: 120000,
    );

    recordHistoricalPayment(
      date: DateTime(2026, 1, 15),
      amount: 100000,
    );

    recordHistoricalPayment(
      date: DateTime(2026, 1, 19),
      amount: 150000,
    );

    // 🧾 NOVI RAČUNI IZ JANUARA
    recordHistoricalBill(
      date: DateTime(2026, 1, 15),
      liters: 4500,
    );

    recordHistoricalBill(
      date: DateTime(2026, 1, 19),
      liters: 3000,
    );

    _analyzeHistoricalTrend();
  }

  void recordHistoricalBill({required DateTime date, required double liters, double? price}) {
    // Provera duplikata
    bool exists = _bills.any(
        (b) => b.date.year == date.year && b.date.month == date.month && b.date.day == date.day && b.liters == liters);
    if (exists) return;

    final bill = HistoricalBill(date: date, liters: liters, price: price);
    _bills.add(bill);
    _bills.sort((a, b) => b.date.compareTo(a.date));

    _generateAdvice(
      'ISTORIJSKI RAČUN',
      'Pronađen račun od ${date.day}.${date.month}.${date.year}.: ${liters.toInt()} L goriva.',
    );
  }

  void recordHistoricalPayment({required DateTime date, required double amount}) {
    // Provera duplikata
    bool exists = _payments.any(
        (p) => p.date.year == date.year && p.date.month == date.month && p.date.day == date.day && p.amount == amount);
    if (exists) return;

    final payment = HistoricalPayment(date: date, amount: amount);
    _payments.add(payment);
    _payments.sort((a, b) => b.date.compareTo(a.date));

    _generateAdvice(
      'ISTORIJSKA UPLATA',
      'Zabeležena uplata od ${date.day}.${date.month}.${date.year}.: ${amount.toInt()} din.',
    );
  }

  void _analyzeHistoricalTrend() {
    if (_milestones.length < 2) return;

    final mLatest = _milestones[0];
    final mPrev = _milestones[1];

    final days = mLatest.date.difference(mPrev.date).inDays;
    if (days <= 0) return;

    final litersUsed = (mLatest.meterReading ?? 0) - (mPrev.meterReading ?? 0);
    final debtChange = (mLatest.debt ?? 0) - (mPrev.debt ?? 0);

    if (litersUsed > 0) {
      final dailyAvg = litersUsed / days;

      if (mLatest.date.month == 1) {
        _generateAdvice(
          'ZIMSKI ŠPIC (JANUAR)',
          'U januaru potrošnja skočila! Između 13.01. i 19.01. prosečno ${dailyAvg.toStringAsFixed(1)} L/dan.',
        );
      } else if (mLatest.date.month == 11) {
        _generateAdvice(
          'ZIMSKA PRIPREMA',
          'Period leto-jesen završen sa prosekom od ${dailyAvg.toStringAsFixed(1)} L/dan. Dug raste pred sezonu.',
        );

        if (debtChange > 200000) {
          _generateAdvice(
            'OPREZ: VISOK DUG',
            'Dug je skočio na preko milion (${mLatest.debt?.toInt()} din). Beba savetuje pojačanu naplatu pre januara!',
            isCritical: true,
          );
        }
      } else if (mLatest.date.month == 6) {
        _generateAdvice(
          'LETNJE ZATIŠJE',
          'U maju i junu tempo pao na ${dailyAvg.toStringAsFixed(1)} L/dan. Sezona se hladi, idealno za servisiranje dugova.',
        );

        if (debtChange > 0) {
          _generateAdvice(
            'BLAGI RAST DUGA',
            'Dug je porastao za ${debtChange.toInt()} din. Proveri da li je bilo većih vanrednih sipanja ili servisa.',
          );
        }
      } else if (mLatest.date.month == 4) {
        _generateAdvice(
          'STABILIZACIJA PROLEĆA',
          'U martu je tempo pao na ${dailyAvg.toStringAsFixed(1)} L/dan. Posao je stabilan, nema naglih skokova.',
        );

        if (debtChange < 0) {
          _generateAdvice(
            'KONTINUIRANA OTPLATA',
            'Dug pada i dalje (za još ${debtChange.abs().toInt()} din). Odlična kontrola troškova!',
          );
        }
      } else if (mLatest.date.month == 3) {
        _generateAdvice(
          'PROLEĆNO UBRZANJE',
          'U februaru potrošnja skočila na ${dailyAvg.toStringAsFixed(1)} L/dan! Kombiji rade punom parom.',
        );

        if (debtChange < -300000) {
          _generateAdvice(
            'BRAVO ZA ISPLATU!',
            'Dug smanjen za skoro ${debtChange.abs().toInt()} din u samo 22 dana! Beba je srećna, knjige su čišće.',
          );
        }
      } else {
        _generateAdvice(
          'ANALIZA IZ SVESKE',
          'Period od $days dana: ${litersUsed.toInt()} L proteklo. Prosek: ${dailyAvg.toStringAsFixed(1)} L/dan.',
        );
      }
    }
  }

  /// 🧠 REKONSTRUKCIJA STANJA IZ ISTORIJE
  /// Beba sama "češlja" bazu da bi shvatila koliko imamo goriva i duga.
  Future<void> reconstructFinancialState() async {
    try {
      if (kDebugMode) print('💰 [ML Finance] Unsupervised Learning & Analiza...');

      // 1. Dobavi sve podatke
      final transactions =
          await _supabase.from('troskovi_unosi').select('tip, iznos, opis, datum').order('datum', ascending: true);
      final List<dynamic> trips = await _supabase.from('voznje_log').select('tip').eq('tip', 'voznja');

      // 🧠 FAZA 0: SAMOSTALNO UČENJE (Unsupervised Learning)
      // Beba analizira istoriju da bi sama podesila svoje koeficijente
      double totalHistoricalFuelLiters = 0;
      int fuelPurchaseCount = 0;

      for (var tx in transactions) {
        final double iznos = double.tryParse(tx['iznos']?.toString() ?? '0') ?? 0;
        final String desc = (tx['opis'] ?? tx['tip'] ?? '').toString().toLowerCase();

        // Uči šta je gorivo na osnovu ključnih reči ili velikih iznosa
        if (desc.contains('gorivo') || desc.contains('nafta') || desc.contains('edizel') || iznos > 20000) {
          totalHistoricalFuelLiters += (iznos / (_inventory.fuelPrice - _inventory.discount));
          fuelPurchaseCount++;
        }
      }

      // Ako imamo dovoljno podataka, beba sama računa prosečnu potrošnju po krugu
      if (fuelPurchaseCount > 0 && trips.isNotEmpty) {
        // Realna matematika: Ukupno kupljeno gorivo / Ukupno odvezenih krugova
        double realAvg = totalHistoricalFuelLiters / trips.length;
        // Ograničavamo na razumne granice (neda beba da prosek bude 0 ili 100 litara)
        _inventory.avgConsumption = realAvg.clamp(2.5, 6.0);
        if (kDebugMode) {
          print(
              '💰 [ML Finance] Beba je sama naučila prosek potrošnje: ${_inventory.avgConsumption.toStringAsFixed(2)} L po krugu');
        }
      }

      double calculatedDebt = 0;
      double calculatedLiters = 0;

      // ANALIZA (Faza 1)
      for (var tx in transactions) {
        final double iznos = double.tryParse(tx['iznos']?.toString() ?? '0') ?? 0;
        final String desc = (tx['opis'] ?? tx['tip'] ?? '').toString().toLowerCase();

        // 2.1. Praćenje duga
        if (desc.contains('dug') || desc.contains('kredit') || desc.contains('pozajmica')) {
          calculatedDebt += iznos;
        }

        // 2.2. Praćenje stanja goriva
        if (desc.contains('gorivo') || desc.contains('nafta') || desc.contains('edizel')) {
          calculatedLiters += (iznos / (_inventory.fuelPrice - _inventory.discount));
        }
      }

      // Procena "neprijavljene" potrošnje na osnovu broja vožnji koristeći NAUČENI prosek
      double estimatedUsage = trips.length * _inventory.avgConsumption;
      calculatedLiters -= estimatedUsage;

      _inventory.totalDebt = calculatedDebt.clamp(0, double.infinity);
      _inventory.litersInStock = calculatedLiters.clamp(0, double.infinity);

      _generateAdvice('UNSUPERVISED ANALIZA',
          'Naučeni prosek: ${_inventory.avgConsumption.toStringAsFixed(1)} L/krug | Zalihe: ${_inventory.litersInStock.toStringAsFixed(1)} L');

      // 🧠 DETEKCIJA ANOMALIJA (Gubici)
      if (_inventory.litersInStock < 0 && trips.isNotEmpty) {
        _generateAdvice(
            'ANOMALIJA POTROŠNJE', 'Zalihe su u minusu! Postoji nesklad između kupljenog goriva i odvezenih krugova.',
            isCritical: true);
      }

      // 🧪 HYBRID CLUSTER: Povezivanje finansija sa stanjem vozila
      await _runHybridFinanceCheck();

      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('⚠️ [ML Finance] Greška u učenju: $e');
    }
  }

  /// 🧪 HYBRID FINANCE (Računovođa + Fizičar)
  Future<void> _runHybridFinanceCheck() async {
    try {
      final vehicleAI = MLVehicleAutonomousService();
      final targets = vehicleAI.activeMonitoringTargets;

      if (targets.containsKey('fuel_efficiency')) {
        _generateAdvice('HIBRIDNI TROŠAK',
            'Poredim finansijski dug sa Bebom Fizičarem. Ako zalihe goriva opadaju brže od duga, imamo logičku rupu.',
            isCritical: _inventory.totalDebt > 100000 && _inventory.litersInStock < 20);
      }
    } catch (_) {}
  }

  void _subscribeToTransactions() {
    _financeStream = _supabase
        .channel('public:troskovi_unosi')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'troskovi_unosi',
          callback: (payload) {
            if (kDebugMode) print('💰 [ML Finance] Nova transakcija detektovana!');
            reconstructFinancialState();
          },
        )
        .subscribe();
  }

  /// 🛑 STOP
  void stop() {
    _isActive = false;
    _analysisTimer?.cancel();
    _financeStream?.unsubscribe();
  }

  /// ⛽ DODAJ GORIVO NA VELIKO (Nabavka)
  void recordBulkPurchase({
    required double liters,
    required double pricePerLiter,
    double? customDiscount,
  }) {
    final double actualPrice = pricePerLiter - (customDiscount ?? _inventory.discount);
    final double cost = liters * actualPrice;

    _inventory.litersInStock += liters;
    _inventory.totalDebt += cost;
    _inventory.fuelPrice = pricePerLiter;

    _generateAdvice('NOVA NABAVKA', 'Dodato $liters litara. Dug je porastao za ${cost.toStringAsFixed(0)} din.');
    _triggerAlert('Gorivo stiglo!', 'Zalihe su sada na ${_inventory.litersInStock.toStringAsFixed(1)} L.');
  }

  /// 🚐 SIPANJE U KOMBI
  void recordVanRefill({
    required String vehicleId,
    required double liters,
    double? km,
  }) {
    if (_inventory.litersInStock < liters) {
      _generateAdvice(
          'KRITIČNE ZALIHE', 'Pokušano sipanje $liters L, ali na stanju imamo samo ${_inventory.litersInStock} L!',
          isCritical: true);
    }

    _inventory.litersInStock -= liters;

    String desc = 'Kombi $vehicleId je sipao $liters L.';
    if (km != null) desc += ' Brojčanik: ${km.toStringAsFixed(0)} km.';
    desc += ' Preostalo: ${_inventory.litersInStock.toStringAsFixed(1)} L.';

    _generateAdvice('POTROŠNJA ZALIHA', desc);

    if (_inventory.litersInStock < 50) {
      _triggerAlert(
          'Zalihe na izmaku!', 'Ostalo je još samo ${_inventory.litersInStock.toStringAsFixed(1)} litara goriva.');
    }
  }

  /// 💸 ISPLATA DUGA
  void recordPayment(double amount) {
    _inventory.totalDebt -= amount;
    _generateAdvice('ISPLATA', 'Uplaćeno $amount din. Preostali dug: ${_inventory.totalDebt.toStringAsFixed(0)} din.');
  }

  /// ⚖️ KALIBRACIJA (Ručno podešavanje početnog stanja)
  void calibrate({double? liters, double? debt}) {
    if (liters != null) _inventory.litersInStock = liters;
    if (debt != null) _inventory.totalDebt = debt;

    _generateAdvice('KALIBRACIJA IZVRŠENA',
        'Ručno podešeno stanje: ${_inventory.litersInStock.toStringAsFixed(1)} L | ${_inventory.totalDebt.toStringAsFixed(0)} din.',
        isCritical: false);
    notifyListeners();
  }

  /// 📔 ZAPISI IZ SVESKE (Istorijski podaci)
  void recordMilestone({required DateTime date, double? debt, double? meterReading, double? litersInStock}) {
    final milestone = FinanceMilestone(
      date: date,
      debt: debt,
      meterReading: meterReading,
      litersInStock: litersInStock,
    );
    _milestones.add(milestone);
    _milestones.sort((a, b) => b.date.compareTo(a.date)); // Najnovije prvo

    String desc = 'Beleška za ${date.day}.${date.month}.${date.year}.';
    if (debt != null) desc += ' Dug: ${debt.toInt()} din.';
    if (meterReading != null) desc += ' Brojilo: ${meterReading.toInt()} L.';
    if (litersInStock != null) desc += ' Zalihe: ${litersInStock.toInt()} L.';

    _generateAdvice('BELEŠKA IZ SVESKE', desc);

    // Ako je ovo novi podatak (zadnjih 7 dana), radimo kalibraciju trenutnog stanja
    if (_milestones.isNotEmpty &&
        _milestones.first == milestone &&
        date.isAfter(DateTime.now().subtract(const Duration(days: 7)))) {
      if (debt != null) _inventory.totalDebt = debt;
      if (litersInStock != null) _inventory.litersInStock = litersInStock;
    }

    notifyListeners();
  }

  void _generateAdvice(String title, String desc, {bool isCritical = false}) {
    _currentAdvice.insert(
        0,
        FinanceAdvice(
          title: title,
          description: desc,
          isCritical: isCritical,
        ));
    if (_currentAdvice.length > 20) _currentAdvice.removeLast();
    notifyListeners();
  }

  void _triggerAlert(String title, String body) {
    try {
      LocalNotificationService.showRealtimeNotification(
        title: 'Beba Računovođa: $title',
        body: body,
        payload: 'ml_lab',
      );
    } catch (_) {}
  }
}

class FinanceAdvice {
  final String title;
  final String description;
  final bool isCritical;
  final DateTime timestamp;

  FinanceAdvice({
    required this.title,
    required this.description,
    this.isCritical = false,
  }) : timestamp = DateTime.now();
}
