import '../services/mesecni_putnik_service.dart';
import '../services/realtime_service.dart';

/// 🔄 GLOBALNI CACHE MANAGER
/// Centralizovano upravljanje cache-om kada se putnici brišu/ažuriraju
class GlobalCacheManager {
  /// 🧹 OČISTI SVE CACHE-OVE I FORSIRAJ REFRESH
  static Future<void> clearAllCachesAndRefresh() async {
    // 1. Očisti cache-ove u servisima
    MesecniPutnikService.clearCache();
    // PutnikService cache clearing se radi direktno u metodi

    // 2. Forsiraj RealtimeService refresh
    try {
      await RealtimeService.instance.refreshNow();
    } catch (e) {
      // Ignoriši greške u refresh-u
    }

    // 3. Kratka pauza i dodatni refresh
    await Future<void>.delayed(const Duration(milliseconds: 200));

    try {
      await RealtimeService.instance.refreshNow();
    } catch (e) {
      // Ignoriši greške u refresh-u
    }
  }

  /// 🔄 BLAGI REFRESH (bez clearing cache-a)
  static Future<void> softRefresh() async {
    try {
      await RealtimeService.instance.refreshNow();
    } catch (e) {
      // Ignoriši greške u refresh-u
    }
  }
}
