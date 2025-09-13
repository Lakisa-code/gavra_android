/// Simple location service as replacement for geolocator
/// This provides basic location functionality without external dependencies
import 'dart:math' as dart_math;

class Position {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double accuracy;
  final double speed;
  final double altitude;
  
  const Position({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy = 0.0,
    this.speed = 0.0,
    this.altitude = 0.0,
  });
  
  @override
  String toString() => 'Position(lat: $latitude, lng: $longitude)';
}

enum LocationPermission {
  denied,
  deniedForever,
  whileInUse,
  always,
}

enum LocationAccuracy {
  lowest,
  low,
  medium,
  high,
  best,
  bestForNavigation,
}

class LocationSettings {
  final LocationAccuracy accuracy;
  final int distanceFilter;
  
  const LocationSettings({
    this.accuracy = LocationAccuracy.best,
    this.distanceFilter = 0,
  });
}

class SimpleGeolocator {
  // Mock current position for Novi Sad (central location)
  static final Position _mockPosition = Position(
    latitude: 45.2671,
    longitude: 19.8335,
    timestamp: DateTime.now(),
    accuracy: 10.0,
    speed: 0.0,
    altitude: 84.0, // Novi Sad elevation
  );
  
  static Future<bool> isLocationServiceEnabled() async {
    // Always return true for now - this avoids permission dialogs
    return true;
  }
  
  static Future<LocationPermission> checkPermission() async {
    return LocationPermission.whileInUse;
  }
  
  static Future<LocationPermission> requestPermission() async {
    return LocationPermission.whileInUse;
  }
  
  static Future<Position> getCurrentPosition({
    LocationAccuracy? desiredAccuracy,
    bool? forceAndroidLocationManager,
    Duration? timeLimit,
  }) async {
    // Return mock position for Novi Sad
    return Position(
      latitude: _mockPosition.latitude,
      longitude: _mockPosition.longitude,
      timestamp: DateTime.now(),
      accuracy: 10.0,
      speed: 0.0,
      altitude: _mockPosition.altitude,
    );
  }
  
  static Stream<Position> getPositionStream({
    LocationSettings? locationSettings,
  }) {
    // Return a stream that emits the same position every 5 seconds
    return Stream.periodic(const Duration(seconds: 5), (count) {
      return Position(
        latitude: _mockPosition.latitude + (count * 0.0001), // Slight movement
        longitude: _mockPosition.longitude + (count * 0.0001),
        timestamp: DateTime.now(),
        accuracy: 10.0,
        speed: 0.0,
        altitude: _mockPosition.altitude,
      );
    });
  }
  
  static double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    // Haversine formula for distance calculation
    const double earthRadius = 6371000; // meters
    
    final double lat1Rad = startLatitude * (dart_math.pi / 180);
    final double lat2Rad = endLatitude * (dart_math.pi / 180);
    final double deltaLatRad = (endLatitude - startLatitude) * (dart_math.pi / 180);
    final double deltaLonRad = (endLongitude - startLongitude) * (dart_math.pi / 180);
    
    final double a = (dart_math.sin(deltaLatRad / 2) * dart_math.sin(deltaLatRad / 2)) +
        (dart_math.cos(lat1Rad) * dart_math.cos(lat2Rad) * 
         dart_math.sin(deltaLonRad / 2) * dart_math.sin(deltaLonRad / 2));
    
    final double c = 2 * dart_math.atan2(dart_math.sqrt(a), dart_math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  static double bearingBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    final double lat1Rad = startLatitude * (dart_math.pi / 180);
    final double lat2Rad = endLatitude * (dart_math.pi / 180);
    final double deltaLonRad = (endLongitude - startLongitude) * (dart_math.pi / 180);
    
    final double y = dart_math.sin(deltaLonRad) * dart_math.cos(lat2Rad);
    final double x = dart_math.cos(lat1Rad) * dart_math.sin(lat2Rad) - 
        dart_math.sin(lat1Rad) * dart_math.cos(lat2Rad) * dart_math.cos(deltaLonRad);
    
    final double bearing = dart_math.atan2(y, x);
    
    return (bearing * (180 / dart_math.pi) + 360) % 360;
  }
  
  static Future<void> openLocationSettings() async {
    // No-op for now
  }
}