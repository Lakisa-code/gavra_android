/// NAVIGATION PROVIDER ENUM
/// Definiše podržanu navigacionu aplikaciju
///
/// KORISTI SE ISKLJUČIVO HERE WEGO:
/// - Besplatan
/// - Offline mape
/// - Radi na svim uređajima (GMS i HMS)
/// - Poštuje redosled waypointa
/// - Max 10 waypointa
enum NavigationProvider {
  hereWeGo(
    packageName: 'com.here.app.maps',
    displayName: 'HERE WeGo',
    maxWaypoints: 10,
    urlScheme: 'here-route',
    playStoreUrl: 'market://details?id=com.here.app.maps',
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

  /// Izračunaj koliko segmenata je potrebno za datu rutu
  int calculateSegments(int totalWaypoints) {
    if (totalWaypoints <= maxWaypoints) return 1;
    return (totalWaypoints / maxWaypoints).ceil();
  }

  /// Podeli listu waypointa na segmente
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
