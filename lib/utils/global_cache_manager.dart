import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/putnik_service.dart';
import '../services/realtime_service.dart';
import '../services/registrovani_putnik_service.dart';

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
  }

  /// 🧹 OČISTI SVE CACHE-OVE I FORSIRAJ REFRESH - BEZ DEBOUNCING-a
  static Future<void> clearAllCachesAndRefresh() async {
    try {
      // 1. Očisti SAMO keširane vrednosti (NE zatvaraj streamove!)
      // Ovo omogućava da aktivni StreamBuilder-i dobiju nove podatke
      RegistrovaniPutnikService.clearCache();
      PutnikService.invalidateCachedValues(); // 🔄 NOVO: Ne zatvara streamove

      // 2. Forsiraj RealtimeService refresh - ovo će triggerovati sve aktivne streamove
      await RealtimeService.instance.refreshNow();

      // 3. Triggeruj globalni refresh signal
      triggerGlobalRefresh();
    } catch (e) {
      // Error clearing cache
    }
  }

  /// 🔄 SOFT REFRESH (bez clearing cache-a)
  static Future<void> softRefresh() async {
    try {
      await RealtimeService.instance.refreshNow();
      triggerGlobalRefresh();
    } catch (e) {
      // Error during soft refresh
    }
  }

  /// 🧹 FORSIRAJ CLEAR - Alias za clearAllCachesAndRefresh
  static Future<void> forceClearAndRefresh() async {
    await clearAllCachesAndRefresh();
  }
}
