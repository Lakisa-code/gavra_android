import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/putnik.dart';
import '../utils/device_utils.dart';
import '../utils/navigation_provider.dart';
import '../utils/navigation_url_builder.dart';

/// 🧭 HERE WEGO NAVIGATION SERVICE
/// Koristi ISKLJUČIVO HERE WeGo za navigaciju - konzistentno ponašanje,
/// poštuje redosled waypointa, radi na svim uređajima (GMS i HMS)
///
/// HERE WeGo prednosti:
/// - Besplatan
/// - Offline mape
/// - Poštuje redosled waypointa (ne pravi se pametan kao Google)
/// - Radi na Huawei bez Google servisa
class MultiProviderNavigationService {
  static const _playStoreUrl = 'market://details?id=com.here.app.maps';
  static const _appGalleryUrl = 'appmarket://details?id=com.here.app.maps';
  // HERE WeGo limit: 9 waypoints + 1 destinacija = 10 tačaka
  // Koristimo 8 da ostavimo prostora za destinaciju
  static const _maxWaypoints = 8;

  /// 🚀 Pokreni navigaciju sa HERE WeGo
  static Future<MultiNavResult> startNavigation({
    required BuildContext context,
    required List<Putnik> putnici,
    required Map<Putnik, Position> coordinates,
    Position? endDestination,
    NavigationProvider? preferredProvider, // Ignorisano - uvek HERE WeGo
  }) async {
    try {
      // 1. PROVERI DA LI JE HERE WEGO INSTALIRAN
      final isInstalled = await _isHereWeGoInstalled();

      if (!isInstalled) {
        // Prikaži user-friendly poruku za instalaciju
        if (context.mounted) {
          await _showInstallDialog(context);
        }
        return MultiNavResult.error('HERE WeGo nije instaliran');
      }
      // 2. FILTRIRAJ PUTNIKE SA VALIDNIM KOORDINATAMA
      final validPutnici = putnici.where((p) => coordinates.containsKey(p)).toList();

      if (validPutnici.isEmpty) {
        return MultiNavResult.error('Nema putnika sa validnim koordinatama');
      }

      // 3. SEGMENTACIJA AKO IMA VIŠE OD 10 PUTNIKA
      if (validPutnici.length <= _maxWaypoints) {
        // Jednostavna navigacija - svi putnici odjednom
        return await _launchNavigation(
          putnici: validPutnici,
          coordinates: coordinates,
          endDestination: endDestination,
        );
      } else {
        // Segmentirana navigacija - proveri mounted pre korišćenja context-a
        if (!context.mounted) {
          return MultiNavResult.error('Context nije više aktivan');
        }
        return await _launchSegmentedNavigation(
          context: context,
          putnici: validPutnici,
          coordinates: coordinates,
          endDestination: endDestination,
        );
      }
    } catch (e) {
      return MultiNavResult.error('Greška: $e');
    }
  }

  /// 🔍 Proveri da li je HERE WeGo instaliran
  static Future<bool> _isHereWeGoInstalled() async {
    return await DeviceUtils.isAppInstalled(NavigationProvider.hereWeGo);
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
            Text(
              'Za navigaciju je potreban HERE WeGo.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              '✅ Besplatan\n'
              '✅ Offline mape\n'
              '✅ Radi na svim telefonima\n'
              '✅ Prati redosled putnika',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kasnije'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _openPlayStore();
            },
            icon: const Icon(Icons.download),
            label: const Text('Instaliraj'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// 🏪 Otvori Store za HERE WeGo (Play Store ili AppGallery)
  static Future<void> _openPlayStore() async {
    // Prvo proveri da li je Huawei uređaj
    final isHuawei = await DeviceUtils.isHuaweiDevice();

    if (isHuawei) {
      // Huawei - probaj AppGallery prvo
      try {
        final appGalleryUri = Uri.parse(_appGalleryUrl);
        final launched = await launchUrl(appGalleryUri, mode: LaunchMode.externalApplication);
        if (launched) return;
      } catch (_) {}

      // Fallback na web AppGallery
      try {
        final webUri = Uri.parse('https://appgallery.huawei.com/app/C101397073');
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        return;
      } catch (_) {}
    }

    // Non-Huawei ili fallback - Play Store
    try {
      final uri = Uri.parse(_playStoreUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      // Krajnji fallback na web URL
      final webUri = Uri.parse('https://play.google.com/store/apps/details?id=com.here.app.maps');
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  /// 🚀 Pokreni HERE WeGo navigaciju
  static Future<MultiNavResult> _launchNavigation({
    required List<Putnik> putnici,
    required Map<Putnik, Position> coordinates,
    Position? endDestination,
  }) async {
    final success = await NavigationUrlBuilder.launchWithPutnici(
      provider: NavigationProvider.hereWeGo,
      putnici: putnici,
      coordinates: coordinates,
      destination: endDestination,
    );

    if (success) {
      return MultiNavResult.success(
        message: '🗺️ HERE WeGo: ${putnici.length} putnika',
        provider: NavigationProvider.hereWeGo,
        launchedPutnici: putnici,
        remainingPutnici: [],
      );
    } else {
      return MultiNavResult.error('Greška pri otvaranju HERE WeGo');
    }
  }

  /// 🔀 Segmentirana navigacija (više od 10 putnika)
  static Future<MultiNavResult> _launchSegmentedNavigation({
    required BuildContext context,
    required List<Putnik> putnici,
    required Map<Putnik, Position> coordinates,
    Position? endDestination,
  }) async {
    // Podeli na segmente po 10 putnika
    final segments = <List<Putnik>>[];
    for (var i = 0; i < putnici.length; i += _maxWaypoints) {
      final end = (i + _maxWaypoints > putnici.length) ? putnici.length : i + _maxWaypoints;
      segments.add(putnici.sublist(i, end));
    }

    final launchedPutnici = <Putnik>[];
    var currentSegment = 0;

    while (currentSegment < segments.length) {
      final segment = segments[currentSegment];

      // Destinacija samo za poslednji segment
      Position? segmentDestination;
      if (currentSegment == segments.length - 1 && endDestination != null) {
        segmentDestination = endDestination;
      }

      final success = await NavigationUrlBuilder.launchWithPutnici(
        provider: NavigationProvider.hereWeGo,
        putnici: segment,
        coordinates: coordinates,
        destination: segmentDestination,
      );

      if (!success) {
        return MultiNavResult.partial(
          message: 'Greška pri segmentu ${currentSegment + 1}',
          provider: NavigationProvider.hereWeGo,
          launchedPutnici: launchedPutnici,
          remainingPutnici: segments.skip(currentSegment).expand((s) => s).toList(),
        );
      }

      launchedPutnici.addAll(segment);
      currentSegment++;

      // Ako ima još segmenata, pitaj korisnika
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
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Završi'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Nastavi'),
              ),
            ],
          ),
        );

        if (shouldContinue != true) {
          return MultiNavResult.partial(
            message: 'Navigacija završena posle segmenta $currentSegment',
            provider: NavigationProvider.hereWeGo,
            launchedPutnici: launchedPutnici,
            remainingPutnici: segments.skip(currentSegment).expand((s) => s).toList(),
          );
        }
      }
    }

    return MultiNavResult.success(
      message: '✅ HERE WeGo: svih ${launchedPutnici.length} putnika',
      provider: NavigationProvider.hereWeGo,
      launchedPutnici: launchedPutnici,
      remainingPutnici: [],
    );
  }

  /// 📊 Proveri status navigacije (za kompatibilnost)
  static Future<NavigationStatus> checkNavigationStatus() async {
    final isInstalled = await _isHereWeGoInstalled();

    return NavigationStatus(
      isHuaweiDevice: await DeviceUtils.isHuaweiDevice(),
      installedApps: isInstalled ? [NavigationProvider.hereWeGo] : [],
      preferredApp: NavigationProvider.hereWeGo,
      recommendedApp: NavigationProvider.hereWeGo,
    );
  }
}

/// 📊 Rezultat multi-provider navigacije
class MultiNavResult {
  MultiNavResult._({
    required this.success,
    required this.message,
    this.provider,
    this.launchedPutnici,
    this.remainingPutnici,
    this.isPartial = false,
  });

  factory MultiNavResult.success({
    required String message,
    required NavigationProvider provider,
    required List<Putnik> launchedPutnici,
    required List<Putnik> remainingPutnici,
  }) {
    return MultiNavResult._(
      success: true,
      message: message,
      provider: provider,
      launchedPutnici: launchedPutnici,
      remainingPutnici: remainingPutnici,
    );
  }

  factory MultiNavResult.partial({
    required String message,
    required NavigationProvider provider,
    required List<Putnik> launchedPutnici,
    required List<Putnik> remainingPutnici,
  }) {
    return MultiNavResult._(
      success: true,
      message: message,
      provider: provider,
      launchedPutnici: launchedPutnici,
      remainingPutnici: remainingPutnici,
      isPartial: true,
    );
  }

  factory MultiNavResult.error(String message) {
    return MultiNavResult._(
      success: false,
      message: message,
    );
  }

  final bool success;
  final String message;
  final NavigationProvider? provider;
  final List<Putnik>? launchedPutnici;
  final List<Putnik>? remainingPutnici;
  final bool isPartial;

  /// Da li ima preostalih putnika?
  bool get hasRemaining => remainingPutnici?.isNotEmpty ?? false;

  /// Broj lansiranih putnika
  int get launchedCount => launchedPutnici?.length ?? 0;

  /// Broj preostalih putnika
  int get remainingCount => remainingPutnici?.length ?? 0;
}

/// 📊 Status navigacionih aplikacija na uređaju
class NavigationStatus {
  const NavigationStatus({
    required this.isHuaweiDevice,
    required this.installedApps,
    required this.preferredApp,
    required this.recommendedApp,
  });

  final bool isHuaweiDevice;
  final List<NavigationProvider> installedApps;
  final NavigationProvider? preferredApp;
  final NavigationProvider recommendedApp;

  /// Da li ima bilo koju navigacionu aplikaciju?
  bool get hasAnyNavigationApp => installedApps.isNotEmpty;

  /// Da li ima preporučenu aplikaciju?
  bool get hasRecommendedApp => installedApps.contains(recommendedApp);

  @override
  String toString() => 'NavigationStatus('
      'isHuawei: $isHuaweiDevice, '
      'installed: ${installedApps.map((a) => a.displayName).join(", ")}, '
      'preferred: ${preferredApp?.displayName ?? "none"}, '
      'recommended: ${recommendedApp.displayName})';
}
