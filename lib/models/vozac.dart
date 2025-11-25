import 'package:uuid/uuid.dart';

/// Model za vozače
class Vozac {
  Vozac({
    String? id,
    required this.ime,
    this.brojTelefona,
    this.email,
    this.aktivan = true,
    this.kusur = 0.0,
    this.obrisan = false,
    this.deletedAt,
    this.status = 'aktivan',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : assert(ime.trim().isNotEmpty, 'Ime vozača ne može biti prazno'),
        assert(kusur >= 0.0, 'Kusur ne može biti negativan'),
        id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Vozac.fromMap(Map<String, dynamic> map) {
    return Vozac(
      id: map['id'] as String,
      ime: map['ime'] as String,
      brojTelefona: map['telefon'] as String?,
      email: map['email'] as String?,
      aktivan: map['aktivan'] as bool? ?? true,
      kusur: (map['kusur'] as num?)?.toDouble() ?? 0.0,
      obrisan: map['obrisan'] as bool? ?? false,
      deletedAt: map['deleted_at'] != null
          ? DateTime.parse(map['deleted_at'] as String)
          : null,
      status: map['status'] as String? ?? 'aktivan',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
  final String id;
  final String ime;
  final String? brojTelefona;
  final String? email;
  final bool aktivan;
  final double kusur;
  final bool obrisan;
  final DateTime? deletedAt;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ime': ime,
      'telefon': brojTelefona,
      'email': email,
      'aktivan': aktivan,
      'kusur': kusur,
      'obrisan': obrisan,
      'deleted_at': deletedAt?.toIso8601String(),
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Vraća puno ime vozača
  String get punoIme {
    return ime;
  }

  /// Validira da li je ime vozača validno (ne sme biti prazno)
  bool get isValidIme {
    return ime.trim().isNotEmpty && ime.trim().length >= 2;
  }

  /// Validira da li je kusur validan (mora biti >= 0)
  bool get isValidKusur {
    return kusur >= 0.0;
  }

  /// Validira telefon format (srpski broj)
  bool get isValidTelefon {
    if (brojTelefona == null || brojTelefona!.isEmpty) {
      return true; // Optional field
    }

    final telefon = brojTelefona!.replaceAll(RegExp(r'[^\d+]'), '');

    // Srpski mobilni: +381 6x xxx xxxx ili 06x xxx xxxx
    // Srpski fiksni: +381 1x xxx xxxx ili 01x xxx xxxx
    return telefon.startsWith('+3816') ||
        telefon.startsWith('06') ||
        telefon.startsWith('+3811') ||
        telefon.startsWith('01') ||
        telefon.length == 8 ||
        telefon.length == 9; // lokalni brojevi
  }

  /// Validira email format
  bool get isValidEmail {
    if (email == null || email!.isEmpty) return true; // Optional field

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email!);
  }

  /// Kompletna validacija vozača
  bool get isValid {
    return isValidIme && isValidKusur && isValidTelefon && isValidEmail;
  }

  /// Lista grešaka validacije
  List<String> get validationErrors {
    final errors = <String>[];

    if (!isValidIme) {
      errors.add('Ime vozača mora imati najmanje 2 karaktera');
    }

    if (!isValidKusur) {
      errors.add('Kusur ne može biti negativan');
    }

    if (!isValidTelefon) {
      errors.add('Nevaljan format telefona');
    }

    if (!isValidEmail) {
      errors.add('Nevaljan format email adrese');
    }

    return errors;
  }

  /// Vraca formatiran kusur za prikaz
  String get displayKusur {
    return '${kusur.toStringAsFixed(2)} RSD';
  }

  /// Kreira kopiju vozača sa promenjenim vrednostima
  Vozac copyWith({
    String? ime,
    String? brojTelefona,
    String? email,
    bool? aktivan,
    double? kusur,
    bool? obrisan,
    DateTime? deletedAt,
    String? status,
  }) {
    return Vozac(
      id: id,
      ime: ime ?? this.ime,
      brojTelefona: brojTelefona ?? this.brojTelefona,
      email: email ?? this.email,
      aktivan: aktivan ?? this.aktivan,
      kusur: kusur ?? this.kusur,
      obrisan: obrisan ?? this.obrisan,
      deletedAt: deletedAt ?? this.deletedAt,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// ToString metoda za debugging
  @override
  String toString() {
    return 'Vozac{id: $id, ime: $ime, aktivan: $aktivan, kusur: $kusur}';
  }
}
