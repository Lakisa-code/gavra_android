/// Prazan stub za geocoding statistike - funkcionalnost uklonjena
class GeocodingStatsService {
  static Future<void> incrementCacheHits() async {}
  static Future<void> incrementApiCalls() async {}
  static Future<void> addPopularLocation(String location) async {}
  static Future<Map<String, dynamic>> getGeocodingStats() async => {};
  static Future<List<Map<String, dynamic>>> getPopularLocations() async => [];
  static Future<void> clearGeocodingCache() async {}
  static Future<void> resetStats() async {}
}
