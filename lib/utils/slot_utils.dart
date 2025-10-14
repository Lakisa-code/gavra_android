import '../models/putnik.dart';
import '../utils/grad_adresa_validator.dart';
import '../utils/text_utils.dart';

class SlotUtils {
  static const List<String> bcVremena = [
    '5:00',
    '6:00',
    '7:00',
    '8:00',
    '9:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:30',
    '18:00',
  ];

  static const List<String> vsVremena = [
    '6:00',
    '7:00',
    '8:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:30',
    '17:00',
    '19:00',
  ];

  // Compute counts per slot for a given day abbreviation ('pon','uto',...)
  // Returns a map with keys 'BC' and 'VS' mapping to slot->count maps.
  static Map<String, Map<String, int>> computeSlotCountsForDayAbbr(
    List<Putnik> allPutnici,
    String targetDayAbbr,
  ) {
    final Map<String, int> brojPutnikaBC = {for (var v in bcVremena) v: 0};
    final Map<String, int> brojPutnikaVS = {for (var v in vsVremena) v: 0};

    for (final p in allPutnici) {
      try {
        final normalizedStatus = TextUtils.normalizeText(p.status ?? '');
        if (normalizedStatus == 'obrisan' ||
            normalizedStatus == 'godišnji' ||
            normalizedStatus == 'godisnji' ||
            normalizedStatus == 'bolovanje') {
          continue;
        }

        // Match by day abbreviation using Putnik.dan (which can be 'Pon'/'pon'/'Ponedeljak')
        final normalizedPutnikDan = GradAdresaValidator.normalizeString(p.dan);
        final normalizedTarget =
            GradAdresaValidator.normalizeString(targetDayAbbr);
        if (!normalizedPutnikDan.contains(normalizedTarget)) continue;

        final vreme = GradAdresaValidator.normalizeTime(p.polazak);
        final grad = p.grad;

        if (bcVremena.contains(vreme) &&
            GradAdresaValidator.isGradMatch(grad, p.adresa, 'Bela Crkva')) {
          brojPutnikaBC[vreme] = (brojPutnikaBC[vreme] ?? 0) + 1;
        }
        if (vsVremena.contains(vreme) &&
            GradAdresaValidator.isGradMatch(grad, p.adresa, 'Vršac')) {
          brojPutnikaVS[vreme] = (brojPutnikaVS[vreme] ?? 0) + 1;
        }
      } catch (e) {
        // Greška u compute funkciji - ignorisana u produkciji
      }
    }

    return {
      'BC': brojPutnikaBC,
      'VS': brojPutnikaVS,
    };
  }

  // Compute counts per slot for a specific ISO date string (yyyy-MM-dd).
  // This is stricter for daily entries that include exact `datum` values.
  static Map<String, Map<String, int>> computeSlotCountsForDate(
    List<Putnik> allPutnici,
    String isoDate,
  ) {
    final Map<String, int> brojPutnikaBC = {for (var v in bcVremena) v: 0};
    final Map<String, int> brojPutnikaVS = {for (var v in vsVremena) v: 0};

    for (final p in allPutnici) {
      try {
        final normalizedStatus = TextUtils.normalizeText(p.status ?? '');
        if (normalizedStatus == 'obrisan' ||
            normalizedStatus == 'godišnji' ||
            normalizedStatus == 'godisnji' ||
            normalizedStatus == 'bolovanje') {
          continue;
        }

        // If putnik has an explicit datum, only count it when dates match
        if (p.datum != null && p.datum!.isNotEmpty) {
          if (p.datum != isoDate) {
            continue;
          }
        } else {
          // fallback: match by day abbreviation in p.dan
          final normalizedPutnikDan =
              GradAdresaValidator.normalizeString(p.dan);
          final targetDayAbbr = isoDateToDayAbbr(isoDate);
          final normalizedTarget =
              GradAdresaValidator.normalizeString(targetDayAbbr);
          if (!normalizedPutnikDan.contains(normalizedTarget)) continue;
        }

        final vreme = GradAdresaValidator.normalizeTime(p.polazak);
        final grad = p.grad;

        if (bcVremena.contains(vreme) &&
            GradAdresaValidator.isGradMatch(grad, p.adresa, 'Bela Crkva')) {
          brojPutnikaBC[vreme] = (brojPutnikaBC[vreme] ?? 0) + 1;
        }
        if (vsVremena.contains(vreme) &&
            GradAdresaValidator.isGradMatch(grad, p.adresa, 'Vršac')) {
          brojPutnikaVS[vreme] = (brojPutnikaVS[vreme] ?? 0) + 1;
        }
      } catch (e) {
        // Greška u computeDate funkciji - ignorisana u produkciji
      }
    }

    return {
      'BC': brojPutnikaBC,
      'VS': brojPutnikaVS,
    };
  }

  // Helper: convert ISO date string to day abbreviation used in mesecni_putnici
  static String isoDateToDayAbbr(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      const abbr = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
      return abbr[dt.weekday - 1];
    } catch (e) {
      return 'pon';
    }
  }
}



