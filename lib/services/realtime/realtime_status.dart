/// Status realtime konekcije
enum RealtimeStatus {
  /// Nije povezan
  disconnected,

  /// U procesu povezivanja
  connecting,

  /// Uspešno povezan
  connected,

  /// Pokušava reconnect
  reconnecting,

  /// Greška - prestao pokušavati
  error,
}
