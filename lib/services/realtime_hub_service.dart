import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/registrovani_putnik.dart';

/// Singleton servis koji održava Realtime Channels za sve tabele
class RealtimeHubService {
  // Singleton pattern
  RealtimeHubService._internal();
  static final RealtimeHubService _instance = RealtimeHubService._internal();
  static RealtimeHubService get instance => _instance;

  // Supabase klijent
  final _supabase = Supabase.instance.client;

  // ==================== REGISTROVANI PUTNICI ====================
  RealtimeChannel? _putnikChannel;
  final _putnikController = StreamController<List<RegistrovaniPutnik>>.broadcast();
  final _putnikChangeController = StreamController<PostgresChangePayload>.broadcast();
  List<Map<String, dynamic>> _cachedPutnikData = [];
  List<RegistrovaniPutnik> _cachedPutnici = [];
  bool _putnikSubscribed = false;

  // ==================== VOZAC LOKACIJE (GPS) ====================
  RealtimeChannel? _gpsChannel;
  final _gpsController = StreamController<List<Map<String, dynamic>>>.broadcast();
  List<Map<String, dynamic>> _cachedGpsData = [];
  bool _gpsSubscribed = false;

  // ==================== VOZACI ====================
  RealtimeChannel? _vozaciChannel;
  final _vozaciController = StreamController<List<Map<String, dynamic>>>.broadcast();
  List<Map<String, dynamic>> _cachedVozaciData = [];
  bool _vozaciSubscribed = false;

  // ==================== KAPACITET POLAZAKA ====================
  RealtimeChannel? _kapacitetChannel;
  final _kapacitetController = StreamController<Map<String, Map<String, int>>>.broadcast();
  Map<String, Map<String, int>> _cachedKapacitet = {'BC': {}, 'VS': {}};
  bool _kapacitetSubscribed = false;

  // ==================== VOZNJE LOG ====================
  RealtimeChannel? _voznjeLogChannel;
  final _voznjeLogController = StreamController<PostgresChangePayload>.broadcast();
  bool _voznjeLogSubscribed = false;

  // Status
  bool _isInitialized = false;

  /// Inicijalizuje sve Realtime Channels (pozovi jednom pri startu aplikacije)
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Učitaj inicijalne podatke paralelno
    await Future.wait([
      _loadPutnikData(),
      _loadGpsData(),
      _loadVozaciData(),
      _loadKapacitetData(),
    ]);

    // Pretplati se na promene
    _subscribeToPutnikChanges();
    _subscribeToGpsChanges();
    _subscribeToVozaciChanges();
    _subscribeToKapacitetChanges();
    _subscribeToVoznjeLogChanges();
  }

  // ==================== REGISTROVANI PUTNICI IMPL ====================

  Future<void> _loadPutnikData() async {
    try {
      final response = await _supabase.from('registrovani_putnici').select().eq('obrisan', false).order('putnik_ime');
      _cachedPutnikData = List<Map<String, dynamic>>.from(response);
      _updatePutnikCache();
      _putnikController.add(_cachedPutnici);
    } catch (e) {
      _cachedPutnikData = [];
      _cachedPutnici = [];
    }
  }

  void _subscribeToPutnikChanges() {
    if (_putnikSubscribed) return;
    _putnikChannel = _supabase.channel('registrovani_putnici_changes');
    _putnikChannel!
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'registrovani_putnici',
      callback: (payload) => _handlePutnikChange(payload),
    )
        .subscribe((status, [error]) {
      _putnikSubscribed = status == RealtimeSubscribeStatus.subscribed;
      if (status == RealtimeSubscribeStatus.closed) {
        Timer(const Duration(seconds: 5), () {
          if (_isInitialized && !_putnikSubscribed) _subscribeToPutnikChanges();
        });
      }
    });
  }

  void _handlePutnikChange(PostgresChangePayload payload) {
    _putnikChangeController.add(payload);
    final newRecord = payload.newRecord;
    final oldRecord = payload.oldRecord;

    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        if (newRecord.isNotEmpty && newRecord['obrisan'] != true) {
          _cachedPutnikData.add(Map<String, dynamic>.from(newRecord));
        }
        break;
      case PostgresChangeEvent.update:
        if (newRecord.isNotEmpty) {
          final id = newRecord['id'];
          final index = _cachedPutnikData.indexWhere((row) => row['id'] == id);
          if (newRecord['obrisan'] == true) {
            if (index >= 0) _cachedPutnikData.removeAt(index);
          } else if (index >= 0) {
            _cachedPutnikData[index] = Map<String, dynamic>.from(newRecord);
          } else {
            _cachedPutnikData.add(Map<String, dynamic>.from(newRecord));
          }
        }
        break;
      case PostgresChangeEvent.delete:
        if (oldRecord.isNotEmpty) {
          _cachedPutnikData.removeWhere((row) => row['id'] == oldRecord['id']);
        }
        break;
      default:
        break;
    }
    _updatePutnikCache();
    _putnikController.add(_cachedPutnici);
  }

  void _updatePutnikCache() {
    try {
      final putnici = _cachedPutnikData.map((json) => RegistrovaniPutnik.fromMap(json)).toList();
      putnici.sort((a, b) {
        if (a.aktivan && !b.aktivan) return -1;
        if (!a.aktivan && b.aktivan) return 1;
        return a.putnikIme.compareTo(b.putnikIme);
      });
      _cachedPutnici = putnici;
    } catch (e) {
      _cachedPutnici = [];
    }
  }

  Stream<List<RegistrovaniPutnik>> get putnikStream {
    if (!_isInitialized) initialize();
    return _putnikController.stream;
  }

  Stream<PostgresChangePayload> get putnikChangeStream => _putnikChangeController.stream;
  List<RegistrovaniPutnik> get cachedPutnici => _cachedPutnici;
  List<Map<String, dynamic>> get cachedRawData => _cachedPutnikData;

  Stream<List<RegistrovaniPutnik>> get aktivniPutnikStream {
    return putnikStream.map((putnici) => putnici.where((p) => p.aktivan).toList());
  }

  Stream<List<RegistrovaniPutnik>> streamPoGradu(String grad) {
    return putnikStream
        .map((putnici) => putnici.where((p) => (p.grad ?? '').toLowerCase() == grad.toLowerCase()).toList());
  }

  // ==================== VOZAC LOKACIJE (GPS) IMPL ====================

  Future<void> _loadGpsData() async {
    try {
      final response = await _supabase.from('vozac_lokacije').select();
      _cachedGpsData = List<Map<String, dynamic>>.from(response);
      _gpsController.add(_cachedGpsData);
    } catch (e) {
      _cachedGpsData = [];
    }
  }

  void _subscribeToGpsChanges() {
    if (_gpsSubscribed) return;
    _gpsChannel = _supabase.channel('vozac_lokacije_changes');
    _gpsChannel!
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'vozac_lokacije',
      callback: (payload) => _handleGpsChange(payload),
    )
        .subscribe((status, [error]) {
      _gpsSubscribed = status == RealtimeSubscribeStatus.subscribed;
      if (status == RealtimeSubscribeStatus.closed) {
        Timer(const Duration(seconds: 5), () {
          if (_isInitialized && !_gpsSubscribed) _subscribeToGpsChanges();
        });
      }
    });
  }

  void _handleGpsChange(PostgresChangePayload payload) {
    final newRecord = payload.newRecord;
    final oldRecord = payload.oldRecord;

    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        if (newRecord.isNotEmpty) {
          _cachedGpsData.add(Map<String, dynamic>.from(newRecord));
        }
        break;
      case PostgresChangeEvent.update:
        if (newRecord.isNotEmpty) {
          final id = newRecord['id'];
          final index = _cachedGpsData.indexWhere((row) => row['id'] == id);
          if (index >= 0) {
            _cachedGpsData[index] = Map<String, dynamic>.from(newRecord);
          } else {
            _cachedGpsData.add(Map<String, dynamic>.from(newRecord));
          }
        }
        break;
      case PostgresChangeEvent.delete:
        if (oldRecord.isNotEmpty) {
          _cachedGpsData.removeWhere((row) => row['id'] == oldRecord['id']);
        }
        break;
      default:
        break;
    }
    _gpsController.add(_cachedGpsData);
  }

  /// Stream GPS lokacija vozača
  Stream<List<Map<String, dynamic>>> get gpsStream {
    if (!_isInitialized) initialize();
    return _gpsController.stream;
  }

  /// Stream GPS lokacija filtriran po gradu
  Stream<List<Map<String, dynamic>>> gpsStreamPoGradu(String grad) {
    return gpsStream.map((data) => data.where((row) => row['grad'] == grad).toList());
  }

  List<Map<String, dynamic>> get cachedGpsData => _cachedGpsData;

  // ==================== VOZACI IMPL ====================

  Future<void> _loadVozaciData() async {
    try {
      final response = await _supabase.from('vozaci').select();
      _cachedVozaciData = List<Map<String, dynamic>>.from(response);
      _vozaciController.add(_cachedVozaciData);
    } catch (e) {
      _cachedVozaciData = [];
    }
  }

  void _subscribeToVozaciChanges() {
    if (_vozaciSubscribed) return;
    _vozaciChannel = _supabase.channel('vozaci_changes');
    _vozaciChannel!
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'vozaci',
      callback: (payload) => _handleVozaciChange(payload),
    )
        .subscribe((status, [error]) {
      _vozaciSubscribed = status == RealtimeSubscribeStatus.subscribed;
      if (status == RealtimeSubscribeStatus.closed) {
        Timer(const Duration(seconds: 5), () {
          if (_isInitialized && !_vozaciSubscribed) _subscribeToVozaciChanges();
        });
      }
    });
  }

  void _handleVozaciChange(PostgresChangePayload payload) {
    final newRecord = payload.newRecord;
    final oldRecord = payload.oldRecord;

    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        if (newRecord.isNotEmpty) {
          _cachedVozaciData.add(Map<String, dynamic>.from(newRecord));
        }
        break;
      case PostgresChangeEvent.update:
        if (newRecord.isNotEmpty) {
          final id = newRecord['id'];
          final index = _cachedVozaciData.indexWhere((row) => row['id'] == id);
          if (index >= 0) {
            _cachedVozaciData[index] = Map<String, dynamic>.from(newRecord);
          } else {
            _cachedVozaciData.add(Map<String, dynamic>.from(newRecord));
          }
        }
        break;
      case PostgresChangeEvent.delete:
        if (oldRecord.isNotEmpty) {
          _cachedVozaciData.removeWhere((row) => row['id'] == oldRecord['id']);
        }
        break;
      default:
        break;
    }
    _vozaciController.add(_cachedVozaciData);
  }

  /// Stream vozača
  Stream<List<Map<String, dynamic>>> get vozaciStream {
    if (!_isInitialized) initialize();
    return _vozaciController.stream;
  }

  /// Stream kusura za određenog vozača
  Stream<double> streamKusurZaVozaca(String vozacIme) {
    return vozaciStream.map((data) {
      final vozac = data.where((row) => row['ime'] == vozacIme).firstOrNull;
      return (vozac?['kusur'] as num?)?.toDouble() ?? 0.0;
    });
  }

  List<Map<String, dynamic>> get cachedVozaciData => _cachedVozaciData;

  // ==================== KAPACITET POLAZAKA IMPL ====================

  Future<void> _loadKapacitetData() async {
    try {
      final response = await _supabase.from('kapacitet_polazaka').select().eq('aktivan', true);
      _updateKapacitetCache(List<Map<String, dynamic>>.from(response));
      _kapacitetController.add(_cachedKapacitet);
    } catch (e) {
      _cachedKapacitet = {'BC': {}, 'VS': {}};
    }
  }

  void _subscribeToKapacitetChanges() {
    if (_kapacitetSubscribed) return;
    _kapacitetChannel = _supabase.channel('kapacitet_polazaka_changes');
    _kapacitetChannel!
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'kapacitet_polazaka',
      callback: (payload) => _handleKapacitetChange(payload),
    )
        .subscribe((status, [error]) {
      _kapacitetSubscribed = status == RealtimeSubscribeStatus.subscribed;
      if (status == RealtimeSubscribeStatus.closed) {
        Timer(const Duration(seconds: 5), () {
          if (_isInitialized && !_kapacitetSubscribed) _subscribeToKapacitetChanges();
        });
      }
    });
  }

  void _handleKapacitetChange(PostgresChangePayload payload) {
    // Za kapacitet, jednostavnije je ponovo učitati sve
    _loadKapacitetData();
  }

  void _updateKapacitetCache(List<Map<String, dynamic>> data) {
    _cachedKapacitet = {'BC': {}, 'VS': {}};
    for (final row in data) {
      if (row['aktivan'] != true) continue;
      final grad = row['grad'] as String?;
      final vreme = row['vreme'] as String?;
      final maxMesta = row['max_mesta'] as int?;
      if (grad != null && vreme != null && maxMesta != null) {
        _cachedKapacitet[grad]?[vreme] = maxMesta;
      }
    }
  }

  /// Stream kapaciteta
  Stream<Map<String, Map<String, int>>> get kapacitetStream {
    if (!_isInitialized) initialize();
    return _kapacitetController.stream;
  }

  Map<String, Map<String, int>> get cachedKapacitet => _cachedKapacitet;

  // ==================== VOZNJE LOG IMPL ====================

  void _subscribeToVoznjeLogChanges() {
    if (_voznjeLogSubscribed) return;
    _voznjeLogChannel = _supabase.channel('voznje_log_changes');
    _voznjeLogChannel!
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'voznje_log',
      callback: (payload) => _voznjeLogController.add(payload),
    )
        .subscribe((status, [error]) {
      _voznjeLogSubscribed = status == RealtimeSubscribeStatus.subscribed;
      if (status == RealtimeSubscribeStatus.closed) {
        Timer(const Duration(seconds: 5), () {
          if (_isInitialized && !_voznjeLogSubscribed) _subscribeToVoznjeLogChanges();
        });
      }
    });
  }

  /// Stream promena u voznje_log (samo promene, ne podaci)
  Stream<PostgresChangePayload> get voznjeLogChangeStream => _voznjeLogController.stream;

  // ==================== UTILITY METODE ====================

  /// Forsira refresh svih podataka
  Future<void> refresh() async {
    await Future.wait([
      _loadPutnikData(),
      _loadGpsData(),
      _loadVozaciData(),
      _loadKapacitetData(),
    ]);
  }

  /// Očisti resurse (pozovi pri logout/dispose)
  void dispose() {
    _putnikChannel?.unsubscribe();
    _gpsChannel?.unsubscribe();
    _vozaciChannel?.unsubscribe();
    _kapacitetChannel?.unsubscribe();
    _voznjeLogChannel?.unsubscribe();

    _putnikSubscribed = false;
    _gpsSubscribed = false;
    _vozaciSubscribed = false;
    _kapacitetSubscribed = false;
    _voznjeLogSubscribed = false;
    _isInitialized = false;

    _cachedPutnikData = [];
    _cachedPutnici = [];
    _cachedGpsData = [];
    _cachedVozaciData = [];
    _cachedKapacitet = {'BC': {}, 'VS': {}};
  }

  /// Reset i ponovna inicijalizacija
  Future<void> reset() async {
    dispose();
    await initialize();
  }
}
