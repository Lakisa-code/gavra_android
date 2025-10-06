import 'package:uuid/uuid.dart';

/// Model za adrese
class Adresa {
  Adresa({
    String? id,
    required this.ulica,
    this.broj,
    required this.grad,
    this.postanskiBroj,
    this.koordinate,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  factory Adresa.fromMap(Map<String, dynamic> map) {
    return Adresa(
      id: map['id'] as String,
      ulica: map['ulica'] as String,
      broj: map['broj'] as String?,
      grad: map['grad'] as String,
      postanskiBroj: map['postanski_broj'] as String?,
      koordinate: map['koordinate'] as String?, // PostgreSQL POINT as string
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Factory constructor with separate lat/lng that creates POINT
  factory Adresa.withCoordinates({
    String? id,
    required String ulica,
    String? broj,
    required String grad,
    String? postanskiBroj,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
  }) {
    return Adresa(
      id: id,
      ulica: ulica,
      broj: broj,
      grad: grad,
      postanskiBroj: postanskiBroj,
      koordinate: createPointString(latitude, longitude),
      createdAt: createdAt,
    );
  }
  final String id;
  final String ulica;
  final String? broj;
  final String grad;
  final String? postanskiBroj;
  final String? koordinate; // PostgreSQL POINT kao string "(lat,lng)"
  final DateTime createdAt;

  // Virtuelna polja za latitude/longitude iz POINT koordinata
  double? get latitude => _parseLatitudeFromPoint();
  double? get longitude => _parseLongitudeFromPoint();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ulica': ulica,
      'broj': broj,
      'grad': grad,
      'postanski_broj': postanskiBroj,
      'koordinate': koordinate, // PostgreSQL POINT as string
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get punaAdresa {
    final delovi = [ulica];
    if (broj != null) delovi.add(broj!);
    delovi.add(grad);
    if (postanskiBroj != null) delovi.add(postanskiBroj!);
    return delovi.join(', ');
  }

  /// Parse latitude from PostgreSQL POINT string format "(lat,lng)"
  double? _parseLatitudeFromPoint() {
    if (koordinate == null) return null;
    try {
      // PostgreSQL POINT format: "(latitude,longitude)"
      final clean = koordinate!.replaceAll(RegExp(r'[()]'), '');
      final parts = clean.split(',');
      if (parts.length == 2) {
        return double.parse(parts[0].trim());
      }
    } catch (e) {
      // Handle parsing errors gracefully
    }
    return null;
  }

  /// Parse longitude from PostgreSQL POINT string format "(lat,lng)"
  double? _parseLongitudeFromPoint() {
    if (koordinate == null) return null;
    try {
      // PostgreSQL POINT format: "(latitude,longitude)"
      final clean = koordinate!.replaceAll(RegExp(r'[()]'), '');
      final parts = clean.split(',');
      if (parts.length == 2) {
        return double.parse(parts[1].trim());
      }
    } catch (e) {
      // Handle parsing errors gracefully
    }
    return null;
  }

  /// Create POINT string from latitude and longitude
  static String? createPointString(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    return '($lat,$lng)';
  }
}
