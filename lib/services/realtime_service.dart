import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/putnik.dart';
import '../utils/grad_adresa_validator.dart';
import '../utils/slot_utils.dart';
import '../utils/logging.dart';
import 'supabase_safe.dart';

typedef RealtimePayloadHandler = void Function(Map<String, dynamic> payload);

/// Centralized RealtimeService for Supabase realtime subscriptions.
/// Exposes broadcast streams for raw table rows and a combined `Putnik` stream
/// which UI code can subscribe to (optionally filtered by `isoDate`, `grad`, `vreme`).
class RealtimeService {
  RealtimeService._internal();
  static final RealtimeService instance = RealtimeService._internal();

  // Raw controllers for commonly used tables
  final StreamController<List<Map<String, dynamic>>> _putovanjaController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  // Combined Putnik stream controller
  final StreamController<List<Putnik>> _combinedPutniciController =
      StreamController<List<Putnik>>.broadcast();

  Stream<List<Map<String, dynamic>>> get putovanjaStream =>
      _putovanjaController.stream;

  Stream<List<Putnik>> get combinedPutniciStream =>
      _combinedPutniciController.stream;

  StreamSubscription<dynamic>? _putovanjaSub;
  StreamSubscription<dynamic>? _mesecniSub;

  // Keep last known rows so we can emit combined payloads
  List<Map<String, dynamic>> _lastPutovanjaRows = [];
  List<Map<String, dynamic>> _lastMesecniRows = [];

  // Expose read-only copies for debugging
  List<Map<String, dynamic>> get lastPutovanjaRows =>
      List.unmodifiable(_lastPutovanjaRows);
  List<Map<String, dynamic>> get lastMesecniRows =>
      List.unmodifiable(_lastMesecniRows);

  // Parametric subscriptions: per-filter controllers and state
  final Map<String, StreamController<List<Putnik>>> _paramControllers = {};
  final Map<String, List<Map<String, dynamic>>> _paramLastPutovanja = {};
  final Map<String, List<StreamSubscription<dynamic>>> _paramSubscriptions = {};

  String _paramKey({String? isoDate, String? grad, String? vreme}) {
    return '${isoDate ?? ''}|${grad ?? ''}|${vreme ?? ''}';
  }

  /// Vrati stream za tabelu. Pozivaoci mogu sami da se pretplate i obrade evente.
  Stream<dynamic> tableStream(String table) {
    final client = Supabase.instance.client;
    try {
      dlog('🔌 [REALTIME SERVICE] Creating stream for table: $table');
      final stream = client.from(table).stream(primaryKey: ['id']);
      return stream.map((data) {
        dlog(
            '🔔 [REALTIME SERVICE] Stream event for $table: ${(data as List?)?.length ?? 0} rows');
        return data;
      });
    } catch (e) {
      dlog('❌ [REALTIME SERVICE] Failed to create stream for $table: $e');
      // Return an empty list stream so callers can subscribe safely.
      return Stream.value(<dynamic>[]);
    }
  }

  /// Pomoćna metoda: pretplati se na tabelu i vrati StreamSubscription.
  StreamSubscription<dynamic> subscribe(
      String table, void Function(dynamic) onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    void loggedOnData(dynamic data) {
      dlog('🔄 Realtime event for $table: ${data?.length ?? 0} records');
      onData(data);
    }

    final stream = tableStream(table);
    return stream.listen(loggedOnData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  Future<void> unsubscribeAll() async {
    // _dailySub je komentarisana
    /*
    try {
      await _dailySub?.cancel();
    } catch (_) {}
    */
    try {
      await _putovanjaSub?.cancel();
    } catch (_) {}
    try {
      await _mesecniSub?.cancel();
    } catch (_) {}
    // Clear controllers
    if (!_putovanjaController.isClosed) {
      _putovanjaController.add([]);
    }
    if (!_combinedPutniciController.isClosed) {
      _combinedPutniciController.add([]);
    }
  }

  /// Start centralized realtime subscriptions for commonly used tables.
  /// If `vozac` is provided, daily_checkins events will be filtered by driver
  /// in the handler before adding to the controller.
  void startForDriver(String? vozac) {
    // daily_checkins - tabela možda ne postoji, preskoči za sada
    // TODO: Omogući kada se tabela kreira u Supabase
    /*
    _dailySub = tableStream('daily_checkins').listen((dynamic data) {
      try {
        final rows = <Map<String, dynamic>>[];
        for (final r in data) {
          if (r is Map) {
            if (vozac == null || r['vozac'] == vozac) {
              rows.add(Map<String, dynamic>.from(r));
            }
          }
        }
        _lastDailyRows = rows;
        if (!_dailyCheckinsController.isClosed) {
          _dailyCheckinsController.add(rows);
        }
        _emitCombinedPutnici();
      } catch (e) {
        // ignore parsing errors
      }
    });
    */

    // putovanja_istorija
    _putovanjaSub = tableStream('putovanja_istorija').listen((dynamic data) {
      try {
        final rows = <Map<String, dynamic>>[];
        for (final r in data) {
          if (r is Map) {
            rows.add(Map<String, dynamic>.from(r));
          }
        }
        _lastPutovanjaRows = rows;
        try {
          final sample = rows
              .take(5)
              .map((r) => r['id']?.toString() ?? r.toString())
              .toList();
          dlog(
              '🔔 [REALTIME] putovanja_istorija rows: ${rows.length}; sample ids: $sample');
        } catch (_) {}
        if (!_putovanjaController.isClosed) {
          _putovanjaController.add(rows);
        }
        _emitCombinedPutnici();
      } catch (e) {
        // ignore
      }
    });

    // mesecni_putnici
    _mesecniSub = tableStream('mesecni_putnici').listen((dynamic data) {
      try {
        final rows = <Map<String, dynamic>>[];
        for (final r in data) {
          if (r is Map) {
            rows.add(Map<String, dynamic>.from(r));
          }
        }
        _lastMesecniRows = rows;
        try {
          final sample = rows
              .take(5)
              .map(
                  (r) => r['putnik_ime'] ?? r['ime'] ?? r['id'] ?? r.toString())
              .toList();
          dlog(
              '🔔 [REALTIME] mesecni_putnici rows: ${rows.length}; sample: $sample');
        } catch (_) {}
        _emitCombinedPutnici();
      } catch (e) {
        // ignore
      }
    });

    // Fetch initial data to ensure streams have data immediately
    refreshNow();
  }

  /// Stop any centralized subscriptions started with [startForDriver]
  Future<void> stopForDriver() async {
    // _dailySub je komentarisana jer se ne kreira
    /*
    try {
      await _dailySub?.cancel();
      _dailySub = null;
    } catch (_) {}
    */
    try {
      await _putovanjaSub?.cancel();
      _putovanjaSub = null;
    } catch (_) {}
    try {
      await _mesecniSub?.cancel();
      _mesecniSub = null;
    } catch (_) {}

    // Clear internal state
    _lastPutovanjaRows.clear();
    _lastMesecniRows.clear();

    // Emit empty lists to clear UI
    if (!_putovanjaController.isClosed) {
      _putovanjaController.add([]);
    }
    if (!_combinedPutniciController.isClosed) {
      _combinedPutniciController.add([]);
    }
  }

  void _emitCombinedPutnici() {
    try {
      final combined = <Putnik>[];
      // Convert putovanja rows
      for (final r in _lastPutovanjaRows) {
        try {
          combined.add(Putnik.fromMap(r));
        } catch (e) {
          dlog('❌ Error converting putovanja row: $e, data: $r');
        }
      }
      // Convert mesecni rows - support both old and new schemas
      for (final Map<String, dynamic> map in _lastMesecniRows) {
        try {
          // New normalized schema: has 'ime' and 'prezime' and 'polasci_po_danu'
          if (map.containsKey('ime') && map.containsKey('prezime')) {
            try {
              final putnici = Putnik.fromMesecniPutniciMultiple(map);
              combined.addAll(putnici);
              continue;
            } catch (inner) {
              dlog('❌ Error converting new-mesecni row: $inner, data: $map');
            }
          }

          // Fallback: try legacy Putnik.fromMap for older schema
          try {
            combined.add(Putnik.fromMap(map));
          } catch (legacyErr) {
            dlog(
                '❌ Error converting mesecni row (legacy): $legacyErr, data: $map');
          }
        } catch (e) {
          dlog('❌ Error converting mesecni row: $e, data: $map');
        }
      }

      dlog('📊 Emitting ${combined.length} combined putnici');
      try {
        final sample = combined
            .take(10)
            .map((p) => '${p.ime}@${p.polazak}@${p.grad}')
            .toList();
        dlog('📋 Combined sample: $sample');
      } catch (_) {}
      if (!_combinedPutniciController.isClosed) {
        _combinedPutniciController.add(combined);
      }
    } catch (e) {
      dlog('❌ Error in _emitCombinedPutnici: $e');
    }
  }

  /// Expose a filtered stream for a specific isoDate. This applies client-side filter
  /// currently; later we will parametrize server queries for efficiency.
  Stream<List<Putnik>> streamKombinovaniPutnici(
      {String? isoDate, String? grad, String? vreme}) {
    if (isoDate == null && grad == null && vreme == null) {
      return combinedPutniciStream;
    }

    return combinedPutniciStream.map((list) {
      Iterable<Putnik> filtered = list;
      if (isoDate != null) {
        final targetDayAbbr = SlotUtils.isoDateToDayAbbr(isoDate);
        dlog(
            '🔍 Filtering by isoDate: $isoDate, targetDayAbbr: $targetDayAbbr');
        filtered = filtered.where((p) {
          final matches = (p.datum != null && p.datum == isoDate) ||
              (p.datum == null &&
                  GradAdresaValidator.normalizeString(p.dan).contains(
                      GradAdresaValidator.normalizeString(targetDayAbbr)));
          if (!matches) {
            dlog('❌ Filtered out: ${p.ime}, dan: ${p.dan}, datum: ${p.datum}');
          }
          return matches;
        });
      }
      if (grad != null) {
        dlog('🔍 Filtering by grad: $grad');
        filtered = filtered.where((p) {
          final matches =
              GradAdresaValidator.isGradMatch(p.grad, p.adresa, grad);
          if (!matches) {
            dlog('❌ Filtered out by grad: ${p.ime}, grad: ${p.grad}');
          }
          return matches;
        });
      }
      if (vreme != null) {
        dlog('🔍 Filtering by vreme: $vreme');
        filtered = filtered.where((p) {
          final matches = GradAdresaValidator.normalizeTime(p.polazak) ==
              GradAdresaValidator.normalizeTime(vreme);
          if (!matches) {
            dlog('❌ Filtered out by vreme: ${p.ime}, polazak: ${p.polazak}');
          }
          return matches;
        });
      }
      final result = filtered.toList();
      dlog('✅ Filtered result: ${result.length} putnici');
      return result;
    });
  }

  /// Parametric combined stream: creates per-filter realtime subscriptions
  /// and emits only Putnik lists relevant for the given filter key.
  Stream<List<Putnik>> streamKombinovaniPutniciParametric(
      {String? isoDate, String? grad, String? vreme}) {
    if (isoDate == null && grad == null && vreme == null) {
      return combinedPutniciStream;
    }

    final key = _paramKey(isoDate: isoDate, grad: grad, vreme: vreme);
    if (_paramControllers.containsKey(key)) {
      return _paramControllers[key]!.stream;
    }

    final controller = StreamController<List<Putnik>>.broadcast();
    _paramControllers[key] = controller;
    _paramLastPutovanja[key] = [];

    // Helper to emit combined for this key
    void emitForKey() {
      try {
        final combined = <Putnik>[];
        for (final r in _paramLastPutovanja[key] ?? []) {
          try {
            combined.add(Putnik.fromMap(r));
          } catch (_) {}
        }
        if (!controller.isClosed) controller.add(combined);
      } catch (_) {}
    }

    // Subscribe to putovanja_istorija; daily_checkins je komentarisana jer tabela ne postoji
    // TODO: Dodati daily_checkins kada se tabela kreira
    /*
    final dailySub = tableStream('daily_checkins').listen((dynamic data) {
      try {
        final rows = <Map<String, dynamic>>[];
        for (final r in data) {
          if (r is Map<String, dynamic>) {
            // Apply client-side match by isoDate/grad/vreme
            if (isoDate != null) {
              if ((r['datum']?.toString() ?? '') != isoDate) {
                continue;
              }
            }
            if (grad != null) {
              final putnikGrad = (r['grad'] ?? '').toString();
              final putnikAdresa = (r['adresa'] ?? '').toString();
              if (!GradAdresaValidator.isGradMatch(
                  putnikGrad, putnikAdresa, grad)) {
                continue;
              }
            }
            if (vreme != null) {
              final pVreme = (r['polazak'] ?? r['vreme'] ?? '').toString();
              if (GradAdresaValidator.normalizeTime(pVreme) !=
                  GradAdresaValidator.normalizeTime(vreme)) {
                continue;
              }
            }

            rows.add(Map<String, dynamic>.from(r));
          }
        }
        _paramLastDaily[key] = rows;
        emitForKey();
      } catch (_) {}
    });
    */

    final putovanjaSub =
        tableStream('putovanja_istorija').listen((dynamic data) {
      try {
        final rows = <Map<String, dynamic>>[];
        for (final r in data) {
          if (r is Map<String, dynamic>) {
            if (isoDate != null) {
              // match by datum if present, otherwise accept and rely on PutnikService filtering
              if ((r['datum']?.toString() ?? '') != isoDate) {
                continue;
              }
            }
            if (grad != null) {
              final putnikGrad = (r['grad'] ?? '').toString();
              final putnikAdresa = (r['adresa'] ?? '').toString();
              if (!GradAdresaValidator.isGradMatch(
                  putnikGrad, putnikAdresa, grad)) {
                continue;
              }
            }
            if (vreme != null) {
              final pVreme = (r['polazak'] ?? r['vreme'] ?? '').toString();
              if (GradAdresaValidator.normalizeTime(pVreme) !=
                  GradAdresaValidator.normalizeTime(vreme)) {
                continue;
              }
            }
            rows.add(Map<String, dynamic>.from(r));
          }
        }
        _paramLastPutovanja[key] = rows;
        emitForKey();
      } catch (_) {}
    });

    _paramSubscriptions[key] = [putovanjaSub];

    controller.onCancel = () async {
      try {
        for (final s in _paramSubscriptions[key] ?? []) {
          await s.cancel();
        }
      } catch (_) {}
      _paramSubscriptions.remove(key);
      _paramControllers.remove(key);
      _paramLastPutovanja.remove(key);
    };

    return controller.stream;
  }

  /// Trigger a one-off refresh (useful after resets) which will make the service re-query
  /// and emit the latest combined set.
  Future<void> refreshNow() async {
    try {
      final putovanja = await SupabaseSafe.select('putovanja_istorija');
      // ✅ ISPRAVLJENO: Dodaj filtere za aktivne i neobrisane mesečne putnike
      final mesecni = await Supabase.instance.client
          .from('mesecni_putnici')
          .select()
          .eq('aktivan', true)
          .eq('obrisan', false);

      _lastPutovanjaRows = (putovanja is List)
          ? putovanja.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : [];
      _lastMesecniRows =
          mesecni.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      try {
        final pSample = _lastPutovanjaRows
            .take(5)
            .map((r) => r['id']?.toString() ?? r.toString())
            .toList();
        final mSample = _lastMesecniRows
            .take(5)
            .map((r) => r['putnik_ime'] ?? r['ime'] ?? r['id'] ?? r.toString())
            .toList();
        dlog(
            '🔄 [REFRESH NOW] fetched putovanja: ${_lastPutovanjaRows.length}, mesecni: ${_lastMesecniRows.length}; samples: putovanja=$pSample, mesecni=$mSample');
      } catch (_) {}
      _emitCombinedPutnici();
    } catch (e) {
      dlog('❌ [REFRESH NOW] Error: $e');
    }
  }
}
