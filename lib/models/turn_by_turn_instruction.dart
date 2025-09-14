import 'package:geolocator/geolocator.dart';

/// 🧭 MODEL ZA TURN-BY-TURN INSTRUKCIJE
/// Predstavlja jednu instrukciju u navigaciji (skretanje, nastavi pravo, itd.)
class TurnByTurnInstruction {
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
  final List<String>? landmarks; // Orijentiri blizu instrukcije

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
      Map<String, dynamic> step, int index) {
    return TurnByTurnInstruction(
      index: index,
      text: step['instruction'] ?? 'Nastavi pravo',
      distance: (step['distance'] ?? 0.0).toDouble(),
      duration: (step['duration'] ?? 0.0).toDouble(),
      maneuver: step['maneuver']?['bearing_after']?.toDouble() ?? 0.0,
      coordinates: _parseCoordinatesFromStep(step),
      streetName: step['name'],
      type: _parseInstructionType(step['type'] ?? 0),
      speedLimit: step['speed_limit']?.toDouble(),
    );
  }

  /// Factory konstruktor iz Mapbox response
  factory TurnByTurnInstruction.fromMapbox(
      Map<String, dynamic> step, int index) {
    return TurnByTurnInstruction(
      index: index,
      text: step['maneuver']?['instruction'] ?? 'Nastavi pravo',
      distance: (step['distance'] ?? 0.0).toDouble(),
      duration: (step['duration'] ?? 0.0).toDouble(),
      maneuver: step['maneuver']?['bearing_after']?.toDouble() ?? 0.0,
      coordinates: _parseMapboxCoordinates(step),
      streetName: step['name'],
      type: _parseMapboxInstructionType(step['maneuver']?['type']),
    );
  }

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
      type: InstructionType.straight,
    );
  }

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
          .map((pos) => {
                'latitude': pos.latitude,
                'longitude': pos.longitude,
              })
          .toList(),
      'waypoint': waypoint,
      'streetName': streetName,
      'direction': direction,
      'type': type.toString(),
      'speedLimit': speedLimit,
      'landmarks': landmarks,
    };
  }

  /// JSON deserijalizacija
  factory TurnByTurnInstruction.fromJson(Map<String, dynamic> json) {
    return TurnByTurnInstruction(
      index: json['index'] ?? 0,
      text: json['text'] ?? '',
      distance: (json['distance'] ?? 0.0).toDouble(),
      duration: (json['duration'] ?? 0.0).toDouble(),
      maneuver: (json['maneuver'] ?? 0.0).toDouble(),
      coordinates: (json['coordinates'] as List?)
              ?.map((coord) => Position(
                    latitude: coord['latitude'],
                    longitude: coord['longitude'],
                    timestamp: DateTime.now(),
                    accuracy: 0,
                    altitude: 0,
                    altitudeAccuracy: 0,
                    heading: 0,
                    headingAccuracy: 0,
                    speed: 0,
                    speedAccuracy: 0,
                  ))
              .toList() ??
          [],
      waypoint: json['waypoint'],
      streetName: json['streetName'],
      direction: json['direction'],
      type: _parseInstructionTypeFromString(json['type']),
      speedLimit: json['speedLimit']?.toDouble(),
      landmarks: json['landmarks']?.cast<String>(),
    );
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
            .map((coord) => Position(
                  latitude: coord[1].toDouble(),
                  longitude: coord[0].toDouble(),
                  timestamp: DateTime.now(),
                  accuracy: 0,
                  altitude: 0,
                  altitudeAccuracy: 0,
                  heading: 0,
                  headingAccuracy: 0,
                  speed: 0,
                  speedAccuracy: 0,
                ))
            .toList();
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return [];
  }

  static List<Position> _parseMapboxCoordinates(Map<String, dynamic> step) {
    try {
      // Mapbox format
      if (step['geometry'] != null && step['geometry']['coordinates'] != null) {
        final coordinates = step['geometry']['coordinates'] as List;
        return coordinates
            .map((coord) => Position(
                  latitude: coord[1].toDouble(),
                  longitude: coord[0].toDouble(),
                  timestamp: DateTime.now(),
                  accuracy: 0,
                  altitude: 0,
                  altitudeAccuracy: 0,
                  heading: 0,
                  headingAccuracy: 0,
                  speed: 0,
                  speedAccuracy: 0,
                ))
            .toList();
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return [];
  }

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

  static InstructionType _parseMapboxInstructionType(String? type) {
    // Mapbox instruction types
    switch (type) {
      case 'turn-left':
        return InstructionType.turnLeft;
      case 'turn-right':
        return InstructionType.turnRight;
      case 'turn-sharp-left':
        return InstructionType.turnSharpLeft;
      case 'turn-sharp-right':
        return InstructionType.turnSharpRight;
      case 'turn-slight-left':
        return InstructionType.turnSlightLeft;
      case 'turn-slight-right':
        return InstructionType.turnSlightRight;
      case 'straight':
        return InstructionType.straight;
      case 'roundabout':
        return InstructionType.roundabout;
      case 'roundabout-exit':
        return InstructionType.exitRoundabout;
      case 'uturn':
        return InstructionType.uturn;
      case 'arrive':
        return InstructionType.arrive;
      case 'depart':
        return InstructionType.depart;
      case 'merge':
        return InstructionType.merge;
      case 'on-ramp':
        return InstructionType.rampRight;
      case 'off-ramp':
        return InstructionType.rampLeft;
      default:
        return InstructionType.straight;
    }
  }

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
