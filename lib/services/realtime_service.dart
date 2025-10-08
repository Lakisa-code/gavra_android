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

  // Expose read-only copies
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
          '🔔 [REALTIME SERVICE] Stream event for $table: ${(data as List?)?.length ?? 0} rows',
        );
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
    String table,
    void Function(dynamic) onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    void loggedOnData(dynamic data) {
      dlog('🔄 Realtime event for $table: ${data?.length ?? 0} records');
      onData(data);
    }

    final stream = tableStream(table);
    return stream.listen(
      loggedOnData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
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

    // 🔄 PUTOVANJA ISTORIJA - umesto dnevni_putnici
    _putovanjaSub = tableStream('putovanja_istorija').listen((dynamic data) {
      try {
        final rows = <Map<String, dynamic>>[];
        for (final r in (data as List<dynamic>)) {
          if (r is Map) {
            rows.add(Map<String, dynamic>.from(r));
          }
        }
        _lastPutovanjaRows = rows;
        try {
          final sample = rows
              .take(5)
              .map(
                (r) => r['putnik_ime'] ?? r['id']?.toString() ?? r.toString(),
              )
              .toList();
          dlog(
            '🔔 [REALTIME] putovanja_istorija rows: ${rows.length}; sample: $sample',
          );
        } catch (_) {}
        if (!_putovanjaController.isClosed) {
          _putovanjaController.add(rows);
        }
        _emitCombinedPutnici();
      } catch (e) {
        dlog('❌ [REALTIME] Error processing putovanja_istorija: $e');
      }
    });

    // mesecni_putnici
    _mesecniSub = tableStream('mesecni_putnici').listen((dynamic data) {
      try {
        final rows = <Map<String, dynamic>>[];
        for (final r in (data as List<dynamic>)) {
          if (r is Map) {
            rows.add(Map<String, dynamic>.from(r));
          }
        }
        _lastMesecniRows = rows;
        try {
          final sample = rows
              .take(5)
              .map(
                (r) => r['putnik_ime'] ?? r['ime'] ?? r['id'] ?? r.toString(),
              )
              .toList();
          dlog(
            '🔔 [REALTIME] mesecni_putnici rows: ${rows.length}; sample: $sample',
          );
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

      // 🔄 Convert putovanja_istorija rows to Putnik objects
      for (final r in _lastPutovanjaRows) {
        try {
          // 🔄 Za putovanja istorija, trebaju podaci iz mesecni_putnici tabele
          // Pronađi odgovarajući mesečni putnik red
          String? putnikIme;
          String? grad;
          double? iznosPlacanja;

          final mesecniPutnikId = r['mesecni_putnik_id'] as String?;
          if (mesecniPutnikId != null) {
            // Pronađi odgovarajući mesečni putnik
            for (final mesecniMap in _lastMesecniRows) {
              if (mesecniMap['id'] == mesecniPutnikId) {
                putnikIme = mesecniMap['putnik_ime'] as String?;
                iznosPlacanja =
                    (mesecniMap['ukupna_cena_meseca'] as num?)?.toDouble();
                // Za grad, koristimo logiku: ako je mesečno plaćanje, označavamo kao takvo
                grad = 'mesecno_placanje';
                break;
              }
            }
          }

          final putnik = Putnik(
            id: r['id'] as String? ?? '',
            ime: putnikIme ?? '',
            polazak: r['vreme_polaska'] as String? ?? 'mesecno_placanje',
            grad: grad ?? '',
            dan: r['dan'] as String? ?? '',
            adresa: r['adresa'] as String?,
            datum: r['datum_putovanja']?.toString(),
            status: r['status'] as String?,
            obrisan: r['obrisan'] == true,
            mesecnaKarta: true, // putovanja iz istorije su mesečni
            iznosPlacanja: iznosPlacanja,
            vremePokupljenja: r['vreme_pokupljenja'] != null
                ? DateTime.tryParse(r['vreme_pokupljenja'].toString())
                : null,
            brojTelefona: r['broj_telefona']?.toString(),
          );
          combined.add(putnik);
        } catch (e) {
          dlog('❌ Error converting dnevni_putnici row: $e, data: $r');
        }
      }

      // Convert mesecni rows - use current MesecniPutnik model structure
      for (final Map<String, dynamic> map in _lastMesecniRows) {
        try {
          // 🔄 Koristi MesecniPutnik.fromMap da parsira mesečne putnike
          // PROBLEM: MesecniPutnik ima drukčiju strukturu od Putnik objekta
          // Za sada, direktno kreiraj Putnik objekat iz mesecni_putnici tabele

          // ✅ ISPRAVKA: Koristi Putnik.fromMesecniPutniciMultipleForDay za sve dane
          final radniDani = (map['radni_dani'] as String? ?? '').split(',');

          for (final dan in radniDani) {
            if (dan.trim().isEmpty) continue;

            final putniciZaDan =
                Putnik.fromMesecniPutniciMultipleForDay(map, dan.trim());
            for (final putnik in putniciZaDan) {
              combined.add(putnik);
            }
          }
          continue;
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
  Stream<List<Putnik>> streamKombinovaniPutnici({
    String? isoDate,
    String? grad,
    String? vreme,
  }) {
    if (isoDate == null && grad == null && vreme == null) {
      return combinedPutniciStream;
    }

    return combinedPutniciStream.map((list) {
      Iterable<Putnik> filtered = list;
      if (isoDate != null) {
        final targetDayAbbr = SlotUtils.isoDateToDayAbbr(isoDate);

        filtered = filtered.where((p) {
          final matches = (p.datum != null && p.datum == isoDate) ||
              (p.datum == null &&
                  GradAdresaValidator.normalizeString(p.dan).contains(
                    GradAdresaValidator.normalizeString(targetDayAbbr),
                  ));

          return matches;
        });
      }
      if (grad != null) {
        filtered = filtered.where((p) {
          final matches =
              GradAdresaValidator.isGradMatch(p.grad, p.adresa, grad);

          return matches;
        });
      }
      if (vreme != null) {
        filtered = filtered.where((p) {
          final matches = GradAdresaValidator.normalizeTime(p.polazak) ==
              GradAdresaValidator.normalizeTime(vreme);

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
  Stream<List<Putnik>> streamKombinovaniPutniciParametric({
    String? isoDate,
    String? grad,
    String? vreme,
  }) {
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
            combined.add(Putnik.fromMap(r as Map<String, dynamic>));
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

    final putovanjaSub = tableStream('dnevni_putnici').listen((dynamic data) {
      try {
        final rows = <Map<String, dynamic>>[];
        for (final r in (data as List<dynamic>)) {
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
                putnikGrad,
                putnikAdresa,
                grad,
              )) {
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
      // 🆕 KORISTI NORMALIZOVANU ŠEMU: dnevni_putnici i mesecni_putnici
      final dnevniPutnici = await SupabaseSafe.select('dnevni_putnici');
      final mesecniPutnici = await Supabase.instance.client
          .from('mesecni_putnici')
          .select()
          .eq('aktivan', true)
          .eq('obrisan', false);

      // 🔄 Ažuriraj interne varijable da koriste nove tabele
      _lastPutovanjaRows = (dnevniPutnici is List)
          ? dnevniPutnici
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : [];
      _lastMesecniRows = mesecniPutnici
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      try {
        final dSample = _lastPutovanjaRows
            .take(5)
            .map((r) => r['ime'] ?? r['id']?.toString() ?? r.toString())
            .toList();
        final mSample = _lastMesecniRows
            .take(5)
            .map((r) => r['ime'] ?? r['putnik_ime'] ?? r['id'] ?? r.toString())
            .toList();
        dlog(
          '🔄 [REFRESH NOW] fetched dnevni: ${_lastPutovanjaRows.length}, mesecni: ${_lastMesecniRows.length}; samples: dnevni=$dSample, mesecni=$mSample',
        );
      } catch (_) {}
      _emitCombinedPutnici();
    } catch (e) {
      dlog('❌ [REFRESH NOW] Error: $e');
    }
  }
}
