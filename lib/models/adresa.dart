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
      koordinate: map['koordinate'] as String?, // PostgreSQL POINT as string
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.now(),
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
    DateTime? updatedAt,
  }) {
    return Adresa(
      id: id,
      ulica: ulica,
      broj: broj,
      grad: grad,
      postanskiBroj: postanskiBroj,
      koordinate: createPointString(latitude, longitude),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
  final String id;
  final String ulica;
  final String? broj;
  final String grad;
  final String? postanskiBroj;
  final String? koordinate; // PostgreSQL POINT kao string "(lat,lng)"
  final DateTime createdAt;
  final DateTime updatedAt;

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

  bool get hasCompleteAddress =>
      isValidAddress && broj != null && broj!.isNotEmpty;

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
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.pow(math.sin(dLon / 2), 2);

    final double c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  // ✅ COMPREHENSIVE VALIDATION METHODS

  /// Validate street name format and content
  bool get isValidUlica {
    if (ulica.trim().isEmpty) return false;
    if (ulica.trim().length < 2) return false;

    // Basic character validation for Serbian addresses
    final validPattern = RegExp(r'^[a-žA-Ž0-9\s.,\-/()]+$', unicode: true);
    if (!validPattern.hasMatch(ulica.trim())) return false;

    // Check for minimum meaningful content
    final cleanStreet = ulica.trim().replaceAll(RegExp(r'\s+'), ' ');
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
    if (grad.trim().isEmpty) return false;

    final normalizedGrad = grad
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

    return allowedCities.any((city) =>
        normalizedGrad.contains(city) || city.contains(normalizedGrad));
  }

  /// Validate postal code format (Serbian postal codes)
  bool get isValidPostanskiBroj {
    if (postanskiBroj == null || postanskiBroj!.trim().isEmpty)
      return true; // Optional

    // Serbian postal codes: 5-digit format
    final postalPattern = RegExp(r'^[0-9]{5}$');
    return postalPattern.hasMatch(postanskiBroj!.trim());
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
    return isValidUlica &&
        isValidBroj &&
        isValidGrad &&
        isValidPostanskiBroj &&
        isInServiceArea;
  }

  /// Get validation error messages
  List<String> get validationErrors {
    final errors = <String>[];

    if (!isValidUlica) {
      errors.add(
          'Naziv ulice nije valjan (minimum 2 karaktera, dozvoljeni karakteri)');
    }
    if (!isValidBroj) {
      errors.add('Broj nije valjan (format: 1, 12a, 5/3, 15-17)');
    }
    if (!isValidGrad) {
      errors
          .add('Grad nije valjan (dozvoljeni samo Bela Crkva i Vršac opštine)');
    }
    if (!isValidPostanskiBroj) {
      errors.add('Poštanski broj nije valjan (format: 12345)');
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

    if (isValidUlica) {
      parts.add(_capitalizeWords(ulica));
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

    if (isValidGrad) {
      parts.add(_capitalizeWords(grad));
    }

    if (isValidPostanskiBroj) {
      parts.add(postanskiBroj!);
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
    final normalizedGrad = grad
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

    final belongsToBelaCrkva = belaCrkvaSettlements.any((settlement) =>
        normalizedGrad.contains(settlement) ||
        settlement.contains(normalizedGrad));

    if (belongsToBelaCrkva) return 'Bela Crkva';
    return 'Vršac'; // Default for all other valid addresses
  }

  // ✅ UI HELPER METHODS

  /// Get icon for address type
  String get addressIcon {
    final lowerUlica = ulica.toLowerCase();

    if (lowerUlica.contains('bolnica')) return '🏥';
    if (lowerUlica.contains('skola') || lowerUlica.contains('škola'))
      return '🏫';
    if (lowerUlica.contains('vrtic') || lowerUlica.contains('vrtić'))
      return '🏠';
    if (lowerUlica.contains('posta') || lowerUlica.contains('pošta'))
      return '📮';
    if (lowerUlica.contains('banka')) return '🏛️';
    if (lowerUlica.contains('crkva')) return '⛪';
    if (lowerUlica.contains('park')) return '🌳';
    if (lowerUlica.contains('stadion')) return '🏟️';
    if (lowerUlica.contains('market') || lowerUlica.contains('prodavnica'))
      return '🏪';
    if (lowerUlica.contains('restoran') ||
        lowerUlica.contains('kafic') ||
        lowerUlica.contains('kafić')) return '🍽️';

    return '📍'; // Default location icon
  }

  /// Get priority score for sorting (important locations first)
  int get priorityScore {
    final lowerUlica = ulica.toLowerCase();

    if (lowerUlica.contains('bolnica')) return 100;
    if (lowerUlica.contains('skola') || lowerUlica.contains('škola')) return 90;
    if (lowerUlica.contains('ambulanta')) return 85;
    if (lowerUlica.contains('posta') || lowerUlica.contains('pošta')) return 80;
    if (lowerUlica.contains('vrtic') || lowerUlica.contains('vrtić')) return 75;
    if (lowerUlica.contains('banka')) return 70;
    if (lowerUlica.contains('centar')) return 65;
    if (lowerUlica.contains('trg')) return 60;
    if (lowerUlica.contains('glavna')) return 55;

    return 0; // Regular residential addresses
  }

  // ✅ COPY AND MODIFICATION METHODS

  /// Create a copy with updated fields
  Adresa copyWith({
    String? id,
    String? ulica,
    String? broj,
    String? grad,
    String? postanskiBroj,
    String? koordinate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Adresa(
      id: id ?? this.id,
      ulica: ulica ?? this.ulica,
      broj: broj ?? this.broj,
      grad: grad ?? this.grad,
      postanskiBroj: postanskiBroj ?? this.postanskiBroj,
      koordinate: koordinate ?? this.koordinate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Create a copy with normalized text fields
  Adresa normalize() {
    return copyWith(
      ulica: _capitalizeWords(ulica.trim()),
      broj: broj?.trim(),
      grad: _capitalizeWords(grad.trim()),
      postanskiBroj: postanskiBroj?.trim(),
    );
  }

  /// Create a copy with updated coordinates
  Adresa withCoordinates(double latitude, double longitude) {
    return copyWith(
      koordinate: createPointString(latitude, longitude),
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
          (word) => word.isNotEmpty
              ? word[0].toUpperCase() + word.substring(1).toLowerCase()
              : word,
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
