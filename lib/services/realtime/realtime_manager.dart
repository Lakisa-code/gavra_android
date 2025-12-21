import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'realtime_config.dart';
import 'realtime_status.dart';

/// Centralizovani manager za sve Supabase Realtime konekcije
///
/// Singleton koji upravlja svim channel-ima, sa automatskim reconnect-om
/// i optimalnim brojem konekcija (1 channel po tabeli).
///
/// Korišćenje:
/// ```dart
/// // Pretplata
/// final subscription = RealtimeManager.instance
///     .subscribe('vozac_lokacije')
///     .listen((payload) => handleChange(payload));
///
/// // Otkazivanje
/// subscription.cancel();
/// RealtimeManager.instance.unsubscribe('vozac_lokacije');
/// ```
class RealtimeManager {
  RealtimeManager._internal();

  static final RealtimeManager _instance = RealtimeManager._internal();
  static RealtimeManager get instance => _instance;

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Jedan channel po tabeli
  final Map<String, RealtimeChannel> _channels = {};

  /// Stream controlleri za broadcast
  final Map<String, StreamController<PostgresChangePayload>> _controllers = {};

  /// Broj listenera po tabeli (za cleanup)
  final Map<String, int> _listenerCount = {};

  /// Broj reconnect pokušaja po tabeli
  final Map<String, int> _reconnectAttempts = {};

  /// Status po tabeli
  final Map<String, RealtimeStatus> _statusMap = {};

  /// Globalni status stream
  final StreamController<Map<String, RealtimeStatus>> _statusController =
      StreamController<Map<String, RealtimeStatus>>.broadcast();

  /// Stream za praćenje statusa svih tabela
  Stream<Map<String, RealtimeStatus>> get statusStream => _statusController.stream;

  /// Trenutni status za tabelu
  RealtimeStatus getStatus(String table) => _statusMap[table] ?? RealtimeStatus.disconnected;

  /// Pretplati se na promene u tabeli
  ///
  /// Vraća Stream koji emituje PostgresChangePayload pri svakoj promeni.
  /// Više listenera može slušati isti stream - deli se isti channel.
  Stream<PostgresChangePayload> subscribe(String table) {
    _listenerCount[table] = (_listenerCount[table] ?? 0) + 1;
    debugPrint('📡 [RealtimeManager] Subscribe to $table (listeners: ${_listenerCount[table]})');

    if (!_controllers.containsKey(table) || _controllers[table]!.isClosed) {
      _controllers[table] = StreamController<PostgresChangePayload>.broadcast();
      _createChannel(table);
    }

    return _controllers[table]!.stream;
  }

  /// Odjavi se sa tabele
  ///
  /// Channel se zatvara samo kad nema više listenera.
  void unsubscribe(String table) {
    _listenerCount[table] = (_listenerCount[table] ?? 1) - 1;
    debugPrint('📡 [RealtimeManager] Unsubscribe from $table (listeners: ${_listenerCount[table]})');

    // Ugasi channel samo ako nema više listenera
    if (_listenerCount[table] != null && _listenerCount[table]! <= 0) {
      _closeChannel(table);
    }
  }

  /// Forsiraj reconnect za tabelu
  void forceReconnect(String table) {
    debugPrint('🔄 [RealtimeManager] Force reconnect for $table');
    _reconnectAttempts[table] = 0;
    _closeChannel(table);
    if (_listenerCount[table] != null && _listenerCount[table]! > 0) {
      _createChannel(table);
    }
  }

  /// Forsiraj reconnect za sve tabele
  void forceReconnectAll() {
    debugPrint('🔄 [RealtimeManager] Force reconnect ALL');
    for (final table in _channels.keys.toList()) {
      forceReconnect(table);
    }
  }

  /// Zatvori channel za tabelu
  void _closeChannel(String table) {
    _channels[table]?.unsubscribe();
    _channels.remove(table);
    _controllers[table]?.close();
    _controllers.remove(table);
    _listenerCount.remove(table);
    _reconnectAttempts.remove(table);
    _updateStatus(table, RealtimeStatus.disconnected);
  }

  /// Kreiraj channel za tabelu
  void _createChannel(String table) {
    _updateStatus(table, RealtimeStatus.connecting);

    final channelName = 'realtime_$table';
    final channel = _supabase.channel(channelName);

    channel
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      callback: (payload) {
        debugPrint('🔔 [RealtimeManager] Change in $table: ${payload.eventType}');
        if (_controllers.containsKey(table) && !_controllers[table]!.isClosed) {
          _controllers[table]!.add(payload);
        }
      },
    )
        .subscribe((status, [error]) {
      _handleSubscribeStatus(table, status, error);
    });

    _channels[table] = channel;
  }

  /// Handle status promene od Supabase
  void _handleSubscribeStatus(String table, RealtimeSubscribeStatus status, dynamic error) {
    switch (status) {
      case RealtimeSubscribeStatus.subscribed:
        _reconnectAttempts[table] = 0;
        _updateStatus(table, RealtimeStatus.connected);
        debugPrint('✅ [RealtimeManager] $table connected');
        break;

      case RealtimeSubscribeStatus.channelError:
        debugPrint('❌ [RealtimeManager] $table channel error: $error');
        _scheduleReconnect(table);
        break;

      case RealtimeSubscribeStatus.closed:
        debugPrint('🔴 [RealtimeManager] $table closed');
        _scheduleReconnect(table);
        break;

      case RealtimeSubscribeStatus.timedOut:
        debugPrint('⏰ [RealtimeManager] $table timed out');
        _scheduleReconnect(table);
        break;
    }
  }

  /// Zakaži reconnect sa exponential backoff
  void _scheduleReconnect(String table) {
    final attempts = _reconnectAttempts[table] ?? 0;

    if (attempts >= RealtimeConfig.maxReconnectAttempts) {
      _updateStatus(table, RealtimeStatus.error);
      debugPrint('🔴 [RealtimeManager] Max reconnect attempts reached for $table');
      return;
    }

    _updateStatus(table, RealtimeStatus.reconnecting);
    _reconnectAttempts[table] = attempts + 1;

    // Exponential backoff: 3s, 6s, 9s, 12s, 15s
    final delay = RealtimeConfig.reconnectDelaySeconds * (attempts + 1);
    debugPrint('🔄 [RealtimeManager] Reconnecting $table in ${delay}s (attempt ${attempts + 1})');

    Future.delayed(Duration(seconds: delay), () {
      // Proveri da li još uvek ima listenera
      if (_listenerCount[table] != null && _listenerCount[table]! > 0) {
        _channels[table]?.unsubscribe();
        _channels.remove(table);
        _createChannel(table);
      }
    });
  }

  /// Ažuriraj status i emituj
  void _updateStatus(String table, RealtimeStatus status) {
    _statusMap[table] = status;
    if (!_statusController.isClosed) {
      _statusController.add(Map.from(_statusMap));
    }
  }

  /// Ugasi sve channel-e i očisti resurse
  void dispose() {
    debugPrint('🧹 [RealtimeManager] Disposing all channels');
    for (final channel in _channels.values) {
      channel.unsubscribe();
    }
    for (final controller in _controllers.values) {
      controller.close();
    }
    _channels.clear();
    _controllers.clear();
    _listenerCount.clear();
    _reconnectAttempts.clear();
    _statusMap.clear();
    _statusController.close();
  }

  /// Debug: Prikaži trenutno stanje
  void debugPrintState() {
    debugPrint('═══════════════════════════════════════');
    debugPrint('📡 [RealtimeManager] Current State:');
    debugPrint('  Channels: ${_channels.keys.toList()}');
    debugPrint('  Listeners: $_listenerCount');
    debugPrint('  Status: $_statusMap');
    debugPrint('═══════════════════════════════════════');
  }
}
