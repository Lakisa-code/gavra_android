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
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
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
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Vraća puno ime vozača
  String get punoIme {
    return ime;
  }

  /// ToString metoda za debugging
  @override
  String toString() {
    return 'Vozac{id: $id, ime: $ime, aktivan: $aktivan, kusur: $kusur}';
  }
}
