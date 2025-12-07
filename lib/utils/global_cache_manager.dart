import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/mesecni_putnik_service.dart';
import '../services/realtime_service.dart';

/// 🔄 GLOBALNI CACHE MANAGER
/// Centralizovano upravljanje cache-om kada se putnici brišu/ažuriraju
class GlobalCacheManager {
  // ═══════════════════════════════════════════════════════════════════════════
  // 🎯 GLOBALNI REFRESH SIGNAL - Kada se promeni, svi StreamBuilder-i se rebuildu-ju
  // ═══════════════════════════════════════════════════════════════════════════
  static final ValueNotifier<int> refreshSignal = ValueNotifier<int>(0);

  /// 🔄 Inkrementiraj refresh signal - forsira sve listenere da se rebuildu-ju
  static void triggerGlobalRefresh() {
    refreshSignal.value++;
    debugPrint('🔄 GLOBAL REFRESH TRIGGERED: ${refreshSignal.value}');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DEBOUNCING - Sprečava previše česte pozive
  // ═══════════════════════════════════════════════════════════════════════════

  static Timer? _debounceTimer;
  static DateTime? _lastClearTime;
  static const Duration _minIntervalBetweenClears = Duration(seconds: 2);
  static const Duration _debounceDelay = Duration(milliseconds: 500);

  /// 🧹 OČISTI SVE CACHE-OVE I FORSIRAJ REFRESH
  /// Sa debouncing-om da se ne poziva previše često
  static Future<void> clearAllCachesAndRefresh() async {
    // Debouncing: Proveri da li je prošlo dovoljno vremena od poslednjeg clear-a
    if (_lastClearTime != null) {
      final timeSinceLastClear = DateTime.now().difference(_lastClearTime!);
      if (timeSinceLastClear < _minIntervalBetweenClears) {
        debugPrint('🔄 Cache clear debounced - prošlo ${timeSinceLastClear.inMilliseconds}ms od poslednjeg');
        return;
      }
    }

    _lastClearTime = DateTime.now();

    try {
      // 1. Očisti cache-ove u servisima
      MesecniPutnikService.clearCache();
      // PutnikService cache clearing se radi direktno u metodi

      // 2. Forsiraj RealtimeService refresh
      await RealtimeService.instance.refreshNow();
    } catch (e) {
      debugPrint('❌ Greška pri čišćenju cache-a: $e');
    }
  }

  /// 🔄 DEBOUNCED REFRESH - Poziva se više puta ali izvršava se samo jednom
  static void debouncedRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, () async {
      await softRefresh();
    });
  }

  /// 🔄 BLAGI REFRESH (bez clearing cache-a)
  static Future<void> softRefresh() async {
    try {
      await RealtimeService.instance.refreshNow();
    } catch (e) {
      debugPrint('❌ Greška pri soft refresh-u: $e');
    }
  }

  /// 🧹 FORSIRAJ CLEAR (ignoriše debouncing) - Samo za kritične operacije
  static Future<void> forceClearAndRefresh() async {
    _lastClearTime = null; // Reset timer
    await clearAllCachesAndRefresh();
  }

  /// ♻️ DISPOSE - Očisti timer pri gašenju aplikacije
  static void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }
}
