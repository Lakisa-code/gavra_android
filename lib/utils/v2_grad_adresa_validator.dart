import 'v2_text_utils.dart';
import 'v2_time_validator.dart';

/// UTIL ZA VALIDACIJU GRADOVA I ADRESA
/// Ogranicava aplikaciju na opštine Bela Crkva i Vrsac
class GradAdresaValidator {
  /// ? PROVERI DA LI JE GRAD BELA CRKVA (ili BC skracenica)
  static bool isBelaCrkva(String? grad) {
    if (grad == null || grad.trim().isEmpty) return false;
    final normalized = normalizeString(grad);
    return normalized.contains('bela') || normalized == 'bc';
  }

  /// ? PROVERI DA LI JE GRAD Vrsac (ili VS skracenica)
  static bool isVrsac(String? grad) {
    if (grad == null || grad.trim().isEmpty) return false;
    final normalized = normalizeString(grad); // uvek lowercase
    return normalized.contains('vrsac') || normalized.contains('vr') || normalized == 'vs';
  }

  /// JEDNOSTAVNO GRAD POREŠENJE - samo 2 glavna grada
  /// LOGIKA: Bela Crkva ili Vrsac - filtrira po gradu putnika
  static bool isGradMatch(
    String? putnikGrad,
    String? putnikAdresa,
    String selectedGrad,
  ) {
    // PROVERI DA LI SE GRAD PUTNIKA POKLAPA SA SELEKTOVANIM GRADOM
    if (isBelaCrkva(selectedGrad) && isBelaCrkva(putnikGrad)) {
      return true; // V2Putnik je iz Bele Crkve i selektovana je Bela Crkva
    }
    if (isVrsac(selectedGrad) && isVrsac(putnikGrad)) {
      return true; // V2Putnik je iz Vrsca i selektovan je Vrsac
    }

    return false; // Gradovi se ne poklapaju
  }

  /// ?? NORMALIZUJ SRPSKE KARAKTERE
  /// Koristi TextUtils.normalizeText() kao bazu i dodaje specificne zamene
  static String normalizeString(String? input) {
    if (input == null) {
      return '';
    }

    // Koristi centralizovanu normalizaciju iz TextUtils
    String normalized = TextUtils.normalizeText(input);

    // Dodatne specificne zamene za ovaj validator
    normalized = normalized
        .replaceAll('Vrsac', 'Vrsac') // vec normalizovano
        .replaceAll('cetvrtak', 'cetvrtak') // vec normalizovano
        .replaceAll('cet', 'cet') // vec normalizovano
        .replaceAll('posta', 'posta'); // vec normalizovano

    return normalized;
  }

  /// NORMALIZUJ GRAD ? uvek vraca 'BC' ili 'VS'
  /// Ovo je jedini ispravan nacin da se grad normalizuje u cijeloj aplikaciji.
  /// DB trigger garantuje da se u bazi uvek cuva 'BC' ili 'VS'.
  static String normalizeGrad(String? grad) {
    if (grad == null || grad.trim().isEmpty) return 'BC';
    final normalized = normalizeString(grad); // lowercase, bez dijakritika
    if (normalized.contains('vr') || normalized == 'vs') return 'VS';
    return 'BC';
  }

  /// NORMALIZUJ VREME - konvertuj "05:00:00" ili "5:00" u "05:00" (HH:MM format)
  /// Delegira na TimeValidator.normalizeTimeFormat() za konzistentnost
  static String normalizeTime(String? time) {
    if (time == null || time.isEmpty) {
      return '';
    }

    // Koristi TimeValidator za standardizovan format
    final normalized = TimeValidator.normalizeTimeFormat(time);
    return normalized ?? '';
  }
}
