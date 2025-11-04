import 'package:uuid/uuid.dart';

import 'action_log.dart';
import 'adresa.dart';
import 'putnik.dart';
import 'ruta.dart';

/// Status dnevnih putnika
enum DnevniPutnikStatus {
  aktivno,
  rezervisan,
  pokupljen,
  otkazan,
  bolovanje,
  godisnji,
}

extension DnevniPutnikStatusExtension on DnevniPutnikStatus {
  String get value {
    switch (this) {
      case DnevniPutnikStatus.aktivno:
        return 'aktivno';
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
      case 'aktivno':
        return DnevniPutnikStatus.aktivno;
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
    required this.grad,
    required this.adresaId,
    required this.rutaId,
    required this.datumPutovanja,
    required this.vremePolaska,
    this.brojMesta = 1,
    required this.cena,
    this.status = DnevniPutnikStatus.aktivno,
    this.napomena,
    this.vremePokupljenja,
    this.vremePlacanja,
    this.voziloId,
    this.vozacId,
    this.createdBy,
    ActionLog? actionLog,
    this.obrisan = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        actionLog = actionLog ?? ActionLog.empty(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory DnevniPutnik.fromMap(Map<String, dynamic> map) {
    return DnevniPutnik(
      id: map['id'] as String,
      ime: map['putnik_ime'] as String,
      brojTelefona: map['telefon'] as String?,
      grad: map['grad'] as String,
      adresaId: map['adresa_id'] as String,
      rutaId: map['ruta_id'] as String,
      datumPutovanja: DateTime.parse(map['datum_putovanja'] as String),
      vremePolaska: map['vreme_polaska'] as String,
      brojMesta: map['broj_mesta'] as int? ?? 1,
      cena: (map['cena'] as num).toDouble(),
      status: DnevniPutnikStatusExtension.fromString(
        map['status'] as String? ?? 'aktivno',
      ),
      napomena: map['napomena'] as String?,
      vremePokupljenja: map['vreme_pokupljenja'] != null ? DateTime.parse(map['vreme_pokupljenja'] as String) : null,
      vremePlacanja: map['vreme_placanja'] != null ? DateTime.parse(map['vreme_placanja'] as String) : null,
      voziloId: map['vozilo_id'] as String?,
      vozacId: map['vozac_id'] as String?,
      createdBy: map['created_by'] as String?,
      actionLog: ActionLog.fromString(map['action_log'] as String?),
      obrisan: map['obrisan'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  final String id;
  final String ime;
  final String? brojTelefona;
  final String grad;
  final String adresaId;
  final String rutaId;
  final DateTime datumPutovanja;
  final String vremePolaska;
  final int brojMesta;
  final double cena;
  final DnevniPutnikStatus status;
  final String? napomena;
  final DateTime? vremePokupljenja;
  final DateTime? vremePlacanja;
  final String? voziloId;
  final String? vozacId;
  final String? createdBy;
  final ActionLog actionLog;
  final bool obrisan;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'putnik_ime': ime,
      'telefon': brojTelefona,
      'grad': grad,
      'adresa_id': adresaId,
      'ruta_id': rutaId,
      'datum_putovanja': datumPutovanja.toIso8601String().split('T')[0],
      'vreme_polaska': vremePolaska,
      'broj_mesta': brojMesta,
      'cena': cena,
      'status': status.value,
      'napomena': napomena,
      'vreme_pokupljenja': vremePokupljenja?.toIso8601String(),
      'vreme_placanja': vremePlacanja?.toIso8601String(),
      'vozilo_id': voziloId,
      'vozac_id': vozacId,
      'created_by': createdBy,
      'action_log': actionLog.toJsonString(),
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
      naplatioVozac: actionLog.getVozacForAction(ActionType.paid),
      pokupioVozac: actionLog.getVozacForAction(ActionType.picked),
      dodaoVozac: actionLog.getVozacForAction(ActionType.created) ?? createdBy,
      grad: adresa.grad ?? '',
      adresa: '${adresa.ulica ?? ''} ${adresa.broj ?? ''}'.trim(),
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
      case DnevniPutnikStatus.aktivno:
        return 'Aktivno'; // ✅ DODANO: default vrednost iz baze
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
      naplatioVozac: actionLog.getVozacForAction(ActionType.paid),
      pokupioVozac: actionLog.getVozacForAction(ActionType.picked),
      dodaoVozac: actionLog.getVozacForAction(ActionType.created) ?? createdBy,
      grad: adresa.grad ?? '',
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
    String? grad,
    String? adresaId,
    String? rutaId,
    DateTime? datumPutovanja,
    String? vremePolaska,
    int? brojMesta,
    double? cena,
    DnevniPutnikStatus? status,
    String? napomena,
    DateTime? vremePokupljenja,
    DateTime? vremePlacanja,
    String? voziloId,
    String? vozacId,
    String? createdBy,
    ActionLog? actionLog,
    bool? obrisan,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DnevniPutnik(
      id: id ?? this.id,
      ime: ime ?? this.ime,
      brojTelefona: brojTelefona ?? this.brojTelefona,
      grad: grad ?? this.grad,
      adresaId: adresaId ?? this.adresaId,
      rutaId: rutaId ?? this.rutaId,
      datumPutovanja: datumPutovanja ?? this.datumPutovanja,
      vremePolaska: vremePolaska ?? this.vremePolaska,
      brojMesta: brojMesta ?? this.brojMesta,
      cena: cena ?? this.cena,
      status: status ?? this.status,
      napomena: napomena ?? this.napomena,
      vremePokupljenja: vremePokupljenja ?? this.vremePokupljenja,
      vremePlacanja: vremePlacanja ?? this.vremePlacanja,
      voziloId: voziloId ?? this.voziloId,
      vozacId: vozacId ?? this.vozacId,
      createdBy: createdBy ?? this.createdBy,
      actionLog: actionLog ?? this.actionLog,
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

  // ✅ HELPER METODE ZA ACTIONLOG

  /// Ko je kreirao putnika
  String? get createdByVozac => actionLog.getVozacForAction(ActionType.created) ?? createdBy;

  /// Ko je naplatio putnika
  String? get paidByVozac => actionLog.getVozacForAction(ActionType.paid);

  /// Ko je pokupio putnika
  String? get pickedByVozac => actionLog.getVozacForAction(ActionType.picked);

  /// Ko je otkazao putnika
  String? get cancelledByVozac => actionLog.getVozacForAction(ActionType.cancelled);

  /// Da li je putnik naplaton
  bool get isNaplaton => actionLog.hasAction(ActionType.paid) || paidByVozac != null;

  /// Da li je putnik otkazan
  bool get isOtkazan => actionLog.hasAction(ActionType.cancelled) || cancelledByVozac != null;

  /// Dodaje akciju u log
  DnevniPutnik addAction(ActionType type, String vozacId, [String? note]) {
    return copyWith(
      actionLog: actionLog.addAction(type, vozacId, note),
    );
  }
}
