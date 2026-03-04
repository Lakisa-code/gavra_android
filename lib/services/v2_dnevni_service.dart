import '../models/v2_dnevni.dart';
import '../models/v2_registrovani_putnik.dart';
import 'v2_profil_service.dart';

/// Servis za dnevne putnike (v2_dnevni tabela).
/// Delegira na V2ProfilService sa fiksnom tabelom 'v2_dnevni'.
class V2DnevniService {
  V2DnevniService._();

  static const String _tabela = 'v2_dnevni';

  // ---------------------------------------------------------------------------
  // CITANJE — iz RM cache-a (sync, 0 DB upita)
  // ---------------------------------------------------------------------------

  static List<V2RegistrovaniPutnik> getAktivne() =>
      V2ProfilService.getAktivne(_tabela);

  static List<V2RegistrovaniPutnik> getSve() =>
      V2ProfilService.getSve(_tabela);

  static V2RegistrovaniPutnik? getById(String id) =>
      V2ProfilService.getById(id, _tabela);

  static String? getImeById(String id) =>
      V2ProfilService.getImeById(id, _tabela);

  static V2RegistrovaniPutnik? getByPin(String pin) =>
      V2ProfilService.getByPin(pin, _tabela);

  // ---------------------------------------------------------------------------
  // STREAM
  // ---------------------------------------------------------------------------

  static Stream<List<V2RegistrovaniPutnik>> streamAktivne() =>
      V2ProfilService.streamAktivne(_tabela);

  // ---------------------------------------------------------------------------
  // CREATE
  // ---------------------------------------------------------------------------

  static Future<V2RegistrovaniPutnik?> create({
    required String ime,
    String? telefon,
    String? telefon2,
    String? adresaBcId,
    String? adresaVsId,
    double? cena,
    String status = 'aktivan',
  }) =>
      V2ProfilService.createDnevni(
        ime: ime,
        telefon: telefon,
        telefon2: telefon2,
        adresaBcId: adresaBcId,
        adresaVsId: adresaVsId,
        cena: cena,
        status: status,
      );

  // ---------------------------------------------------------------------------
  // UPDATE / DELETE
  // ---------------------------------------------------------------------------

  static Future<bool> update(String id, Map<String, dynamic> updates) =>
      V2ProfilService.update(id, _tabela, updates);

  static Future<bool> setStatus(String id, String status) =>
      V2ProfilService.setStatus(id, _tabela, status);

  static Future<bool> delete(String id) =>
      V2ProfilService.delete(id, _tabela);

  // ---------------------------------------------------------------------------
  // KONVERZIJA — V2RegistrovaniPutnik → V2Dnevni (typed model)
  // ---------------------------------------------------------------------------

  /// Vraca typed V2Dnevni model iz cache-a
  static V2Dnevni? getDnevniById(String id) {
    final row = V2ProfilService.getById(id, _tabela);
    if (row == null) return null;
    return V2Dnevni.fromJson(row.toMap());
  }

  /// Vraca sve aktivne dnevne putnike kao typed modele
  static List<V2Dnevni> getAktivneKaoModele() =>
      getAktivne().map((r) => V2Dnevni.fromJson(r.toMap())).toList();
}
