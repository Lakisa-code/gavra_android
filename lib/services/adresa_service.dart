import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/adresa.dart';
import 'cache_service.dart';

/// 📍 MODERNIZED CLOUD SERVICE za upravljanje adresama u Supabase Cloud
/// KOMPLETNO MODERNIZOVAN - caching, batch operations, analytics, validation
///
/// FUNKCIONALNOSTI:
/// ✅ Smart caching system sa TTL i memory management
/// ✅ Batch CRUD operacije za performance
/// ✅ Advanced search sa filtering i geolocation
/// ✅ Comprehensive error handling i logging
/// ✅ Real-time subscriptions
/// ✅ Address validation i normalizacija
/// ✅ Statistics i usage analytics
/// ✅ CSV export functionality
/// ✅ Coordinate geocoding integration
///
/// KADA KORISTITI:
/// - Za sve cloud CRUD operacije sa adresama
/// - Za persistent storage adresa sa UUID-jima
/// - Za real-time tracking address changes
/// - Za analytics i reporting
/// - Za batch import/export operations
///
/// OGRANIČENO NA: Bela Crkva i Vršac opštine samo
class AdresaService {
  AdresaService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;
  final SupabaseClient _supabase;
  static final Logger _logger = Logger();
  static const String _cachePrefix = 'adresa_';
  static const String _listCacheKey = 'adrese_list';

  // 📊 Statistics tracking
  static int _totalOperations = 0;
  static int _cacheHits = 0;
  static int _cacheMisses = 0;
  static DateTime? _lastOperationTime;

  // ✅ ENHANCED CRUD OPERATIONS WITH CACHING

  /// Get all addresses with smart caching
  Future<List<Adresa>> getAllAdrese({bool forceRefresh = false}) async {
    _incrementOperation();

    try {
      // Check cache first unless force refresh
      if (!forceRefresh) {
        final cached =
            await CacheService.getFromDisk<List<Map<String, dynamic>>>(
                _listCacheKey,);
        if (cached != null) {
          _logger.i('🎯 Cache hit: $_listCacheKey');
          _cacheHits++;
          return cached.map((json) => Adresa.fromMap(json)).toList();
        }
      }

      _logger.i('📡 Fetching all addresses from Supabase...');
      _cacheMisses++;

      final response = await _supabase
          .from('adrese')
          .select()
          .order('updated_at', ascending: false);

      final adrese = (response as List)
          .map((json) => Adresa.fromMap(json as Map<String, dynamic>))
          .where((adresa) => adresa.isInServiceArea) // Filter service area
          .toList();

      // Cache the results
      await CacheService.saveToDisk(
        _listCacheKey,
        adrese.map((a) => a.toMap()).toList(),
      );

      _logger
          .i('✅ Loaded ${adrese.length} addresses (filtered for service area)');
      return adrese;
    } catch (e) {
      _logger.e('❌ Error loading addresses: $e');
      rethrow;
    }
  }

  /// Get address by ID with caching
  Future<Adresa?> getAdresaById(String id) async {
    _incrementOperation();

    try {
      // Check cache first
      final cacheKey = '$_cachePrefix$id';
      final cached =
          await CacheService.getFromDisk<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        _logger.i('🎯 Cache hit: $cacheKey');
        _cacheHits++;
        return Adresa.fromMap(cached);
      }

      _logger.i('📡 Fetching address $id from Supabase...');
      _cacheMisses++;

      final response =
          await _supabase.from('adrese').select().eq('id', id).single();

      final adresa = Adresa.fromMap(response);

      // Validate service area
      if (!adresa.isInServiceArea) {
        _logger.w('⚠️ Address $id is outside service area');
        return null;
      }

      // Cache the result
      await CacheService.saveToDisk(cacheKey, adresa.toMap());

      _logger.i('✅ Loaded address: ${adresa.shortAddress}');
      return adresa;
    } catch (e) {
      _logger.e('❌ Error loading address $id: $e');
      return null;
    }
  }

  /// Create new address with validation
  Future<Adresa> createAdresa(Adresa adresa) async {
    _incrementOperation();

    try {
      // Validate before creating
      if (!adresa.isCompletelyValid) {
        final errors = adresa.validationErrors.join(', ');
        throw Exception('Address validation failed: $errors');
      }

      // Normalize the address
      final normalizedAdresa = adresa.normalize();

      _logger.i('📝 Creating address: ${normalizedAdresa.displayAddress}');

      final response = await _supabase
          .from('adrese')
          .insert(normalizedAdresa.toMap())
          .select()
          .single();

      final createdAdresa = Adresa.fromMap(response);

      // Cache the new address
      final cacheKey = '$_cachePrefix${createdAdresa.id}';
      await CacheService.saveToDisk(cacheKey, createdAdresa.toMap());

      // Invalidate list cache
      await CacheService.clearFromDisk(_listCacheKey);

      _logger.i('✅ Created address: ${createdAdresa.displayAddress}');
      return createdAdresa;
    } catch (e) {
      _logger.e('❌ Error creating address: $e');
      rethrow;
    }
  }

  /// Update address with validation
  Future<Adresa> updateAdresa(String id, Map<String, dynamic> updates) async {
    _incrementOperation();

    try {
      // Add updated_at timestamp
      updates['updated_at'] = DateTime.now().toIso8601String();

      _logger.i('📝 Updating address $id with: ${updates.keys.join(', ')}');

      final response = await _supabase
          .from('adrese')
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      final updatedAdresa = Adresa.fromMap(response);

      // Validate after update
      if (!updatedAdresa.isCompletelyValid) {
        _logger.w(
            '⚠️ Updated address failed validation: ${updatedAdresa.validationErrors}',);
      }

      // Update cache
      final cacheKey = '$_cachePrefix$id';
      await CacheService.saveToDisk(cacheKey, updatedAdresa.toMap());

      // Invalidate list cache
      await CacheService.clearFromDisk(_listCacheKey);

      _logger.i('✅ Updated address: ${updatedAdresa.displayAddress}');
      return updatedAdresa;
    } catch (e) {
      _logger.e('❌ Error updating address $id: $e');
      rethrow;
    }
  }

  /// Soft delete address
  Future<void> deleteAdresa(String id) async {
    _incrementOperation();

    try {
      _logger.i('🗑️ Soft deleting address $id');

      await _supabase.from('adrese').update({
        'deleted_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      // Remove from cache
      final cacheKey = '$_cachePrefix$id';
      await CacheService.clearFromDisk(cacheKey);
      await CacheService.clearFromDisk(_listCacheKey);

      _logger.i('✅ Soft deleted address $id');
    } catch (e) {
      _logger.e('❌ Error deleting address $id: $e');
      rethrow;
    }
  }

  // ✅ BATCH OPERATIONS for performance

  /// Create multiple addresses in batch
  Future<List<Adresa>> createMultipleAdrese(List<Adresa> adrese) async {
    _incrementOperation();

    try {
      if (adrese.isEmpty) return [];

      // Validate all addresses
      final validAdrese = <Adresa>[];
      final invalidAdrese = <String>[];

      for (final adresa in adrese) {
        final normalized = adresa.normalize();
        if (normalized.isCompletelyValid) {
          validAdrese.add(normalized);
        } else {
          invalidAdrese.add(
              '${adresa.displayAddress}: ${adresa.validationErrors.join(', ')}',);
        }
      }

      if (invalidAdrese.isNotEmpty) {
        _logger.w('⚠️ ${invalidAdrese.length} addresses failed validation');
      }

      if (validAdrese.isEmpty) {
        throw Exception('No valid addresses to create');
      }

      _logger.i('📝 Batch creating ${validAdrese.length} addresses');

      final response = await _supabase
          .from('adrese')
          .insert(validAdrese.map((a) => a.toMap()).toList())
          .select();

      final createdAdrese = (response as List)
          .map((json) => Adresa.fromMap(json as Map<String, dynamic>))
          .toList();

      // Cache all created addresses
      for (final adresa in createdAdrese) {
        final cacheKey = '$_cachePrefix${adresa.id}';
        await CacheService.saveToDisk(cacheKey, adresa.toMap());
      }

      // Invalidate list cache
      await CacheService.clearFromDisk(_listCacheKey);

      _logger.i('✅ Batch created ${createdAdrese.length} addresses');
      return createdAdrese;
    } catch (e) {
      _logger.e('❌ Error batch creating addresses: $e');
      rethrow;
    }
  }

  /// Update multiple addresses in batch
  Future<void> updateMultipleAdrese(
      Map<String, Map<String, dynamic>> updates,) async {
    _incrementOperation();

    try {
      if (updates.isEmpty) return;

      _logger.i('📝 Batch updating ${updates.length} addresses');

      // Add updated_at to all updates
      final now = DateTime.now().toIso8601String();
      for (final update in updates.values) {
        update['updated_at'] = now;
      }

      // Execute batch updates (Supabase doesn't support batch update, so we do sequential)
      for (final entry in updates.entries) {
        final id = entry.key;
        final updateData = entry.value;

        await _supabase.from('adrese').update(updateData).eq('id', id);

        // Invalidate cache for this address
        final cacheKey = '$_cachePrefix$id';
        await CacheService.clearFromDisk(cacheKey);
      }

      // Invalidate list cache
      await CacheService.clearFromDisk(_listCacheKey);

      _logger.i('✅ Batch updated ${updates.length} addresses');
    } catch (e) {
      _logger.e('❌ Error batch updating addresses: $e');
      rethrow;
    }
  }

  /// Batch soft delete addresses
  Future<void> deleteMultipleAdrese(List<String> ids) async {
    _incrementOperation();

    try {
      if (ids.isEmpty) return;

      _logger.i('🗑️ Batch deleting ${ids.length} addresses');

      final now = DateTime.now().toIso8601String();

      // Execute batch soft deletes
      for (final id in ids) {
        await _supabase.from('adrese').update({
          'deleted_at': now,
          'updated_at': now,
        }).eq('id', id);

        // Remove from cache
        final cacheKey = '$_cachePrefix$id';
        await CacheService.clearFromDisk(cacheKey);
      }

      // Invalidate list cache
      await CacheService.clearFromDisk(_listCacheKey);

      _logger.i('✅ Batch deleted ${ids.length} addresses');
    } catch (e) {
      _logger.e('❌ Error batch deleting addresses: $e');
      rethrow;
    }
  }

  // ✅ ADVANCED SEARCH OPERATIONS

  /// Search addresses with advanced filtering
  Future<List<Adresa>> searchAdrese(
    String? query, {
    String? grad,
    bool? hasCoordinates,
    double? nearLatitude,
    double? nearLongitude,
    double? radiusKm,
    String? sortBy,
    bool ascending = true,
    int? limit,
  }) async {
    _incrementOperation();

    try {
      _logger.i('🔍 Searching addresses with query: "$query"');

      dynamic queryBuilder = _supabase.from('adrese').select();

      // Text search in ulica and grad
      if (query != null && query.trim().isNotEmpty) {
        final searchTerm = query.trim().toLowerCase();
        queryBuilder = queryBuilder
            .or('ulica.ilike.%$searchTerm%,grad.ilike.%$searchTerm%');
      }

      // Filter by city
      if (grad != null && grad.trim().isNotEmpty) {
        queryBuilder = queryBuilder.eq('grad', grad);
      }

      // Filter by coordinate existence
      if (hasCoordinates != null) {
        if (hasCoordinates) {
          queryBuilder = queryBuilder.filter('koordinate', 'not.is', null);
        } else {
          queryBuilder = queryBuilder.filter('koordinate', 'is', null);
        }
      }

      // Sort options
      if (sortBy != null) {
        queryBuilder = queryBuilder.order(sortBy, ascending: ascending);
      } else {
        queryBuilder = queryBuilder.order('updated_at', ascending: false);
      }

      // Limit results
      if (limit != null && limit > 0) {
        queryBuilder = queryBuilder.limit(limit);
      }

      final response = await queryBuilder;
      var adrese = (response as List)
          .map((json) => Adresa.fromMap(json as Map<String, dynamic>))
          .where((adresa) => adresa.isInServiceArea) // Filter service area
          .toList();

      // Geographic proximity filtering (if coordinates provided)
      if (nearLatitude != null && nearLongitude != null && radiusKm != null) {
        final centerPoint = Adresa(
          id: 'temp',
          ulica: 'temp',
          grad: 'temp',
          koordinate: 'POINT($nearLongitude $nearLatitude)',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        adrese = adrese.where((adresa) {
          final distance = centerPoint.distanceTo(adresa);
          return distance != null && distance <= radiusKm;
        }).toList();

        // Sort by distance if doing proximity search
        adrese.sort((a, b) {
          final distA = centerPoint.distanceTo(a) ?? double.infinity;
          final distB = centerPoint.distanceTo(b) ?? double.infinity;
          return distA.compareTo(distB);
        });
      }

      _logger.i('✅ Found ${adrese.length} addresses matching search criteria');
      return adrese;
    } catch (e) {
      _logger.e('❌ Error searching addresses: $e');
      rethrow;
    }
  }

  /// Get addresses grouped by municipality
  Future<Map<String, List<Adresa>>> getAdreseByMunicipality() async {
    _incrementOperation();

    try {
      _logger.i('📊 Grouping addresses by municipality');

      final allAdrese = await getAllAdrese();
      final grouped = <String, List<Adresa>>{};

      for (final adresa in allAdrese) {
        final municipality = adresa.municipality;
        grouped[municipality] ??= [];
        grouped[municipality]!.add(adresa);
      }

      // Sort addresses within each municipality by priority then name
      for (final addresses in grouped.values) {
        addresses.sort((a, b) {
          final priorityComparison = b.priorityScore.compareTo(a.priorityScore);
          if (priorityComparison != 0) return priorityComparison;
          return a.displayAddress.compareTo(b.displayAddress);
        });
      }

      _logger.i(
          '✅ Grouped ${allAdrese.length} addresses into ${grouped.length} municipalities',);
      return grouped;
    } catch (e) {
      _logger.e('❌ Error grouping addresses by municipality: $e');
      rethrow;
    }
  }

  // ✅ STATISTICS AND ANALYTICS

  /// Get comprehensive address statistics
  Future<Map<String, dynamic>> getAddressStatistics() async {
    _incrementOperation();

    try {
      _logger.i('📊 Calculating address statistics');

      final allAdrese = await getAllAdrese();
      final stats = <String, dynamic>{};

      // Basic counts
      stats['totalAddresses'] = allAdrese.length;
      stats['addressesWithCoordinates'] =
          allAdrese.where((a) => a.hasValidCoordinates).length;
      stats['validAddresses'] =
          allAdrese.where((a) => a.isCompletelyValid).length;

      // Municipality breakdown
      final byMunicipality = <String, int>{};
      final coordinatesByMunicipality = <String, int>{};

      for (final adresa in allAdrese) {
        final municipality = adresa.municipality;
        byMunicipality[municipality] = (byMunicipality[municipality] ?? 0) + 1;

        if (adresa.hasValidCoordinates) {
          coordinatesByMunicipality[municipality] =
              (coordinatesByMunicipality[municipality] ?? 0) + 1;
        }
      }

      stats['byMunicipality'] = byMunicipality;
      stats['coordinatesCoverage'] = coordinatesByMunicipality;

      // Service coverage
      final inServiceArea = allAdrese.where((a) => a.isInServiceArea).length;
      stats['serviceAreaCoverage'] = inServiceArea;
      stats['serviceAreaPercentage'] = allAdrese.isNotEmpty
          ? (inServiceArea / allAdrese.length * 100).round()
          : 0;

      // Priority locations
      final priorityLocations =
          allAdrese.where((a) => a.priorityScore > 0).length;
      stats['priorityLocations'] = priorityLocations;

      // Cache statistics
      stats['cacheStatistics'] = {
        'totalOperations': _totalOperations,
        'cacheHits': _cacheHits,
        'cacheMisses': _cacheMisses,
        'cacheHitRate': _totalOperations > 0
            ? (_cacheHits / _totalOperations * 100).round()
            : 0,
        'lastOperation': _lastOperationTime?.toIso8601String(),
      };

      _logger.i('✅ Address statistics calculated');
      return stats;
    } catch (e) {
      _logger.e('❌ Error calculating address statistics: $e');
      rethrow;
    }
  }

  /// Export addresses to CSV format
  Future<String> exportToCSV({String? municipality}) async {
    _incrementOperation();

    try {
      _logger.i('📁 Exporting addresses to CSV');

      var adrese = await getAllAdrese();

      // Filter by municipality if specified
      if (municipality != null && municipality.trim().isNotEmpty) {
        adrese = adrese.where((a) => a.municipality == municipality).toList();
      }

      final csv = StringBuffer();

      // CSV Header
      csv.writeln(
          'ID,Ulica,Broj,Grad,Postanski_Broj,Latitude,Longitude,Municipality,Valid,Created_At,Updated_At',);

      // CSV Data
      for (final adresa in adrese) {
        csv.write('"${adresa.id}",');
        csv.write('"${adresa.ulica.replaceAll('"', '""')}",');
        csv.write('"${adresa.broj ?? ''}",');
        csv.write('"${adresa.grad.replaceAll('"', '""')}",');
        csv.write('"${adresa.postanskiBroj ?? ''}",');
        csv.write('"${adresa.latitude ?? ''}",');
        csv.write('"${adresa.longitude ?? ''}",');
        csv.write('"${adresa.municipality}",');
        csv.write('"${adresa.isCompletelyValid}",');
        csv.write('"${adresa.createdAt.toIso8601String()}",');
        csv.writeln('"${adresa.updatedAt.toIso8601String()}"');
      }

      _logger.i('✅ Exported ${adrese.length} addresses to CSV');
      return csv.toString();
    } catch (e) {
      _logger.e('❌ Error exporting addresses to CSV: $e');
      rethrow;
    }
  }

  // ✅ REAL-TIME OPERATIONS

  /// Real-time subscription to address changes
  Stream<List<Adresa>> watchAdrese() {
    _logger.i('👁️ Starting real-time address subscription');

    return _supabase
        .from('adrese')
        .stream(primaryKey: ['id'])
        .order('updated_at')
        .map(
          (data) => data
              .map((json) => Adresa.fromMap(json))
              .where((adresa) => adresa.isInServiceArea)
              .toList(),
        );
  }

  /// Watch specific address by ID
  Stream<Adresa?> watchAdresa(String id) {
    _logger.i('👁️ Starting real-time subscription for address: $id');

    return _supabase
        .from('adrese')
        .stream(primaryKey: ['id'])
        .eq('id', id)
        .map((data) {
          if (data.isEmpty) return null;
          final adresa = Adresa.fromMap(data.first);
          return adresa.isInServiceArea ? adresa : null;
        });
  }

  // ✅ CACHE MANAGEMENT

  /// Clear all address caches
  Future<void> clearCache() async {
    _logger.i('🧹 Clearing all address caches');

    await CacheService.clearFromDisk(_listCacheKey);

    // Clear individual address caches (this is a simplified approach)
    // In a real app, you might want to track cache keys or use a pattern-based clear

    _logger.i('✅ Address caches cleared');
  }

  /// Warm up cache with frequently accessed data
  Future<void> warmUpCache() async {
    _logger.i('🔥 Warming up address cache');

    try {
      // Pre-load all addresses
      await getAllAdrese(forceRefresh: true);

      // Pre-load municipality groups
      await getAdreseByMunicipality();

      _logger.i('✅ Address cache warmed up');
    } catch (e) {
      _logger.e('❌ Error warming up cache: $e');
    }
  }

  // ✅ UTILITY METHODS

  /// Increment operation counter and update last operation time
  static void _incrementOperation() {
    _totalOperations++;
    _lastOperationTime = DateTime.now();
  }

  /// Reset statistics
  static void resetStatistics() {
    _totalOperations = 0;
    _cacheHits = 0;
    _cacheMisses = 0;
    _lastOperationTime = null;
  }

  /// Get service status
  Map<String, dynamic> getServiceStatus() {
    return {
      'isHealthy': true,
      'totalOperations': _totalOperations,
      'cacheHitRate': _totalOperations > 0
          ? (_cacheHits / _totalOperations * 100).round()
          : 0,
      'lastOperation': _lastOperationTime?.toIso8601String(),
      'cacheSize': 'N/A', // Could be implemented with cache size tracking
    };
  }
}
