// 🚀 REALTIME HUB SERVICE - Centralizovani Supabase Realtime Channels
// ✅ OPTIMIZACIJA: Koristi prave WebSocket channels umesto .stream()
//
// PREDNOSTI:
// - Šalje SAMO promene (INSERT/UPDATE/DELETE), ne sve podatke
// - Manji bandwidth i manja cena
// - Jedan kanal za celu aplikaciju

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/registrovani_putnik.dart';

/// Singleton servis koji održava JEDAN Realtime Channel za registrovani_putnici
/// Koristi Postgres Changes umesto .stream() za manju potrošnju
class RealtimeHubService {
  // Singleton pattern
  RealtimeHubService._internal();
  static final RealtimeHubService _instance = RealtimeHubService._internal();
  static RealtimeHubService get instance => _instance;

  // Supabase klijent
  final _supabase = Supabase.instance.client;

  // Realtime channel
  RealtimeChannel? _channel;

  // Stream controllers za broadcast
  final _putnikController = StreamController<List<RegistrovaniPutnik>>.broadcast();
  final _changeController = StreamController<PostgresChangePayload>.broadcast();

  // Cache podataka - inicijalno učitavanje + incremental updates
  List<Map<String, dynamic>> _cachedData = [];
  List<RegistrovaniPutnik> _cachedPutnici = [];

  // Status
  bool _isInitialized = false;
  bool _isSubscribed = false;

  /// Inicijalizuje Realtime Channel (pozovi jednom pri startu aplikacije)
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // 1. Prvo učitaj inicijalne podatke (jednom)
    await _loadInitialData();

    // 2. Pretplati se na promene (samo delta)
    _subscribeToChanges();
  }

  /// Učitava inicijalne podatke iz baze (jednom)
  Future<void> _loadInitialData() async {
    try {
      final response = await _supabase.from('registrovani_putnici').select().eq('obrisan', false).order('putnik_ime');

      _cachedData = List<Map<String, dynamic>>.from(response);
      _updatePutnikCache();
      _putnikController.add(_cachedPutnici);
    } catch (e) {
      // Greška pri učitavanju - nastavi sa praznom listom
      _cachedData = [];
      _cachedPutnici = [];
    }
  }

  /// Pretplaćuje se na Postgres Changes (INSERT, UPDATE, DELETE)
  void _subscribeToChanges() {
    if (_isSubscribed) return;

    _channel = _supabase.channel('registrovani_putnici_changes');

    _channel!
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'registrovani_putnici',
      callback: (payload) {
        _handleChange(payload);
      },
    )
        .subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        _isSubscribed = true;
      } else if (status == RealtimeSubscribeStatus.closed) {
        _isSubscribed = false;
        // Retry nakon 5 sekundi
        Timer(const Duration(seconds: 5), () {
          if (_isInitialized && !_isSubscribed) {
            _subscribeToChanges();
          }
        });
      }
    });
  }

  /// Obrađuje promenu iz Realtime kanala
  void _handleChange(PostgresChangePayload payload) {
    // Emituj raw change za one koji žele da slušaju pojedinačne promene
    _changeController.add(payload);

    final eventType = payload.eventType;
    final newRecord = payload.newRecord;
    final oldRecord = payload.oldRecord;

    switch (eventType) {
      case PostgresChangeEvent.insert:
        if (newRecord.isNotEmpty && newRecord['obrisan'] != true) {
          _cachedData.add(Map<String, dynamic>.from(newRecord));
        }
        break;

      case PostgresChangeEvent.update:
        if (newRecord.isNotEmpty) {
          final id = newRecord['id'];
          final index = _cachedData.indexWhere((row) => row['id'] == id);

          if (newRecord['obrisan'] == true) {
            // Ako je obrisan, ukloni iz cache-a
            if (index >= 0) {
              _cachedData.removeAt(index);
            }
          } else if (index >= 0) {
            // Update postojećeg
            _cachedData[index] = Map<String, dynamic>.from(newRecord);
          } else {
            // Novi (možda je bio obrisan pa vraćen)
            _cachedData.add(Map<String, dynamic>.from(newRecord));
          }
        }
        break;

      case PostgresChangeEvent.delete:
        if (oldRecord.isNotEmpty) {
          final id = oldRecord['id'];
          _cachedData.removeWhere((row) => row['id'] == id);
        }
        break;

      default:
        break;
    }

    // Ažuriraj putnik cache i emituj
    _updatePutnikCache();
    _putnikController.add(_cachedPutnici);
  }

  /// Ažurira cache parsiranih RegistrovaniPutnik objekata
  void _updatePutnikCache() {
    try {
      final putnici = _cachedData.map((json) => RegistrovaniPutnik.fromMap(json)).toList();

      // Sortiraj: aktivni na vrhu (po imenu), neaktivni na dnu (po imenu)
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

  /// Stream parsiranih RegistrovaniPutnik objekata
  Stream<List<RegistrovaniPutnik>> get putnikStream {
    if (!_isInitialized) {
      initialize();
    }
    // Emituj cached vrednost odmah, pa nastavi sa stream-om
    return _putnikController.stream;
  }

  /// Stream pojedinačnih promena (za specifične use-case-ove)
  Stream<PostgresChangePayload> get changeStream => _changeController.stream;

  /// Dohvati poslednju cached vrednost (bez čekanja)
  List<RegistrovaniPutnik> get cachedPutnici => _cachedPutnici;
  List<Map<String, dynamic>> get cachedRawData => _cachedData;

  /// Stream samo aktivnih putnika
  Stream<List<RegistrovaniPutnik>> get aktivniPutnikStream {
    return putnikStream.map((putnici) => putnici.where((p) => p.aktivan).toList());
  }

  /// Stream filtriran po gradu
  Stream<List<RegistrovaniPutnik>> streamPoGradu(String grad) {
    return putnikStream
        .map((putnici) => putnici.where((p) => (p.grad ?? '').toLowerCase() == grad.toLowerCase()).toList());
  }

  /// Forsira refresh (ponovo učitaj sve iz baze)
  Future<void> refresh() async {
    await _loadInitialData();
  }

  /// Očisti resurse (pozovi pri logout/dispose)
  void dispose() {
    _channel?.unsubscribe();
    _isSubscribed = false;
    _isInitialized = false;
    _cachedData = [];
    _cachedPutnici = [];
  }

  /// Reset i ponovna inicijalizacija
  Future<void> reset() async {
    dispose();
    await initialize();
  }
}
