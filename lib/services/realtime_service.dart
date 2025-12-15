import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/putnik.dart';
import 'supabase_safe.dart';

typedef RealtimePayloadHandler = void Function(Map<String, dynamic> payload);

/// Centralized RealtimeService for Supabase realtime subscriptions.
/// Exposes broadcast streams for raw table rows and a combined `Putnik` stream
/// which UI code can subscribe to (optionally filtered by `isoDate`, `grad`, `vreme`).
class RealtimeService {
  RealtimeService._internal();
  static final RealtimeService instance = RealtimeService._internal();

  // Combined Putnik stream controller
  final StreamController<List<Putnik>> _combinedPutniciController = StreamController<List<Putnik>>.broadcast();

  Stream<List<Putnik>> get combinedPutniciStream => _combinedPutniciController.stream;

  // ignore: unused_field - subscriptions are kept alive intentionally
  StreamSubscription<dynamic>? _registrovaniSub;
  // ignore: unused_field - subscriptions are kept alive intentionally
  StreamSubscription<dynamic>? _dailySub;

  // Keep last known rows so we can emit combined payloads
  List<Map<String, dynamic>> _lastRegistrovaniRows = [];
  List<Map<String, dynamic>> _lastDailyRows = [];

  // Expose read-only copies
  List<Map<String, dynamic>> get lastRegistrovaniRows => List.unmodifiable(_lastRegistrovaniRows);
  List<Map<String, dynamic>> get lastDailyRows => List.unmodifiable(_lastDailyRows);

  /// Vrati stream za tabelu. Pozivaoci mogu sami da se pretplate i obrade evente.
  Stream<dynamic> tableStream(String table) {
    final client = Supabase.instance.client;
    try {
      final stream = client.from(table).stream(primaryKey: ['id']).timeout(
        const Duration(seconds: 30),
        onTimeout: (sink) {
          sink.close();
        },
      );
      return stream;
    } catch (e) {
      // Return an empty list stream so callers can subscribe safely.
      return Stream.value(<dynamic>[]);
    }
  }

  /// Pomoćna metoda: pretplati se na tabelu i vrati StreamSubscription.
  StreamSubscription<dynamic> subscribe(
    String table,
    void Function(dynamic) onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final stream = tableStream(table);
    return stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  /// 🔄 FORCE REFRESH: Forsira osvežavanje podataka za datu tabelu
  /// Koristi se nakon UPDATE operacija da bi se UI odmah ažurirao
  void forceRefresh(String table) {
    try {
      final client = Supabase.instance.client;

      if (table == 'registrovani_putnici') {
        // Fetch fresh data i emit na stream
        client.from('registrovani_putnici').select().then((data) {
          final rows = (data as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _lastRegistrovaniRows = rows;
          _emitCombinedPutnici();
        });
      }
      // voznje_log se ne koristi za realtime UI, samo za istoriju
    } catch (e) {
      // Ignore errors - stream će se osvežiti prirodno
    }
  }

  /// Start centralized realtime subscriptions for commonly used tables.
  /// If `vozac` is provided, daily_checkins events will be filtered by driver
  /// in the handler before adding to the controller.
  void startForDriver(String? vozac) {
    // daily_checkins - tabela kreirana, aktiviram stream
    // ✅ AKTIVNO: daily_checkins tabela real-time stream
    _dailySub = tableStream('daily_checkins').listen((dynamic data) {
      try {
        final rows = <Map<String, dynamic>>[];
        for (final r in (data as List<dynamic>)) {
          if (r is Map) {
            if (vozac == null || r['vozac'] == vozac) {
              rows.add(Map<String, dynamic>.from(r));
            }
          }
        }
        _lastDailyRows = rows;
        _emitCombinedPutnici();
      } catch (e) {
        // ignore parsing errors
      }
    });

    // 🔄 POJEDNOSTAVLJENO: Sada koristimo SAMO registrovani_putnici
    // Tabela putovanja_istorija je uklonjena, sve je u registrovani_putnici
    _registrovaniSub = tableStream('registrovani_putnici').listen(
      (dynamic data) {
        try {
          final rows = <Map<String, dynamic>>[];
          for (final r in (data as List<dynamic>)) {
            if (r is Map) {
              rows.add(Map<String, dynamic>.from(r));
            }
          }
          _lastRegistrovaniRows = rows;
          _emitCombinedPutnici();
        } catch (e) {
          // Nastavi rad bez prekidanja
        }
      },
      onError: (Object error) {
        // Pokušaj reconnect preko ConnectionResilience
      },
    );

    // Fetch initial data to ensure streams have data immediately
    refreshNow();
  }

  void _emitCombinedPutnici() {
    try {
      final combined = <Putnik>[];

      // 🔄 POJEDNOSTAVLJENO: Samo registrovani_putnici (putovanja_istorija više ne postoji)
      // Convert registrovani rows - use current RegistrovaniPutnik model structure
      for (final Map<String, dynamic> map in _lastRegistrovaniRows) {
        try {
          // ✅ ISPRAVKA: Koristi Putnik.fromRegistrovaniPutniciMultipleForDay za sve dane
          final radniDani =
              (map['radni_dani'] as String? ?? '').split(',').map((d) => d.trim()).where((d) => d.isNotEmpty).toList();

          for (final dan in radniDani) {
            final putniciZaDan = Putnik.fromRegistrovaniPutniciMultipleForDay(map, dan);
            for (final putnik in putniciZaDan) {
              combined.add(putnik);
            }
          }
          continue;
        } catch (e) {
          // Ignoriši greške pri parsiranju pojedinih putnika
        }
      }

      if (!_combinedPutniciController.isClosed) {
        _combinedPutniciController.add(combined);
      }
    } catch (e) {
      // Ignoriši greške - stream će se osvježiti prirodno
    }
  }

  /// Trigger a one-off refresh (useful after resets) which will make the service re-query
  /// and emit the latest combined set.
  Future<void> refreshNow() async {
    try {
      // 🔄 POJEDNOSTAVLJENO: Samo registrovani_putnici
      final registrovaniData = await SupabaseSafe.select('registrovani_putnici');

      _lastRegistrovaniRows =
          (registrovaniData is List) ? registrovaniData.map((e) => Map<String, dynamic>.from(e as Map)).toList() : [];

      _emitCombinedPutnici();
    } catch (_) {
      // Ignoriši greške pri osvežavanju - stream će se osvežiti prirodno
    }
  }
}
