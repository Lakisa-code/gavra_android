import 'dart:async';

import 'daily_checkin_service.dart';

/// 🚀 SIMPLIFIKOVANI DAILY CHECK-IN SERVIS
/// Wrapper oko DailyCheckInService za kompatibilnost
class SimplifiedDailyCheckInService {
  static final StreamController<double> _streamController = StreamController<double>.broadcast();

  /// 📡 GLAVNI STREAM ZA KUSUR KOCKU
  static Stream<double> streamTodayAmount(String vozac) {
    return DailyCheckInService.streamTodayAmount(vozac);
  }

  /// 💾 JEDNOSTAVNO ČUVANJE KUSURA
  static Future<bool> saveKusur(String vozac, double iznos) async {
    try {
      // Koristi pravi DailyCheckInService
      await DailyCheckInService.saveCheckIn(vozac, iznos);
      // Emituj update za stream
      if (!_streamController.isClosed) {
        _streamController.add(iznos);
      }
      return true;
    } catch (e) {
      // Debug logging removed for production
      return false;
    }
  }

  /// 📊 DOBIJ TRENUTNI KUSUR
  static Future<double> getTodayAmount(String vozac) async {
    try {
      final data = await DailyCheckInService.getTodayCheckIn(vozac);
      final amount = data['sitan_novac'];
      if (amount is num) return amount.toDouble();
      if (amount is String) return double.tryParse(amount) ?? 0.0;
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// 💾 LEGACY SUPPORT - saveCheckIn wrapper
  static Future<void> saveCheckIn(String vozac, double sitanNovac, {double dnevniPazari = 0.0}) async {
    await DailyCheckInService.saveCheckIn(vozac, sitanNovac, dnevniPazari: dnevniPazari);
  }

  /// ✅ LEGACY SUPPORT - hasCheckedInToday wrapper
  static Future<bool> hasCheckedInToday(String vozac) async {
    try {
      return await DailyCheckInService.hasCheckedInToday(vozac);
    } catch (e) {
      // Debug logging removed for production
      return false;
    }
  }

  /// 📊 LEGACY SUPPORT - getLastDailyReport wrapper
  static Future<Map<String, dynamic>?> getLastDailyReport(String vozac) async {
    try {
      return await DailyCheckInService.getLastDailyReport(vozac);
    } catch (e) {
      return null;
    }
  }

  /// 📊 LEGACY SUPPORT - generateAutomaticReport wrapper
  static Future<Map<String, dynamic>?> generateAutomaticReport(String vozac, DateTime targetDate) async {
    try {
      return await DailyCheckInService.generateAutomaticReport(vozac, targetDate);
    } catch (e) {
      return null;
    }
  }

  /// 📊 LEGACY SUPPORT - saveDailyReport wrapper
  static Future<void> saveDailyReport(String vozac, DateTime datum, Map<String, dynamic> podaci) async {
    try {
      await DailyCheckInService.saveDailyReport(vozac, datum, podaci);
    } catch (e) {
      // Debug logging removed for production
    }
  }

  /// 🔗 LEGACY SUPPORT - initializeRealtimeForDriver wrapper
  static StreamSubscription<dynamic>? initializeRealtimeForDriver(String vozac) {
    return DailyCheckInService.initializeRealtimeForDriver(vozac);
  }

  /// 🔄 SYNC OFFLINE CHANGES
  static Future<void> syncOfflineChanges() async {
    // SimplifiedDailyCheckInService doesn't need offline sync
    // because it uses SharedPreferences directly
  }

  /// 🧹 CLEANUP
  static Future<void> cleanup() async {
    // SimplifiedDailyCheckInService cleanup
  }

  /// 🔒 DISPOSE RESOURCES
  static void dispose() {
    if (!_streamController.isClosed) {
      _streamController.close();
    }
  }
}
