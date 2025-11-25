import 'dart:math' as math;

import 'package:uuid/uuid.dart';

/// Model za adrese
class Adresa {
  Adresa({
    String? id,
    required this.naziv,
    this.ulica,
    this.broj,
    this.grad,
    this.koordinate,
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
      koordinate: map['koordinate'], // JSONB data
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : DateTime.now(),
    );
  }

  /// Factory constructor with separate lat/lng that creates JSONB coordinates
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
      koordinate: createCoordinatesJsonb(latitude, longitude),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
  final String id;
  final String naziv;
  final String? ulica;
  final String? broj;
  final String? grad;
  final dynamic koordinate; // JSONB data from PostgreSQL
  final DateTime createdAt;
  final DateTime updatedAt;

  // Virtuelna polja za latitude/longitude iz JSONB koordinata
  double? get latitude => _parseLatitudeFromJsonb();
  double? get longitude => _parseLongitudeFromJsonb();

  // Puna adresa za kompatibilnost
  String get punaAdresa {
    final delovi = <String>[];
    if (ulica != null && ulica!.isNotEmpty) delovi.add(ulica!);
    if (broj != null && broj!.isNotEmpty) delovi.add(broj!);
    if (grad != null && grad!.isNotEmpty) delovi.add(grad!);
    return delovi.join(', ');
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'naziv': naziv,
      'ulica': ulica,
      'broj': broj,
      'grad': grad,
      'koordinate': koordinate, // JSONB data
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Parse latitude from JSONB coordinates
  double? _parseLatitudeFromJsonb() {
    if (koordinate == null) return null;
    try {
      if (koordinate is Map<String, dynamic>) {
        final lat = (koordinate as Map<String, dynamic>)['lat'];
        return lat is num ? lat.toDouble() : null;
      }
    } catch (e) {
      // Handle parsing errors gracefully
    }
    return null;
  }

  /// Parse longitude from JSONB coordinates
  double? _parseLongitudeFromJsonb() {
    if (koordinate == null) return null;
    try {
      if (koordinate is Map<String, dynamic>) {
        final lng = (koordinate as Map<String, dynamic>)['lng'];
        return lng is num ? lng.toDouble() : null;
      }
    } catch (e) {
      // Handle parsing errors gracefully
    }
    return null;
  }

  /// Create JSONB coordinates from latitude and longitude
  static Map<String, double>? createCoordinatesJsonb(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    return {'lat': lat, 'lng': lng};
  }

  /// Validation methods
  bool get hasValidCoordinates => latitude != null && longitude != null;

  bool get isValidAddress => (ulica?.isNotEmpty ?? false) && (grad?.isNotEmpty ?? false);

  bool get hasCompleteAddress => isValidAddress && broj != null && broj!.isNotEmpty;

  /// Standardized address format
  String get standardizedAddress {
    final parts = <String>[];

    // Add street
    if (ulica != null && ulica!.isNotEmpty) {
      parts.add(_capitalizeWords(ulica!));
    }

    // Add number if exists
    if (broj != null && broj!.isNotEmpty) {
      parts.add(broj!);
    }

    // Add city
    if (grad != null && grad!.isNotEmpty) {
      parts.add(_capitalizeWords(grad!));
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

    final normalizedGrad = grad!
        .toLowerCase()
        .trim()
        .replaceAll('š', 's')
        .replaceAll('đ', 'd')
        .replaceAll('č', 'c')
        .replaceAll('ć', 'c')
        .replaceAll('ž', 'z');

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

  /// Get full address including city
  String get fullAddress {
    final parts = <String>[];

    final address = displayAddress;
    if (address.isNotEmpty) {
      parts.add(address);
    }

    if (grad != null && grad!.isNotEmpty) {
      parts.add(_capitalizeWords(grad!));
    }

    return parts.join(', ');
  }

  /// Get short address for UI lists
  String get shortAddress {
    if (displayAddress.length <= 25) {
      return displayAddress;
    }
    return '${displayAddress.substring(0, 22)}...';
  }

  /// Calculate walking time to another address (assumes 5 km/h walking speed)
  Duration? walkingTimeTo(Adresa other) {
    final distance = distanceTo(other);
    if (distance == null) return null;

    const walkingSpeedKmh = 5.0;
    final hours = distance / walkingSpeedKmh;
    return Duration(milliseconds: (hours * 3600 * 1000).round());
  }

  /// Check if two addresses are approximately the same location
  bool isNearby(Adresa other, {double radiusKm = 0.1}) {
    final distance = distanceTo(other);
    return distance != null && distance <= radiusKm;
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

  // ✅ UI HELPER METHODS

  /// Get icon for address type
  String get addressIcon {
    final lowerNaziv = naziv.toLowerCase();

    if (lowerNaziv.contains('bolnica')) return '🏥';
    if (lowerNaziv.contains('skola') || lowerNaziv.contains('škola')) {
      return '🏫';
    }
    if (lowerNaziv.contains('vrtic') || lowerNaziv.contains('vrtić')) {
      return '🏠';
    }
    if (lowerNaziv.contains('posta') || lowerNaziv.contains('pošta')) {
      return '📮';
    }
    if (lowerNaziv.contains('banka')) return '🏛️';
    if (lowerNaziv.contains('crkva')) return '⛪';
    if (lowerNaziv.contains('park')) return '🌳';
    if (lowerNaziv.contains('stadion')) return '🏟️';
    if (lowerNaziv.contains('market') || lowerNaziv.contains('prodavnica')) {
      return '🏪';
    }
    if (lowerNaziv.contains('restoran') || lowerNaziv.contains('kafic') || lowerNaziv.contains('kafić')) {
      return '🍽️';
    }

    return '📍'; // Default location icon
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
    dynamic koordinate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Adresa(
      id: id ?? this.id,
      naziv: naziv ?? this.naziv,
      ulica: ulica ?? this.ulica,
      broj: broj ?? this.broj,
      grad: grad ?? this.grad,
      koordinate: koordinate ?? this.koordinate,
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
      koordinate: createCoordinatesJsonb(latitude, longitude),
      updatedAt: DateTime.now(),
    );
  }

  /// Create a copy marking it as updated
  Adresa markAsUpdated() {
    return copyWith(updatedAt: DateTime.now());
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
