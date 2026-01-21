import 'dart:async';

import 'package:flutter/foundation.dart'; // Dodaj ponovo za kDebugMode
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import 'local_notification_service.dart';

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

/// 💰 BEBA RAČUNOVOĐA (ML Finance Autonomous Service)
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
  bool _isActive = false;

  // Rezultati za UI
  final List<FinanceAdvice> _currentAdvice = <FinanceAdvice>[];

  static final MLFinanceAutonomousService _instance = MLFinanceAutonomousService._internal();
  factory MLFinanceAutonomousService() => _instance;
  MLFinanceAutonomousService._internal();

  FuelInventory get inventory => _inventory;
  List<FinanceAdvice> get activeAdvice => List.unmodifiable(_currentAdvice);

  /// 🚀 POKRENI RAČUNOVOĐU
  Future<void> start() async {
    if (_isActive) return;
    _isActive = true;
    if (kDebugMode) print('💰 [ML Finance] Beba Računovođa je budna i otvara knjige (Realtime)...');

    await reconstructFinancialState();
    _subscribeToTransactions();

    // Pokreni periodičnu proveru duga i stanja (backup)
    _analysisTimer = Timer.periodic(const Duration(minutes: 15), (timer) {
      reconstructFinancialState();
    });
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
// ...existing code...
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

      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('⚠️ [ML Finance] Greška u učenju: $e');
    }
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
  }) {
    if (_inventory.litersInStock < liters) {
      _generateAdvice(
          'KRITIČNE ZALIHE', 'Pokušano sipanje $liters L, ali na stanju imamo samo ${_inventory.litersInStock} L!',
          isCritical: true);
    }

    _inventory.litersInStock -= liters;

    _generateAdvice('POTROŠNJA ZALIHA',
        'Kombi $vehicleId je sipao $liters L. Preostalo: ${_inventory.litersInStock.toStringAsFixed(1)} L.');

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
