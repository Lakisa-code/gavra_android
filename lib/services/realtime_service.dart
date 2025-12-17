import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_safe.dart';

/// ✅ POJEDNOSTAVLJEN RealtimeService
/// Samo helper funkcije za Supabase realtime - bez posredničkih streamova
class RealtimeService {
  RealtimeService._internal();
  static final RealtimeService instance = RealtimeService._internal();

  // Subscriptions za cleanup
  StreamSubscription<dynamic>? _registrovaniSub;
  StreamSubscription<dynamic>? _dailySub;

  /// Vrati stream za tabelu - direktan Supabase WebSocket
  Stream<dynamic> tableStream(String table) {
    final client = Supabase.instance.client;
    try {
      return client.from(table).stream(primaryKey: ['id']);
    } catch (e) {
      return Stream.value(<dynamic>[]);
    }
  }

  /// Pomoćna metoda: pretplati se na tabelu
  StreamSubscription<dynamic> subscribe(
    String table,
    void Function(dynamic) onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return tableStream(table).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  /// Start subscriptions za tabele (poziva se iz main.dart)
  void startForDriver(String? vozac) {
    // daily_checkins stream
    _dailySub = tableStream('daily_checkins').listen((_) {
      // Stream aktivno sluša - PutnikService će sam refetch-ovati
    });

    // registrovani_putnici stream
    _registrovaniSub = tableStream('registrovani_putnici').listen((_) {
      // Stream aktivno sluša - PutnikService će sam refetch-ovati
    });

    // Initial data fetch
    refreshNow();
  }

  /// Refresh podataka - triggeruje sve aktivne streamove
  Future<void> refreshNow() async {
    try {
      // Jednostavan ping ka bazi da osveži Supabase realtime konekciju
      await SupabaseSafe.select('registrovani_putnici');
    } catch (_) {
      // Ignore errors
    }
  }

  /// Cleanup subscriptions
  void dispose() {
    _registrovaniSub?.cancel();
    _dailySub?.cancel();
  }
}
