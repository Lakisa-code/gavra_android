

import '../models/adresa.dart';
import 'adresa_service.dart';
import 'cache_service.dart';

/// 📊 COMPREHENSIVE ADDRESS ANALYTICS SERVICE
/// Detaljni servis za analitiku i statistike adresa
///
/// FUNKCIONALNOSTI:
/// ✅ Detaljne address usage statistics
/// ✅ Geographic distribution analysis
/// ✅ Coordinate coverage metrics
/// ✅ Validation quality reports
/// ✅ Performance monitoring
/// ✅ Trend analysis
/// ✅ Export capabilities
/// ✅ Dashboard data preparation
///
/// KORISTI SE ZA:
/// - Admin dashboard statistike
/// - Performance monitoring
/// - Data quality reports
/// - Geographic coverage analysis
/// - Usage pattern tracking
class AdresaStatisticsService {
  AdresaStatisticsService({AdresaService? adresaService})
      : _adresaService = adresaService ?? AdresaService();

  static const String _statsCacheKey = 'adresa_statistics';
  static const Duration _statsCacheTTL = Duration(minutes: 15);

  final AdresaService _adresaService;

  // ✅ COMPREHENSIVE STATISTICS

  /// Get complete address analytics dashboard data
  Future<Map<String, dynamic>> getComprehensiveStatistics({
    bool forceRefresh = false,
  }) async {
    try {
      // Check cache first
      if (!forceRefresh) {
        final cached = await CacheService.getFromDisk<Map<String, dynamic>>(
          _statsCacheKey,
        );
        if (cached != null) {
          // Logger removed
          return cached;
        }
      }

      // Logger removed

      final allAdrese = await _adresaService.getAllAdrese(forceRefresh: true);
      final stats = <String, dynamic>{};

      // Basic overview
      stats['overview'] = await _calculateOverviewStats(allAdrese);

      // Geographic analysis
      stats['geographic'] = await _calculateGeographicStats(allAdrese);

      // Quality analysis
      stats['quality'] = await _calculateQualityStats(allAdrese);

      // Usage patterns
      stats['usage'] = await _calculateUsageStats(allAdrese);

      // Performance metrics
      stats['performance'] = _adresaService.getServiceStatus();

      // Timestamp
      stats['generated_at'] = DateTime.now().toIso8601String();
      stats['total_addresses_analyzed'] = allAdrese.length;

      // Cache the results
      await CacheService.saveToDisk(_statsCacheKey, stats);

      
      return stats;
    } catch (e) {
      // Logger removed
      rethrow;
    }
  }

  /// Calculate basic overview statistics
  Future<Map<String, dynamic>> _calculateOverviewStats(
    List<Adresa> adrese,
  ) async {
    final overview = <String, dynamic>{};

    overview['total_addresses'] = adrese.length;
    overview['addresses_with_coordinates'] =
        adrese.where((a) => a.hasValidCoordinates).length;
    overview['fully_valid_addresses'] =
        adrese.where((a) => a.isCompletelyValid).length;
    overview['in_service_area'] = adrese.where((a) => a.isInServiceArea).length;

    // Percentages
    final total = adrese.length;
    if (total > 0) {
      overview['coordinate_coverage_percentage'] =
          (overview['addresses_with_coordinates'] / total * 100).round();
      overview['validation_success_percentage'] =
          (overview['fully_valid_addresses'] / total * 100).round();
      overview['service_area_coverage_percentage'] =
          (overview['in_service_area'] / total * 100).round();
    } else {
      overview['coordinate_coverage_percentage'] = 0;
      overview['validation_success_percentage'] = 0;
      overview['service_area_coverage_percentage'] = 0;
    }

    // Priority locations
    overview['priority_locations'] =
        adrese.where((a) => a.priorityScore > 0).length;
    overview['high_priority_locations'] =
        adrese.where((a) => a.priorityScore >= 80).length;

    return overview;
  }

  /// Calculate geographic distribution statistics
  Future<Map<String, dynamic>> _calculateGeographicStats(
    List<Adresa> adrese,
  ) async {
    final geographic = <String, dynamic>{};

    // Municipality distribution
    final municipalityDistribution = <String, int>{};
    final municipalityCoordinates = <String, int>{};
    final municipalityValidation = <String, int>{};

    for (final adresa in adrese) {
      final municipality = adresa.municipality;

      // Count by municipality
      municipalityDistribution[municipality] =
          (municipalityDistribution[municipality] ?? 0) + 1;

      // Count with coordinates
      if (adresa.hasValidCoordinates) {
        municipalityCoordinates[municipality] =
            (municipalityCoordinates[municipality] ?? 0) + 1;
      }

      // Count fully valid
      if (adresa.isCompletelyValid) {
        municipalityValidation[municipality] =
            (municipalityValidation[municipality] ?? 0) + 1;
      }
    }

    geographic['municipality_distribution'] = municipalityDistribution;
    geographic['municipality_coordinates'] = municipalityCoordinates;
    geographic['municipality_validation'] = municipalityValidation;

    // Calculate percentages for each municipality
    final municipalityPercentages = <String, Map<String, int>>{};
    for (final municipality in municipalityDistribution.keys) {
      final total = municipalityDistribution[municipality]!;
      final withCoords = municipalityCoordinates[municipality] ?? 0;
      final valid = municipalityValidation[municipality] ?? 0;

      municipalityPercentages[municipality] = {
        'coordinate_coverage':
            total > 0 ? (withCoords / total * 100).round() : 0,
        'validation_success': total > 0 ? (valid / total * 100).round() : 0,
      };
    }
    geographic['municipality_quality'] = municipalityPercentages;

    // Geographic bounds analysis
    if (adrese.where((a) => a.hasValidCoordinates).isNotEmpty) {
      geographic['bounds'] = _calculateGeographicBounds(
        adrese.where((a) => a.hasValidCoordinates).toList(),
      );
    }

    // Street analysis
    geographic['street_analysis'] = _calculateStreetStatistics(adrese);

    return geographic;
  }

  /// Calculate data quality statistics
  Future<Map<String, dynamic>> _calculateQualityStats(
    List<Adresa> adrese,
  ) async {
    final quality = <String, dynamic>{};

    // Validation breakdown
    final validationBreakdown = <String, int>{
      'valid_ulica': 0,
      'valid_broj': 0,
      'valid_grad': 0,
      'valid_postanski_broj': 0,
      'valid_coordinates_serbia': 0,
      'in_service_area': 0,
    };

    final commonIssues = <String, int>{};

    for (final adresa in adrese) {
      if (adresa.isValidUlica)
        validationBreakdown['valid_ulica'] =
            validationBreakdown['valid_ulica']! + 1;
      if (adresa.isValidBroj)
        validationBreakdown['valid_broj'] =
            validationBreakdown['valid_broj']! + 1;
      if (adresa.isValidGrad)
        validationBreakdown['valid_grad'] =
            validationBreakdown['valid_grad']! + 1;
      if (adresa.isValidPostanskiBroj)
        validationBreakdown['valid_postanski_broj'] =
            validationBreakdown['valid_postanski_broj']! + 1;
      if (adresa.areCoordinatesValidForSerbia)
        validationBreakdown['valid_coordinates_serbia'] =
            validationBreakdown['valid_coordinates_serbia']! + 1;
      if (adresa.isInServiceArea)
        validationBreakdown['in_service_area'] =
            validationBreakdown['in_service_area']! + 1;

      // Track common validation issues
      final errors = adresa.validationErrors;
      for (final error in errors) {
        commonIssues[error] = (commonIssues[error] ?? 0) + 1;
      }
    }

    quality['validation_breakdown'] = validationBreakdown;
    quality['common_issues'] = commonIssues;

    // Data completeness
    final completeness = <String, dynamic>{};
    final total = adrese.length;

    if (total > 0) {
      completeness['ulica_filled'] =
          adrese.where((a) => a.ulica.isNotEmpty).length;
      completeness['broj_filled'] =
          adrese.where((a) => a.broj != null && a.broj!.isNotEmpty).length;
      completeness['postanski_broj_filled'] = adrese
          .where((a) => a.postanskiBroj != null && a.postanskiBroj!.isNotEmpty)
          .length;
      completeness['coordinates_filled'] =
          adrese.where((a) => a.hasValidCoordinates).length;

      // Percentages
      completeness['ulica_percentage'] =
          (completeness['ulica_filled'] / total * 100).round();
      completeness['broj_percentage'] =
          (completeness['broj_filled'] / total * 100).round();
      completeness['postanski_broj_percentage'] =
          (completeness['postanski_broj_filled'] / total * 100).round();
      completeness['coordinates_percentage'] =
          (completeness['coordinates_filled'] / total * 100).round();
    }

    quality['completeness'] = completeness;

    return quality;
  }

  /// Calculate usage pattern statistics
  Future<Map<String, dynamic>> _calculateUsageStats(List<Adresa> adrese) async {
    final usage = <String, dynamic>{};

    // Address type analysis based on street names
    final addressTypes = <String, int>{
      'institutional': 0, // Schools, hospitals, etc.
      'commercial': 0, // Markets, restaurants, etc.
      'residential': 0, // Regular streets
      'transportation': 0, // Bus stations, etc.
      'religious': 0, // Churches, etc.
      'recreational': 0, // Parks, stadiums, etc.
    };

    for (final adresa in adrese) {
      final lowerUlica = adresa.ulica.toLowerCase();

      if (lowerUlica.contains('bolnica') ||
          lowerUlica.contains('skola') ||
          lowerUlica.contains('škola') ||
          lowerUlica.contains('ambulanta') ||
          lowerUlica.contains('vrtic') ||
          lowerUlica.contains('vrtić')) {
        addressTypes['institutional'] = addressTypes['institutional']! + 1;
      } else if (lowerUlica.contains('market') ||
          lowerUlica.contains('restoran') ||
          lowerUlica.contains('kafic') ||
          lowerUlica.contains('kafić') ||
          lowerUlica.contains('prodavnica') ||
          lowerUlica.contains('banka')) {
        addressTypes['commercial'] = addressTypes['commercial']! + 1;
      } else if (lowerUlica.contains('crkva')) {
        addressTypes['religious'] = addressTypes['religious']! + 1;
      } else if (lowerUlica.contains('park') ||
          lowerUlica.contains('stadion')) {
        addressTypes['recreational'] = addressTypes['recreational']! + 1;
      } else if (lowerUlica.contains('stanica') ||
          lowerUlica.contains('posta') ||
          lowerUlica.contains('pošta')) {
        addressTypes['transportation'] = addressTypes['transportation']! + 1;
      } else {
        addressTypes['residential'] = addressTypes['residential']! + 1;
      }
    }

    usage['address_types'] = addressTypes;

    // Priority distribution
    final priorityDistribution = <String, int>{
      'high_priority': adrese.where((a) => a.priorityScore >= 80).length,
      'medium_priority': adrese
          .where((a) => a.priorityScore >= 50 && a.priorityScore < 80)
          .length,
      'low_priority': adrese
          .where((a) => a.priorityScore > 0 && a.priorityScore < 50)
          .length,
      'no_priority': adrese.where((a) => a.priorityScore == 0).length,
    };

    usage['priority_distribution'] = priorityDistribution;

    // Recent updates analysis
    final now = DateTime.now();
    final recentUpdates = <String, int>{
      'last_24h': 0,
      'last_week': 0,
      'last_month': 0,
      'older': 0,
    };

    for (final adresa in adrese) {
      final daysSinceUpdate = now.difference(adresa.updatedAt).inDays;

      if (daysSinceUpdate < 1) {
        recentUpdates['last_24h'] = recentUpdates['last_24h']! + 1;
      } else if (daysSinceUpdate < 7) {
        recentUpdates['last_week'] = recentUpdates['last_week']! + 1;
      } else if (daysSinceUpdate < 30) {
        recentUpdates['last_month'] = recentUpdates['last_month']! + 1;
      } else {
        recentUpdates['older'] = recentUpdates['older']! + 1;
      }
    }

    usage['recent_updates'] = recentUpdates;

    return usage;
  }

  /// Calculate geographic bounds for addresses with coordinates
  Map<String, double> _calculateGeographicBounds(
    List<Adresa> adreseSaKoordinatama,
  ) {
    if (adreseSaKoordinatama.isEmpty) return {};

    double minLat = adreseSaKoordinatama.first.latitude!;
    double maxLat = adreseSaKoordinatama.first.latitude!;
    double minLng = adreseSaKoordinatama.first.longitude!;
    double maxLng = adreseSaKoordinatama.first.longitude!;

    for (final adresa in adreseSaKoordinatama) {
      final lat = adresa.latitude!;
      final lng = adresa.longitude!;

      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    return {
      'min_latitude': minLat,
      'max_latitude': maxLat,
      'min_longitude': minLng,
      'max_longitude': maxLng,
      'center_latitude': (minLat + maxLat) / 2,
      'center_longitude': (minLng + maxLng) / 2,
      'span_latitude': maxLat - minLat,
      'span_longitude': maxLng - minLng,
    };
  }

  /// Calculate street-level statistics
  Map<String, dynamic> _calculateStreetStatistics(List<Adresa> adrese) {
    final streetStats = <String, dynamic>{};

    // Group by street name
    final streetCounts = <String, int>{};
    final streetCoordinateCounts = <String, int>{};

    for (final adresa in adrese) {
      final streetName = adresa.ulica.toLowerCase();
      streetCounts[streetName] = (streetCounts[streetName] ?? 0) + 1;

      if (adresa.hasValidCoordinates) {
        streetCoordinateCounts[streetName] =
            (streetCoordinateCounts[streetName] ?? 0) + 1;
      }
    }

    // Most common streets
    final sortedStreets = streetCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    streetStats['most_common_streets'] =
        Map.fromEntries(sortedStreets.take(10));
    streetStats['total_unique_streets'] = streetCounts.length;
    streetStats['average_addresses_per_street'] = streetCounts.isNotEmpty
        ? (adrese.length / streetCounts.length).round()
        : 0;

    // Streets with best coordinate coverage
    final streetCoverageRates = <String, double>{};
    for (final entry in streetCounts.entries) {
      final streetName = entry.key;
      final totalCount = entry.value;
      final coordinateCount = streetCoordinateCounts[streetName] ?? 0;
      streetCoverageRates[streetName] =
          totalCount > 0 ? coordinateCount / totalCount : 0;
    }

    final sortedCoverage = streetCoverageRates.entries
        .where(
          (e) => streetCounts[e.key]! >= 2,
        ) // Only streets with 2+ addresses
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    streetStats['best_coordinate_coverage'] = Map.fromEntries(
      sortedCoverage
          .take(10)
          .map((e) => MapEntry(e.key, (e.value * 100).round())),
    );

    return streetStats;
  }

  // ✅ TREND ANALYSIS

  /// Calculate address creation trends
  Future<Map<String, dynamic>> getCreationTrends({int daysBack = 30}) async {
    try {
      // Logger removed;

      final adrese = await _adresaService.getAllAdrese();
      final trends = <String, dynamic>{};

      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: daysBack));

      // Daily creation counts
      final dailyCounts = <String, int>{};

      for (final adresa in adrese) {
        if (adresa.createdAt.isAfter(startDate)) {
          final dateKey =
              '${adresa.createdAt.year}-${adresa.createdAt.month.toString().padLeft(2, '0')}-${adresa.createdAt.day.toString().padLeft(2, '0')}';
          dailyCounts[dateKey] = (dailyCounts[dateKey] ?? 0) + 1;
        }
      }

      trends['daily_creation_counts'] = dailyCounts;
      trends['total_new_addresses'] =
          dailyCounts.values.fold(0, (sum, count) => sum + count);
      trends['average_daily_creation'] = dailyCounts.isNotEmpty
          ? (trends['total_new_addresses'] / dailyCounts.length).round()
          : 0;

      // Municipality trends
      final municipalityTrends = <String, int>{};
      for (final adresa in adrese) {
        if (adresa.createdAt.isAfter(startDate)) {
          final municipality = adresa.municipality;
          municipalityTrends[municipality] =
              (municipalityTrends[municipality] ?? 0) + 1;
        }
      }

      trends['municipality_trends'] = municipalityTrends;
      trends['analysis_period_days'] = daysBack;
      trends['generated_at'] = DateTime.now().toIso8601String();

      
      return trends;
    } catch (e) {
      // Logger removed
      rethrow;
    }
  }

  // ✅ EXPORT CAPABILITIES

  /// Export detailed statistics to CSV
  Future<String> exportStatisticsToCSV() async {
    try {
      // Logger removed

      final stats = await getComprehensiveStatistics();
      final csv = StringBuffer();

      // Overview CSV
      csv.writeln('# ADDRESS STATISTICS REPORT');
      csv.writeln('Generated At,${stats['generated_at']}');
      csv.writeln('Total Addresses,${stats['overview']['total_addresses']}');
      csv.writeln();

      // Overview section
      csv.writeln('# OVERVIEW STATISTICS');
      csv.writeln('Metric,Count,Percentage');
      final overview = stats['overview'] as Map<String, dynamic>;
      csv.writeln('Total Addresses,${overview['total_addresses']},100');
      csv.writeln(
        'With Coordinates,${overview['addresses_with_coordinates']},${overview['coordinate_coverage_percentage']}',
      );
      csv.writeln(
        'Fully Valid,${overview['fully_valid_addresses']},${overview['validation_success_percentage']}',
      );
      csv.writeln(
        'In Service Area,${overview['in_service_area']},${overview['service_area_coverage_percentage']}',
      );
      csv.writeln('Priority Locations,${overview['priority_locations']},N/A');
      csv.writeln();

      // Municipality distribution
      csv.writeln('# MUNICIPALITY DISTRIBUTION');
      csv.writeln(
        'Municipality,Total Addresses,With Coordinates,Coordinate Coverage %',
      );
      final geographic = stats['geographic'] as Map<String, dynamic>;
      final municipalityDist =
          geographic['municipality_distribution'] as Map<String, dynamic>;
      final municipalityCoords =
          geographic['municipality_coordinates'] as Map<String, dynamic>;

      for (final entry in municipalityDist.entries) {
        final municipality = entry.key;
        final total = (entry.value as num?)?.toInt() ?? 0;
        final withCoords =
            (municipalityCoords[municipality] as num?)?.toInt() ?? 0;
        final percentage = total > 0 ? (withCoords / total * 100).round() : 0;
        csv.writeln('$municipality,$total,$withCoords,$percentage');
      }

      // Logger removed
      return csv.toString();
    } catch (e) {
      // Logger removed
      rethrow;
    }
  }

  // ✅ CACHE MANAGEMENT

  /// Clear statistics cache
  Future<void> clearStatisticsCache() async {
    await CacheService.clearFromDisk(_statsCacheKey);
    // Logger removed
  }

  /// Get cache status
  Future<Map<String, dynamic>> getCacheStatus() async {
    final hasCache =
        await CacheService.getFromDisk<Map<String, dynamic>>(_statsCacheKey) !=
            null;
    return {
      'has_cached_statistics': hasCache,
      'cache_key': _statsCacheKey,
      'cache_ttl_minutes': _statsCacheTTL.inMinutes,
    };
  }
}





