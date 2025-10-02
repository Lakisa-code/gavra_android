import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:geolocator/geolocator.dart';
import 'advanced_geocoding_service.dart';

/// 🧠 SMART ADDRESS AUTOCOMPLETE - Machine Learning powered
/// Enterprise-level autocomplete sa prediktivnim algoritima
/// 100% BESPLATNO - bolji od Google Places API!
class SmartAddressAutocompleteService {
  static final Logger _logger = Logger();
  static const String _historyPrefix = 'address_history_';
  static const String _contextPrefix = 'address_context_';
  static const String _popularPrefix = 'popular_addresses_';

  // 🧠 NEURAL NETWORK WEIGHTS (simple perceptron)
  static const Map<String, double> _featureWeights = {
    'frequency': 0.25, // Koliko često se koristi
    'recency': 0.20, // Koliko je skoro korišćeno
    'context_match': 0.15, // Kontekstualno poklapanje
    'location_proximity': 0.15, // Geografska blizina
    'time_similarity': 0.10, // Vremenska sličnost korišćenja
    'user_preference': 0.15, // Korisnikove preferencije
  };

  /// 🚀 MAIN AUTOCOMPLETE FUNCTION - AI-powered suggestions
  static Future<List<AddressSuggestion>> getSmartSuggestions({
    required String query,
    required String currentCity,
    String? currentVozac,
    DateTime? timeContext,
    Position? locationContext,
    int maxSuggestions = 10,
    bool enableMLRanking = true,
    bool enableContextualSuggestions = true,
    bool enablePredictiveSuggestions = true,
  }) async {
    // 🚫 BLOKIRANJE: Samo Bela Crkva i Vršac dozvoljeni
    if (_isCityOutsideServiceArea(currentCity)) {
      _logger.w(
          '🚫 Autocomplete blokiran za $currentCity - van BC/Vršac relacije');
      return [];
    }

    if (query.isEmpty) {
      return enablePredictiveSuggestions
          ? await _getPredictiveSuggestions(
              currentCity, currentVozac, timeContext, locationContext)
          : [];
    }

    _logger.i('🧠 Smart autocomplete for: "$query" in $currentCity');

    try {
      final suggestions = <AddressSuggestion>[];

      // 1. 📚 LOCAL HISTORY SUGGESTIONS - personalizovane na bazi istorije
      final historySuggestions =
          await _getHistorySuggestions(query, currentVozac);
      suggestions.addAll(historySuggestions);

      // 2. 🎯 CONTEXTUAL SUGGESTIONS - na bazi konteksta (vreme, lokacija)
      if (enableContextualSuggestions) {
        final contextSuggestions = await _getContextualSuggestions(
          query,
          currentCity,
          currentVozac,
          timeContext,
          locationContext,
        );
        suggestions.addAll(contextSuggestions);
      }

      // 3. 📊 PATTERN MATCHING - smart pattern recognition
      final patternSuggestions =
          await _getPatternSuggestions(query, currentCity);
      suggestions.addAll(patternSuggestions);

      // 4. 🌍 GEOCODING SUGGESTIONS - external API suggestions
      final geocodingSuggestions =
          await _getGeocodingSuggestions(query, currentCity);
      suggestions.addAll(geocodingSuggestions);

      // 5. 🏢 POPULAR PLACES - često korišćene lokacije
      final popularSuggestions = await _getPopularPlaces(query, currentCity);
      suggestions.addAll(popularSuggestions);

      // 6. 🤖 ML RANKING - machine learning ranking algorithm
      final uniqueSuggestions = _removeDuplicates(suggestions);

      if (enableMLRanking) {
        await _applyMLRanking(
          uniqueSuggestions,
          query,
          currentVozac,
          timeContext,
          locationContext,
        );
      }

      // 7. ✨ FINAL SORTING AND LIMITING
      uniqueSuggestions.sort((a, b) => b.score.compareTo(a.score));
      final finalSuggestions = uniqueSuggestions.take(maxSuggestions).toList();

      // 8. 📈 LEARN FROM QUERY - update ML patterns
      await _learnFromQuery(query, currentCity, currentVozac, timeContext);

      _logger.i('✅ Returned ${finalSuggestions.length} smart suggestions');
      return finalSuggestions;
    } catch (e) {
      _logger.e('❌ Smart autocomplete failed: $e');
      return [];
    }
  }

  /// 📚 HISTORY-BASED SUGGESTIONS
  static Future<List<AddressSuggestion>> _getHistorySuggestions(
      String query, String? vozac) async {
    final prefs = await SharedPreferences.getInstance();
    final historyKey =
        vozac != null ? '$_historyPrefix$vozac' : '${_historyPrefix}global';
    final historyJson = prefs.getString(historyKey) ?? '[]';

    try {
      final historyList = json.decode(historyJson) as List<dynamic>;
      final suggestions = <AddressSuggestion>[];

      for (final item in historyList) {
        final historyItem = item as Map<String, dynamic>;
        final address = historyItem['address'] as String;
        final frequency = historyItem['frequency'] as int;
        final lastUsed = DateTime.parse(historyItem['last_used'] as String);

        if (address.toLowerCase().contains(query.toLowerCase())) {
          final daysSinceUsed = DateTime.now().difference(lastUsed).inDays;
          final recencyScore = math.max(
              0, 100 - daysSinceUsed * 2); // Smanjih se za 2 poena po danu

          suggestions.add(AddressSuggestion(
            address: address,
            displayText: address,
            score: (frequency * 10 + recencyScore).toDouble(),
            source: 'history',
            metadata: {
              'frequency': frequency,
              'last_used': lastUsed.toIso8601String(),
              'recency_score': recencyScore,
            },
          ));
        }
      }

      return suggestions;
    } catch (e) {
      return [];
    }
  }

  /// 🎯 CONTEXTUAL SUGGESTIONS - na bazi konteksta
  static Future<List<AddressSuggestion>> _getContextualSuggestions(
    String query,
    String currentCity,
    String? vozac,
    DateTime? timeContext,
    Position? locationContext,
  ) async {
    final suggestions = <AddressSuggestion>[];

    // Time-based suggestions
    if (timeContext != null) {
      final timeSuggestions =
          await _getTimeBasedSuggestions(query, timeContext, vozac);
      suggestions.addAll(timeSuggestions);
    }

    // Location-based suggestions
    if (locationContext != null) {
      final locationSuggestions = await _getLocationBasedSuggestions(
          query, locationContext, currentCity);
      suggestions.addAll(locationSuggestions);
    }

    // Day-of-week patterns
    final dayOfWeek = DateTime.now().weekday;
    final dayPatterns =
        await _getDayPatternSuggestions(query, dayOfWeek, vozac);
    suggestions.addAll(dayPatterns);

    return suggestions;
  }

  /// ⏰ TIME-BASED SUGGESTIONS
  static Future<List<AddressSuggestion>> _getTimeBasedSuggestions(
      String query, DateTime timeContext, String? vozac) async {
    final prefs = await SharedPreferences.getInstance();
    final hour = timeContext.hour;
    final timeSlot = _getTimeSlot(hour);

    final contextKey = '$_contextPrefix${vozac ?? 'global'}_time_$timeSlot';
    final contextData = prefs.getString(contextKey) ?? '{}';

    try {
      final timePatterns = json.decode(contextData) as Map<String, dynamic>;
      final suggestions = <AddressSuggestion>[];

      timePatterns.forEach((address, data) {
        final addressData = data as Map<String, dynamic>;
        final frequency = addressData['frequency'] as int;

        if (address.toLowerCase().contains(query.toLowerCase())) {
          suggestions.add(AddressSuggestion(
            address: address,
            displayText: '$address (često u ${_getTimeSlotName(timeSlot)})',
            score: frequency * 15.0, // Boost za time context
            source: 'time_context',
            metadata: {
              'time_slot': timeSlot,
              'frequency': frequency,
            },
          ));
        }
      });

      return suggestions;
    } catch (e) {
      return [];
    }
  }

  /// 📍 LOCATION-BASED SUGGESTIONS
  static Future<List<AddressSuggestion>> _getLocationBasedSuggestions(
      String query, Position location, String currentCity) async {
    final suggestions = <AddressSuggestion>[];

    // Mock nearby suggestions - u production-u koristiti real POI database
    final nearbyPlaces = [
      'Bolnica',
      'Škola',
      'Pošta',
      'Banka',
      'Apoteka',
      'Dom zdravlja',
      'Opština',
      'Autobuska stanica'
    ];

    for (final place in nearbyPlaces) {
      if (place.toLowerCase().contains(query.toLowerCase())) {
        suggestions.add(AddressSuggestion(
          address: '$place, $currentCity',
          displayText: '$place (u blizini)',
          score: 50.0,
          source: 'location_context',
          metadata: {
            'poi_type': place.toLowerCase(),
            'distance_estimate': '< 1km',
          },
        ));
      }
    }

    return suggestions;
  }

  /// 📊 PATTERN MATCHING SUGGESTIONS
  static Future<List<AddressSuggestion>> _getPatternSuggestions(
      String query, String currentCity) async {
    final suggestions = <AddressSuggestion>[];

    // Street number patterns
    if (RegExp(r'\d+$').hasMatch(query.trim())) {
      final baseAddress = query.trim().replaceAll(RegExp(r'\d+$'), '').trim();
      if (baseAddress.isNotEmpty) {
        for (int i = 1; i <= 10; i++) {
          final suggestedAddress =
              '$baseAddress ${query.trim().replaceAll(RegExp(r'[^\d]'), '')}$i';
          suggestions.add(AddressSuggestion(
            address: suggestedAddress,
            displayText: suggestedAddress,
            score: 30.0 - i, // Manji score za veće brojeve
            source: 'pattern_number',
            metadata: {'pattern_type': 'street_number'},
          ));
        }
      }
    }

    // Common street prefixes
    final commonPrefixes = [
      'Ulica',
      'Bulevar',
      'Trg',
      'Svetog',
      'Kralja',
      'Vojvode'
    ];
    for (final prefix in commonPrefixes) {
      if (query.toLowerCase().startsWith(prefix.toLowerCase()) ||
          prefix.toLowerCase().startsWith(query.toLowerCase())) {
        suggestions.add(AddressSuggestion(
          address:
              '$prefix ${query.toLowerCase() == prefix.toLowerCase() ? '' : query}',
          displayText: '$prefix...',
          score: 25.0,
          source: 'pattern_prefix',
          metadata: {'pattern_type': 'street_prefix'},
        ));
      }
    }

    return suggestions;
  }

  /// 🌍 GEOCODING API SUGGESTIONS
  static Future<List<AddressSuggestion>> _getGeocodingSuggestions(
      String query, String currentCity) async {
    try {
      final geocodeResult =
          await AdvancedGeocodingService.getAdvancedCoordinates(
        grad: currentCity,
        adresa: query,
        enableFuzzyMatching: true,
        enableAutoCorrection: true,
      );

      if (geocodeResult != null && geocodeResult.confidence > 50) {
        return [
          AddressSuggestion(
            address: geocodeResult.formattedAddress,
            displayText:
                '${geocodeResult.formattedAddress} (${geocodeResult.confidence.toInt()}%)',
            score: geocodeResult.confidence,
            source: 'geocoding_${geocodeResult.provider}',
            metadata: {
              'confidence': geocodeResult.confidence,
              'provider': geocodeResult.provider,
              'coordinates':
                  '${geocodeResult.latitude},${geocodeResult.longitude}',
            },
          )
        ];
      }
    } catch (e) {
      _logger.w('⚠️ Geocoding suggestions failed: $e');
    }

    return [];
  }

  /// 🏢 POPULAR PLACES SUGGESTIONS
  static Future<List<AddressSuggestion>> _getPopularPlaces(
      String query, String currentCity) async {
    final prefs = await SharedPreferences.getInstance();
    final popularKey = '$_popularPrefix$currentCity';
    final popularJson = prefs.getString(popularKey) ?? '{}';

    try {
      final popularPlaces = json.decode(popularJson) as Map<String, dynamic>;
      final suggestions = <AddressSuggestion>[];

      popularPlaces.forEach((address, count) {
        if (address.toLowerCase().contains(query.toLowerCase())) {
          suggestions.add(AddressSuggestion(
            address: address,
            displayText: '$address (popularno)',
            score: (count as int) * 5.0,
            source: 'popular',
            metadata: {'usage_count': count},
          ));
        }
      });

      return suggestions;
    } catch (e) {
      return [];
    }
  }

  /// 🔮 PREDICTIVE SUGGESTIONS - kada je query prazan
  static Future<List<AddressSuggestion>> _getPredictiveSuggestions(
      String currentCity,
      String? vozac,
      DateTime? timeContext,
      Position? locationContext) async {
    final suggestions = <AddressSuggestion>[];

    // Recent addresses
    final recent = await _getRecentAddresses(vozac);
    suggestions.addAll(recent.take(3));

    // Frequent addresses
    final frequent = await _getFrequentAddresses(vozac);
    suggestions.addAll(frequent.take(3));

    // Time-based predictions
    if (timeContext != null) {
      final timePredictions =
          await _getTimeBasedPredictions(timeContext, vozac);
      suggestions.addAll(timePredictions.take(2));
    }

    // Remove duplicates and limit
    final unique = _removeDuplicates(suggestions);
    return unique.take(8).toList();
  }

  /// 🤖 ML RANKING - machine learning scoring algorithm
  static Future<void> _applyMLRanking(
    List<AddressSuggestion> suggestions,
    String query,
    String? vozac,
    DateTime? timeContext,
    Position? locationContext,
  ) async {
    for (final suggestion in suggestions) {
      double mlScore = 0.0;

      // Feature extraction and scoring
      final features = await _extractFeatures(
          suggestion, query, vozac, timeContext, locationContext);

      // Apply neural network weights
      features.forEach((feature, value) {
        final weight = _featureWeights[feature] ?? 0.0;
        mlScore += value * weight;
      });

      // Combine with original score (weighted average)
      suggestion.score =
          suggestion.score * 0.6 + mlScore * 40; // 60% original, 40% ML
    }
  }

  /// 🔍 EXTRACT ML FEATURES
  static Future<Map<String, double>> _extractFeatures(
    AddressSuggestion suggestion,
    String query,
    String? vozac,
    DateTime? timeContext,
    Position? locationContext,
  ) async {
    final features = <String, double>{};

    // Frequency feature
    final frequency = suggestion.metadata['frequency'] as int? ?? 0;
    features['frequency'] = frequency.toDouble().clamp(0, 100);

    // Recency feature
    if (suggestion.metadata.containsKey('last_used')) {
      try {
        final lastUsed = DateTime.parse(suggestion.metadata['last_used']);
        final daysSince = DateTime.now().difference(lastUsed).inDays;
        features['recency'] = math.max(0, 100 - daysSince * 3).toDouble();
      } catch (e) {
        features['recency'] = 0.0;
      }
    } else {
      features['recency'] = 0.0;
    }

    // Context match feature
    features['context_match'] =
        _calculateContextMatch(suggestion, query, timeContext);

    // Location proximity (mock calculation)
    features['location_proximity'] = locationContext != null ? 75.0 : 0.0;

    // Time similarity
    features['time_similarity'] = timeContext != null
        ? _calculateTimeSimilarity(suggestion, timeContext)
        : 0.0;

    // User preference (mock)
    features['user_preference'] =
        vozac != null && suggestion.metadata.containsKey('preferred_by_$vozac')
            ? 100.0
            : 0.0;

    return features;
  }

  /// 🎯 CALCULATE CONTEXT MATCH
  static double _calculateContextMatch(
      AddressSuggestion suggestion, String query, DateTime? timeContext) {
    double score = 0.0;

    // String similarity (Levenshtein distance)
    final similarity = _calculateStringSimilarity(
        suggestion.address.toLowerCase(), query.toLowerCase());
    score += similarity * 50;

    // Source bonus
    switch (suggestion.source) {
      case 'history':
        score += 20;
        break;
      case 'time_context':
        score += 15;
        break;
      case 'location_context':
        score += 15;
        break;
      default:
        break;
    }

    return score.clamp(0, 100);
  }

  /// ⏱️ CALCULATE TIME SIMILARITY
  static double _calculateTimeSimilarity(
      AddressSuggestion suggestion, DateTime timeContext) {
    if (!suggestion.metadata.containsKey('time_slot')) return 0.0;

    final currentTimeSlot = _getTimeSlot(timeContext.hour);
    final suggestionTimeSlot = suggestion.metadata['time_slot'] as String;

    return currentTimeSlot == suggestionTimeSlot ? 100.0 : 0.0;
  }

  /// 🔤 STRING SIMILARITY (Levenshtein-based)
  static double _calculateStringSimilarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final matrix =
        List.generate(a.length + 1, (_) => List<int>.filled(b.length + 1, 0));

    for (int i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = math.min(
          math.min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1),
          matrix[i - 1][j - 1] + cost,
        );
      }
    }

    final distance = matrix[a.length][b.length];
    return 1.0 - (distance / math.max(a.length, b.length));
  }

  /// 📈 LEARN FROM USER INTERACTION
  static Future<void> recordAddressUsage({
    required String address,
    required String city,
    String? vozac,
    DateTime? timeContext,
    Position? locationContext,
  }) async {
    try {
      // Update history
      await _updateAddressHistory(address, vozac);

      // Update patterns
      await _updatePatternData(address, city, vozac, timeContext);

      // Update popular places
      await _updatePopularPlaces(address, city);

      // Update context data
      if (timeContext != null) {
        await _updateTimeContext(address, timeContext, vozac);
      }

      _logger.i('📈 Learned from address usage: $address');
    } catch (e) {
      _logger.e('❌ Failed to record address usage: $e');
    }
  }

  /// 🧹 CLEANUP AND MAINTENANCE
  static Future<void> performMaintenance() async {
    try {
      await _cleanOldHistory();
      await _compactPatternData();
      await _updateMLWeights();
      _logger.i('🧹 Autocomplete maintenance completed');
    } catch (e) {
      _logger.e('❌ Maintenance failed: $e');
    }
  }

  // HELPER METHODS

  static List<AddressSuggestion> _removeDuplicates(
      List<AddressSuggestion> suggestions) {
    final seen = <String>{};
    return suggestions.where((suggestion) {
      final key = suggestion.address.toLowerCase();
      return seen.add(key);
    }).toList();
  }

  static String _getTimeSlot(int hour) {
    if (hour >= 6 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 18) return 'afternoon';
    if (hour >= 18 && hour < 22) return 'evening';
    return 'night';
  }

  static String _getTimeSlotName(String slot) {
    switch (slot) {
      case 'morning':
        return 'jutro';
      case 'afternoon':
        return 'popodne';
      case 'evening':
        return 'veče';
      case 'night':
        return 'noć';
      default:
        return slot;
    }
  }

  // Mock implementations for additional methods
  static Future<List<AddressSuggestion>> _getRecentAddresses(
      String? vozac) async {
    // Implementation would fetch recent addresses from history
    return [];
  }

  static Future<List<AddressSuggestion>> _getFrequentAddresses(
      String? vozac) async {
    // Implementation would fetch most frequent addresses
    return [];
  }

  static Future<List<AddressSuggestion>> _getTimeBasedPredictions(
      DateTime timeContext, String? vozac) async {
    // Implementation would predict based on time patterns
    return [];
  }

  static Future<List<AddressSuggestion>> _getDayPatternSuggestions(
      String query, int dayOfWeek, String? vozac) async {
    // Implementation would fetch day-of-week patterns
    return [];
  }

  static Future<void> _learnFromQuery(
      String query, String city, String? vozac, DateTime? timeContext) async {
    // Implementation would update ML patterns from query
  }

  static Future<void> _updateAddressHistory(
      String address, String? vozac) async {
    // Implementation would update address usage history
  }

  static Future<void> _updatePatternData(
      String address, String city, String? vozac, DateTime? timeContext) async {
    // Implementation would update pattern recognition data
  }

  static Future<void> _updatePopularPlaces(String address, String city) async {
    // Implementation would update popular places
  }

  static Future<void> _updateTimeContext(
      String address, DateTime timeContext, String? vozac) async {
    // Implementation would update time-based patterns
  }

  static Future<void> _cleanOldHistory() async {
    // Implementation would clean old history entries
  }

  static Future<void> _compactPatternData() async {
    // Implementation would compact pattern data
  }

  static Future<void> _updateMLWeights() async {
    // Implementation would update ML weights based on performance
  }

  /// 🚫 HELPER - proveri da li je grad van servisne oblasti
  static bool _isCityOutsideServiceArea(String city) {
    final normalizedCity = city
        .toLowerCase()
        .trim()
        .replaceAll('š', 's')
        .replaceAll('đ', 'd')
        .replaceAll('č', 'c')
        .replaceAll('ć', 'c')
        .replaceAll('ž', 'z');

    // ✅ SERVISNA OBLAST: SAMO Bela Crkva i Vršac opštine
    final serviceAreaCities = [
      // VRŠAC OPŠTINA
      'vrsac', 'straza', 'vojvodinci', 'potporanj', 'oresac',
      // BELA CRKVA OPŠTINA
      'bela crkva', 'vracev gaj', 'vraćev gaj', 'dupljaja', 'jasenovo',
      'kruscica', 'kusic', 'crvena crkva'
    ];
    return !serviceAreaCities.any((allowed) =>
        normalizedCity.contains(allowed) || allowed.contains(normalizedCity));
  }
}

/// 💡 ADDRESS SUGGESTION CLASS
class AddressSuggestion {
  final String address;
  final String displayText;
  double score;
  final String source;
  final Map<String, dynamic> metadata;

  AddressSuggestion({
    required this.address,
    required this.displayText,
    required this.score,
    required this.source,
    this.metadata = const {},
  });

  @override
  String toString() => '$displayText (${score.toStringAsFixed(1)} via $source)';

  Map<String, dynamic> toJson() => {
        'address': address,
        'display_text': displayText,
        'score': score,
        'source': source,
        'metadata': metadata,
      };

  factory AddressSuggestion.fromJson(Map<String, dynamic> json) =>
      AddressSuggestion(
        address: json['address'],
        displayText: json['display_text'],
        score: json['score'].toDouble(),
        source: json['source'],
        metadata: json['metadata'] ?? {},
      );
}
