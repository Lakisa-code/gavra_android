import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import 'realtime_notification_service.dart';
import 'voznje_log_service.dart';

class FuelInventory {
  double litersInStock;
  double totalDebt;
  double fuelPrice;
  double discount;
  double avgConsumption;
  double maxCapacity;

  FuelInventory({
    this.litersInStock = 0,
    this.totalDebt = 0,
    this.fuelPrice = 0,
    this.discount = 0,
    this.avgConsumption = 10.5,
    this.maxCapacity = 3000,
  });
}

class FinanceMilestone {
  final DateTime date;
  final double? debt;
  final double? meterReading;
  final double? litersInStock;
  FinanceMilestone({required this.date, this.debt, this.meterReading, this.litersInStock});
}

class HistoricalBill {
  final DateTime date;
  final double liters;
  final double? price;
  HistoricalBill({required this.date, required this.liters, this.price});
}

class HistoricalPayment {
  final DateTime date;
  final double amount;
  HistoricalPayment({required this.date, required this.amount});
}

class HistoricalUsage {
  final DateTime date;
  final String vehicleId;
  final double liters;
  final double? km;
  final double? pumpMeter;
  HistoricalUsage({
    required this.date,
    required this.vehicleId,
    required this.liters,
    this.km,
    this.pumpMeter,
  });
}

enum FinanceAdviceType { lowFuel, highDebt, savingsOpportunity }

class FinanceAdvice {
  final String title;
  final String description;
  final FinanceAdviceType type;
  final DateTime timestamp;
  final String action;
  FinanceAdvice(
      {required this.title,
      required this.description,
      required this.type,
      required this.timestamp,
      required this.action});

  bool get isCritical => type == FinanceAdviceType.highDebt || type == FinanceAdviceType.lowFuel;
}

class MLFinanceAutonomousService extends ChangeNotifier {
  static SupabaseClient get _supabase => supabase;

  Timer? _analysisTimer;
  RealtimeChannel? _financeStream;

  final FuelInventory _inventory = FuelInventory();
  final List<FinanceMilestone> _milestones = [];
  final List<HistoricalBill> _bills = [];
  final List<HistoricalPayment> _payments = [];
  final List<HistoricalUsage> _usages = [];
  double? _lastKnownPumpMeter;

  // ⛽ NOVO: Pronađi poslednje stanje brojila na pumpi
  double? get lastPumpMeter {
    // 1. Prvo traži u usage listi (koja je sortirana po vremenu u reconstructFinancialState)
    if (_usages.isNotEmpty) {
      for (var i = _usages.length - 1; i >= 0; i--) {
        if (_usages[i].pumpMeter != null) return _usages[i].pumpMeter;
      }
    }
    // 2. Ako nema u usage, vrati poslednji poznati iz kalibracije/milestone-a
    return _lastKnownPumpMeter;
  }

  bool _isActive = false;
  bool _isAutopilotEnabled = false;

  final List<FinanceAdvice> _currentAdvice = <FinanceAdvice>[];

  static final MLFinanceAutonomousService _instance = MLFinanceAutonomousService._internal();
  factory MLFinanceAutonomousService() => _instance;
  MLFinanceAutonomousService._internal();

  FuelInventory get inventory => _inventory;
  List<FinanceAdvice> get activeAdvice => List.unmodifiable(_currentAdvice);
  List<FinanceMilestone> get milestones => List.unmodifiable(_milestones);
  bool get isAutopilotEnabled => _isAutopilotEnabled;

  void toggleAutopilot(bool enabled) {
    _isAutopilotEnabled = enabled;
    notifyListeners();
    if (kDebugMode) print('💰 [Finance Autopilot] Status: ${enabled ? 'ON' : 'OFF'}');
  }

  Future<void> start() async {
    if (_isActive) return;
    _isActive = true;
    _loadHistoricalMemory();
    await reconstructFinancialState();
    _subscribeToTransactions();
    _analysisTimer = Timer.periodic(const Duration(minutes: 15), (timer) {
      reconstructFinancialState();
    });
  }

  void _loadHistoricalMemory() {
    // Hardcoded historical data removed as per user request to move away from "Sveska" (notebook) data.
    // The system now relies on Supabase 'fuel_logs' for autonomy.
  }

  void recordMilestone({required DateTime date, double? debt, double? meterReading, double? litersInStock}) {
    _milestones.add(FinanceMilestone(date: date, debt: debt, meterReading: meterReading, litersInStock: litersInStock));
    _milestones.sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> reconstructFinancialState() async {
    DateTime startDate = DateTime(2024);
    if (_milestones.isNotEmpty) {
      final latest = _milestones.first;
      _inventory.totalDebt = latest.debt ?? 0;
      _inventory.litersInStock = latest.litersInStock ?? 0;
      _lastKnownPumpMeter = latest.meterReading;
      startDate = latest.date;
    } else {
      _inventory.totalDebt = 0;
      _inventory.litersInStock = 0;
      _lastKnownPumpMeter = null;
    }

    // Clear lists before reconstructing to avoid duplicates
    _bills.clear();
    _payments.clear();
    _usages.clear();

    final response = await _supabase
        .from('fuel_logs')
        .select()
        .gt('created_at', startDate.toIso8601String())
        .order('created_at', ascending: true);

    final List logs = response as List;
    for (var log in logs) {
      final DateTime date = DateTime.parse(log['created_at']);

      // ✅ Uvek ažuriraj poslednje poznato stanje brojila ako postoji, nezavisno od tipa loga
      if (log['pump_meter'] != null) {
        _lastKnownPumpMeter = (log['pump_meter'] as num).toDouble();
      }

      if (log['type'] == 'BILL') {
        final liters = (log['liters'] as num).toDouble();
        final price = (log['price'] as num?)?.toDouble();
        _inventory.totalDebt += (liters * (price ?? 0));
        _inventory.litersInStock += liters;
        _bills.add(HistoricalBill(date: date, liters: liters, price: price));
      } else if (log['type'] == 'PAYMENT') {
        final amount = (log['amount'] as num).toDouble();
        _inventory.totalDebt -= amount;
        _payments.add(HistoricalPayment(date: date, amount: amount));
      } else if (log['type'] == 'USAGE') {
        final liters = (log['liters'] as num).toDouble();
        _inventory.litersInStock -= liters;
        _usages.add(HistoricalUsage(
          date: date,
          vehicleId: log['vehicle_id'] ?? 'Unknown',
          liters: liters,
          km: (log['km'] as num?)?.toDouble(),
          pumpMeter: (log['pump_meter'] as num?)?.toDouble(),
        ));
      } else if (log['type'] == 'CALIBRATION') {
        if (log['liters'] != null) _inventory.litersInStock = (log['liters'] as num).toDouble();
        if (log['amount'] != null) _inventory.totalDebt = (log['amount'] as num).toDouble();
      }
    }

    _generateAdvice();
    if (_isAutopilotEnabled) {
      _executeAutopilotActions();
    }
    notifyListeners();
  }

  void _generateAdvice() {
    _currentAdvice.clear();
    if (_inventory.totalDebt > 1200000) {
      _currentAdvice.add(FinanceAdvice(
        title: 'KRITIČAN DUG',
        description: 'Dug za gorivo je prešao 1.2M dinara. Potrebna hitna uplata.',
        type: FinanceAdviceType.highDebt,
        timestamp: DateTime.now(),
        action: 'UPLATI ODMAH',
      ));
    }
    if (_inventory.litersInStock < 300) {
      _currentAdvice.add(FinanceAdvice(
        title: 'NISKE ZALIHE',
        description: 'Ostalo je manje od 300L goriva. Naruči novu turu.',
        type: FinanceAdviceType.lowFuel,
        timestamp: DateTime.now(),
        action: 'NARUČI GORIVO',
      ));
    }
  }

  void _executeAutopilotActions() {
    if (_inventory.totalDebt > 1200000) {
      _logAudit(
          'FINANCE_CRITICAL_DEBT', 'Dug: ${_inventory.totalDebt.toStringAsFixed(0)} RSD. Slanje upozorenja adminu.');

      // 📲 Prebačeno na Supabase Push (umesto lokalne notifikacije)
      RealtimeNotificationService.sendNotificationToAdmins(
        title: '🚨 BEBA RAČUNOVOĐA: DUG!',
        body: 'Dug je prešao kritičnu granicu! Trenutno: ${_inventory.totalDebt.toStringAsFixed(0)} RSD.',
        data: {'type': 'finance_alert', 'sub_type': 'debt'},
      );
    }

    if (_inventory.litersInStock < 200) {
      _logAudit('FINANCE_LOW_FUEL', 'Zalihe: ${_inventory.litersInStock.toStringAsFixed(0)}L. Alarm za nabavku.');

      // 📲 Prebačeno na Supabase Push
      RealtimeNotificationService.sendNotificationToAdmins(
        title: '⛽ BEBA RAČUNOVOĐA: GORIVO!',
        body: 'Zalihe su kritično niske (${_inventory.litersInStock.toStringAsFixed(0)}L). Naruči odmah!',
        data: {'type': 'finance_alert', 'sub_type': 'fuel'},
      );
    }
  }

  Future<void> _logAudit(String action, String details) async {
    try {
      await _supabase.from('admin_audit_logs').insert({
        'action_type': action,
        'details': details,
        'metadata': {'liters': _inventory.litersInStock, 'debt': _inventory.totalDebt},
      });
    } catch (e) {
      if (kDebugMode) print('❌ [ML Finance] Greška pri logovanju audita: $e');
    }
  }

  void _subscribeToTransactions() {
    _financeStream = _supabase
        .channel('public:fuel_logs')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'fuel_logs',
            callback: (payload) {
              reconstructFinancialState();
            })
        .subscribe();
  }

  Future<void> recordBulkPurchase({required double liters, double? pricePerLiter}) async {
    try {
      await _supabase.from('fuel_logs').insert({
        'type': 'BILL',
        'liters': liters,
        'price': pricePerLiter,
      });
      _inventory.litersInStock += liters;
      _inventory.totalDebt += (liters * (pricePerLiter ?? 0));
      _bills.add(HistoricalBill(date: DateTime.now(), liters: liters, price: pricePerLiter));
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ [ML Finance] Greška pri snimanju kupovine: $e');
    }
  }

  Future<void> recordPayment(double amount) async {
    try {
      await _supabase.from('fuel_logs').insert({
        'type': 'PAYMENT',
        'amount': amount,
      });
      _inventory.totalDebt -= amount;
      _payments.add(HistoricalPayment(date: DateTime.now(), amount: amount));
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ [ML Finance] Greška pri snimanju uplate: $e');
    }
  }

  Future<void> recordVanRefill({
    required double liters,
    required String vehicleId,
    double? km,
    double? pumpMeter,
  }) async {
    try {
      await _supabase.from('fuel_logs').insert({
        'type': 'USAGE',
        'liters': liters,
        'vehicle_id': vehicleId,
        'km': km,
        'pump_meter': pumpMeter,
      });

      // 🔥 NOVO: Ažuriraj trenutnu kilometražu vozila ako je uneta veća cifra
      if (km != null) {
        try {
          // Prvo proveri trenutnu vrednost da ne bismo smanjili kilometražu slučajno
          final res = await _supabase.from('vozila').select('kilometraza').eq('id', vehicleId).maybeSingle();
          if (res != null) {
            final double currentKm = (res['kilometraza'] as num?)?.toDouble() ?? 0;
            if (km > currentKm) {
              await _supabase.from('vozila').update({'kilometraza': km}).eq('id', vehicleId);
            }
          }
        } catch (e) {
          if (kDebugMode) print('⚠️ [ML Finance] Neuspešno ažuriranje kilometraže vozila: $e');
        }
      }

      _inventory.litersInStock -= liters;
      _usages.add(HistoricalUsage(
        date: DateTime.now(),
        vehicleId: vehicleId,
        liters: liters,
        km: km,
        pumpMeter: pumpMeter,
      ));
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ [ML Finance] Greška pri snimanju točenja: $e');
    }
  }

  // ⛽ NOVO: Snimanje točenja za više vozila odjednom (izračunava litre iz brojila)
  Future<void> recordMultiVanRefill({
    required List<String> vehicleIds,
    required double newPumpMeter,
  }) async {
    if (vehicleIds.isEmpty) return;

    final oldMeter = lastPumpMeter;
    if (oldMeter == null) {
      throw Exception('Nema prethodnog stanja brojila. Prvo uradi jedno obično sipanje ili kalibraciju.');
    }

    final totalLiters = newPumpMeter - oldMeter;
    if (totalLiters <= 0) {
      throw Exception('Novo stanje brojila ($newPumpMeter) mora biti veće od starog ($oldMeter).');
    }

    final litersPerVan = totalLiters / vehicleIds.length;

    try {
      for (final vId in vehicleIds) {
        await _supabase.from('fuel_logs').insert({
          'type': 'USAGE',
          'liters': litersPerVan,
          'vehicle_id': vId,
          'pump_meter': newPumpMeter, // Set the same new meter for all
          'km': null, // KM unknown in rush
        });

        _inventory.litersInStock -= litersPerVan;
        _usages.add(HistoricalUsage(
          date: DateTime.now(),
          vehicleId: vId,
          liters: litersPerVan,
          pumpMeter: newPumpMeter,
        ));
      }

      // 📝 LOGOVANJE U GENERALNI DNEVNIK
      await VoznjeLogService.logGeneric(
        tip: 'gorivo_refill',
        detalji:
            'Multi-refill: ${totalLiters.toStringAsFixed(1)} L podeljeno na ${vehicleIds.length} vozila. Pump: ${newPumpMeter.toStringAsFixed(1)}',
      );

      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ [ML Finance] Greška pri snimanju višestrukog točenja: $e');
      rethrow;
    }
  }

  Future<void> calibrate({double? liters, double? debt, double? km, double? pumpMeter}) async {
    try {
      await _supabase.from('fuel_logs').insert({
        'type': 'CALIBRATION',
        'liters': liters,
        'amount': debt,
        'km': km,
        'pump_meter': pumpMeter,
      });

      if (liters != null) _inventory.litersInStock = liters;
      if (debt != null) _inventory.totalDebt = debt;
      if (pumpMeter != null) _lastKnownPumpMeter = pumpMeter;

      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ [ML Finance] Greška pri kalibraciji: $e');
    }
  }

  @override
  void dispose() {
    _analysisTimer?.cancel();
    _financeStream?.unsubscribe();
    super.dispose();
  }
}
