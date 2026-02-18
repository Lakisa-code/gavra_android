/// Konfiguracija za RealtimeManager
class RealtimeConfig {
  RealtimeConfig._();

  /// Delay pre reconnect-a (sekunde) - povećano da smanji spam
  static const int reconnectDelaySeconds = 10;

  /// Maksimalan broj pokušaja reconnect-a
  static const int maxReconnectAttempts = 3;

  /// Liste tabela koje pratimo - mora biti u skladu sa initializeAll() u RealtimeManager
  static const List<String> tables = [
    'registrovani_putnici', // 👥 Aktivni putnici
    'kapacitet_polazaka', // 🚐 Kapacitet vozila
    'vozac_lokacije', // 📍 GPS pozicije vozača
    'voznje_log', // 📊 Log vožnji
    'vozila', // 🚗 Vozila
    'vozaci', // 👨 Vozači
    'seat_requests', // 🎫 Zahtjevi za mjesta
    'daily_reports', // 📈 Dnevni izvještaji
    'app_settings', // ⚙️ Postavke aplikacije
    'adrese', // 📍 Adrese
    'registrovani_putnici_svi', // 👥 Svi registrovani putnici
  ];
}
