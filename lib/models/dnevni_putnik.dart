import 'package:uuid/uuid.dart';
import 'putnik.dart';
import 'adresa.dart';
import 'ruta.dart';

/// Status dnevnih putnika
enum DnevniPutnikStatus {
  rezervisan,
  pokupljen,
  otkazan,
  bolovanje,
  godisnji,
}

extension DnevniPutnikStatusExtension on DnevniPutnikStatus {
  String get value {
    switch (this) {
      case DnevniPutnikStatus.rezervisan:
        return 'rezervisan';
      case DnevniPutnikStatus.pokupljen:
        return 'pokupljen';
      case DnevniPutnikStatus.otkazan:
        return 'otkazan';
      case DnevniPutnikStatus.bolovanje:
        return 'bolovanje';
      case DnevniPutnikStatus.godisnji:
        return 'godisnji';
    }
  }

  static DnevniPutnikStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'rezervisan':
        return DnevniPutnikStatus.rezervisan;
      case 'pokupljen':
        return DnevniPutnikStatus.pokupljen;
      case 'otkazan':
        return DnevniPutnikStatus.otkazan;
      case 'bolovanje':
        return DnevniPutnikStatus.bolovanje;
      case 'godisnji':
        return DnevniPutnikStatus.godisnji;
      default:
        return DnevniPutnikStatus.rezervisan;
    }
  }
}

/// Model za dnevne putnike
class DnevniPutnik {
  final String id;
  final String ime;
  final String? brojTelefona;
  final String adresaId;
  final String rutaId;
  final DateTime datumPutovanja;
  final String vremePolaska;
  final int brojMesta;
  final double cena;
  final DnevniPutnikStatus status;
  final String? napomena;
  final DateTime? vremePokupljenja;
  final String? pokupioVozacId;
  final DateTime? vremePlacanja;
  final String? naplatioVozacId;
  final String? dodaoVozacId;
  final bool obrisan;
  final DateTime createdAt;
  final DateTime updatedAt;

  DnevniPutnik({
    String? id,
    required this.ime,
    this.brojTelefona,
    required this.adresaId,
    required this.rutaId,
    required this.datumPutovanja,
    required this.vremePolaska,
    this.brojMesta = 1,
    required this.cena,
    this.status = DnevniPutnikStatus.rezervisan,
    this.napomena,
    this.vremePokupljenja,
    this.pokupioVozacId,
    this.vremePlacanja,
    this.naplatioVozacId,
    this.dodaoVozacId,
    this.obrisan = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory DnevniPutnik.fromMap(Map<String, dynamic> map) {
    return DnevniPutnik(
      id: map['id'] as String,
      ime: map['ime'] as String,
      brojTelefona: map['broj_telefona'] as String?,
      adresaId: map['adresa_id'] as String,
      rutaId: map['ruta_id'] as String,
      datumPutovanja: DateTime.parse(map['datum'] as String),
      vremePolaska: map['polazak'] as String,
      brojMesta: map['broj_mesta'] as int? ?? 1,
      cena: (map['cena'] as num).toDouble(),
      status: DnevniPutnikStatusExtension.fromString(
          map['status'] as String? ?? 'rezervisan'),
      napomena: map['napomena'] as String?,
      vremePokupljenja: map['vreme_pokupljenja'] != null
          ? DateTime.parse(map['vreme_pokupljenja'] as String)
          : null,
      pokupioVozacId: map['pokupio_vozac_id'] as String?,
      vremePlacanja: map['vreme_placanja'] != null
          ? DateTime.parse(map['vreme_placanja'] as String)
          : null,
      naplatioVozacId: map['naplatio_vozac_id'] as String?,
      dodaoVozacId: map['dodao_vozac_id'] as String?,
      obrisan: map['obrisan'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ime': ime,
      'broj_telefona': brojTelefona,
      'adresa_id': adresaId,
      'ruta_id': rutaId,
      'datum': datumPutovanja.toIso8601String().split('T')[0],
      'polazak': vremePolaska,
      'broj_mesta': brojMesta,
      'cena': cena,
      'status': status.value,
      'napomena': napomena,
      'vreme_pokupljenja': vremePokupljenja?.toIso8601String(),
      'pokupio_vozac_id': pokupioVozacId,
      'vreme_placanja': vremePlacanja?.toIso8601String(),
      'naplatio_vozac_id': naplatioVozacId,
      'dodao_vozac_id': dodaoVozacId,
      'obrisan': obrisan,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get punoIme => ime;

  bool get jePokupljen =>
      status == DnevniPutnikStatus.pokupljen || vremePokupljenja != null;
  bool get jePlacen => vremePlacanja != null;
  bool get jeOtkazan => status == DnevniPutnikStatus.otkazan;
  bool get jeOdsustvo =>
      status == DnevniPutnikStatus.bolovanje ||
      status == DnevniPutnikStatus.godisnji;

  /// Konvertuje DnevniPutnik u legacy Putnik format za kompatibilnost sa UI
  Putnik toPutnik(Adresa adresa, Ruta ruta) {
    return Putnik(
      id: id,
      ime: punoIme,
      polazak: vremePolaska,
      pokupljen: jePokupljen,
      vremeDodavanja: createdAt,
      mesecnaKarta: false,
      dan: datumPutovanja.weekday == 1
          ? 'pon'
          : datumPutovanja.weekday == 2
              ? 'uto'
              : datumPutovanja.weekday == 3
                  ? 'sre'
                  : datumPutovanja.weekday == 4
                      ? 'cet'
                      : datumPutovanja.weekday == 5
                          ? 'pet'
                          : datumPutovanja.weekday == 6
                              ? 'sub'
                              : 'ned',
      status: status.value,
      vremePokupljenja: vremePokupljenja,
      vremePlacanja: vremePlacanja,
      placeno: jePlacen,
      iznosPlacanja: cena,
      naplatioVozac: naplatioVozacId,
      pokupioVozac: pokupioVozacId,
      dodaoVozac: dodaoVozacId,
      vozac:
          null, // Driver linking will be implemented with enhanced driver management
      grad: adresa.grad,
      adresa: '${adresa.ulica} ${adresa.broj}',
      obrisan: obrisan,
      brojTelefona: brojTelefona,
      datum: datumPutovanja.toIso8601String().split('T')[0],
    );
  }
}
