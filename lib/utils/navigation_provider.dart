/// 🧭 NAVIGATION PROVIDER ENUM
/// Definiše podržane navigacione aplikacije sa njihovim karakteristikama
///
/// Prioritet korišćenja:
/// 1. Google Maps (ako je dostupan - GMS uređaji)
/// 2. HERE WeGo (fallback za Huawei, radi bez GMS)
/// 3. Petal Maps (fabrički instaliran na Huawei)
///
/// Waypoint limiti:
/// - Google Maps: 10 waypointa
/// - HERE WeGo: 10 waypointa
/// - Petal Maps: 5 waypointa
enum NavigationProvider {
  googleMaps(
    packageName: 'com.google.android.apps.maps',
    displayName: 'Google Maps',
    maxWaypoints: 10,
    urlScheme: 'google.navigation',
    playStoreUrl: 'market://details?id=com.google.android.apps.maps',
    requiresGms: true,
  ),
  hereWeGo(
    packageName: 'com.here.app.maps',
    displayName: 'HERE WeGo',
    maxWaypoints: 10,
    urlScheme: 'here-route',
    playStoreUrl: 'market://details?id=com.here.app.maps',
    requiresGms: false,
  ),
  petalMaps(
    packageName: 'com.huawei.maps.app',
    displayName: 'Petal Maps',
    maxWaypoints: 5,
    urlScheme: 'petalmaps',
    playStoreUrl: 'appmarket://details?id=com.huawei.maps.app', // AppGallery
    requiresGms: false,
  );

  const NavigationProvider({
    required this.packageName,
    required this.displayName,
    required this.maxWaypoints,
    required this.urlScheme,
    required this.playStoreUrl,
    required this.requiresGms,
  });

  /// Android package name za proveru instalacije
  final String packageName;

  /// Ime za prikaz korisniku
  final String displayName;

  /// Maksimalan broj waypointa (bez start i destination)
  final int maxWaypoints;

  /// URL scheme za deep linking
  final String urlScheme;

  /// Store URL za instalaciju
  final String playStoreUrl;

  /// Da li zahteva Google Mobile Services
  final bool requiresGms;

  /// 📊 Izračunaj koliko segmenata je potrebno za datu rutu
  int calculateSegments(int totalWaypoints) {
    if (totalWaypoints <= maxWaypoints) return 1;
    return (totalWaypoints / maxWaypoints).ceil();
  }

  /// 📊 Podeli listu waypointa na segmente
  List<List<T>> segmentWaypoints<T>(List<T> waypoints) {
    if (waypoints.length <= maxWaypoints) {
      return [waypoints];
    }

    final segments = <List<T>>[];
    for (var i = 0; i < waypoints.length; i += maxWaypoints) {
      final end = (i + maxWaypoints > waypoints.length) ? waypoints.length : i + maxWaypoints;
      segments.add(waypoints.sublist(i, end));
    }
    return segments;
  }

  @override
  String toString() => displayName;
}

/// 🔧 Extension metode za NavigationProvider
extension NavigationProviderExtension on NavigationProvider {
  /// Da li je ovo Huawei-native app
  bool get isHuaweiNative => this == NavigationProvider.petalMaps;

  /// Da li podržava offline mape
  bool get supportsOfflineMaps => this == NavigationProvider.hereWeGo || this == NavigationProvider.petalMaps;

  /// Preporučena poruka za Huawei korisnike
  String get huaweiRecommendation {
    switch (this) {
      case NavigationProvider.hereWeGo:
        return 'HERE WeGo radi odlično na Huawei uređajima bez Google servisa. '
            'Podržava 10 waypointa i offline mape.';
      case NavigationProvider.petalMaps:
        return 'Petal Maps je fabrički instaliran na vašem Huawei uređaju. '
            'Ograničen je na 5 waypointa po segmentu.';
      case NavigationProvider.googleMaps:
        return 'Google Maps nije dostupan na Huawei uređajima bez GMS.';
    }
  }
}
