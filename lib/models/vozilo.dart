import 'package:uuid/uuid.dart';

/// Model za vozila
class Vozilo {
  Vozilo({
    String? id,
    required this.registracija,
    this.marka,
    this.model,
    this.godinaProizvodnje,
    this.brojSedista = 50,
    this.aktivan = true,
    this.obrisan = false,
    this.deletedAt,
    this.status = 'aktivan',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Vozilo.fromMap(Map<String, dynamic> map) {
    return Vozilo(
      id: map['id'] as String,
      registracija: map['registarski_broj'] as String,
      marka: map['marka'] as String?,
      model: map['model'] as String?,
      godinaProizvodnje: map['godina_proizvodnje'] as int?,
      brojSedista: map['broj_mesta'] as int? ?? 50,
      aktivan: map['aktivan'] as bool? ?? true,
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
  final String registracija;
  final String? marka;
  final String? model;
  final int? godinaProizvodnje;
  final int brojSedista;
  final bool aktivan;
  final bool obrisan;
  final DateTime? deletedAt;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'registarski_broj': registracija,
      'marka': marka,
      'model': model,
      'godina_proizvodnje': godinaProizvodnje,
      'broj_mesta': brojSedista,
      'aktivan': aktivan,
      'obrisan': obrisan,
      'deleted_at': deletedAt?.toIso8601String(),
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get punNaziv => '$marka $model ($registracija)';

  /// CopyWith metoda za kreiranje kopije sa izmenjenim poljima
  Vozilo copyWith({
    String? registracija,
    String? marka,
    String? model,
    int? godinaProizvodnje,
    int? brojSedista,
    bool? aktivan,
    bool? obrisan,
    DateTime? deletedAt,
    String? status,
  }) {
    return Vozilo(
      id: id,
      registracija: registracija ?? this.registracija,
      marka: marka ?? this.marka,
      model: model ?? this.model,
      godinaProizvodnje: godinaProizvodnje ?? this.godinaProizvodnje,
      brojSedista: brojSedista ?? this.brojSedista,
      aktivan: aktivan ?? this.aktivan,
      obrisan: obrisan ?? this.obrisan,
      deletedAt: deletedAt ?? this.deletedAt,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
