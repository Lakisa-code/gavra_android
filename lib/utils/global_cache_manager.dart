import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/registrovani_putnik_service.dart';
import '../services/putnik_service.dart';
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

  /// 🧹 OČISTI SVE CACHE-OVE I FORSIRAJ REFRESH - BEZ DEBOUNCING-a
  static Future<void> clearAllCachesAndRefresh() async {
    try {
      // 1. Očisti cache-ove u servisima
      RegistrovaniPutnikService.clearCache();
      PutnikService.clearCache();

      // 2. Forsiraj RealtimeService refresh
      await RealtimeService.instance.refreshNow();

      // 3. Triggeruj globalni refresh signal
      triggerGlobalRefresh();
    } catch (e) {
      debugPrint('❌ Greška pri čišćenju cache-a: $e');
    }
  }

  /// 🔄 SOFT REFRESH (bez clearing cache-a)
  static Future<void> softRefresh() async {
    try {
      await RealtimeService.instance.refreshNow();
      triggerGlobalRefresh();
    } catch (e) {
      debugPrint('❌ Greška pri soft refresh-u: $e');
    }
  }

  /// 🧹 FORSIRAJ CLEAR - Alias za clearAllCachesAndRefresh
  static Future<void> forceClearAndRefresh() async {
    await clearAllCachesAndRefresh();
  }
}
