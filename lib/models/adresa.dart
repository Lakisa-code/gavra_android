import 'dart:math' as math;

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

  // Naziv adrese za kompatibilnost sa DnevniPutnik modelom
  String get naziv => punaAdresa;

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

  /// Validation methods
  bool get hasValidCoordinates => latitude != null && longitude != null;

  bool get isValidAddress => ulica.isNotEmpty && grad.isNotEmpty;

  bool get hasCompleteAddress => isValidAddress && broj != null && broj!.isNotEmpty;

  /// Standardized address format
  String get standardizedAddress {
    final parts = <String>[];

    // Add street
    if (ulica.isNotEmpty) {
      parts.add(_capitalizeWords(ulica));
    }

    // Add number if exists
    if (broj != null && broj!.isNotEmpty) {
      parts.add(broj!);
    }

    // Add city
    if (grad.isNotEmpty) {
      parts.add(_capitalizeWords(grad));
    }

    // Add postal code if exists
    if (postanskiBroj != null && postanskiBroj!.isNotEmpty) {
      parts.add(postanskiBroj!);
    }

    return parts.join(', ');
  }

  /// Distance calculation between two addresses
  double? distanceTo(Adresa other) {
    if (!hasValidCoordinates || !other.hasValidCoordinates) {
      return null;
    }

    final lat1 = latitude!;
    final lon1 = longitude!;
    final lat2 = other.latitude!;
    final lon2 = other.longitude!;

    // Haversine formula
    const double earthRadius = 6371; // km
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) * math.pow(math.sin(dLon / 2), 2);

    final double c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  /// Helper methods
  String _capitalizeWords(String text) {
    return text
        .split(' ')
        .map(
          (word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : word,
        )
        .join(' ');
  }

  double _toRadians(double degrees) => degrees * (math.pi / 180);

  /// Enhanced toString for debugging
  @override
  String toString() {
    return 'Adresa{id: $id, adresa: $standardizedAddress, '
        'koordinate: ${hasValidCoordinates ? "($latitude,$longitude)" : "none"}}';
  }
}

// Remove the extension as we're using dart:math directly
