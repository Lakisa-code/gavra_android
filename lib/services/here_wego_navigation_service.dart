import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/putnik.dart';
import '../utils/device_utils.dart';

/// 🧭 HERE WEGO NAVIGATION SERVICE
/// Koristi ISKLJUČIVO HERE WeGo za navigaciju - konzistentno ponašanje,
/// poštuje redosled waypointa, radi na svim uređajima (GMS i HMS)
class HereWeGoNavigationService {
  // HERE WeGo konstante
  static const String packageName = 'com.here.app.maps';
  static const String urlScheme = 'here-route';
  static const int maxWaypoints = 10;
  static const String _playStoreUrl = 'market://details?id=com.here.app.maps';
  static const String _appGalleryUrl = 'appmarket://details?id=com.here.app.maps';

  /// 🚀 Pokreni navigaciju sa HERE WeGo
  static Future<HereWeGoNavResult> startNavigation({
    required BuildContext context,
    required List<Putnik> putnici,
    required Map<Putnik, Position> coordinates,
    Position? endDestination,
  }) async {
    try {
      // 1. PROVERI DA LI JE HERE WEGO INSTALIRAN
      final isInstalled = await isHereWeGoInstalled();

      if (!isInstalled) {
        if (context.mounted) {
          await _showInstallDialog(context);
        }
        return HereWeGoNavResult.error('HERE WeGo nije instaliran');
      }

      // 2. FILTRIRAJ PUTNIKE SA VALIDNIM KOORDINATAMA
      final validPutnici = putnici.where((p) => coordinates.containsKey(p)).toList();

      if (validPutnici.isEmpty) {
        return HereWeGoNavResult.error('Nema putnika sa validnim koordinatama');
      }

      // 3. SEGMENTACIJA AKO IMA VIŠE OD 10 PUTNIKA
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
  static Future<bool> isHereWeGoInstalled() async {
    try {
      final testUri = Uri.parse('$urlScheme://test');
      return await canLaunchUrl(testUri);
    } catch (_) {
      return false;
    }
  }

  /// 📲 Prikaži dijalog za instalaciju HERE WeGo
  static Future<void> _showInstallDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.navigation, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('HERE WeGo'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Za navigaciju je potreban HERE WeGo.', style: TextStyle(fontSize: 16)),
            SizedBox(height: 16),
            Text(
              '✅ Besplatan\n✅ Offline mape\n✅ Radi na svim telefonima\n✅ Prati redosled putnika',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kasnije')),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _openPlayStore();
            },
            icon: const Icon(Icons.download),
            label: const Text('Instaliraj'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  /// 🏪 Otvori Store za HERE WeGo
  static Future<void> _openPlayStore() async {
    final isHuawei = await DeviceUtils.isHuaweiDevice();

    if (isHuawei) {
      try {
        final appGalleryUri = Uri.parse(_appGalleryUrl);
        final launched = await launchUrl(appGalleryUri, mode: LaunchMode.externalApplication);
        if (launched) return;
      } catch (_) {}

      try {
        final webUri = Uri.parse('https://appgallery.huawei.com/app/C101397073');
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        return;
      } catch (_) {}
    }

    try {
      final uri = Uri.parse(_playStoreUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      final webUri = Uri.parse('https://play.google.com/store/apps/details?id=com.here.app.maps');
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  /// 🚀 Gradi HERE WeGo URL za navigaciju
  static String _buildUrl(List<Position> waypoints, Position destination) {
    final StringBuffer url = StringBuffer();
    url.write('here-route://');

    for (int i = 0; i < waypoints.length; i++) {
      final wp = waypoints[i];
      url.write('${wp.latitude},${wp.longitude},Putnik${i + 1}/');
    }

    url.write('${destination.latitude},${destination.longitude},Destinacija');
    url.write('?m=d');

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
    final isInstalled = await isHereWeGoInstalled();
    return NavigationStatus(
      isHuaweiDevice: await DeviceUtils.isHuaweiDevice(),
      isHereWeGoInstalled: isInstalled,
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
