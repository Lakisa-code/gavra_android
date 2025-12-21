/// Konfiguracija za RealtimeManager
class RealtimeConfig {
  RealtimeConfig._();

  /// Delay pre reconnect-a (sekunde)
  static const int reconnectDelaySeconds = 3;

  /// Maksimalan broj pokušaja reconnect-a
  static const int maxReconnectAttempts = 5;

  /// Interval za heartbeat proveru (sekunde)
  static const int heartbeatIntervalSeconds = 30;

  /// Liste tabela koje pratimo
  static const List<String> tables = [
    'registrovani_putnici',
    'vozac_lokacije',
    'kapacitet_polazaka',
    'daily_checkins',
    'voznje_log',
  ];
}
