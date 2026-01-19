import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/putnik.dart';

/// 🧭 HERE WEGO NAVIGATION SERVICE
/// Koristi ISKLJUČIVO HERE WeGo za navigaciju - OBAVEZNA INSTALACIJA
class HereWeGoNavigationService {
  // HERE WeGo konstante
  static const String appScheme = 'here.directions';
  static const String webScheme = 'https://share.here.com';
  static const int maxWaypoints = 10;

  /// 🚀 Pokreni navigaciju sa HERE WeGo
  static Future<HereWeGoNavResult> startNavigation({
    required BuildContext context,
    required List<Putnik> putnici,
    required Map<Putnik, Position> coordinates,
    Position? endDestination,
  }) async {
    try {
      // ⚠️ OBAVEZNA PROVERA - Mora biti instaliran HERE WeGo
      final isInstalled = await _isHereWeGoInstalled();
      if (!isInstalled) {
        return HereWeGoNavResult.error('❌ HERE WeGo nije instaliran. Instalirajte aplikaciju za navigaciju.');
      }

      // FILTRIRAJ PUTNIKE SA VALIDNIM KOORDINATAMA
      final validPutnici = putnici.where((p) => coordinates.containsKey(p)).toList();

      if (validPutnici.isEmpty) {
        return HereWeGoNavResult.error('Nema putnika sa validnim koordinatama');
      }

      // SEGMENTACIJA AKO IMA VIŠE OD 10 PUTNIKA
      if (validPutnici.length <= maxWaypoints) {
        return await _launchNavigation(
          putnici: validPutnici,
          coordinates: coordinates,
          endDestination: endDestination,
        );
      } else {
        if (!context.mounted) {
          return HereWeGoNavResult.error('Context nije više aktivan');
        }
        return await _launchSegmentedNavigation(
          context: context,
          putnici: validPutnici,
          coordinates: coordinates,
          endDestination: endDestination,
        );
      }
    } catch (e) {
      return HereWeGoNavResult.error('Greška: $e');
    }
  }

  /// 🔍 Proveri da li je HERE WeGo instaliran
  static Future<bool> _isHereWeGoInstalled() async {
    try {
      final appUri = Uri.parse('$appScheme://test');
      return await canLaunchUrl(appUri);
    } catch (_) {
      return false;
    }
  }

  /// 🚀 Gradi HERE WeGo URL za navigaciju
  static String _buildUrl(List<Position> waypoints, Position destination) {
    final StringBuffer url = StringBuffer();

    // Koristimo web share URL koji uvek radi (otvara web ili app ako je instaliran)
    url.write('$webScheme/r/');

    for (int i = 0; i < waypoints.length; i++) {
      final wp = waypoints[i];
      url.write('${wp.latitude},${wp.longitude},Putnik${i + 1}/');
    }

    url.write('${destination.latitude},${destination.longitude},Destinacija');
    url.write('?m=d'); // m=d = driving mode

    return url.toString();
  }

  /// 🚀 Pokreni HERE WeGo navigaciju
  static Future<HereWeGoNavResult> _launchNavigation({
    required List<Putnik> putnici,
    required Map<Putnik, Position> coordinates,
    Position? endDestination,
  }) async {
    final validPutnici = putnici.where((p) => coordinates.containsKey(p)).toList();

    if (validPutnici.isEmpty) {
      return HereWeGoNavResult.error('Nema putnika sa validnim koordinatama');
    }

    final List<Position> waypoints;
    final Position dest;

    if (endDestination != null) {
      waypoints = validPutnici.map((p) => coordinates[p]!).toList();
      dest = endDestination;
    } else {
      waypoints = validPutnici.take(validPutnici.length - 1).map((p) => coordinates[p]!).toList();
      dest = coordinates[validPutnici.last]!;
    }

    final url = _buildUrl(waypoints, dest);
    final uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (success) {
          return HereWeGoNavResult.success(
            message: '🗺️ HERE WeGo: ${putnici.length} putnika',
            launchedPutnici: putnici,
            remainingPutnici: [],
          );
        }
      }
      return HereWeGoNavResult.error('Greška pri otvaranju HERE WeGo');
    } catch (e) {
      return HereWeGoNavResult.error('Greška: $e');
    }
  }

  /// 🔀 Segmentirana navigacija (više od 10 putnika)
  static Future<HereWeGoNavResult> _launchSegmentedNavigation({
    required BuildContext context,
    required List<Putnik> putnici,
    required Map<Putnik, Position> coordinates,
    Position? endDestination,
  }) async {
    final segments = <List<Putnik>>[];
    for (var i = 0; i < putnici.length; i += maxWaypoints) {
      final end = (i + maxWaypoints > putnici.length) ? putnici.length : i + maxWaypoints;
      segments.add(putnici.sublist(i, end));
    }

    final launchedPutnici = <Putnik>[];
    var currentSegment = 0;

    while (currentSegment < segments.length) {
      final segment = segments[currentSegment];

      Position? segmentDestination;
      if (currentSegment == segments.length - 1 && endDestination != null) {
        segmentDestination = endDestination;
      }

      final result = await _launchNavigation(
        putnici: segment,
        coordinates: coordinates,
        endDestination: segmentDestination,
      );

      if (!result.success) {
        return HereWeGoNavResult.partial(
          message: 'Greška pri segmentu ${currentSegment + 1}',
          launchedPutnici: launchedPutnici,
          remainingPutnici: segments.skip(currentSegment).expand((s) => s).toList(),
        );
      }

      launchedPutnici.addAll(segment);
      currentSegment++;

      if (currentSegment < segments.length) {
        final remainingCount = segments.skip(currentSegment).fold<int>(0, (sum, s) => sum + s.length);

        if (!context.mounted) break;

        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Segment ${currentSegment}/${segments.length} završen'),
            content: Text(
              'Pokupljeno: ${launchedPutnici.length} putnika\n'
              'Preostalo: $remainingCount putnika\n\n'
              'Nastaviti sa sledećim segmentom?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Završi')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Nastavi')),
            ],
          ),
        );

        if (shouldContinue != true) {
          return HereWeGoNavResult.partial(
            message: 'Navigacija završena posle segmenta $currentSegment',
            launchedPutnici: launchedPutnici,
            remainingPutnici: segments.skip(currentSegment).expand((s) => s).toList(),
          );
        }
      }
    }

    return HereWeGoNavResult.success(
      message: '✅ HERE WeGo: svih ${launchedPutnici.length} putnika',
      launchedPutnici: launchedPutnici,
      remainingPutnici: [],
    );
  }

  /// 📊 Proveri status navigacije
  static Future<NavigationStatus> checkNavigationStatus() async {
    return const NavigationStatus(
      isHuaweiDevice: false,
      isHereWeGoInstalled: true, // Web scheme uvek radi
    );
  }
}

/// 📊 Rezultat HERE WeGo navigacije
class HereWeGoNavResult {
  HereWeGoNavResult._({
    required this.success,
    required this.message,
    this.launchedPutnici,
    this.remainingPutnici,
    this.isPartial = false,
  });

  factory HereWeGoNavResult.success({
    required String message,
    required List<Putnik> launchedPutnici,
    required List<Putnik> remainingPutnici,
  }) =>
      HereWeGoNavResult._(
        success: true,
        message: message,
        launchedPutnici: launchedPutnici,
        remainingPutnici: remainingPutnici,
      );

  factory HereWeGoNavResult.partial({
    required String message,
    required List<Putnik> launchedPutnici,
    required List<Putnik> remainingPutnici,
  }) =>
      HereWeGoNavResult._(
        success: true,
        message: message,
        launchedPutnici: launchedPutnici,
        remainingPutnici: remainingPutnici,
        isPartial: true,
      );

  factory HereWeGoNavResult.error(String message) => HereWeGoNavResult._(success: false, message: message);

  final bool success;
  final String message;
  final List<Putnik>? launchedPutnici;
  final List<Putnik>? remainingPutnici;
  final bool isPartial;

  bool get hasRemaining => remainingPutnici?.isNotEmpty ?? false;
  int get launchedCount => launchedPutnici?.length ?? 0;
  int get remainingCount => remainingPutnici?.length ?? 0;
}

/// 📊 Status navigacije na uređaju
class NavigationStatus {
  const NavigationStatus({required this.isHuaweiDevice, required this.isHereWeGoInstalled});

  final bool isHuaweiDevice;
  final bool isHereWeGoInstalled;

  bool get hasNavigationApp => isHereWeGoInstalled;

  @override
  String toString() => 'NavigationStatus(isHuawei: $isHuaweiDevice, hereWeGo: $isHereWeGoInstalled)';
}
