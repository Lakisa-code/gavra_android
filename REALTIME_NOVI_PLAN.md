# 🚀 NOVI REALTIME SISTEM - PLAN OD NULE

## 📋 CILJ
Centralizovani realtime manager koji upravlja svim WebSocket konekcijama, sa automatskim reconnect-om i optimalnim brojem channel-a.

---

## 🏗️ ARHITEKTURA

```
┌─────────────────────────────────────────────────────────┐
│                    RealtimeManager                       │
│  (Singleton - upravlja svim channel-ima)                │
├─────────────────────────────────────────────────────────┤
│  - _channels: Map<String, RealtimeChannel>              │
│  - _streams: Map<String, StreamController>              │
│  - _reconnectTimers: Map<String, Timer>                 │
│  - _isConnected: bool                                   │
├─────────────────────────────────────────────────────────┤
│  + subscribe(table, callback)                           │
│  + unsubscribe(table)                                   │
│  + unsubscribeAll()                                     │
│  + forceReconnect()                                     │
└─────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────┐
│              TABELE (1 channel po tabeli)               │
├─────────────────────────────────────────────────────────┤
│  📍 vozac_lokacije      → GPS tracking                  │
│  👥 registrovani_putnici → Lista putnika                │
│  🎫 kapacitet_polazaka  → Slobodna mesta                │
│  📊 daily_checkins      → Kusur vozača                  │
│  📝 voznje_log          → Istorija vožnji               │
└─────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────┐
│                    SERVISI/WIDGETI                       │
├─────────────────────────────────────────────────────────┤
│  PutnikService ──────────┐                              │
│  RegistrovaniPutnikService ──► slušaju isti stream      │
│  StatistikaService ──────┘                              │
│                                                         │
│  KombiEtaWidget ─────────┐                              │
│  AdminMapScreen ─────────┴──► slušaju isti GPS stream   │
└─────────────────────────────────────────────────────────┘
```

---

## 📁 STRUKTURA FAJLOVA

```
lib/services/realtime/
├── realtime_manager.dart       # Glavni singleton
├── realtime_config.dart        # Konfiguracija (tabele, retry delay...)
├── realtime_status.dart        # Enum za status konekcije
└── realtime_event.dart         # Model za realtime event
```

---

## 🔧 IMPLEMENTACIJA

### 1. `realtime_config.dart`
```dart
class RealtimeConfig {
  static const int reconnectDelaySeconds = 3;
  static const int maxReconnectAttempts = 5;
  static const int heartbeatIntervalSeconds = 30;
  
  static const List<String> tables = [
    'registrovani_putnici',
    'vozac_lokacije',
    'kapacitet_polazaka',
    'daily_checkins',
    'voznje_log',
  ];
}
```

### 2. `realtime_status.dart`
```dart
enum RealtimeStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}
```

### 3. `realtime_manager.dart`
```dart
class RealtimeManager {
  static final RealtimeManager _instance = RealtimeManager._internal();
  static RealtimeManager get instance => _instance;
  RealtimeManager._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Jedan channel po tabeli
  final Map<String, RealtimeChannel> _channels = {};
  
  // Stream controlleri za broadcast
  final Map<String, StreamController<PostgresChangePayload>> _controllers = {};
  
  // Status
  RealtimeStatus _status = RealtimeStatus.disconnected;
  int _reconnectAttempts = 0;
  
  // Listener count po tabeli (za cleanup)
  final Map<String, int> _listenerCount = {};

  /// Pretplati se na tabelu
  Stream<PostgresChangePayload> subscribe(String table) {
    _listenerCount[table] = (_listenerCount[table] ?? 0) + 1;
    
    if (!_controllers.containsKey(table)) {
      _controllers[table] = StreamController<PostgresChangePayload>.broadcast();
      _createChannel(table);
    }
    
    return _controllers[table]!.stream;
  }
  
  /// Odjavi se sa tabele
  void unsubscribe(String table) {
    _listenerCount[table] = (_listenerCount[table] ?? 1) - 1;
    
    // Ugasi channel samo ako nema više listenera
    if (_listenerCount[table] == 0) {
      _channels[table]?.unsubscribe();
      _channels.remove(table);
      _controllers[table]?.close();
      _controllers.remove(table);
    }
  }
  
  /// Kreiraj channel za tabelu
  void _createChannel(String table) {
    final channel = _supabase.channel('realtime_$table');
    
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      callback: (payload) {
        if (_controllers.containsKey(table) && !_controllers[table]!.isClosed) {
          _controllers[table]!.add(payload);
        }
      },
    ).subscribe((status, [error]) {
      _handleStatus(table, status, error);
    });
    
    _channels[table] = channel;
  }
  
  /// Handle status promene
  void _handleStatus(String table, RealtimeSubscribeStatus status, dynamic error) {
    switch (status) {
      case RealtimeSubscribeStatus.subscribed:
        _status = RealtimeStatus.connected;
        _reconnectAttempts = 0;
        debugPrint('✅ [RealtimeManager] $table connected');
        break;
        
      case RealtimeSubscribeStatus.channelError:
      case RealtimeSubscribeStatus.closed:
      case RealtimeSubscribeStatus.timedOut:
        debugPrint('❌ [RealtimeManager] $table error: $status');
        _scheduleReconnect(table);
        break;
    }
  }
  
  /// Reconnect sa exponential backoff
  void _scheduleReconnect(String table) {
    if (_reconnectAttempts >= RealtimeConfig.maxReconnectAttempts) {
      _status = RealtimeStatus.error;
      debugPrint('🔴 [RealtimeManager] Max reconnect attempts reached for $table');
      return;
    }
    
    _status = RealtimeStatus.reconnecting;
    _reconnectAttempts++;
    
    final delay = RealtimeConfig.reconnectDelaySeconds * _reconnectAttempts;
    debugPrint('🔄 [RealtimeManager] Reconnecting $table in ${delay}s (attempt $_reconnectAttempts)');
    
    Future.delayed(Duration(seconds: delay), () {
      if (_controllers.containsKey(table) && !_controllers[table]!.isClosed) {
        _channels[table]?.unsubscribe();
        _createChannel(table);
      }
    });
  }
  
  /// Ugasi sve
  void dispose() {
    for (final channel in _channels.values) {
      channel.unsubscribe();
    }
    for (final controller in _controllers.values) {
      controller.close();
    }
    _channels.clear();
    _controllers.clear();
    _listenerCount.clear();
  }
}
```

---

## 🔄 MIGRACIJA POSTOJEĆIH SERVISA

### PRE (staro):
```dart
// KombiEtaWidget - svaki widget ima svoj channel
_channel = supabase.channel('gps_eta_${widget.putnikIme}');
_channel!.onPostgresChanges(...).subscribe(...);
```

### POSLE (novo):
```dart
// KombiEtaWidget - svi widgeti dele isti stream
_subscription = RealtimeManager.instance
    .subscribe('vozac_lokacije')
    .listen((payload) {
      _loadGpsData();
    });

@override
void dispose() {
  _subscription?.cancel();
  RealtimeManager.instance.unsubscribe('vozac_lokacije');
  super.dispose();
}
```

---

## ✅ PREDNOSTI NOVOG SISTEMA

| Aspekt | Staro | Novo |
|--------|-------|------|
| Broj channel-a za GPS | 20 (po putniku) | 1 |
| Reconnect logika | Svaki servis posebno | Centralno |
| Cleanup | Ručno svuda | Automatski |
| Debugging | Teško pratiti | Jedan log |
| Memory leaks | Moguće | Sprečeno |

---

## 📅 KORACI IMPLEMENTACIJE

1. ⬜ Kreirati `lib/services/realtime/` folder
2. ⬜ Implementirati `RealtimeManager`
3. ⬜ Migrirati `KombiEtaWidget` (najviše channel-a)
4. ⬜ Migrirati `AdminMapScreen`
5. ⬜ Migrirati `DailyCheckInService`
6. ⬜ Migrirati `KapacitetService`
7. ⬜ Migrirati `PutnikService`
8. ⬜ Migrirati `RegistrovaniPutnikService`
9. ⬜ Testirati reconnect scenarije
10. ⬜ Obrisati stari kod

---

## ⚠️ RIZICI

- Potrebno testiranje na lošoj mreži
- Pažljivo sa listener count-om da se ne ugasi channel prerano
- Backward compatibility sa postojećim kodom
