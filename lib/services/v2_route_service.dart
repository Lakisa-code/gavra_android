import '../config/v2_route_config.dart';

/// Servis za dobavljanje satnih redoslijeda
/// Koristi fiksne redoslijede iz V2RouteConfig-a na osnovu aktivnog režima (zimski/letnji/praznici)
class V2RouteService {
  V2RouteService._();

  /// Dobija vremena polazaka za grad i sezonu direktno iz konfiguracije
  static List<String> getVremenaPolazakaSync({
    required String grad,
    required String sezona,
  }) {
    final isBc = grad == 'BC';

    if (sezona == 'praznici') {
      return isBc ? V2RouteConfig.bcVremenaPraznici : V2RouteConfig.vsVremenaPraznici;
    } else if (sezona == 'zimski') {
      return isBc ? V2RouteConfig.bcVremenaZimski : V2RouteConfig.vsVremenaZimski;
    } else {
      // letnji ili default
      return isBc ? V2RouteConfig.bcVremenaLetnji : V2RouteConfig.vsVremenaLetnji;
    }
  }

  /// Kompatibilnost sa postojećim async pozivima (vraća odmah bez baze)
  static Future<List<String>> getVremenaPolazaka({
    required String grad,
    required String sezona,
  }) async {
    return getVremenaPolazakaSync(grad: grad, sezona: sezona);
  }
}
