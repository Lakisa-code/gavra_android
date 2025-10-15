import 'package:uuid/uuid.dart';

/// Model za vozače
class Vozac {
  Vozac({
    String? id,
    required this.ime,
    this.prezime,
    this.brojTelefona,
    this.email,
    this.adresaId,
    this.aktivan = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Vozac.fromMap(Map<String, dynamic> map) {
    return Vozac(
      id: map['id'] as String,
      ime: map['ime'] as String,
      prezime: map['prezime'] as String?,
      brojTelefona: map['broj_telefona'] as String?,
      email: map['email'] as String?,
      adresaId: map['adresa_id'] as String?,
      aktivan: map['aktivan'] as bool? ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
  final String id;
  final String ime;
  final String? prezime;
  final String? brojTelefona;
  final String? email;
  final String? adresaId; // ID adrese vozača
  final bool aktivan;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ime': ime,
      'prezime': prezime,
      'broj_telefona': brojTelefona,
      'email': email,
      'adresa_id': adresaId,
      'aktivan': aktivan,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Vraća puno ime vozača (ime + prezime)
  String get punoIme {
    if (prezime != null && prezime!.isNotEmpty) {
      return '$ime $prezime';
    }
    return ime;
  }

  /// ToString metoda za debugging
  @override
  String toString() {
    return 'Vozac{id: $id, ime: $ime, prezime: $prezime, aktivan: $aktivan}';
  }
}





