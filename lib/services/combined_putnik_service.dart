import '../models/putnik.dart';
import 'dnevni_putnik_service.dart';
import 'mesecni_putnik_service_novi.dart';
import 'adresa_service.dart';
import 'ruta_service.dart';
import 'package:logger/logger.dart';
import '../utils/grad_adresa_validator.dart';
import '../utils/logging.dart';

/// Kombinovani servis za putnike - koristi normalizovanu šemu ali pruža
/// kompatibilan interfejs sa starim PutnikService-om
class CombinedPutnikService {
  final Logger _logger = Logger();
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

    // Debug: log dnevniPutnici count and sample
    try {
      final sampleDnevni = dnevniPutnici.take(5).map((d) => d.ime).toList();
      dlog(
          '🔍 [COMBINED] fetched ${dnevniPutnici.length} dnevni putnici; sample: $sampleDnevni');
    } catch (_) {}

    // Dohvati mesečne putnike
    final mesecniPutnici = await _mesecniService.getAktivniMesecniPutnici();

    // Debug: log mesecniPutnici count and sample
    try {
      final sampleMesecni =
          mesecniPutnici.take(5).map((m) => m.punoIme).toList();
      dlog(
          '🔍 [COMBINED] fetched ${mesecniPutnici.length} mesecni putnici; sample: $sampleMesecni');
    } catch (_) {}

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

    // Filtriraj po gradu i vremenu koristeći normalizaciju (vrijeme/grad)
    final filtered = result.where((putnik) {
      if (grad != null) {
        if (!GradAdresaValidator.isGradMatch(putnik.grad, putnik.adresa, grad))
          return false;
      }
      if (vreme != null) {
        // Normalize both times before comparison (handles 05:00 vs 5:00, seconds, etc.)
        if (GradAdresaValidator.normalizeTime(putnik.polazak) !=
            GradAdresaValidator.normalizeTime(vreme)) return false;
      }
      return true;
    }).toList();

    try {
      final sampleFiltered = filtered
          .take(10)
          .map((p) => '${p.ime}@${p.polazak}@${p.grad}')
          .toList();
      dlog(
          '🔎 [COMBINED] after filtering (grad=$grad, vreme=$vreme): ${filtered.length} -> sample: $sampleFiltered');
    } catch (_) {}

    return filtered;
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
    _logger.i(
        '🔄 RESET POKUPLJENJA - novo vreme: $novoVreme, grad: $grad, vozač: $currentDriver');
  }

  /// Dohvata sve putnike iz obe tabele (za kompatibilnost)
  Future<List<Putnik>> getAllPutniciFromBothTables({String? targetDay}) async {
    // TODO: Implementirati dohvatanje iz normalizovane šeme
    // Za sada vraćamo praznu listu
    try {
      // Determine target date from provided full day name (e.g., "Ponedeljak")
      DateTime now = DateTime.now();
      DateTime targetDate = now;
      if (targetDay != null && targetDay.isNotEmpty) {
        final dayNames = [
          'ponedeljak',
          'utorak',
          'sreda',
          'četvrtak',
          'petak',
          'subota',
          'nedelja'
        ];
        final idx = dayNames.indexOf(targetDay.toLowerCase());
        if (idx != -1) {
          final targetDayIndex = idx; // 0-based where 0 == ponedeljak
          final currentDayIndex = now.weekday - 1; // 0-based
          int daysToAdd = targetDayIndex >= currentDayIndex
              ? targetDayIndex - currentDayIndex
              : (7 - currentDayIndex) + targetDayIndex;
          targetDate = now.add(Duration(days: daysToAdd));
        }
      }

      // Fetch daily passengers for the computed date
      final dnevniPutnici =
          await _dnevniService.getDnevniPutniciZaDatum(targetDate);

      // Fetch monthly passengers
      final mesecniPutnici = await _mesecniService.getAktivniMesecniPutnici();

      final List<Putnik> combined = [];

      // Convert daily putnici
      for (final dnevni in dnevniPutnici) {
        final adresa = await _adresaService.getAdresaById(dnevni.adresaId);
        final ruta = await _rutaService.getRutaById(dnevni.rutaId);
        if (adresa != null && ruta != null) {
          combined.add(dnevni.toPutnik(adresa, ruta));
        }
      }

      // Convert monthly putnici for the day abbreviation
      final dayAbbrev = _abbrevFromFullName(targetDay ?? '');
      for (final mes in mesecniPutnici) {
        final adresa = await _adresaService.getAdresaById(mes.adresaId);
        final ruta = await _rutaService.getRutaById(mes.rutaId);
        if (adresa != null && ruta != null) {
          combined.addAll(mes.toPutnikList(dayAbbrev, adresa, ruta));
        }
      }

      return combined;
    } catch (e) {
      dlog('❌ Error in getAllPutniciFromBothTables: $e');
      return [];
    }
  }

  /// Map full day name (e.g., "Ponedeljak") to short abbreviation used by model
  String _abbrevFromFullName(String fullDay) {
    switch (fullDay.toLowerCase()) {
      case 'ponedeljak':
      case 'pon':
        return 'pon';
      case 'utorak':
      case 'uto':
        return 'uto';
      case 'sreda':
      case 'sre':
        return 'sre';
      case 'četvrtak':
      case 'cet':
      case 'čet':
        return 'cet';
      case 'petak':
      case 'pet':
        return 'pet';
      case 'subota':
      case 'sub':
        return 'sub';
      case 'nedelja':
      case 'ned':
        return 'ned';
      default:
        // Fallback to 'pon' so toPutnikList can handle it; callers should pass valid day
        return 'pon';
    }
  }

  /// Dodaje putnika (za kompatibilnost)
  Future<void> dodajPutnika(Putnik putnik) async {
    // TODO: Implementirati dodavanje u normalizovanu šemu
    // Za sada samo logujemo
    _logger.i('🚀 DODAJ PUTNIKA: ${putnik.ime}');
  }
}
