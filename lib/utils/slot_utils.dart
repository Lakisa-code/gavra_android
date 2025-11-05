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
        final normalizedTarget = GradAdresaValidator.normalizeString(targetDayAbbr);
        if (!normalizedPutnikDan.contains(normalizedTarget)) continue;

        final vreme = GradAdresaValidator.normalizeTime(p.polazak);
        final grad = p.grad;
        final adresa = p.adresa;

        // 🔧 EKSPLICITNA PROVERA: Da li putnik ide u Belu Crkva (koristi i grad i adresu)
        final normalizedGrad = grad.toLowerCase();
        final normalizedAdresa = (adresa ?? '').toLowerCase();
        final jeBelaCrkva = normalizedGrad.contains('bela') || 
                           normalizedGrad.contains('bc') || 
                           normalizedGrad == 'bela crkva' ||
                           normalizedAdresa.contains('bela') || 
                           normalizedAdresa.contains('bc');

        if (bcVremena.contains(vreme) && jeBelaCrkva) {
          // 🔍 DODATNA VALIDACIJA ZA BC 6:00 I U DAY ABBR
          if (vreme == '6:00') {
            bool validanBc6Putnik = true;

            if (p.polazak.trim() != '6:00' && p.polazak.trim() != '06:00') {
              validanBc6Putnik = false;
            }

            final gradLower = p.grad.toLowerCase();
            if (!gradLower.contains('bela') && !gradLower.contains('bc') && gradLower != 'bela crkva') {
              validanBc6Putnik = false;
            }

            final statusLower = (p.status ?? '').toLowerCase();
            if (statusLower.contains('otkazan') ||
                statusLower.contains('obrisan') ||
                statusLower.contains('bolovanje') ||
                statusLower.contains('godišnji')) {
              validanBc6Putnik = false;
            }

            if (validanBc6Putnik) {
              brojPutnikaBC[vreme] = (brojPutnikaBC[vreme] ?? 0) + 1;
            }
          } else {
            brojPutnikaBC[vreme] = (brojPutnikaBC[vreme] ?? 0) + 1;
          brojPutnikaBC[vreme] = (brojPutnikaBC[vreme] ?? 0) + 1;
        }

        // 🔧 EKSPLICITNA PROVERA: Da li putnik ide u Vršac (koristi i grad i adresu)
        final jeVrsac = normalizedGrad.contains('vrsac') || 
                       normalizedGrad.contains('vs') || 
                       normalizedGrad == 'vrsac' ||
                       normalizedAdresa.contains('vrsac') || 
                       normalizedAdresa.contains('vs');

        if (vsVremena.contains(vreme) && jeVrsac) {
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

    print('🔍 === SLOT UTILS DEBUG ===');
    print('🔍 ISO Date: $isoDate');
    print('🔍 Ukupno putnika za analizu: ${allPutnici.length}');

    int ukupnoObrisanih = 0;
    int ukupnoGodisnjihBolovanja = 0;
    int ukupnoValidnih = 0;
    int ukupnoBcPutnika = 0;
    int ukupnoVsPutnika = 0;
    int ukupnoBc6 = 0;

    for (final p in allPutnici) {
      try {
        // 🔧 STANDARDIZACIJA: Koristi TextUtils.isStatusActive za konzistentnost
        if (!TextUtils.isStatusActive(p.status)) {
          final normalizedStatus = TextUtils.normalizeText(p.status ?? '');
          if (normalizedStatus == 'obrisan')
            ukupnoObrisanih++;
          else
            ukupnoGodisnjihBolovanja++;
          continue;
        }

        // If putnik has an explicit datum, only count it when dates match
        bool dateMatches = false;
        if (p.datum != null && p.datum!.isNotEmpty) {
          dateMatches = (p.datum == isoDate);
        } else {
          // fallback: match by day abbreviation in p.dan
          final normalizedPutnikDan = GradAdresaValidator.normalizeString(p.dan);
          final targetDayAbbr = isoDateToDayAbbr(isoDate);
          final normalizedTarget = GradAdresaValidator.normalizeString(targetDayAbbr);
          dateMatches = normalizedPutnikDan.contains(normalizedTarget);
        }

        if (!dateMatches) continue;

        ukupnoValidnih++;

        final vreme = GradAdresaValidator.normalizeTime(p.polazak);
        final grad = p.grad;
        final adresa = p.adresa;

        // 🔧 EKSPLICITNA PROVERA: Da li putnik ide u Belu Crkva (koristi i grad i adresu)
        final normalizedGrad = grad.toLowerCase();
        final normalizedAdresa = (adresa ?? '').toLowerCase();
        final jeBelaCrkva = normalizedGrad.contains('bela') || 
                           normalizedGrad.contains('bc') || 
                           normalizedGrad == 'bela crkva' ||
                           normalizedAdresa.contains('bela') || 
                           normalizedAdresa.contains('bc');

        // 🐛 DEBUG: Privremeno log-ovanje za BC putnike
        if (vreme == '6:00') {
          print('🔍 [computeSlotCountsForDate] BC 6:00 putnik: ${p.ime}, grad="$grad", adresa="$adresa", jeBelaCrkva=$jeBelaCrkva');
        }

        if (bcVremena.contains(vreme) && jeBelaCrkva) {
          // 🔍 DODATNA VALIDACIJA: Proveri da li je zaista BC 6:00 putnik
          if (vreme == '6:00') {
            // Striktna validacija za BC 6:00
            bool validanBc6Putnik = true;

            // 1. Proveri da li polazak eksplicitno sadrži 6:00
            if (p.polazak.trim() != '6:00' && p.polazak.trim() != '06:00') {
              validanBc6Putnik = false;
              print('🚨 ODBAČEN BC 6:00 putnik - netačno vreme: ${p.ime}, polazak="${p.polazak}"');
            }

            // 2. Proveri da li grad eksplicitno sadrži Bela Crkva
            final gradLower = p.grad.toLowerCase();
            if (!gradLower.contains('bela') && !gradLower.contains('bc') && gradLower != 'bela crkva') {
              validanBc6Putnik = false;
              print('🚨 ODBAČEN BC 6:00 putnik - netačan grad: ${p.ime}, grad="${p.grad}"');
            }

            // 3. Proveri status - mora biti aktivan
            if (!TextUtils.isStatusActive(p.status)) {
              validanBc6Putnik = false;
              print('🚨 ODBAČEN BC 6:00 putnik - neaktivan: ${p.ime}, status="${p.status}"');
            }

            // 4. KRITIČNO: Proveri da li je dan validan za današnji datum
            if (p.datum != null && p.datum!.isNotEmpty) {
              if (p.datum != isoDate) {
                validanBc6Putnik = false;
                print('🚨 ODBAČEN BC 6:00 putnik - pogrešan datum: ${p.ime}, datum="${p.datum}" (trebalo: $isoDate)');
              }
            } else {
              // Za mesečne putnike, proveri dan u nedelji
              final danasAbbr = isoDateToDayAbbr(isoDate);
              final putnikDan = p.dan.toLowerCase();
              if (!putnikDan.contains(danasAbbr.toLowerCase())) {
                validanBc6Putnik = false;
                print('🚨 ODBAČEN BC 6:00 putnik - pogrešan dan: ${p.ime}, dan="${p.dan}" (trebalo: $danasAbbr)');
              }
            }

            if (validanBc6Putnik) {
              brojPutnikaBC[vreme] = (brojPutnikaBC[vreme] ?? 0) + 1;
              ukupnoBcPutnika++;
              ukupnoBc6++;
              print(
                '✅ VALIDNI BC 6:00 putnik #$ukupnoBc6: ${p.ime}, status=${p.status}, polazak=${p.polazak}, grad=${p.grad}',
              );
            }
          } else {
            // Za ostala vremena, koristi standardno brojanje
            brojPutnikaBC[vreme] = (brojPutnikaBC[vreme] ?? 0) + 1;
            ukupnoBcPutnika++;
          }
        }

        // 🔧 EKSPLICITNA PROVERA: Da li putnik ide u Vršac (koristi i grad i adresu)
        final jeVrsac = normalizedGrad.contains('vrsac') || 
                       normalizedGrad.contains('vs') || 
                       normalizedGrad == 'vrsac' ||
                       normalizedAdresa.contains('vrsac') || 
                       normalizedAdresa.contains('vs');

        if (vsVremena.contains(vreme) && jeVrsac) {
          brojPutnikaVS[vreme] = (brojPutnikaVS[vreme] ?? 0) + 1;
          ukupnoVsPutnika++;
        }
      } catch (e) {
        print('🚨 Greška u analizi putnika: $e');
      }
    }

    print('🔍 === FINALNI REZULTATI ===');
    print('🔍 Obrisani: $ukupnoObrisanih');
    print('🔍 Godišnji/Bolovanje: $ukupnoGodisnjihBolovanja');
    print('🔍 Validni za datum: $ukupnoValidnih');
    print('🔍 BC putnici: $ukupnoBcPutnika');
    print('🔍 VS putnici: $ukupnoVsPutnika');
    print('🔍 BC 6:00 FINALNO: ${brojPutnikaBC['6:00']} (nakon stroge validacije)');
    print('🔍 Sva BC vremena: $brojPutnikaBC');

    // 🎯 KRITIČNA PORUKA
    final bc6Finalno = brojPutnikaBC['6:00'] ?? 0;
    if (bc6Finalno < 50) {
      print('✅ BC 6:00 broj je sada realističan: $bc6Finalno');
    } else if (bc6Finalno > 70) {
      print('❌ BC 6:00 još uvek visok: $bc6Finalno - potrebna dodatna analiza!');
    } else {
      print('⚠️ BC 6:00 broj je granični: $bc6Finalno - proveri da li je tačan');
    }

    return {
      'BC': brojPutnikaBC,
      'VS': brojPutnikaVS,
    };
  } // Helper: convert ISO date string to day abbreviation used in mesecni_putnici

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
