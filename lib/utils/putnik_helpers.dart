import '../models/putnik.dart';

/// 🎯 PUTNIK HELPERS - Centralizovane funkcije za proveru statusa putnika
///
/// Ove funkcije koriste Putnik getters za potpunu proveru, uključujući:
/// - jeOtkazan (proverava obrisan, otkazanZaPolazak, status)
/// - jeOdsustvo (proverava bolovanje, godišnji)
///
/// ## Razlike od TextUtils.isStatusActive:
/// - TextUtils.isStatusActive proverava SAMO string status
/// - PutnikHelpers.shouldCountInSeats koristi Putnik getters za potpunu proveru
class PutnikHelpers {
  /// 🔢 Da li putnik treba da se RAČUNA u broju zauzetih mesta
  ///
  /// Ne računa:
  /// - Otkazane (jeOtkazan: obrisan, otkazanZaPolazak, status='otkazano')
  /// - Odsustvo (jeOdsustvo: bolovanje, godišnji)
  ///
  /// Koristi za: brojčanike na tabovima, slobodna mesta, optimizaciju rute
  static bool shouldCountInSeats(Putnik p) {
    // Ne računaj ako je otkazan (uključuje obrisan flag i otkazanZaPolazak)
    if (p.jeOtkazan) return false;

    // Ne računaj ako je na odsustvu (bolovanje/godišnji)
    if (p.jeOdsustvo) return false;

    // 🆕 Ne računaj ako je status 'ceka_mesto' (VIP lista čekanja za drugi kombi)
    if (p.status == 'ceka_mesto') return false;

    // 🆕 Ne računaj ako je status 'pending' (zahtev čeka potvrdu admina)
    if (p.status == 'pending') return false;

    // 🆕 Ne računaj ako je status 'waiting' (zahtev čeka mesto)
    if (p.status == 'waiting') return false;

    return true;
  }

  /// 🔢 Da li putnik treba da ima REDNI BROJ u listi
  ///
  /// Isto kao shouldCountInSeats - putnici koji se ne broje u mesta
  /// ne treba da imaju redni broj
  static bool shouldHaveOrdinalNumber(Putnik p) {
    return shouldCountInSeats(p);
  }

  /// 🗺️ Da li putnik treba da bude uključen u OPTIMIZACIJU RUTE
  ///
  /// Uključuje samo aktivne putnike koji nisu pokupljeni
  static bool shouldIncludeInRouteOptimization(Putnik p) {
    // Mora da se računa u mesta
    if (!shouldCountInSeats(p)) return false;

    // Već pokupljeni se ne računaju u optimizaciju
    if (p.jePokupljen) return false;

    return true;
  }

  /// 📊 Filtrira listu putnika za BROJANJE mesta
  ///
  /// Vraća samo putnike koji se računaju u zauzeta mesta
  static List<Putnik> filterForSeatCounting(List<Putnik> putnici) {
    return putnici.where(shouldCountInSeats).toList();
  }

  /// 🔢 Računa ukupan broj ZAUZETIH MESTA iz liste putnika
  ///
  /// Uzima u obzir brojMesta svakog putnika i filtrira neaktivne
  static int countTotalSeats(List<Putnik> putnici) {
    return filterForSeatCounting(putnici).fold(0, (sum, p) => sum + p.brojMesta);
  }
}
