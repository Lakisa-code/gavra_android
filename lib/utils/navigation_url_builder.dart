import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/putnik.dart';
import 'navigation_provider.dart';

/// 🔗 NAVIGATION URL BUILDER
/// Gradi URL-ove za različite navigacione aplikacije
class NavigationUrlBuilder {
  /// 🗺️ Gradi URL za navigaciju sa koordinatama
  ///
  /// [provider] - Navigaciona aplikacija
  /// [waypoints] - Lista koordinata (lat, lng parovi)
  /// [destination] - Krajnja destinacija
  /// [startPosition] - Početna pozicija (opciono)
  static String buildUrl({
    required NavigationProvider provider,
    required List<Position> waypoints,
    required Position destination,
    Position? startPosition,
  }) {
    switch (provider) {
      case NavigationProvider.googleMaps:
        return _buildGoogleMapsUrl(waypoints, destination);
      case NavigationProvider.hereWeGo:
        return _buildHereWeGoUrl(waypoints, destination);
      case NavigationProvider.petalMaps:
        return _buildPetalMapsUrl(waypoints, destination);
    }
  }

  /// 🗺️ Gradi URL za navigaciju sa putnicima
  static String buildUrlFromPutnici({
    required NavigationProvider provider,
    required List<Putnik> putnici,
    required Map<Putnik, Position> coordinates,
    Position? destination,
  }) {
    // Filtriraj samo putnike sa koordinatama
    final validPutnici = putnici.where((p) => coordinates.containsKey(p)).toList();

    if (validPutnici.isEmpty) {
      throw ArgumentError('Nema putnika sa validnim koordinatama');
    }

    // Waypoints su svi osim poslednjeg
    final waypoints = validPutnici.take(validPutnici.length - 1).map((p) => coordinates[p]!).toList();

    // Destinacija je poslednji putnik ili prosleđena destinacija
    final dest = destination ?? coordinates[validPutnici.last]!;

    return buildUrl(
      provider: provider,
      waypoints: waypoints,
      destination: dest,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 🔗 GOOGLE MAPS URL BUILDER
  // ═══════════════════════════════════════════════════════════════════════

  /// 🔗 Google Maps Navigation URL
  /// Format: google.navigation:q=LAT,LNG&waypoints=LAT1,LNG1|LAT2,LNG2&mode=d
  static String _buildGoogleMapsUrl(List<Position> waypoints, Position destination) {
    final StringBuffer url = StringBuffer();
    url.write('google.navigation:q=${destination.latitude},${destination.longitude}');

    if (waypoints.isNotEmpty) {
      final waypointsStr = waypoints.map((p) => '${p.latitude},${p.longitude}').join('|');
      url.write('&waypoints=$waypointsStr');
    }

    url.write('&mode=d'); // d = driving

    return url.toString();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 🔗 HERE WEGO URL BUILDER
  // ═══════════════════════════════════════════════════════════════════════

  /// 🔗 HERE WeGo Navigation URL
  /// Format: here-route://LAT,LNG,NAME/LAT,LNG,NAME?m=d
  /// Alternativno: https://share.here.com/r/LAT,LNG,NAME/LAT,LNG,NAME?m=d
  static String _buildHereWeGoUrl(List<Position> waypoints, Position destination) {
    final StringBuffer url = StringBuffer();
    url.write('here-route://');

    // Dodaj waypointe
    for (int i = 0; i < waypoints.length; i++) {
      final wp = waypoints[i];
      url.write('${wp.latitude},${wp.longitude},Putnik${i + 1}/');
    }

    // Dodaj destinaciju
    url.write('${destination.latitude},${destination.longitude},Destinacija');

    // Driving mode
    url.write('?m=d');

    return url.toString();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 🔗 PETAL MAPS URL BUILDER
  // ═══════════════════════════════════════════════════════════════════════

  /// 🔗 Petal Maps Navigation URL
  /// Format: petalmaps://route?saddr=LAT,LNG&daddr=LAT,LNG&waypoints=LAT,LNG|LAT,LNG&type=drive
  static String _buildPetalMapsUrl(List<Position> waypoints, Position destination) {
    final StringBuffer url = StringBuffer();
    url.write('petalmaps://route?');

    // Destinacija
    url.write('daddr=${destination.latitude},${destination.longitude}');

    // Waypointi (max 5!)
    if (waypoints.isNotEmpty) {
      final waypointsStr = waypoints.map((p) => '${p.latitude},${p.longitude}').join('|');
      url.write('&waypoints=$waypointsStr');
    }

    // Driving mode
    url.write('&type=drive');

    return url.toString();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 🚀 LAUNCH HELPERS
  // ═══════════════════════════════════════════════════════════════════════

  /// 🚀 Otvori navigacionu aplikaciju
  static Future<bool> launch({
    required NavigationProvider provider,
    required List<Position> waypoints,
    required Position destination,
  }) async {
    try {
      final url = buildUrl(
        provider: provider,
        waypoints: waypoints,
        destination: destination,
      );

      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// 🚀 Otvori navigacionu aplikaciju sa putnicima
  static Future<bool> launchWithPutnici({
    required NavigationProvider provider,
    required List<Putnik> putnici,
    required Map<Putnik, Position> coordinates,
    Position? destination,
  }) async {
    try {
      final url = buildUrlFromPutnici(
        provider: provider,
        putnici: putnici,
        coordinates: coordinates,
        destination: destination,
      );

      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// 🏪 Otvori store za instalaciju aplikacije
  static Future<bool> openStore(NavigationProvider provider) async {
    try {
      final uri = Uri.parse(provider.playStoreUrl);

      if (await canLaunchUrl(uri)) {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        // Fallback na web URL
        final webUri = provider == NavigationProvider.petalMaps
            ? Uri.parse('https://appgallery.huawei.com/app/${provider.packageName}')
            : Uri.parse('https://play.google.com/store/apps/details?id=${provider.packageName}');

        return await launchUrl(webUri);
      }
    } catch (e) {
      return false;
    }
  }
}

/// 🔀 ROUTE SEGMENTATION
/// Razbija rutu na segmente prema limitu waypoinata
class RouteSegmentation {
  /// 📊 Segmentiraj putnike prema limitu providera
  static List<List<Putnik>> segmentPutnici(
    List<Putnik> putnici,
    NavigationProvider provider,
  ) {
    return provider.segmentWaypoints(putnici);
  }

  /// 📊 Segmentiraj koordinate prema limitu providera
  static List<List<Position>> segmentCoordinates(
    List<Position> coordinates,
    NavigationProvider provider,
  ) {
    return provider.segmentWaypoints(coordinates);
  }

  /// 📊 Dobij informacije o segmentaciji
  static SegmentationInfo getSegmentationInfo(
    List<Putnik> putnici,
    NavigationProvider provider,
  ) {
    final segments = segmentPutnici(putnici, provider);

    return SegmentationInfo(
      totalPutnici: putnici.length,
      maxWaypoints: provider.maxWaypoints,
      segmentCount: segments.length,
      segments: segments,
      provider: provider,
    );
  }
}

/// 📊 Informacije o segmentaciji rute
class SegmentationInfo {
  const SegmentationInfo({
    required this.totalPutnici,
    required this.maxWaypoints,
    required this.segmentCount,
    required this.segments,
    required this.provider,
  });

  final int totalPutnici;
  final int maxWaypoints;
  final int segmentCount;
  final List<List<Putnik>> segments;
  final NavigationProvider provider;

  /// Da li je potrebna segmentacija?
  bool get needsSegmentation => segmentCount > 1;

  /// Broj putnika u prvom segmentu
  int get firstSegmentCount => segments.isNotEmpty ? segments.first.length : 0;

  /// Broj preostalih putnika (posle prvog segmenta)
  int get remainingCount => totalPutnici - firstSegmentCount;

  /// Poruka za korisnika
  String get userMessage {
    if (!needsSegmentation) {
      return 'Navigacija za $totalPutnici putnika';
    }

    return 'Navigacija za $firstSegmentCount putnika (deo 1/$segmentCount). '
        'Preostalo: $remainingCount putnika.';
  }

  @override
  String toString() => 'SegmentationInfo(total: $totalPutnici, segments: $segmentCount, maxWaypoints: $maxWaypoints)';
}
