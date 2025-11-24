/// 🏘️ UTIL ZA VALIDACIJU GRADOVA I ADRESA
/// Ograničava aplikaciju na opštine Bela Crkva i Vršac
class GradAdresaValidator {
  /// 🔍 JEDNOSTAVNO GRAD POREĐENJE - samo 2 glavna grada
  /// ✅ LOGIKA: Bela Crkva ili Vršac - filtrira po gradu putnika
  static bool isGradMatch(
    String? putnikGrad,
    String? putnikAdresa,
    String selectedGrad,
  ) {
    final normalizedSelectedGrad = normalizeString(selectedGrad);
    final normalizedPutnikGrad = normalizeString(putnikGrad);

    // 🎯 LOGIKA: Uporedi grad putnika sa selektovanim gradom
    final selectedBelaCrkva = normalizedSelectedGrad.contains('bela');
    final selectedVrsac = normalizedSelectedGrad.contains('vrsac');

    final putnikBelaCrkva = normalizedPutnikGrad.contains('bela');
    final putnikVrsac = normalizedPutnikGrad.contains('vrsac');

    // ✅ PROVERI DA LI SE GRAD PUTNIKA POKLAPA SA SELEKTOVANIM GRADOM
    if (selectedBelaCrkva && putnikBelaCrkva) {
      return true; // Putnik je iz Bele Crkve i selektovana je Bela Crkva
    }
    if (selectedVrsac && putnikVrsac) {
      return true; // Putnik je iz Vršca i selektovan je Vršac
    }

    return false; // Gradovi se ne poklapaju
  }

  /// 🏘️ NASELJA I ADRESE OPŠTINE BELA CRKVA
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

  /// 🏘️ NASELJA I ADRESE OPŠTINE VRŠAC
  // Reduced — only include the villages that should be treated as Vršac
  // Intentionally exclude Pavliš / Malo Središte / Veliko Središte and similar
  static const List<String> naseljaOpstineVrsac = [
    'vrsac',
    'straza',
    'potporanj',
  ];

  /// 🔤 NORMALIZUJ SRPSKE KARAKTERE
  static String normalizeString(String? input) {
    if (input == null) {
      return '';
    }

    String normalized = input.toString().trim().toLowerCase();

    // Normalizuj srpske karaktere
    normalized = normalized
        .replaceAll('š', 's')
        .replaceAll('đ', 'd')
        .replaceAll('č', 'c')
        .replaceAll('ć', 'c')
        .replaceAll('ž', 'z')
        .replaceAll('vršac', 'vrsac')
        .replaceAll('vr?ac', 'vrsac')
        .replaceAll('četvrtak', 'cetvrtak')
        .replaceAll('čet', 'cet')
        .replaceAll('pošta', 'posta');

    return normalized;
  }

  /// 🏘️ PROVERI DA LI JE ADRESA U DOZVOLJENIM OPŠTINAMA (Bela Crkva ili Vršac)
  static bool isAdresaInAllowedCity(String? adresa, String? putnikGrad) {
    if (adresa == null || adresa.trim().isEmpty) {
      return true; // Bez adrese je OK
    }

    final normalizedAdresa = normalizeString(adresa);
    final normalizedPutnikGrad = normalizeString(putnikGrad);

    // 🚫 PRVO BLOKIRAJ EKSPLICITNO ZABRANJENE GRADOVE
    final containsVranje = normalizedAdresa.contains('vranje');
    final containsPancevo = normalizedAdresa.contains('pancevo');
    final containsBeograd = normalizedAdresa.contains('beograd');
    final containsNS = normalizedAdresa.contains('novi sad');

    if (containsVranje || containsPancevo || containsBeograd || containsNS) {
      return false; // Eksplicitno blokiraj druge gradove
    }

    // ✅ AKO GRAD PRIPADA DOZVOLJENIM OPŠTINAMA, DOZVOLI BILO KOJU ADRESU
    final gradBelongs = naseljaOpstineBelaCrkva.any((naselje) => normalizedPutnikGrad.contains(naselje)) ||
        naseljaOpstineVrsac.any((naselje) => normalizedPutnikGrad.contains(naselje));

    if (gradBelongs) {
      return true; // Dozvoli bilo koju adresu u validnim opštinama
    }

    // 🔍 PROVERI DA LI ADRESA SADRŽI POZNATA NASELJA (fallback)
    final belongsToBelaCrkva = naseljaOpstineBelaCrkva.any((naselje) => normalizedAdresa.contains(naselje));

    final belongsToVrsac = naseljaOpstineVrsac.any((naselje) => normalizedAdresa.contains(naselje));

    // Dozvoli ako pripada bilo kojoj opštini
    return belongsToBelaCrkva || belongsToVrsac;
  }

  /// 📍 VALIDUJ ADRESU PRILIKOM DODAVANJA PUTNIKA
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
      return isAdresaInAllowedCity(adresa, 'Vršac');
    }

    return false; // Ako grad nije iz dozvoljenih opština, odbaci
  }

  /// 🚫 LISTA BLOKIRANIH GRADOVA
  static const List<String> blockedCities = [
    'vranje',
    'pancevo',
    'beograd',
    'novi sad',
    'nis',
    'kragujevac',
    'subotica',
    'zrenjanin',
    'novi pazar',
    'leskovac',
  ];

  /// 🚫 PROVERI DA LI JE GRAD BLOKIRAN
  static bool isCityBlocked(String? grad) {
    if (grad == null || grad.trim().isEmpty) {
      return false;
    }

    final normalizedGrad = normalizeString(grad);

    // Prvo proveri da li pripada dozvoljenim opštinama
    final belongsToBelaCrkva = naseljaOpstineBelaCrkva.any((naselje) => normalizedGrad.contains(naselje));

    final belongsToVrsac = naseljaOpstineVrsac.any((naselje) => normalizedGrad.contains(naselje));

    // Ako pripada dozvoljenim opštinama, ne blokiraj
    if (belongsToBelaCrkva || belongsToVrsac) {
      return false;
    }

    // Inače proveri da li je u listi blokiranih gradova
    return blockedCities.any(
      (blocked) => normalizedGrad.contains(blocked) || blocked.contains(normalizedGrad),
    );
  }

  /// ⏰ NORMALIZUJ VREME - konvertuj "05:00:00" u "5:00", osiguraj vodeću nulu za minute
  static String normalizeTime(String? time) {
    if (time == null || time.isEmpty) {
      return '';
    }

    String normalized = time.trim();

    // Ukloni sekunde ako postoje (05:00:00 -> 05:00)
    if (normalized.contains(':') && normalized.split(':').length == 3) {
      List<String> parts = normalized.split(':');
      normalized = '${parts[0]}:${parts[1]}';
    }

    // Ensure minutes have leading zero, remove leading zero from hours
    final parts = normalized.split(':');
    if (parts.length == 2) {
      final h = int.tryParse(parts[0])?.toString() ?? parts[0];
      final m = parts[1].padLeft(2, '0');
      normalized = '$h:$m';
    }

    return normalized;
  }
}
