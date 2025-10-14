import 'package:uuid/uuid.dart';

import 'adresa.dart';
import 'putnik.dart';
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
        map['status'] as String? ?? 'rezervisan',
      ),
      napomena: map['napomena'] as String?,
      vremePokupljenja: map['vreme_pokupljenja'] != null ? DateTime.parse(map['vreme_pokupljenja'] as String) : null,
      pokupioVozacId: map['pokupio_vozac_id'] as String?,
      vremePlacanja: map['vreme_placanja'] != null ? DateTime.parse(map['vreme_placanja'] as String) : null,
      naplatioVozacId: map['naplatio_vozac_id'] as String?,
      dodaoVozacId: map['dodao_vozac_id'] as String?,
      obrisan: map['obrisan'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
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

  bool get jePokupljen => status == DnevniPutnikStatus.pokupljen || vremePokupljenja != null;
  bool get jePlacen => vremePlacanja != null;
  bool get jeOtkazan => status == DnevniPutnikStatus.otkazan;
  bool get jeOdsustvo => status == DnevniPutnikStatus.bolovanje || status == DnevniPutnikStatus.godisnji;

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
      cena: cena,
      naplatioVozac: naplatioVozacId,
      pokupioVozac: pokupioVozacId,
      dodaoVozac: dodaoVozacId,
      grad: adresa.grad,
      adresa: '${adresa.ulica} ${adresa.broj}',
      obrisan: obrisan,
      brojTelefona: brojTelefona,
      datum: datumPutovanja.toIso8601String().split('T')[0],
    );
  }

  // ✅ VALIDACIJSKE METODE

  /// Validira da li su sva obavezna polja popunjena
  bool get isValid {
    return ime.trim().isNotEmpty && adresaId.isNotEmpty && rutaId.isNotEmpty && cena >= 0 && vremePolaska.isNotEmpty;
  }

  /// Validira format vremena polaska (HH:mm)
  bool get isVremePolaskaValid {
    final timeRegex = RegExp(r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$');
    return timeRegex.hasMatch(vremePolaska);
  }

  /// Proverava da li je putnik aktivan (nije obrisan i nije otkazan)
  bool get isAktivan {
    return !obrisan && status != DnevniPutnikStatus.otkazan;
  }

  /// Proverava da li je putnik pokupljen
  bool get isPokupljen {
    return status == DnevniPutnikStatus.pokupljen && vremePokupljenja != null;
  }

  /// Proverava da li je putnik plaćen
  bool get isPlacen {
    return vremePlacanja != null && cena > 0;
  }

  /// Vraća ljudski čitljiv status
  String get statusLabel {
    switch (status) {
      case DnevniPutnikStatus.rezervisan:
        return 'Rezervisan';
      case DnevniPutnikStatus.pokupljen:
        return 'Pokupljen';
      case DnevniPutnikStatus.otkazan:
        return 'Otkazan';
      case DnevniPutnikStatus.bolovanje:
        return 'Bolovanje';
      case DnevniPutnikStatus.godisnji:
        return 'Godišnji odmor';
    }
  }

  /// Vraća dan u nedelji kao kraticu
  String get danKratica {
    switch (datumPutovanja.weekday) {
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

  // ✅ RELATIONSHIP HELPER METODE

  /// Konvertuje u Putnik objekat za kompatibilnost sa UI
  Putnik toPutnikWithRelations(Adresa adresa, Ruta ruta) {
    return Putnik(
      id: id,
      ime: ime,
      polazak: vremePolaska,
      pokupljen: isPokupljen,
      vremeDodavanja: createdAt,
      mesecnaKarta: false,
      dan: danKratica,
      status: status.value,
      vremePokupljenja: vremePokupljenja,
      vremePlacanja: vremePlacanja,
      placeno: isPlacen,
      cena: cena,
      naplatioVozac: naplatioVozacId,
      pokupioVozac: pokupioVozacId,
      dodaoVozac: dodaoVozacId,
      grad: adresa.grad,
      adresa: adresa.naziv,
      obrisan: obrisan,
      brojTelefona: brojTelefona,
      datum: datumPutovanja.toIso8601String().split('T')[0],
      // Nova polja specifična za dnevne putnike
      rutaNaziv: ruta.naziv,
      adresaKoordinate: '${adresa.latitude},${adresa.longitude}',
    );
  }

  /// Kopira objekat sa izmenjenim vrednostima
  DnevniPutnik copyWith({
    String? id,
    String? ime,
    String? brojTelefona,
    String? adresaId,
    String? rutaId,
    DateTime? datumPutovanja,
    String? vremePolaska,
    int? brojMesta,
    double? cena,
    DnevniPutnikStatus? status,
    String? napomena,
    DateTime? vremePokupljenja,
    String? pokupioVozacId,
    DateTime? vremePlacanja,
    String? naplatioVozacId,
    String? dodaoVozacId,
    bool? obrisan,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DnevniPutnik(
      id: id ?? this.id,
      ime: ime ?? this.ime,
      brojTelefona: brojTelefona ?? this.brojTelefona,
      adresaId: adresaId ?? this.adresaId,
      rutaId: rutaId ?? this.rutaId,
      datumPutovanja: datumPutovanja ?? this.datumPutovanja,
      vremePolaska: vremePolaska ?? this.vremePolaska,
      brojMesta: brojMesta ?? this.brojMesta,
      cena: cena ?? this.cena,
      status: status ?? this.status,
      napomena: napomena ?? this.napomena,
      vremePokupljenja: vremePokupljenja ?? this.vremePokupljenja,
      pokupioVozacId: pokupioVozacId ?? this.pokupioVozacId,
      vremePlacanja: vremePlacanja ?? this.vremePlacanja,
      naplatioVozacId: naplatioVozacId ?? this.naplatioVozacId,
      dodaoVozacId: dodaoVozacId ?? this.dodaoVozacId,
      obrisan: obrisan ?? this.obrisan,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// toString za debugging
  @override
  String toString() {
    return 'DnevniPutnik(id: $id, ime: $ime, datum: ${datumPutovanja.toIso8601String().split('T')[0]}, '
        'polazak: $vremePolaska, status: ${status.value}, cena: $cena)';
  }

  /// Jednakost dva objekta
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DnevniPutnik &&
        other.id == id &&
        other.ime == ime &&
        other.datumPutovanja == datumPutovanja &&
        other.vremePolaska == vremePolaska;
  }

  @override
  int get hashCode {
    return id.hashCode ^ ime.hashCode ^ datumPutovanja.hashCode ^ vremePolaska.hashCode;
  }
}



