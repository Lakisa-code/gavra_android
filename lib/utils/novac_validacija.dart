import '../models/putnik.dart';
import '../utils/vozac_boja.dart';

/// 💰 CENTRALIZOVANA VALIDACIJA NOVCA
/// Objedinjuje sve logike validacije plaćanja, pazara i finansijskih operacija
class NovcanaValidacija {
  /// Proverava da li je iznos valjan za plaćanje
  static bool isValidAmount(double? amount) {
    return amount != null && amount > 0;
  }

  /// Proverava da li je vozač registrovan i valjan
  static bool isValidDriver(String? driver) {
    if (driver == null || driver.isEmpty) return false;
    return VozacBoja.isValidDriver(driver);
  }

  /// Glavna validacija za računanje pazara - koristi se svuda!
  static bool isValidPayment(Putnik putnik) {
    // Osnovni uslovi za validno računanje pazara
    final imaIznos = isValidAmount(putnik.iznosPlacanja);

    // ✅ PRIORITET: naplatioVozac > vozac (SAMO REGISTROVANI VOZAČI)
    final registrovaniVozac = putnik.naplatioVozac ?? putnik.vozac;
    final imaRegistrovanogVozaca = isValidDriver(registrovaniVozac);

    final nijeOtkazan = !putnik.jeOtkazan;

    return imaIznos && imaRegistrovanogVozaca && nijeOtkazan;
  }

  /// Validacija za mesečna plaćanja
  static bool isValidMonthlyPayment(double? amount, String? vozac, String? mesec) {
    if (!isValidAmount(amount)) return false;
    if (!isValidDriver(vozac)) return false;
    if (mesec == null || mesec.isEmpty) return false;

    return true;
  }

  /// Formatiranje iznosa za prikaz u UI
  static String formatAmount(double? amount) {
    if (amount == null || amount <= 0) return '0 RSD';
    return '${amount.toStringAsFixed(0)} RSD';
  }

  /// Validacija za unos iznosa u UI
  static String? validateAmountInput(String input) {
    if (input.isEmpty) return 'Iznos je obavezan';

    final amount = double.tryParse(input);
    if (amount == null) return 'Unesite valjan broj';
    if (amount <= 0) return 'Iznos mora biti veći od 0';
    if (amount > 100000) return 'Iznos je previše veliki';

    return null; // Validno
  }

  /// Proverava da li putnik ima dugovanje
  static bool hasDugovanje(Putnik putnik) {
    return !putnik.jeOtkazan && !isValidAmount(putnik.iznosPlacanja);
  }

  /// Računa procenat naplate za vozača
  static double calculateNaplataRate(List<Putnik> putnici, String vozac) {
    final vozacPutnici = putnici
        .where(
          (p) => (p.naplatioVozac ?? p.vozac) == vozac && !p.jeOtkazan,
        )
        .toList();

    if (vozacPutnici.isEmpty) return 0.0;

    final placeni = vozacPutnici.where((p) => isValidAmount(p.iznosPlacanja)).length;
    return (placeni / vozacPutnici.length) * 100;
  }

  /// Računa ukupni pazar za vozača
  static double calculatePazarForVozac(List<Putnik> putnici, String vozac) {
    return putnici
        .where(
          (p) => ((p.naplatioVozac ?? p.vozac) == vozac) && isValidPayment(p),
        )
        .fold<double>(0.0, (sum, p) => sum + (p.iznosPlacanja ?? 0.0));
  }

  /// Proverava konzistentnost između model.iznosPlacanja i database.cena
  static bool isDataConsistent(Putnik putnik, Map<String, dynamic> dbData) {
    final modelAmount = putnik.iznosPlacanja;
    final dbAmount = dbData['cena'] as double?;

    // Dozvoljena razlika od 0.01 zbog floating point greške
    if (modelAmount == null && dbAmount == null) return true;
    if (modelAmount == null || dbAmount == null) return false;

    return (modelAmount - dbAmount).abs() < 0.01;
  }
}



