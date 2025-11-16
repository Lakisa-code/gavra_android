import 'package:geolocator/geolocator.dart';

/// 🧭 MODEL ZA TURN-BY-TURN INSTRUKCIJE
/// Predstavlja jednu instrukciju u navigaciji (skretanje, nastavi pravo, itd.)
class TurnByTurnInstruction {
  // Orijentiri blizu instrukcije

  /// Glavni konstruktor
  const TurnByTurnInstruction({
    required this.index,
    required this.text,
    required this.distance,
    required this.duration,
    required this.maneuver,
    required this.coordinates,
    this.waypoint,
    this.streetName,
    this.direction,
    this.type = InstructionType.straight,
    this.speedLimit,
    this.landmarks,
  });

  /// Factory konstruktor iz OpenRouteService response
  factory TurnByTurnInstruction.fromOpenRoute(
    Map<String, dynamic> step,
    int index,
  ) {
    return TurnByTurnInstruction(
      index: index,
      text: (step['instruction'] as String?) ?? 'Nastavi pravo',
      distance: (step['distance'] as num?)?.toDouble() ?? 0.0,
      duration: (step['duration'] as num?)?.toDouble() ?? 0.0,
      maneuver: (step['maneuver']?['bearing_after'] as num?)?.toDouble() ?? 0.0,
      coordinates: _parseCoordinatesFromStep(step),
      streetName: step['name'] as String?,
      type: _parseInstructionType((step['type'] as int?) ?? 0),
      speedLimit: (step['speed_limit'] as num?)?.toDouble(),
    );
  }

  // Mapbox factory removed - use OpenRoute/OSRM formats only

  /// Kreira jednostavnu instrukciju za fallback
  factory TurnByTurnInstruction.simple({
    required int index,
    required String text,
    required Position startCoord,
    required Position endCoord,
  }) {
    final distance = Geolocator.distanceBetween(
      startCoord.latitude,
      startCoord.longitude,
      endCoord.latitude,
      endCoord.longitude,
    );

    final bearing = Geolocator.bearingBetween(
      startCoord.latitude,
      startCoord.longitude,
      endCoord.latitude,
      endCoord.longitude,
    );

    return TurnByTurnInstruction(
      index: index,
      text: text,
      distance: distance,
      duration: distance / 13.89, // ~50 km/h prosečna brzina u gradu
      maneuver: bearing,
      coordinates: [startCoord, endCoord],
    );
  }

  /// JSON deserijalizacija
  factory TurnByTurnInstruction.fromJson(Map<String, dynamic> json) {
    return TurnByTurnInstruction(
      index: (json['index'] as int?) ?? 0,
      text: (json['text'] as String?) ?? '',
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      maneuver: (json['maneuver'] as num?)?.toDouble() ?? 0.0,
      coordinates: (json['coordinates'] as List?)
              ?.map(
                (coord) => Position(
                  latitude: (coord['latitude'] as num).toDouble(),
                  longitude: (coord['longitude'] as num).toDouble(),
                  timestamp: DateTime.now(),
                  accuracy: 0,
                  altitude: 0,
                  altitudeAccuracy: 0,
                  heading: 0,
                  headingAccuracy: 0,
                  speed: 0,
                  speedAccuracy: 0,
                ),
              )
              .toList() ??
          [],
      waypoint: json['waypoint'] as String?,
      streetName: json['streetName'] as String?,
      direction: json['direction'] as String?,
      type: _parseInstructionTypeFromString(json['type'] as String?),
      speedLimit: (json['speedLimit'] as num?)?.toDouble(),
      landmarks: (json['landmarks'] as List?)?.cast<String>(),
    );
  }
  final int index; // Redni broj instrukcije
  final String text; // Tekst instrukcije (npr. "Skreni levo na Glavnu ulicu")
  final double distance; // Rastojanje do sledeće instrukcije (u metrima)
  final double duration; // Vreme do sledeće instrukcije (u sekundama)
  final double maneuver; // Ugao skretanja (u stepenima)
  final List<Position> coordinates; // Koordinate za ovaj segment rute
  final String? waypoint; // Ime putnika/destinacije (ako je relevantno)
  final String? streetName; // Ime ulice
  final String? direction; // Smer (north, south, east, west)
  final InstructionType type; // Tip instrukcije
  final double? speedLimit; // Ograničenje brzine (km/h)
  final List<String>? landmarks;

  /// Formatiran prikaz distancije
  String get formattedDistance {
    if (distance < 1000) {
      return '${distance.toInt()} m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
  }

  /// Formatiran prikaz vremena
  String get formattedDuration {
    final minutes = (duration / 60).floor();
    final seconds = (duration % 60).floor();

    if (minutes > 0) {
      return '$minutes min ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// Ikona za tip instrukcije
  String get iconName {
    switch (type) {
      case InstructionType.turnLeft:
        return 'turn_left';
      case InstructionType.turnRight:
        return 'turn_right';
      case InstructionType.turnSharpLeft:
        return 'turn_sharp_left';
      case InstructionType.turnSharpRight:
        return 'turn_sharp_right';
      case InstructionType.turnSlightLeft:
        return 'turn_slight_left';
      case InstructionType.turnSlightRight:
        return 'turn_slight_right';
      case InstructionType.straight:
        return 'straight';
      case InstructionType.uturn:
        return 'u_turn';
      case InstructionType.roundabout:
        return 'roundabout';
      case InstructionType.exitRoundabout:
        return 'exit_roundabout';
      case InstructionType.arrive:
        return 'arrive';
      case InstructionType.depart:
        return 'depart';
      case InstructionType.merge:
        return 'merge';
      case InstructionType.rampLeft:
        return 'ramp_left';
      case InstructionType.rampRight:
        return 'ramp_right';
    }
  }

  /// Da li je ovo instrukcija za skretanje
  bool get isTurn {
    return [
      InstructionType.turnLeft,
      InstructionType.turnRight,
      InstructionType.turnSharpLeft,
      InstructionType.turnSharpRight,
      InstructionType.turnSlightLeft,
      InstructionType.turnSlightRight,
      InstructionType.uturn,
    ].contains(type);
  }

  /// Da li je ovo instrukcija za destinaciju
  bool get isDestination {
    return type == InstructionType.arrive;
  }

  /// JSON serijalizacija
  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'text': text,
      'distance': distance,
      'duration': duration,
      'maneuver': maneuver,
      'coordinates': coordinates
          .map(
            (pos) => {
              'latitude': pos.latitude,
              'longitude': pos.longitude,
            },
          )
          .toList(),
      'waypoint': waypoint,
      'streetName': streetName,
      'direction': direction,
      'type': type.toString(),
      'speedLimit': speedLimit,
      'landmarks': landmarks,
    };
  }

  @override
  String toString() {
    return 'TurnByTurnInstruction(index: $index, text: "$text", distance: $formattedDistance, duration: $formattedDuration)';
  }

  // === HELPER FUNKCIJE ===

  static List<Position> _parseCoordinatesFromStep(Map<String, dynamic> step) {
    try {
      // OpenRouteService format
      if (step['geometry'] != null) {
        final coordinates = step['geometry']['coordinates'] as List;
        return coordinates
            .map(
              (coord) => Position(
                latitude: (coord[1] as num).toDouble(),
                longitude: (coord[0] as num).toDouble(),
                timestamp: DateTime.now(),
                accuracy: 0,
                altitude: 0,
                altitudeAccuracy: 0,
                heading: 0,
                headingAccuracy: 0,
                speed: 0,
                speedAccuracy: 0,
              ),
            )
            .toList();
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return [];
  }

  // Mapbox parsing removed

  static InstructionType _parseInstructionType(int type) {
    // OpenRouteService instruction types
    switch (type) {
      case 0:
        return InstructionType.turnLeft;
      case 1:
        return InstructionType.turnRight;
      case 2:
        return InstructionType.turnSharpLeft;
      case 3:
        return InstructionType.turnSharpRight;
      case 4:
        return InstructionType.turnSlightLeft;
      case 5:
        return InstructionType.turnSlightRight;
      case 6:
        return InstructionType.straight;
      case 7:
        return InstructionType.roundabout;
      case 8:
        return InstructionType.exitRoundabout;
      case 9:
        return InstructionType.uturn;
      case 10:
        return InstructionType.arrive;
      case 11:
        return InstructionType.depart;
      default:
        return InstructionType.straight;
    }
  }

  // Mapbox instruction type parsing removed.

  static InstructionType _parseInstructionTypeFromString(String? typeString) {
    if (typeString == null) return InstructionType.straight;

    final parts = typeString.split('.');
    final typeName = parts.length > 1 ? parts[1] : typeString;

    switch (typeName) {
      case 'turnLeft':
        return InstructionType.turnLeft;
      case 'turnRight':
        return InstructionType.turnRight;
      case 'turnSharpLeft':
        return InstructionType.turnSharpLeft;
      case 'turnSharpRight':
        return InstructionType.turnSharpRight;
      case 'turnSlightLeft':
        return InstructionType.turnSlightLeft;
      case 'turnSlightRight':
        return InstructionType.turnSlightRight;
      case 'straight':
        return InstructionType.straight;
      case 'roundabout':
        return InstructionType.roundabout;
      case 'exitRoundabout':
        return InstructionType.exitRoundabout;
      case 'uturn':
        return InstructionType.uturn;
      case 'arrive':
        return InstructionType.arrive;
      case 'depart':
        return InstructionType.depart;
      case 'merge':
        return InstructionType.merge;
      case 'rampLeft':
        return InstructionType.rampLeft;
      case 'rampRight':
        return InstructionType.rampRight;
      default:
        return InstructionType.straight;
    }
  }
}

/// 🚦 TIPOVI INSTRUKCIJA ZA NAVIGACIJU
enum InstructionType {
  turnLeft, // Skreni levo
  turnRight, // Skreni desno
  turnSharpLeft, // Oštro skreni levo
  turnSharpRight, // Oštro skreni desno
  turnSlightLeft, // Blago skreni levo
  turnSlightRight, // Blago skreni desno
  straight, // Nastavi pravo
  uturn, // Polukrug
  roundabout, // Uđi u kružni tok
  exitRoundabout, // Izađi iz kružnog toka
  arrive, // Stigao si na destinaciju
  depart, // Kreni sa lokacije
  merge, // Uklopiti se u saobraćaj
  rampLeft, // Rampa levo (autocesta)
  rampRight, // Rampa desno (autocesta)
}

/// 🗺️ EKSTENZIJE ZA LAKŠE RUKOVANJE
extension InstructionTypeExtension on InstructionType {
  String get displayName {
    switch (this) {
      case InstructionType.turnLeft:
        return 'Skreni levo';
      case InstructionType.turnRight:
        return 'Skreni desno';
      case InstructionType.turnSharpLeft:
        return 'Oštro levo';
      case InstructionType.turnSharpRight:
        return 'Oštro desno';
      case InstructionType.turnSlightLeft:
        return 'Blago levo';
      case InstructionType.turnSlightRight:
        return 'Blago desno';
      case InstructionType.straight:
        return 'Nastavi pravo';
      case InstructionType.uturn:
        return 'Polukrug';
      case InstructionType.roundabout:
        return 'Kružni tok';
      case InstructionType.exitRoundabout:
        return 'Izlaz iz kružnog';
      case InstructionType.arrive:
        return 'Destinacija';
      case InstructionType.depart:
        return 'Pokreni se';
      case InstructionType.merge:
        return 'Uklopi se';
      case InstructionType.rampLeft:
        return 'Rampa levo';
      case InstructionType.rampRight:
        return 'Rampa desno';
    }
  }
}
