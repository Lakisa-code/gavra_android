import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

/// Model za GPS lokacije vozila
class GPSLokacija {
  GPSLokacija({
    String? id,
    this.voziloId,
    this.vozacId,
    required this.latitude,
    required this.longitude,
    this.brzina,
    this.pravac,
    this.tacnost,
    DateTime? vreme,
  })  : id = id ?? const Uuid().v4(),
        vreme = vreme ?? DateTime.now();

  factory GPSLokacija.fromMap(Map<String, dynamic> map) {
    return GPSLokacija(
      id: map['id'] as String,
      voziloId: map['vozilo_id'] as String?,
      vozacId: map['vozac_id'] as String?,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      brzina: (map['brzina'] as num?)?.toDouble(),
      pravac: (map['pravac'] as num?)?.toDouble(),
      tacnost: (map['tacnost'] as num?)?.toDouble(),
      vreme: DateTime.parse(map['vreme'] as String),
    );
  }

  /// Kreira GPS lokaciju sa trenutnim vremenom
  factory GPSLokacija.sada({
    String? voziloId,
    String? vozacId,
    required double latitude,
    required double longitude,
    double? brzina,
    double? pravac,
    double? tacnost,
  }) {
    return GPSLokacija(
      voziloId: voziloId,
      vozacId: vozacId,
      latitude: latitude,
      longitude: longitude,
      brzina: brzina,
      pravac: pravac,
      tacnost: tacnost,
      vreme: DateTime.now(),
    );
  }
  final String id;
  final String? voziloId;
  final String? vozacId;
  final double latitude;
  final double longitude;
  final double? brzina;
  final double? pravac;
  final double? tacnost;
  final DateTime vreme;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vozilo_id': voziloId,
      'vozac_id': vozacId,
      'latitude': latitude,
      'longitude': longitude,
      'brzina': brzina,
      'pravac': pravac,
      'tacnost': tacnost,
      'vreme': vreme.toIso8601String(),
    };
  }

  /// Vraća distancu do druge lokacije u kilometrima
  double distanceTo(GPSLokacija other) {
    return Geolocator.distanceBetween(
          latitude,
          longitude,
          other.latitude,
          other.longitude,
        ) /
        1000;
  }

  /// Formatirana tacnost za prikaz
  String get displayTacnost {
    if (tacnost == null) return 'N/A';
    return '${tacnost!.toStringAsFixed(1)} m';
  }

  /// Da li je lokacija "sveža" (manja od 5 minuta)
  bool get isFresh => DateTime.now().difference(vreme).inMinutes < 5;

  /// Validira GPS koordinate
  bool get isValidCoordinates {
    return latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180;
  }

  /// Validira brzinu (realna vrednost)
  bool get isValidSpeed {
    return brzina == null || (brzina! >= 0 && brzina! <= 200);
  }

  /// Validira tacnost (realna vrednost)
  bool get isValidAccuracy {
    return tacnost == null || (tacnost! >= 0 && tacnost! <= 1000);
  }

  /// Formatirana brzina za prikaz
  String get displayBrzina {
    if (brzina == null) return 'N/A';
    return '${brzina!.toStringAsFixed(1)} km/h';
  }

  /// Formatiran pravac za prikaz
  String get displayPravac {
    if (pravac == null) return 'N/A';
    final directions = ['S', 'SI', 'I', 'JI', 'J', 'JZ', 'Z', 'SZ'];
    final index = ((pravac! + 22.5) % 360 / 45).floor();
    return '${directions[index]} (${pravac!.toStringAsFixed(0)}°)';
  }

  /// ToString metoda za debugging
  @override
  String toString() {
    return 'GPSLokacija{id: $id, vozilo: ${voziloId ?? 'null'}, vozac: $vozacId, '
        'lat: ${latitude.toStringAsFixed(6)}, lng: ${longitude.toStringAsFixed(6)}, '
        'tacnost: ${tacnost?.toStringAsFixed(1)}m, vreme: $vreme}';
  }
}
