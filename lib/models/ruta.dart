import 'package:uuid/uuid.dart';

/// Model za rute
class Ruta {
  Ruta({
    String? id,
    required this.naziv,
    required this.polazak,
    required this.dolazak,
    this.opis,
    this.udaljenostKm,
    this.prosecnoVreme,
    this.aktivan = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Ruta.fromMap(Map<String, dynamic> map) {
    return Ruta(
      id: map['id'] as String,
      naziv: map['naziv'] as String,
      polazak: map['polazak'] as String,
      dolazak: map['dolazak'] as String,
      opis: map['opis'] as String?,
      udaljenostKm: (map['udaljenost_km'] as num?)?.toDouble(),
      prosecnoVreme: map['prosecno_vreme'] != null
          ? Duration(seconds: map['prosecno_vreme'] as int)
          : null,
      aktivan: map['aktivan'] as bool? ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
  final String id;
  final String naziv;
  final String polazak;
  final String dolazak;
  final String? opis;
  final double? udaljenostKm;
  final Duration? prosecnoVreme;
  final bool aktivan;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'naziv': naziv,
      'polazak': polazak,
      'dolazak': dolazak,
      'opis': opis,
      'udaljenost_km': udaljenostKm,
      'prosecno_vreme': prosecnoVreme?.inSeconds,
      'aktivan': aktivan,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get rutaOpis => '$polazak → $dolazak';
}
