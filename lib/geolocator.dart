// Geolocator compatibility shim
// This file provides geolocator-compatible exports using our simple location service

import 'services/simple_location_service.dart';

// Re-export all the types
export 'services/simple_location_service.dart' show 
  Position, 
  LocationPermission, 
  LocationAccuracy, 
  LocationSettings;

class Geolocator {
  static Future<bool> isLocationServiceEnabled() => 
    SimpleGeolocator.isLocationServiceEnabled();
    
  static Future<LocationPermission> checkPermission() => 
    SimpleGeolocator.checkPermission();
    
  static Future<LocationPermission> requestPermission() => 
    SimpleGeolocator.requestPermission();
    
  static Future<Position> getCurrentPosition({
    LocationAccuracy? desiredAccuracy,
    bool? forceAndroidLocationManager,
    Duration? timeLimit,
  }) => SimpleGeolocator.getCurrentPosition(
    desiredAccuracy: desiredAccuracy,
    forceAndroidLocationManager: forceAndroidLocationManager,
    timeLimit: timeLimit,
  );
  
  static Stream<Position> getPositionStream({
    LocationSettings? locationSettings,
  }) => SimpleGeolocator.getPositionStream(
    locationSettings: locationSettings,
  );
  
  static double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) => SimpleGeolocator.distanceBetween(
    startLatitude,
    startLongitude,
    endLatitude,
    endLongitude,
  );
  
  static double bearingBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) => SimpleGeolocator.bearingBetween(
    startLatitude,
    startLongitude,
    endLatitude,
    endLongitude,
  );
  
  static Future<void> openLocationSettings() => 
    SimpleGeolocator.openLocationSettings();
}