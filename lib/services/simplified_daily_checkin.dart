import 'dart:async';

import '../services/optimized_kusur_service.dart';
import '../utils/logging.dart';

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
        dlog('✅ SimplifiedDailyCheckIn: Saved $vozac: $iznos');
        // Emituj update za stream
        if (!_streamController.isClosed) {
          _streamController.add(iznos);
        }
        return true;
      } else {
        dlog('🔄 SimplifiedDailyCheckIn: Saved locally $vozac: $iznos');
        return false; // Samo lokalno sačuvano
      }
    } catch (e) {
      dlog('❌ SimplifiedDailyCheckIn error $vozac: $e');
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
    dlog('📊 SimplifiedDailyCheckIn: getLastDailyReport za $vozac - vraćamo null (optimizovano)');
    return null;
  }

  /// 📊 LEGACY SUPPORT - generateAutomaticReport wrapper
  static Future<Map<String, dynamic>?> generateAutomaticReport(String vozac, DateTime targetDate) async {
    // Optimizovani servis ne generiše automatske popise - vraćamo null
    dlog(
        '📊 SimplifiedDailyCheckIn: generateAutomaticReport za $vozac na ${targetDate.day}.${targetDate.month}.${targetDate.year} - vraćamo null (optimizovano)');
    return null;
  }

  /// 📊 LEGACY SUPPORT - saveDailyReport wrapper
  static Future<void> saveDailyReport(String vozac, DateTime datum, Map<String, dynamic> podaci) async {
    // Za sada samo logujemo - možda implementirati u budućnosti
    dlog('📊 SimplifiedDailyCheckIn: Daily report za $vozac na ${datum.day}.${datum.month}.${datum.year}');
  }

  /// 🔗 LEGACY SUPPORT - initializeRealtimeForDriver wrapper
  static StreamSubscription<dynamic>? initializeRealtimeForDriver(String vozac) {
    // Vraćamo null jer optimizovani servis ne treba realtime init
    dlog('📊 SimplifiedDailyCheckIn: Legacy initializeRealtimeForDriver pozvan za $vozac - vraćamo null');
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
