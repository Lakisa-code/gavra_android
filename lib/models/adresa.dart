import 'package:uuid/uuid.dart';

/// Model za adrese
class Adresa {
  final String id;
  final String ulica;
  final String? broj;
  final String grad;
  final String? postanskiBroj;
  final double? latitude;
  final double? longitude;
  final String? napomena;
  final bool aktivan;
  final DateTime createdAt;
  final DateTime updatedAt;

  Adresa({
    String? id,
    required this.ulica,
    this.broj,
    required this.grad,
    this.postanskiBroj,
    this.latitude,
    this.longitude,
    this.napomena,
    this.aktivan = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Adresa.fromMap(Map<String, dynamic> map) {
    return Adresa(
      id: map['id'] as String,
      ulica: map['ulica'] as String,
      broj: map['broj'] as String?,
      grad: map['grad'] as String,
      postanskiBroj: map['postanski_broj'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      napomena: map['napomena'] as String?,
      aktivan: map['aktivan'] as bool? ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ulica': ulica,
      'broj': broj,
      'grad': grad,
      'postanski_broj': postanskiBroj,
      'latitude': latitude,
      'longitude': longitude,
      'napomena': napomena,
      'aktivan': aktivan,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get punaAdresa {
    final delovi = [ulica];
    if (broj != null) delovi.add(broj!);
    delovi.add(grad);
    if (postanskiBroj != null) delovi.add(postanskiBroj!);
    return delovi.join(', ');
  }
}
