/// 🧱 APPLIKATION CONSTANTS
/// Centralno mesto za sve fiksne vrednosti u aplikaciji.
/// Koristiti ove konstante umesto "hardkodovanih" stringova.

class AppConstants {
  // 👥 TIPOVI KORISNIKA
  static const String userTypeUcenik = 'ucenik';
  static const String userTypeRadnik = 'radnik';
  static const String userTypeStudent = 'student';

  // 🚦 STATUSI VOŽNJE (RIDE STATUS)
  static const String statusSlobodno = 'slobodno'; // Nije rezervisano
  static const String statusConfirmed = 'confirmed'; // Potvrđeno
  static const String statusWaiting = 'waiting'; // Na čekanju
  static const String statusCancelled = 'cancelled'; // Otkazano
  static const String statusPending = 'pending'; // Zahtev poslat, čeka se odgovor

  // 📝 TIPOVI LOGOVA (LOG TYPES)
  static const String logTypeVoznja = 'voznja';
  static const String logTypeOtkazivanje = 'otkazivanje';
  static const String logTypeUplata = 'uplata';
  static const String logTypePromenaKapaciteta = 'promena_kapaciteta';
  static const String logTypeAdminAkcija = 'admin_akcija';

  // 🚌 SMENE / POLASCI
  static const String smenaPrva = '05:00';
  static const String smenaDruga = '13:00';
  static const String smenaTreca = '21:00';

  // 📍 GRADOVI / LOKACIJE
  static const String lokacijaKovacica = 'Kovačica';
  static const String lokacijaBeograd = 'Beograd';
  static const String lokacijaDebeljaca = 'Debeljača';
  static const String lokacijaCrepaja = 'Crepaja';
  static const String lokacijaPadina = 'Padina';
  static const String lokacijaPancevo = 'Pančevo';

  // 🔔 NOTIFIKACIJE CHANNELS
  static const String channelIdReservations = 'reservations_channel';
  static const String channelNameReservations = 'Rezervacije';
}
