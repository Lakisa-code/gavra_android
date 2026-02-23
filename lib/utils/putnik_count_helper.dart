import '../models/putnik.dart';
import 'grad_adresa_validator.dart';
import 'putnik_helpers.dart';

/// 🎯 HELPER ZA BROJANJE PUTNIKA PO GRADU I VREMENU
/// Centralizovana logika za konzistentno brojanje putnika na svim ekranima
class PutnikCountHelper {
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
    // Dinamičke mape za brojanje - ne koristimo više hardkodovane šablone
    final brojPutnikaBC = <String, int>{};
    final brojPutnikaVS = <String, int>{};

    for (final p in putnici) {
      // 🛡️ KORISTIMO centralizovanu logiku za utvrđivanje ko zauzima mesto
      // Napomena: PutnikHelpers.shouldCountInSeats uključuje đake (ucenik) što je ovde poželjno
      // jer za Nav Bar želimo da vidimo punu fizičku popunjenost vozila.
      if (!PutnikHelpers.shouldCountInSeats(p)) continue;

      // Provera dana — koristimo sr.dan (kratica: pon, uto...) jer datum nije pouzdano polje
      final dayMatch = p.dan.toLowerCase().contains(targetDayAbbr.toLowerCase());
      if (!dayMatch) continue;

      final normVreme = GradAdresaValidator.normalizeTime(p.polazak);

      // Koristi centralizovane helpere za proveru grada
      final jeBelaCrkva = GradAdresaValidator.isBelaCrkva(p.grad);
      final jeVrsac = GradAdresaValidator.isVrsac(p.grad);

      // 🎓 BC LOGIKA (DISPLAY OVERRIDE):
      // Za prikaz na Nav Bar-u BROJIMO SVE PUTNIKE (uključujući đake u BC)
      // jer vozač mora da vidi koliko ljudi fizički ima u vozilu.
      if (jeBelaCrkva) {
        brojPutnikaBC[normVreme] =
            (brojPutnikaBC[normVreme] ?? 0) + p.brojMesta;
      } else if (jeVrsac) {
        brojPutnikaVS[normVreme] =
            (brojPutnikaVS[normVreme] ?? 0) + p.brojMesta;
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
      return brojPutnikaBC[normVreme] ?? 0;
    }
    if (GradAdresaValidator.isVrsac(grad)) {
      return brojPutnikaVS[normVreme] ?? 0;
    }
    return 0;
  }
}
