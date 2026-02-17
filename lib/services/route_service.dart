import '../config/route_config.dart';

/// 🚐 Servis za dobavljanje satnih redoslijeda
/// Koristi fiksne redoslijede iz RouteConfig-a na osnovu aktivnog režima (zimski/letnji/praznici)
class RouteService {
  static final RouteService _instance = RouteService._internal();

  RouteService._internal();

  factory RouteService() {
    return _instance;
  }

  /// 🚐 Dobija vremena polazaka za grad i sezonu direktno iz konfiguracije
  static List<String> getVremenaPolazakaSync({
    required String grad,
    required String sezona,
  }) {
    final isBc = grad.toLowerCase().contains('bc') ||
        grad.toLowerCase().contains('bela');

    if (sezona == 'praznici') {
      return isBc
          ? RouteConfig.bcVremenaPraznici
          : RouteConfig.vsVremenaPraznici;
    } else if (sezona == 'zimski') {
      return isBc ? RouteConfig.bcVremenaZimski : RouteConfig.vsVremenaZimski;
    } else {
      // letnji ili default
      return isBc ? RouteConfig.bcVremenaLetnji : RouteConfig.vsVremenaLetnji;
    }
  }

  /// 🚐 Kompatibilnost sa postojećim async pozivima (vraća odmah bez baze)
  static Future<List<String>> getVremenaPolazaka({
    required String grad,
    required String sezona,
  }) async {
    return getVremenaPolazakaSync(grad: grad, sezona: sezona);
  }
}
