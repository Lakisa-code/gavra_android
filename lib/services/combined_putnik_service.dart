import '../models/putnik.dart';
import '../models/dnevni_putnik.dart';
import '../models/mesecni_putnik_novi.dart';
import '../models/adresa.dart';
import '../models/ruta.dart';
import 'dnevni_putnik_service.dart';
import 'mesecni_putnik_service_novi.dart';
import 'adresa_service.dart';
import 'ruta_service.dart';

/// Kombinovani servis za putnike - koristi normalizovanu šemu ali pruža
/// kompatibilan interfejs sa starim PutnikService-om
class CombinedPutnikService {
  final DnevniPutnikService _dnevniService = DnevniPutnikService();
  final MesecniPutnikService _mesecniService = MesecniPutnikService();
  final AdresaService _adresaService = AdresaService();
  final RutaService _rutaService = RutaService();

  /// Stream kombinovanih putnika filtriranih po parametrima
  Stream<List<Putnik>> streamKombinovaniPutniciFiltered({
    String? isoDate,
    String? grad,
    String? vreme,
  }) {
    // Za sada vraćamo stream sa jednom vrednošću
    // TODO: Implementirati pravi realtime stream
    return Stream.fromFuture(getKombinovaniPutnici(
      isoDate: isoDate,
      grad: grad,
      vreme: vreme,
    ));
  }

  /// Dohvata kombinovane putnike za dati datum
  Future<List<Putnik>> getKombinovaniPutnici({
    String? isoDate,
    String? grad,
    String? vreme,
  }) async {
    final date = isoDate != null ? DateTime.parse(isoDate) : DateTime.now();

    // Dohvati dnevne putnike
    final dnevniPutnici = await _dnevniService.getDnevniPutniciZaDatum(date);

    // Dohvati mesečne putnike
    final mesecniPutnici = await _mesecniService.getAktivniMesecniPutnici();

    // Konvertuj u Putnik objekte
    final List<Putnik> result = [];

    // Konvertuj dnevne putnike
    for (final dnevniPutnik in dnevniPutnici) {
      final adresa = await _adresaService.getAdresaById(dnevniPutnik.adresaId);
      final ruta = await _rutaService.getRutaById(dnevniPutnik.rutaId);
      if (adresa != null && ruta != null) {
        result.add(dnevniPutnik.toPutnik(adresa, ruta));
      }
    }

    // Konvertuj mesečne putnike za dati dan
    final dan = _getDayAbbreviation(date.weekday);
    for (final mesecniPutnik in mesecniPutnici) {
      final adresa = await _adresaService.getAdresaById(mesecniPutnik.adresaId);
      final ruta = await _rutaService.getRutaById(mesecniPutnik.rutaId);
      if (adresa != null && ruta != null) {
        result.addAll(mesecniPutnik.toPutnikList(dan, adresa, ruta));
      }
    }

    // Filtriraj po gradu i vremenu
    return result.where((putnik) {
      if (grad != null && putnik.grad != grad) return false;
      if (vreme != null && putnik.polazak != vreme) return false;
      return true;
    }).toList();
  }

  /// Konvertuje broj dana u nedelji u skraćenicu
  String _getDayAbbreviation(int weekday) {
    switch (weekday) {
      case 1:
        return 'pon';
      case 2:
        return 'uto';
      case 3:
        return 'sre';
      case 4:
        return 'cet';
      case 5:
        return 'pet';
      case 6:
        return 'sub';
      case 7:
        return 'ned';
      default:
        return 'pon';
    }
  }

  /// Resetuje pokupljenja na novo vreme polaska (za kompatibilnost)
  Future<void> resetPokupljenjaNaPolazak(
      String novoVreme, String grad, String currentDriver) async {
    // TODO: Implementirati reset logiku za normalizovanu šemu
    // Za sada samo logujemo
    print(
        '🔄 RESET POKUPLJENJA - novo vreme: $novoVreme, grad: $grad, vozač: $currentDriver');
  }

  /// Dohvata sve putnike iz obe tabele (za kompatibilnost)
  Future<List<Putnik>> getAllPutniciFromBothTables({String? targetDay}) async {
    // TODO: Implementirati dohvatanje iz normalizovane šeme
    // Za sada vraćamo praznu listu
    return [];
  }

  /// Dodaje putnika (za kompatibilnost)
  Future<void> dodajPutnika(Putnik putnik) async {
    // TODO: Implementirati dodavanje u normalizovanu šemu
    // Za sada samo logujemo
    print('🚀 DODAJ PUTNIKA: ${putnik.ime}');
  }
}
