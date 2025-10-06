import 'package:uuid/uuid.dart';

/// Model za vozila
class Vozilo {
  Vozilo({
    String? id,
    required this.registracija,
    required this.marka,
    required this.model,
    this.godinaProizvodnje,
    this.brojSedista = 50,
    this.aktivan = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Vozilo.fromMap(Map<String, dynamic> map) {
    return Vozilo(
      id: map['id'] as String,
      registracija: map['registracija'] as String,
      marka: map['marka'] as String,
      model: map['model'] as String,
      godinaProizvodnje: map['godina_proizvodnje'] as int?,
      brojSedista: map['broj_sedista'] as int? ?? 50,
      aktivan: map['aktivan'] as bool? ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
  final String id;
  final String registracija;
  final String marka;
  final String model;
  final int? godinaProizvodnje;
  final int brojSedista;
  final bool aktivan;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'registracija': registracija,
      'marka': marka,
      'model': model,
      'godina_proizvodnje': godinaProizvodnje,
      'broj_sedista': brojSedista,
      'aktivan': aktivan,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get punNaziv => '$marka $model ($registracija)';
}
