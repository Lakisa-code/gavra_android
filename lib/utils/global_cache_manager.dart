import 'dart:async';

import 'package:flutter/foundation.dart';

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
      // Očisti SAMO keširane vrednosti
      RegistrovaniPutnikService.clearCache();

      // Triggeruj globalni refresh signal
      triggerGlobalRefresh();
    } catch (e) {
      // Error clearing cache
    }
  }

  /// 🔄 SOFT REFRESH (bez clearing cache-a)
  static Future<void> softRefresh() async {
    try {
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
