import 'dart:async';

import '../services/optimized_kusur_service.dart';
/// 🚀 SIMPLIFIKOVANI DAILY CHECK-IN SERVIS
/// Rešava problem duplog čuvanja i kompleksnosti
class SimplifiedDailyCheckInService {
  static final StreamController<double> _streamController = StreamController<double>.broadcast();

  /// 📡 GLAVNI STREAM ZA KUSUR KOCKU
  static Stream<double> streamTodayAmount(String vozac) {
    return OptimizedKusurService.streamKusurForVozac(vozac);
  }

  /// 💾 JEDNOSTAVNO ČUVANJE KUSURA
  static Future<bool> saveKusur(String vozac, double iznos) async {
    try {
      final success = await OptimizedKusurService.updateKusurForVozac(vozac, iznos);

      if (success) {
      // Debug logging removed for production
// Emituj update za stream
        if (!_streamController.isClosed) {
          _streamController.add(iznos);
        }
        return true;
      } else {
      // Debug logging removed for production
return false; // Samo lokalno sačuvano
      }
    } catch (e) {
      // Debug logging removed for production
return false;
    }
  }

  /// 📊 DOBIJ TRENUTNI KUSUR
  static Future<double> getTodayAmount(String vozac) async {
    return await OptimizedKusurService.getKusurForVozac(vozac);
  }

  /// 💾 LEGACY SUPPORT - saveCheckIn wrapper
  static Future<void> saveCheckIn(String vozac, double sitanNovac, {double dnevniPazari = 0.0}) async {
    await saveKusur(vozac, sitanNovac);
  }

  /// ✅ LEGACY SUPPORT - hasCheckedInToday wrapper
  static Future<bool> hasCheckedInToday(String vozac) async {
    // Proveravamo da li postoji kusur za danas - ako postoji, vozač je obavio check-in
    final kusur = await OptimizedKusurService.getKusurForVozac(vozac);
    return kusur > 0.0; // Ako ima kusur, uradio je check-in
  }

  /// 📊 LEGACY SUPPORT - getLastDailyReport wrapper
  static Future<Map<String, dynamic>?> getLastDailyReport(String vozac) async {
    // Optimizovani servis ne čuva kompleksne dnevne popise - vraćamo null
      // Debug logging removed for production
return null;
  }

  /// 📊 LEGACY SUPPORT - generateAutomaticReport wrapper
  static Future<Map<String, dynamic>?> generateAutomaticReport(String vozac, DateTime targetDate) async {
    // Optimizovani servis ne generiše automatske popise - vraćamo null
      // Debug logging removed for production
return null;
  }

  /// 📊 LEGACY SUPPORT - saveDailyReport wrapper
  static Future<void> saveDailyReport(String vozac, DateTime datum, Map<String, dynamic> podaci) async {
    // Za sada samo logujemo - možda implementirati u budućnosti
      // Debug logging removed for production
}

  /// 🔗 LEGACY SUPPORT - initializeRealtimeForDriver wrapper
  static StreamSubscription<dynamic>? initializeRealtimeForDriver(String vozac) {
    // Vraćamo null jer optimizovani servis ne treba realtime init
      // Debug logging removed for production
return null;
  }

  /// 🔄 SYNC OFFLINE CHANGES
  static Future<void> syncOfflineChanges() async {
    await OptimizedKusurService.syncPendingChanges();
  }

  /// 🧹 CLEANUP
  static Future<void> cleanup() async {
    await OptimizedKusurService.cleanup();
  }

  /// 🔒 DISPOSE RESOURCES
  static void dispose() {
    if (!_streamController.isClosed) {
      _streamController.close();
    }
  }
}
