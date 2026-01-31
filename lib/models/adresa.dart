import 'dart:math' as math;

import 'package:uuid/uuid.dart';

import '../utils/text_utils.dart';

/// Model za adrese
class Adresa {
  Adresa({
    String? id,
    required this.naziv,
    this.ulica,
    this.broj,
    this.grad,
    this.gpsLat, // Direct DECIMAL column
    this.gpsLng, // Direct DECIMAL column
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Adresa.fromMap(Map<String, dynamic> map) {
    return Adresa(
      id: map['id'] as String,
      naziv: map['naziv'] as String,
      ulica: map['ulica'] as String?,
      broj: map['broj'] as String?,
      grad: map['grad'] as String?,
      gpsLat: map['gps_lat'] as double?, // Direct column
      gpsLng: map['gps_lng'] as double?, // Direct column
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : DateTime.now(),
    );
  }

  /// Factory constructor with separate lat/lng using direct columns
  factory Adresa.withCoordinates({
    String? id,
    required String naziv,
    String? ulica,
    String? broj,
    String? grad,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Adresa(
      id: id,
      naziv: naziv,
      ulica: ulica,
      broj: broj,
      grad: grad,
      gpsLat: latitude, // Direct column
      gpsLng: longitude, // Direct column
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
  final String id;
  final String naziv;
  final String? ulica;
  final String? broj;
  final String? grad;
  final double? gpsLat; // Direct DECIMAL column
  final double? gpsLng; // Direct DECIMAL column
  final DateTime createdAt;
  final DateTime updatedAt;

  // Legacy properties for backward compatibility
  dynamic get koordinate => gpsLat != null && gpsLng != null ? {'lat': gpsLat, 'lng': gpsLng} : null;

  // Virtuelna polja za latitude/longitude iz direktnih kolona
  double? get latitude => gpsLat;
  double? get longitude => gpsLng;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'naziv': naziv,
      'ulica': ulica,
      'broj': broj,
      'grad': grad,
      'gps_lat': gpsLat, // Direct column
      'gps_lng': gpsLng, // Direct column
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Validation methods
  bool get hasValidCoordinates => gpsLat != null && gpsLng != null;

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

  // ✅ COMPREHENSIVE VALIDATION METHODS

  /// Validate street name format and content
  bool get isValidUlica {
    if (ulica == null || ulica!.trim().isEmpty) return true; // Now optional
    if (ulica!.trim().length < 2) return false;

    // Basic character validation for Serbian addresses
    final validPattern = RegExp(r'^[a-žA-Ž0-9\s.,\-/()]+$', unicode: true);
    if (!validPattern.hasMatch(ulica!.trim())) return false;

    // Check for minimum meaningful content
    final cleanStreet = ulica!.trim().replaceAll(RegExp(r'\s+'), ' ');
    return cleanStreet.length >= 2;
  }

  /// Validate house number format
  bool get isValidBroj {
    if (broj == null || broj!.trim().isEmpty) return true; // Optional field

    // Serbian house number patterns: 1, 12a, 5/3, 15-17, etc.
    final numberPattern = RegExp(r'^[0-9]+[a-zA-Z]?([\/\-][0-9]+[a-zA-Z]?)?$');
    return numberPattern.hasMatch(broj!.trim());
  }

  /// Validate city name (restricted to Bela Crkva and Vršac municipalities)
  bool get isValidGrad {
    if (grad == null || grad!.trim().isEmpty) return true; // Now optional

    // Koristi centralizovanu normalizaciju iz TextUtils
    final normalizedGrad = TextUtils.normalizeText(grad!);

    // Allowed municipalities: Bela Crkva and Vršac
    const allowedCities = [
      // Bela Crkva municipality
      'bela crkva', 'kaluđerovo', 'jasenovo', 'centa', 'grebenac',
      'kuscica', 'krustica', 'dupljaja', 'velika greda', 'dobricevo',
      // Vršac municipality
      'vrsac', 'malo srediste', 'veliko srediste', 'mesic', 'pavlis',
      'ritisevo', 'straza', 'uljma', 'vojvodinci', 'zagajica',
      'gudurica', 'kustilj', 'marcovac', 'potporanj', 'socica',
    ];

    return allowedCities.any(
      (city) => normalizedGrad.contains(city) || city.contains(normalizedGrad),
    );
  }

  /// Validate postal code format (Serbian postal codes)
  bool get isValidPostanskiBroj {
    // Remove this field as it's not in database
    return true;
  }

  /// Validate coordinate precision and bounds for Serbia
  bool get areCoordinatesValidForSerbia {
    if (!hasValidCoordinates) return false;

    // Serbia approximate bounds
    // Latitude: 42.0 to 46.5
    // Longitude: 18.0 to 23.0
    final validLatitude = latitude! >= 42.0 && latitude! <= 46.5;
    final validLongitude = longitude! >= 18.0 && longitude! <= 23.0;

    return validLatitude && validLongitude;
  }

  /// Check if address is in service area (Bela Crkva/Vršac region)
  bool get isInServiceArea {
    if (!hasValidCoordinates) return isValidGrad; // Fallback to city validation

    // Service area approximate bounds for Bela Crkva and Vršac region
    // Latitude: 44.8 to 45.5
    // Longitude: 20.8 to 21.8
    final inServiceLatitude = latitude! >= 44.8 && latitude! <= 45.5;
    final inServiceLongitude = longitude! >= 20.8 && longitude! <= 21.8;

    return inServiceLatitude && inServiceLongitude && isValidGrad;
  }

  /// Comprehensive validation combining all rules
  bool get isCompletelyValid {
    return naziv.isNotEmpty && isValidUlica && isValidBroj && isValidGrad && isValidPostanskiBroj && isInServiceArea;
  }

  /// Get validation error messages
  List<String> get validationErrors {
    final errors = <String>[];

    if (naziv.isEmpty) {
      errors.add('Naziv adrese je obavezan');
    }
    if (!isValidUlica) {
      errors.add(
        'Naziv ulice nije valjan (minimum 2 karaktera, dozvoljeni karakteri)',
      );
    }
    if (!isValidBroj) {
      errors.add('Broj nije valjan (format: 1, 12a, 5/3, 15-17)');
    }
    if (!isValidGrad) {
      errors.add('Grad nije valjan (dozvoljeni samo Bela Crkva i Vršac opštine)');
    }
    if (hasValidCoordinates && !areCoordinatesValidForSerbia) {
      errors.add('Koordinate nisu validne za Srbiju');
    }
    if (!isInServiceArea) {
      errors.add('Adresa nije u servisnoj oblasti (Bela Crkva/Vršac region)');
    }

    return errors;
  }

  // ✅ BUSINESS LOGIC METHODS

  /// Get formatted address for display
  String get displayAddress {
    final parts = <String>[];

    if (ulica != null && ulica!.isNotEmpty) {
      parts.add(_capitalizeWords(ulica!));
    }

    if (isValidBroj && broj!.isNotEmpty) {
      parts.add(broj!);
    }

    return parts.join(' ');
  }

  /// Get municipality name
  String get municipality {
    if (grad == null || grad!.trim().isEmpty) return 'Unknown';

    final normalizedGrad = grad!
        .toLowerCase()
        .trim()
        .replaceAll('š', 's')
        .replaceAll('đ', 'd')
        .replaceAll('č', 'c')
        .replaceAll('ć', 'c')
        .replaceAll('ž', 'z');

    const belaCrkvaSettlements = [
      'bela crkva',
      'kaluđerovo',
      'jasenovo',
      'centa',
      'grebenac',
      'kuscica',
      'krustica',
      'dupljaja',
      'velika greda',
      'dobricevo',
    ];

    final belongsToBelaCrkva = belaCrkvaSettlements.any(
      (settlement) => normalizedGrad.contains(settlement) || settlement.contains(normalizedGrad),
    );

    if (belongsToBelaCrkva) return 'Bela Crkva';
    return 'Vršac'; // Default for all other valid addresses
  }

  /// Get priority score for sorting (important locations first)
  int get priorityScore {
    final lowerNaziv = naziv.toLowerCase();

    if (lowerNaziv.contains('bolnica')) return 100;
    if (lowerNaziv.contains('skola') || lowerNaziv.contains('škola')) return 90;
    if (lowerNaziv.contains('ambulanta')) return 85;
    if (lowerNaziv.contains('posta') || lowerNaziv.contains('pošta')) return 80;
    if (lowerNaziv.contains('vrtic') || lowerNaziv.contains('vrtić')) return 75;
    if (lowerNaziv.contains('banka')) return 70;
    if (lowerNaziv.contains('centar')) return 65;
    if (lowerNaziv.contains('trg')) return 60;
    if (lowerNaziv.contains('glavna')) return 55;

    return 0; // Regular residential addresses
  }

  // ✅ COPY AND MODIFICATION METHODS

  /// Create a copy with updated fields
  Adresa copyWith({
    String? id,
    String? naziv,
    String? ulica,
    String? broj,
    String? grad,
    double? gpsLat,
    double? gpsLng,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Adresa(
      id: id ?? this.id,
      naziv: naziv ?? this.naziv,
      ulica: ulica ?? this.ulica,
      broj: broj ?? this.broj,
      grad: grad ?? this.grad,
      gpsLat: gpsLat ?? this.gpsLat,
      gpsLng: gpsLng ?? this.gpsLng,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Create a copy with normalized text fields
  Adresa normalize() {
    return copyWith(
      naziv: _capitalizeWords(naziv.trim()),
      ulica: ulica != null ? _capitalizeWords(ulica!.trim()) : null,
      broj: broj?.trim(),
      grad: grad != null ? _capitalizeWords(grad!.trim()) : null,
    );
  }

  /// Create a copy with updated coordinates
  Adresa withCoordinates(double latitude, double longitude) {
    return copyWith(
      gpsLat: latitude,
      gpsLng: longitude,
      updatedAt: DateTime.now(),
    );
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
    return 'Adresa{id: $id, naziv: $naziv, '
        'koordinate: ${hasValidCoordinates ? "($latitude,$longitude)" : "none"}}';
  }
}

// Remove the extension as we're using dart:math directly
