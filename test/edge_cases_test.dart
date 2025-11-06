import 'package:flutter_test/flutter_test.dart';

void main() {
  group('🚨 EDGE CASES I ERROR SCENARIOS', () {
    // Test null safety i edge cases
    test('🔒 Null Safety i Edge Cases', () {
      print('🔒 Testiranje null safety i edge cases...');

      // Test null putnik data
      const nullPutnikData = <String, dynamic>{
        'id': null,
        'ime': null,
        'tip': null,
        'aktivan': null,
        'vozac_id': null,
      };

      // Test handling null values
      final safeId = nullPutnikData['id'] ?? 'default_id';
      final safeIme = nullPutnikData['ime'] ?? 'Unknown';
      final safeTip = nullPutnikData['tip'] ?? 'radnik';
      final safeAktivan = nullPutnikData['aktivan'] ?? false;

      expect(safeId, 'default_id');
      expect(safeIme, 'Unknown');
      expect(safeTip, 'radnik');
      expect(safeAktivan, false);
      print('  ✅ Null values handled gracefully');

      // Test empty strings
      const emptyStringData = {
        'ime': '',
        'telefon': '   ',
        'adresa': '\t\n',
        'napomena': '          ',
      };

      final cleanedData = <String, String>{};
      for (final entry in emptyStringData.entries) {
        final cleanValue = entry.value.trim();
        cleanedData[entry.key] = cleanValue.isEmpty ? 'N/A' : cleanValue;
      }

      expect(cleanedData['ime'], 'N/A');
      expect(cleanedData['telefon'], 'N/A');
      expect(cleanedData['adresa'], 'N/A');
      expect(cleanedData['napomena'], 'N/A');
      print('  ✅ Empty strings sanitized');

      // Test boundary values
      const boundaryTests = [
        {'value': -1, 'min': 0, 'max': 1000, 'expected': 0},
        {'value': 1001, 'min': 0, 'max': 1000, 'expected': 1000},
        {'value': 500, 'min': 0, 'max': 1000, 'expected': 500},
        {'value': 0, 'min': 0, 'max': 1000, 'expected': 0},
        {'value': 1000, 'min': 0, 'max': 1000, 'expected': 1000},
      ];

      for (final test in boundaryTests) {
        final value = test['value'] as int;
        final min = test['min'] as int;
        final max = test['max'] as int;
        final expected = test['expected'] as int;

        final clampedValue = value.clamp(min, max);
        expect(
          clampedValue,
          expected,
          reason: 'Value $value should clamp to $expected between $min-$max',
        );
      }
      print('  ✅ Boundary values handled correctly');

      print('🎯 NULL SAFETY I EDGE CASES TESTIRANI!');
    });

    // Test date/time edge cases
    test('📅 Date/Time Edge Cases', () {
      print('📅 Testiranje date/time edge cases...');

      // Test različitih date formata
      final dateTestCases = [
        {'input': '2025-11-06', 'valid': true, 'format': 'ISO'},
        {'input': '06.11.2025', 'valid': false, 'format': 'Serbian'}, // DateTime.parse won't handle this
        {'input': '11/06/2025', 'valid': false, 'format': 'US'},
        {'input': '2025-13-01', 'valid': false, 'format': 'Invalid month'},
        {'input': '2025-11-32', 'valid': false, 'format': 'Invalid day'},
        {'input': '', 'valid': false, 'format': 'Empty'},
        {'input': 'invalid', 'valid': false, 'format': 'Invalid string'},
      ];

      for (final testCase in dateTestCases) {
        final input = testCase['input'] as String;
        final expectedValid = testCase['valid'] as bool;

        var actualValid = false;

        try {
          if (input.isNotEmpty && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(input)) {
            final parts = input.split('-');
            final month = int.parse(parts[1]);
            final day = int.parse(parts[2]);

            // Basic range validation before DateTime.parse
            if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
              DateTime.parse(input);
              actualValid = true;
            }
          }
        } catch (e) {
          actualValid = false;
        }

        expect(
          actualValid,
          expectedValid,
          reason: 'Date "$input" validation should be $expectedValid',
        );
      }
      print('  ✅ Date format validation: ${dateTestCases.length} cases tested');

      // Test edge dates
      final edgeDates = [
        DateTime(2025), // Start of year
        DateTime(2025, 12, 31), // End of year
        DateTime(2025, 2, 28), // February (non-leap year)
        DateTime(2024, 2, 29), // Leap year
        DateTime(1970), // Unix epoch
        DateTime(2038, 1, 19), // 32-bit timestamp limit
      ];

      for (final date in edgeDates) {
        expect(date.year, greaterThan(1900));
        expect(date.month, inInclusiveRange(1, 12));
        expect(date.day, inInclusiveRange(1, 31));

        // Test serialization
        final isoString = date.toIso8601String();
        final parsedBack = DateTime.parse(isoString);
        expect(parsedBack.year, date.year);
        expect(parsedBack.month, date.month);
        expect(parsedBack.day, date.day);
      }
      print('  ✅ Edge dates handling: ${edgeDates.length} dates tested');

      // Test timezone handling
      final now = DateTime.now();
      final utcNow = DateTime.now().toUtc();
      final localNow = utcNow.toLocal();

      expect(now.day, localNow.day); // Should be same day (usually)
      expect(utcNow.isUtc, true);
      expect(localNow.isUtc, false);
      print('  ✅ Timezone handling: UTC/Local conversion working');

      print('🎯 DATE/TIME EDGE CASES TESTIRANI!');
    });

    // Test string manipulation edge cases
    test('🔤 String Manipulation Edge Cases', () {
      print('🔤 Testiranje string manipulation edge cases...');

      // Test special characters
      const specialStringTests = [
        {'input': 'Đorđe Čović', 'type': 'Serbian characters'},
        {'input': 'Müller', 'type': 'German umlaut'},
        {'input': 'José', 'type': 'Spanish accent'},
        {'input': '😀🚗💰', 'type': 'Emojis'},
        {'input': 'test\nwith\nnewlines', 'type': 'Newlines'},
        {'input': 'tabs\there', 'type': 'Tabs'},
        {'input': '<script>alert(1)</script>', 'type': 'HTML/JS injection'},
        {'input': 'SELECT * FROM users', 'type': 'SQL injection attempt'},
        {'input': '../../etc/passwd', 'type': 'Path traversal'},
        {
          'input':
              'very_long_string_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'type': 'Very long string',
        },
      ];

      for (final test in specialStringTests) {
        final input = test['input'] as String;
        final type = test['type'] as String;

        // Test basic string operations
        expect(input.length, greaterThanOrEqualTo(0));

        // Test sanitization
        final sanitized = input
            .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
            .replaceAll(RegExp(r'[<>"' + "'" + r']'), '') // Remove dangerous chars
            .trim();

        expect(sanitized.length, lessThanOrEqualTo(input.length));
        print('  ✅ $type: ${input.length} chars -> ${sanitized.length} chars sanitized');
      }

      // Test string encoding
      const utf8TestStrings = [
        'ASCII test',
        'Ћирилица тест',
        'Латиница тест',
        '中文测试',
        '🌍🇷🇸🇺🇸',
      ];

      for (final testString in utf8TestStrings) {
        final bytes = testString.codeUnits;
        final reconstructed = String.fromCharCodes(bytes);
        expect(reconstructed, testString);
      }
      print('  ✅ UTF-8 encoding: ${utf8TestStrings.length} strings tested');

      print('🎯 STRING MANIPULATION EDGE CASES TESTIRANI!');
    });

    // Test numeric edge cases
    test('🔢 Numeric Edge Cases', () {
      print('🔢 Testiranje numeric edge cases...');

      // Test floating point precision
      const precisionTests = [
        {'a': 0.1, 'b': 0.2, 'expected_sum': 0.3},
        {'a': 1.0, 'b': 2.0, 'expected_sum': 3.0},
        {'a': 0.00001, 'b': 0.00002, 'expected_sum': 0.00003},
      ];

      for (final test in precisionTests) {
        final a = test['a'] as double;
        final b = test['b'] as double;
        final expectedSum = test['expected_sum'] as double;
        final actualSum = a + b;

        // Use closeTo for floating point comparison
        expect(
          actualSum,
          closeTo(expectedSum, 0.0001),
          reason: '$a + $b should be close to $expectedSum',
        );
      }
      print('  ✅ Floating point precision handled');

      // Test division by zero and infinity
      const divisionTests = [
        {'numerator': 1.0, 'denominator': 0.0, 'expected': double.infinity},
        {'numerator': -1.0, 'denominator': 0.0, 'expected': double.negativeInfinity},
        {'numerator': 0.0, 'denominator': 0.0, 'expected': double.nan},
      ];

      for (final test in divisionTests) {
        final numerator = test['numerator'] as double;
        final denominator = test['denominator'] as double;
        final result = numerator / denominator;

        if ((test['expected'] as double).isInfinite) {
          expect(result.isInfinite, true);
        } else if ((test['expected'] as double).isNaN) {
          expect(result.isNaN, true);
        }
      }
      print('  ✅ Division by zero handled');

      // Test number parsing edge cases
      const numberParsingTests = [
        {'input': '123', 'expected': 123, 'valid': true},
        {'input': '123.45', 'expected': 123.45, 'valid': true},
        {'input': '-123', 'expected': -123, 'valid': true},
        {'input': '0', 'expected': 0, 'valid': true},
        {'input': '', 'expected': null, 'valid': false},
        {'input': 'abc', 'expected': null, 'valid': false},
        {'input': '123abc', 'expected': null, 'valid': false},
        {'input': '∞', 'expected': null, 'valid': false},
      ];

      for (final test in numberParsingTests) {
        final input = test['input'] as String;
        final expectedValid = test['valid'] as bool;

        var actualValid = false;

        try {
          if (input.isNotEmpty) {
            num.parse(input);
            actualValid = true;
          }
        } catch (e) {
          actualValid = false;
        }

        expect(
          actualValid,
          expectedValid,
          reason: 'Parsing "$input" should be $expectedValid',
        );
      }
      print('  ✅ Number parsing: ${numberParsingTests.length} cases tested');

      print('🎯 NUMERIC EDGE CASES TESTIRANI!');
    });

    // Test collection edge cases
    test('📋 Collection Edge Cases', () {
      print('📋 Testiranje collection edge cases...');

      // Test empty collections
      const emptyList = <String>[];
      const emptyMap = <String, String>{};
      const emptySet = <String>{};

      expect(emptyList.isEmpty, true);
      expect(emptyMap.isEmpty, true);
      expect(emptySet.isEmpty, true);

      // Test operations on empty collections
      expect(emptyList.firstOrNull, null);
      expect(emptyList.lastOrNull, null);
      expect(emptyMap['nonexistent'], null);

      print('  ✅ Empty collections handled');

      // Test duplicate handling
      final listWithDuplicates = ['a', 'b', 'a', 'c', 'b', 'a'];
      final uniqueSet = listWithDuplicates.toSet();
      final uniqueList = uniqueSet.toList();

      expect(listWithDuplicates.length, 6);
      expect(uniqueSet.length, 3);
      expect(uniqueList.length, 3);
      expect(uniqueList.contains('a'), true);
      expect(uniqueList.contains('b'), true);
      expect(uniqueList.contains('c'), true);

      print('  ✅ Duplicate handling: ${listWithDuplicates.length} -> ${uniqueList.length} unique items');

      // Test large collection operations
      final largeList = List.generate(10000, (i) => i);
      final evenNumbers = largeList.where((n) => n % 2 == 0).toList();
      final sum = largeList.fold(0, (prev, element) => prev + element);

      expect(largeList.length, 10000);
      expect(evenNumbers.length, 5000);
      expect(sum, 49995000); // Sum of 0 to 9999

      print('  ✅ Large collections: 10K items, ${evenNumbers.length} even, sum=$sum');

      // Test nested collections
      final nestedList = [
        ['a', 'b'],
        ['c', 'd', 'e'],
        <String>[],
        ['f'],
      ];

      final flattened = nestedList.expand((list) => list).toList();
      final totalItems = nestedList.fold(0, (sum, list) => sum + list.length);

      expect(nestedList.length, 4);
      expect(flattened.length, 6);
      expect(totalItems, 6);
      expect(flattened.contains('a'), true);
      expect(flattened.contains('f'), true);

      print('  ✅ Nested collections: ${nestedList.length} lists, ${flattened.length} total items');

      print('🎯 COLLECTION EDGE CASES TESTIRANI!');
    });

    // Test async/await edge cases
    test('⏱️ Async/Await Edge Cases', () async {
      print('⏱️ Testiranje async/await edge cases...');

      // Test timeout handling
      try {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        print('  ✅ Normal async operation completed');
      } catch (e) {
        fail('Normal async operation should not fail');
      }

      // Test multiple futures
      final futures = <Future<int>>[];
      for (int i = 0; i < 10; i++) {
        futures.add(
          Future.delayed(
            Duration(milliseconds: 10 + i * 5),
            () => i * 2,
          ),
        );
      }

      final results = await Future.wait(futures);
      expect(results.length, 10);
      expect(results[0], 0);
      expect(results[9], 18);
      print('  ✅ Multiple futures: ${results.length} completed');

      // Test future error handling
      var errorCaught = false;
      try {
        await Future.delayed(const Duration(milliseconds: 10), () {
          throw Exception('Test error');
        });
      } catch (e) {
        errorCaught = true;
        expect(e.toString().contains('Test error'), true);
      }
      expect(errorCaught, true);
      print('  ✅ Future error handling: exception caught');

      // Test future timeout
      var timeoutOccurred = false;
      try {
        await Future<void>.delayed(const Duration(milliseconds: 100)).timeout(const Duration(milliseconds: 50));
      } catch (e) {
        timeoutOccurred = true;
        expect(e.toString().contains('TimeoutException'), true);
      }
      expect(timeoutOccurred, true);
      print('  ✅ Future timeout: handled correctly');

      // Test stream handling
      final streamController = Stream.periodic(
        const Duration(milliseconds: 10),
        (count) => count,
      ).take(5);

      final streamResults = <int>[];
      await for (final value in streamController) {
        streamResults.add(value);
      }

      expect(streamResults.length, 5);
      expect(streamResults, [0, 1, 2, 3, 4]);
      print('  ✅ Stream handling: ${streamResults.length} values received');

      print('🎯 ASYNC/AWAIT EDGE CASES TESTIRANI!');
    });

    // Test error recovery scenarios
    test('🔄 Error Recovery Scenarios', () async {
      print('🔄 Testiranje error recovery scenarios...');

      // Test retry mechanism
      var attemptCount = 0;
      const maxAttempts = 3;

      Future<bool> unreliableOperation() async {
        attemptCount++;
        if (attemptCount < maxAttempts) {
          throw Exception('Temporary failure');
        }
        return true;
      }

      // Retry logic
      var success = false;
      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          await unreliableOperation();
          success = true;
          break;
        } catch (e) {
          if (attempt == maxAttempts) {
            // Final attempt failed
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      }

      expect(success, true);
      expect(attemptCount, maxAttempts);
      print('  ✅ Retry mechanism: success after $attemptCount attempts');

      // Test circuit breaker pattern
      var circuitBreakerOpen = false;
      var failureCount = 0;
      const failureThreshold = 5;

      Future<bool> serviceCall() async {
        if (circuitBreakerOpen) {
          throw Exception('Circuit breaker open');
        }

        // Simulate failures
        if (failureCount < failureThreshold) {
          failureCount++;
          throw Exception('Service failure');
        }

        return true;
      }

      // Test circuit breaker logic
      for (int i = 0; i < failureThreshold + 2; i++) {
        try {
          await serviceCall();
        } catch (e) {
          if (failureCount >= failureThreshold) {
            circuitBreakerOpen = true;
          }
        }
      }

      expect(failureCount, failureThreshold);
      expect(circuitBreakerOpen, true);
      print('  ✅ Circuit breaker: opened after $failureCount failures');

      // Test graceful degradation
      const features = [
        {'name': 'core_payment', 'critical': true, 'fallback': 'offline_queue'},
        {'name': 'gps_tracking', 'critical': false, 'fallback': 'manual_entry'},
        {'name': 'push_notifications', 'critical': false, 'fallback': 'in_app_alerts'},
        {'name': 'analytics', 'critical': false, 'fallback': 'local_storage'},
      ];

      // Simulate service degradation
      final unavailableServices = ['gps_tracking', 'analytics'];
      final availableFeatures = <Map<String, dynamic>>[];

      for (final feature in features) {
        final featureName = feature['name'] as String;
        final isCritical = feature['critical'] as bool;
        final fallback = feature['fallback'] as String;

        if (unavailableServices.contains(featureName)) {
          if (isCritical) {
            // Critical features must have fallback
            availableFeatures.add({
              'name': featureName,
              'mode': 'fallback',
              'implementation': fallback,
            });
          } else {
            // Non-critical features can be disabled
            // Skip adding to available features
          }
        } else {
          availableFeatures.add({
            'name': featureName,
            'mode': 'normal',
            'implementation': 'primary',
          });
        }
      }

      final corePaymentAvailable = availableFeatures.any((f) => f['name'] == 'core_payment');
      expect(corePaymentAvailable, true);
      print('  ✅ Graceful degradation: ${availableFeatures.length}/${features.length} features available');

      print('🎯 ERROR RECOVERY SCENARIOS TESTIRANI!');
    });
  });
}
