import 'package:geolocator/geolocator.dart';
import '../models/putnik.dart';

/// 📊 Model za realtime podatke o ruti
class RealtimeRouteData {
  RealtimeRouteData({
    required this.currentPosition,
    required this.currentRoute,
    required this.optimalRoute,
    required this.isTrackingActive,
    required this.driverId,
    required this.timestamp,
    this.currentSpeed,
    this.estimatedTimeToNextDestination,
  }) : remainingPassengers = currentRoute
            .where((p) => p.vremePokupljenja == null && p.status != 'otkazan')
            .length;
  final Position currentPosition;
  final List<Putnik> currentRoute;
  final String? optimalRoute;
  final bool isTrackingActive;
  final String driverId;
  final DateTime timestamp;

  // Dodatni podaci za brzinu kretanja
  final double? currentSpeed;
  final double? estimatedTimeToNextDestination;
  final int remainingPassengers;

  /// 📍 Dobij sledeću destinaciju
  Putnik? get nextDestination {
    try {
      return currentRoute.firstWhere(
        (p) => p.vremePokupljenja == null && p.status != 'otkazan',
      );
    } catch (e) {
      return null;
    }
  }

  /// 📊 Procenti završetka rute
  double get routeCompletionPercentage {
    if (currentRoute.isEmpty) return 100.0;

    final pickedUp =
        currentRoute.where((p) => p.vremePokupljenja != null).length;
    return (pickedUp / currentRoute.length) * 100;
  }

  /// ⏱️ Formatovano vreme poslednjeg ažuriranja
  String get formattedTimestamp {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }

  /// 🗺️ Da li je vozač u pokretu
  bool get isMoving {
    return currentSpeed != null && currentSpeed! > 5; // preko 5 km/h
  }
}

/// 🚦 Model za saobraćajne alertе
class TrafficAlert {
  TrafficAlert({
    required this.message,
    required this.severity,
    this.affectedRoute,
    required this.delayMinutes,
    required this.timestamp,
  });
  final String message;
  final String severity; // 'low', 'medium', 'high'
  final String? affectedRoute;
  final int delayMinutes;
  final DateTime timestamp;

  /// 🎨 Boja na osnovu ozbiljnosti
  String get severityColor {
    switch (severity) {
      case 'high':
        return '#F44336'; // Crvena
      case 'medium':
        return '#FF9800'; // Narandžasta
      case 'low':
      default:
        return '#FFC107'; // Žuta
    }
  }

  /// 🚨 Ikona na osnovu ozbiljnosti
  String get severityIcon {
    switch (severity) {
      case 'high':
        return '🚨';
      case 'medium':
        return '⚠️';
      case 'low':
      default:
        return '🚦';
    }
  }
}




