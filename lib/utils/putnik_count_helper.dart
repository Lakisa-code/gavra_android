import '../models/putnik.dart';
import 'grad_adresa_validator.dart';
import 'putnik_helpers.dart';

/// 🎯 HELPER ZA BROJANJE PUTNIKA PO GRADU I VREMENU
/// Centralizovana logika za konzistentno brojanje putnika na svim ekranima
class PutnikCountHelper {
  /// Standardna vremena polazaka za Belu Crkvu
  static const Map<String, int> bcVremenaTemplate = {
    '05:00': 0,
    '06:00': 0,
    '07:00': 0,
    '08:00': 0,
    '09:00': 0,
    '11:00': 0,
    '12:00': 0,
    '13:00': 0,
    '14:00': 0,
    '15:00': 0,
    '15:30': 0,
    '18:00': 0,
  };

  /// Standardna vremena polazaka za Vršac
  static const Map<String, int> vsVremenaTemplate = {
    '06:00': 0,
    '07:00': 0,
    '08:00': 0,
    '10:00': 0,
    '11:00': 0,
    '12:00': 0,
    '13:00': 0,
    '14:00': 0,
    '15:30': 0,
    '17:00': 0,
    '19:00': 0,
  };

  /// Rezultat brojanja putnika po gradovima
  final Map<String, int> brojPutnikaBC;
  final Map<String, int> brojPutnikaVS;

  PutnikCountHelper._({
    required this.brojPutnikaBC,
    required this.brojPutnikaVS,
  });

  /// Izračunaj broj putnika za dati datum iz liste putnika
  /// [putnici] - lista svih putnika
  /// [targetDateIso] - ISO datum (yyyy-MM-dd) za koji se broji
  /// [targetDayAbbr] - skraćenica dana (pon, uto, sre...) za fallback
  factory PutnikCountHelper.fromPutnici({
    required List<Putnik> putnici,
    required String targetDateIso,
    required String targetDayAbbr,
  }) {
    // Kreiraj kopije template mapa
    final brojPutnikaBC = Map<String, int>.from(bcVremenaTemplate);
    final brojPutnikaVS = Map<String, int>.from(vsVremenaTemplate);

    for (final p in putnici) {
      // Ne računa: otkazane (jeOtkazan), odsustvo (jeOdsustvo)
      if (!PutnikHelpers.shouldCountInSeats(p)) continue;

      // Provera dana
      final dayMatch =
          p.datum != null ? p.datum == targetDateIso : p.dan.toLowerCase().contains(targetDayAbbr.toLowerCase());
      if (!dayMatch) continue;

      final normVreme = GradAdresaValidator.normalizeTime(p.polazak);

      // Koristi centralizovane helpere za proveru grada
      final jeBelaCrkva = GradAdresaValidator.isBelaCrkva(p.grad);
      final jeVrsac = GradAdresaValidator.isVrsac(p.grad);

      // 🎓 BC LOGIKA: Učenici se ne broje u standardni kapacitet polaska za Belu Crkvu
      // (Subvencionisani od strane opštine, idu kao "ekstra" kapacitet)
      final bool jeBCUcenik = jeBelaCrkva && p.tipPutnika == 'ucenik';

      if (jeBelaCrkva && brojPutnikaBC.containsKey(normVreme)) {
        if (!jeBCUcenik) {
          brojPutnikaBC[normVreme] = (brojPutnikaBC[normVreme] ?? 0) + p.brojMesta;
        }
      }
      if (jeVrsac && brojPutnikaVS.containsKey(normVreme)) {
        brojPutnikaVS[normVreme] = (brojPutnikaVS[normVreme] ?? 0) + p.brojMesta;
      }
    }

    return PutnikCountHelper._(
      brojPutnikaBC: brojPutnikaBC,
      brojPutnikaVS: brojPutnikaVS,
    );
  }

  /// Dohvati broj putnika za grad i vreme
  int getCount(String grad, String vreme) {
    final normVreme = GradAdresaValidator.normalizeTime(vreme);
    if (GradAdresaValidator.isBelaCrkva(grad)) {
      return brojPutnikaBC[normVreme] ?? brojPutnikaBC[vreme] ?? 0;
    }
    if (GradAdresaValidator.isVrsac(grad)) {
      return brojPutnikaVS[normVreme] ?? brojPutnikaVS[vreme] ?? 0;
    }
    return 0;
  }
}
