/// 🚩 FEATURE FLAGS za kontrolu novih funkcionalnosti
///
/// Koristi se za A/B testiranje, staged rollout, i brzo isključivanje buggy features.
class FeatureFlags {
  /// 🔥 ADMIN SCREEN V2 (MasterRealtimeStream)
  ///
  /// **When true:** Koristi admin_screen_v2.dart sa single GlobalAppState stream
  /// **When false:** Koristi stari admin_screen.dart sa 9 streams
  ///
  /// **Migration status:**
  /// - Infrastructure: ✅ Complete (RPC, Freezed, SmartCache, MasterRealtimeStream)
  /// - AdminScreenV2: ✅ Created (808 lines, 1 StreamBuilder)
  /// - Testing: ⏳ Pending
  /// - Performance metrics: ⏳ Pending
  ///
  /// **Expected improvements:**
  /// - API calls: -75% (40-50 calls → ~5-10 calls)
  /// - Memory: -60% (16 streams → 1 stream)
  /// - Latency: -40% (server-side RPC vs client aggregation)
  ///
  /// **Rollout plan:**
  /// 1. Set to `true` for internal testing ✅ ACTIVE NOW!
  /// 2. Measure performance (Flutter DevTools + Supabase Dashboard)
  /// 3. A/B test with 50% users
  /// 4. Gradual rollout (10% → 25% → 50% → 100%)
  /// 5. Remove old admin_screen.dart when stable
  static const bool USE_ADMIN_SCREEN_V2 =
      false; // ❌ DISABLED: User prefers OLD design

  /// 🔥 DANAS SCREEN V2 (MasterRealtimeStream)
  ///
  /// **Status:** ✅ CREATED (2,538 lines) - ZERO ERRORS!
  /// **Target:** Replace 7+ streams with 1 GlobalAppState stream
  /// **Improvements:** -70% API calls, -60% memory, single source of truth
  static const bool USE_DANAS_SCREEN_V2 =
      false; // ❌ DISABLED: User prefers OLD design

  /// 🔥 DAILY CHECKIN SCREEN V2 (MasterRealtimeStream)
  ///
  /// **Status:** ✅ CREATED (634 lines) - ZERO ERRORS!
  /// **Target:** Replace DnevniKusurService + SimplifiedDailyCheckInService with MasterRealtimeStream
  /// **Improvements:** 2 services → 1 stream, real-time kusur display
  static const bool USE_DAILY_CHECKIN_SCREEN_V2 =
      false; // ❌ DISABLED: User prefers OLD design

  /// � HOME SCREEN V2 (MasterRealtimeStream HYBRID)
  ///
  /// **Status:** 🆕 CREATED (2,426 lines) - Hybrid approach
  /// **Target:** Real-time passenger list updates without full model conversion
  /// **Approach:** Outer StreamBuilder (MasterStream) triggers refresh → Inner FutureBuilder (PutnikService)
  /// **Benefits:** Real-time updates + Full Putnik model compatibility
  /// **Improvements:** Eliminates manual refresh, auto-updates on passenger changes
  static const bool USE_HOME_SCREEN_V2 = false; // 🔄 TESTING PHASE

  /// �🐛 DEBUG MODE
  ///
  /// Enables verbose logging, performance monitoring, dev tools
  static const bool DEBUG_MODE = false; // Set to false for production

  /// 📊 PERFORMANCE MONITORING
  ///
  /// Tracks API calls, memory usage, stream health
  static const bool ENABLE_PERFORMANCE_MONITORING = false;

  /// 🔔 REALTIME NOTIFICATIONS V2
  ///
  /// Enhanced notification system with better filtering
  static const bool USE_REALTIME_NOTIFICATIONS_V2 = false;
}
