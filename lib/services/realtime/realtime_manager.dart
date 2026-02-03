import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../globals.dart';
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

  SupabaseClient get _supabase => supabase;

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

  /// Pending reconnect timeri (debounce)
  final Map<String, Timer?> _reconnectTimers = {};

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
    // 🛡️ Provera pre pretplate
    if (!isSupabaseReady) {
      if (kDebugMode) debugPrint('❌ [RealtimeManager] Cannot subscribe to $table: Supabase not ready');
      return const Stream.empty();
    }

    _listenerCount[table] = (_listenerCount[table] ?? 0) + 1;

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

    // Ugasi channel samo ako nema više listenera
    if (_listenerCount[table] != null && _listenerCount[table]! <= 0) {
      _closeChannel(table);
    }
  }

  /// Forsiraj reconnect za tabelu
  void forceReconnect(String table) {
    _reconnectAttempts[table] = 0;
    _closeChannel(table);
    if (_listenerCount[table] != null && _listenerCount[table]! > 0) {
      _createChannel(table);
    }
  }

  /// Forsiraj reconnect za sve tabele
  void forceReconnectAll() {
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

    // 📝 SUPABASE PRAVILO: Channel name NE SME počinjati sa 'realtime'
    // https://supabase.com/docs/guides/realtime/postgres-changes
    // "The channel name can be any string except 'realtime'."
    final channelName = 'db-changes:$table';

    final channel = _supabase.channel(channelName);

    channel
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      callback: (payload) {
        // Filtriraj samo INSERT i UPDATE evente, preskoči DELETE
        if (payload.eventType == PostgresChangeEvent.delete) return;

        // debugPrint('🔄 [RealtimeManager] EVENT na tabeli "$table": ${payload.eventType}');
        if (_controllers.containsKey(table) && !_controllers[table]!.isClosed) {
          _controllers[table]!.add(payload);
          // debugPrint('✅ [RealtimeManager] Payload emitovan za tabelu "$table"');
        } else {
          // debugPrint('⚠️ [RealtimeManager] Controller zatvoren ili ne postoji za tabelu "$table"');
        }
      },
    )
        .subscribe((status, [error]) {
      // debugPrint(
      //     '📡 [RealtimeManager] Subscribe status za "$table": $status${error != null ? " (Error: $error)" : ""}');
      _handleSubscribeStatus(table, status, error);
    });

    _channels[table] = channel;
    // debugPrint('🔗 [RealtimeManager] Channel kreiiran za tabelu "$table"');
  }

  /// Handle status promene od Supabase
  void _handleSubscribeStatus(String table, RealtimeSubscribeStatus status, dynamic error) {
    switch (status) {
      case RealtimeSubscribeStatus.subscribed:
        _reconnectAttempts[table] = 0;
        _updateStatus(table, RealtimeStatus.connected);
        break;

      case RealtimeSubscribeStatus.channelError:
        _scheduleReconnect(table);
        break;

      case RealtimeSubscribeStatus.closed:
        // ✅ FIKSUJ: Ne pokušavaj reconnect ako nema aktivnih listenera
        if (_listenerCount[table] != null && _listenerCount[table]! > 0) {
          _scheduleReconnect(table);
        } else {
          // Nema listenera, samo zatvori
          _closeChannel(table);
        }
        break;

      case RealtimeSubscribeStatus.timedOut:
        _scheduleReconnect(table);
        break;
    }
  }

  /// Zakaži reconnect sa exponential backoff
  void _scheduleReconnect(String table) {
    final attempts = _reconnectAttempts[table] ?? 0;

    if (attempts >= RealtimeConfig.maxReconnectAttempts) {
      _updateStatus(table, RealtimeStatus.error);
      return;
    }

    _updateStatus(table, RealtimeStatus.reconnecting);
    _reconnectAttempts[table] = attempts + 1;

    // Exponential backoff: 3s, 6s, 10s (brži recovery nego prethodno 10s, 20s, 30s)
    // https://supabase.com/docs/guides/realtime/troubleshooting - preporučuje kraće intervale
    final delays = [3, 6, 10]; // sekunde za attempt 0, 1, 2
    final delay = delays[attempts.clamp(0, delays.length - 1)];

    Future.delayed(Duration(seconds: delay), () async {
      // Proveri da li još uvek ima listenera
      if (_listenerCount[table] != null && _listenerCount[table]! > 0) {
        // ВАЖНО: Морамо потпуно уклонити канал из SDK пре креирања новог!
        // Supabase SDK има leaveOpenTopic() који затвара канале са истим именом
        // што изазива race condition ако се нови канал направи пре него што
        // је стари потпуно уклоњен.
        final existingChannel = _channels[table];
        if (existingChannel != null) {
          try {
            // ✅ Користи removeChannel() уместо unsubscribe()
            // SDK метода: SupabaseClient.removeChannel(RealtimeChannel)
            // https://pub.dev/documentation/supabase_flutter/latest/supabase_flutter/SupabaseClient/removeChannel.html
            // Ово потпуно уклања канал из SDK и спречава race conditions
            await _supabase.removeChannel(existingChannel);
          } catch (e) {
            debugPrint('⚠️ Error removing realtime channel: $e');
          }
          _channels.remove(table);
        }

        // 🔁 RETRY LOOP: Сачекај да SDK стварно очисти канал
        int retries = 0;
        const maxRetries = 20; // 20 x 50ms = 1 sekунда max
        final initialChannelCount = _supabase.getChannels().length;

        while (retries < maxRetries) {
          final currentChannelCount = _supabase.getChannels().length;

          // Ako se broj kanala smanjio, SDK je očistio kanal
          if (currentChannelCount < initialChannelCount) {
            break;
          }

          await Future.delayed(const Duration(milliseconds: 50));
          retries++;
        }

        // Сада безбедно креирај нови канал
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

  /// Inicijalizuj sve važne tabele za realtime praćenje
  /// Poziva se jednom pri startu aplikacije
  /// Za realtime-first aplikacije - samo priprema sistem, kanali se kreiraju on-demand
  Future<void> initializeAll() async {
    if (!isSupabaseReady) {
      debugPrint('❌ [RealtimeManager] Cannot initialize: Supabase not ready');
      return;
    }

    // Lista svih tabela koje mogu biti praćene (za referencu)
    final tablesToMonitor = [
      'registrovani_putnici', // 👥 Aktivni putnici
      'kapacitet_polazaka', // 🚐 Kapacitet vozila
      'vozac_lokacije', // 📍 GPS pozicije vozača
      'voznje_log', // 📊 Log vožnji
      'vozila', // 🚗 Vozila
      'vozaci', // 👨 Vozači
      'voznje_po_sezoni', // 📅 Redosljed polazaka
      'seat_requests', // 🎫 Zahtjevi za mjesta
      'daily_reports', // 📈 Dnevni izvještaji
      'app_settings', // ⚙️ Postavke aplikacije
      'ml_config', // 🧠 ML konfiguracija
      'adrese', // 📍 Adrese
      'registrovani_putnici_svi', // 👥 Svi registrovani putnici
    ];

    debugPrint(
        '🚀 [RealtimeManager] Realtime sistem spreman - kanali će se kreirati on-demand za ${tablesToMonitor.length} tabela');

    // Ne kreiraj kanale odmah - čekaj subscribe() pozive
    // debugPrint('✅ [RealtimeManager] Sistem je spreman za realtime praćenje!');
  }

  /// Ugasi sve channel-e i očisti resurse
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
    _reconnectAttempts.clear();
    _statusMap.clear();
    _statusController.close();
  }
}
