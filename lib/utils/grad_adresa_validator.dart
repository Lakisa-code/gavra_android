import 'text_utils.dart';
import 'time_validator.dart';

/// UTIL ZA VALIDACIJU GRADOVA I ADRESA
/// Ograničava aplikaciju na opštine Bela Crkva i Vršac
class GradAdresaValidator {
  /// ✅ PROVERI DA LI JE GRAD BELA CRKVA (ili BC skraćenica)
  static bool isBelaCrkva(String? grad) {
    if (grad == null || grad.trim().isEmpty) return false;
    final normalized = normalizeString(grad);
    return normalized.contains('bela') || normalized == 'bc';
  }

  /// ✅ PROVERI DA LI JE GRAD VRŠAC (ili VS skraćenica)
  static bool isVrsac(String? grad) {
    if (grad == null || grad.trim().isEmpty) return false;
    final normalized = normalizeString(grad);
    return normalized.contains('vrsac') || normalized == 'vs';
  }

  /// JEDNOSTAVNO GRAD POREĐENJE - samo 2 glavna grada
  /// LOGIKA: Bela Crkva ili Vršac - filtrira po gradu putnika
  static bool isGradMatch(
    String? putnikGrad,
    String? putnikAdresa,
    String selectedGrad,
  ) {
    // PROVERI DA LI SE GRAD PUTNIKA POKLAPA SA SELEKTOVANIM GRADOM
    if (isBelaCrkva(selectedGrad) && isBelaCrkva(putnikGrad)) {
      return true; // Putnik je iz Bele Crkve i selektovana je Bela Crkva
    }
    if (isVrsac(selectedGrad) && isVrsac(putnikGrad)) {
      return true; // Putnik je iz Vršca i selektovan je Vršac
    }

    return false; // Gradovi se ne poklapaju
  }

  /// NASELJA I ADRESE OPŠTINE BELA CRKVA
  // Reduced — keep only the places we want to accept as Bela Crkva
  // NOTE: these values are stored in a normalized, diacritic-free form
  static const List<String> naseljaOpstineBelaCrkva = [
    'bela crkva',
    'jasenovo',
    'dupljaja',
    'kruscica',
    'kusic',
    'vracev gaj',
  ];

  /// NASELJA I ADRESE OPŠTINE VRŠAC
  // Reduced — only include the villages that should be treated as Vršac
  // Intentionally exclude Pavliš / Malo Središte / Veliko Središte and similar
  static const List<String> naseljaOpstineVrsac = [
    'vrsac',
    'straza',
    'potporanj',
  ];

  /// 🔤 NORMALIZUJ SRPSKE KARAKTERE
  /// Koristi TextUtils.normalizeText() kao bazu i dodaje specifične zamene
  static String normalizeString(String? input) {
    if (input == null) {
      return '';
    }

    // Koristi centralizovanu normalizaciju iz TextUtils
    String normalized = TextUtils.normalizeText(input);

    // Dodatne specifične zamene za ovaj validator
    normalized = normalized
        .replaceAll('vrsac', 'vrsac') // već normalizovano
        .replaceAll('cetvrtak', 'cetvrtak') // već normalizovano
        .replaceAll('cet', 'cet') // već normalizovano
        .replaceAll('posta', 'posta'); // već normalizovano

    return normalized;
  }

  /// PROVERI DA LI JE ADRESA U DOZVOLJENIM OPŠTINAMA (Bela Crkva ili Vršac)
  static bool isAdresaInAllowedCity(String? adresa, String? putnikGrad) {
    if (adresa == null || adresa.trim().isEmpty) {
      return false; // Adresa je OBAVEZNA - ne dozvoljavamo putnike bez adrese
    }

    final normalizedAdresa = normalizeString(adresa);
    final normalizedPutnikGrad = normalizeString(putnikGrad);

    // AKO GRAD PRIPADA DOZVOLJENIM OPŠTINAMA, DOZVOLI BILO KOJU ADRESU
    final gradBelongs = naseljaOpstineBelaCrkva.any((naselje) => normalizedPutnikGrad.contains(naselje)) ||
        naseljaOpstineVrsac.any((naselje) => normalizedPutnikGrad.contains(naselje));

    if (gradBelongs) {
      return true; // Dozvoli bilo koju adresu u validnim opštinama
    }

    // PROVERI DA LI ADRESA SADRŽI POZNATA NASELJA (fallback)
    final belongsToBelaCrkva = naseljaOpstineBelaCrkva.any((naselje) => normalizedAdresa.contains(naselje));

    final belongsToVrsac = naseljaOpstineVrsac.any((naselje) => normalizedAdresa.contains(naselje));

    // Dozvoli ako pripada bilo kojoj opštini
    return belongsToBelaCrkva || belongsToVrsac;
  }

  /// VALIDUJ ADRESU PRILIKOM DODAVANJA PUTNIKA
  static bool validateAdresaForCity(String? adresa, String? grad) {
    if (adresa == null || adresa.trim().isEmpty) {
      return true;
    }
    if (grad == null || grad.trim().isEmpty) {
      return false;
    }

    final normalizedGrad = normalizeString(grad);

    // Proveri da li grad pripada opštini Bela Crkva
    final belongsToBelaCrkva = naseljaOpstineBelaCrkva.any((naselje) => normalizedGrad.contains(naselje));

    // Proveri da li grad pripada opštini Vršac
    final belongsToVrsac = naseljaOpstineVrsac.any((naselje) => normalizedGrad.contains(naselje));

    if (belongsToBelaCrkva) {
      return isAdresaInAllowedCity(adresa, 'Bela Crkva');
    }

    if (belongsToVrsac) {
      return isAdresaInAllowedCity(adresa, 'Vrsac');
    }

    return false; // Ako grad nije iz dozvoljenih opština, odbaci
  }

  /// PROVERI DA LI JE GRAD BLOKIRAN
  static bool isCityBlocked(String? grad) {
    if (grad == null || grad.trim().isEmpty) {
      return false;
    }

    final normalizedGrad = normalizeString(grad);

    // Proveri da li pripada dozvoljenim opštinama (Bela Crkva ili Vršac)
    final belongsToBelaCrkva = naseljaOpstineBelaCrkva.any((naselje) => normalizedGrad.contains(naselje));
    final belongsToVrsac = naseljaOpstineVrsac.any((naselje) => normalizedGrad.contains(naselje));

    // Blokiraj ako NE pripada dozvoljenim opštinama
    return !(belongsToBelaCrkva || belongsToVrsac);
  }

  /// NORMALIZUJ GRAD → uvek vraća 'BC' ili 'VS'
  /// Ovo je jedini ispravan način da se grad normalizuje u cijeloj aplikaciji.
  /// DB trigger garantuje da se u bazi uvek čuva 'BC' ili 'VS'.
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
