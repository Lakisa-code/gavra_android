import 'dart:async';

import 'package:flutter/foundation.dart'; // Dodaj ponovo za kDebugMode
import 'package:supabase_flutter/supabase_flutter.dart';

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

class MLFinanceAutonomousService {
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

    await _loadFinancialContext();

    // Pokreni periodičnu proveru duga i stanja (backup)
    _analysisTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_financeStream == null) _loadFinancialContext();
    });
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

  Future<void> _loadFinancialContext() async {
    // Ovde bi beba mogla da čita iz finansije_licno ili troskovi_unosi da inicijalizuje stanje
    // REMOVED: Licni bilans izbacen iz koda
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
