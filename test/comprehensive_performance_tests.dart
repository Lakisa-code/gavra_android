import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/services/mesecni_putnik_service.dart';
// Import real services for performance testing
import '../lib/services/putnik_service.dart';
import '../lib/services/vozac_mapping_service.dart';
import '../lib/services/vozac_service.dart';
// Import test helper
import 'test_supabase_setup.dart';

void main() {
  group('⚡ COMPREHENSIVE PERFORMANCE TESTS', () {
    setUpAll(() async {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize real Supabase connection
      await TestSupabaseSetup.initialize();

      print('✅ Performance test services initialized');
    });

    group('🚀 SERVICE INITIALIZATION PERFORMANCE', () {
      test('⚡ Service Creation Speed', () async {
        final stopwatch = Stopwatch()..start();

        // Test service creation time
        for (int i = 0; i < 10; i++) {
          final putnik = PutnikService();
          final vozac = VozacService();
          final mesecni = MesecniPutnikService();

          expect(putnik, isNotNull);
          expect(vozac, isNotNull);
          expect(mesecni, isNotNull);
        }

        stopwatch.stop();
        final avgTime = stopwatch.elapsedMilliseconds / 10;

        expect(
          avgTime,
          lessThan(10),
          reason: 'Service creation should be under 10ms average',
        );

        print('✅ Service creation performance: ${avgTime.toStringAsFixed(2)}ms average');
      });

      test('🔄 UUID Mapping Performance', () async {
        final stopwatch = Stopwatch()..start();
        final drivers = ['Bojan', 'Svetlana', 'Bruda', 'Bilevski'];

        // Test UUID mapping speed
        for (int i = 0; i < 50; i++) {
          for (final driver in drivers) {
            await VozacMappingService.getVozacUuid(driver);
          }
        }

        stopwatch.stop();
        final avgTime = stopwatch.elapsedMilliseconds / (50 * drivers.length);

        expect(
          avgTime,
          lessThan(1),
          reason: 'UUID mapping should be under 1ms average',
        );

        print('✅ UUID mapping performance: ${avgTime.toStringAsFixed(3)}ms average');
      });
    });

    group('📊 DATA PROCESSING PERFORMANCE', () {
      test('🔢 Large Dataset Processing', () async {
        final stopwatch = Stopwatch()..start();

        // Generate large test dataset
        final testData = List.generate(
          1000,
          (index) => {
            'id': 'putnik-$index',
            'ime': 'Test$index',
            'prezime': 'User$index',
            'telefon': '064123${index.toString().padLeft(4, '0')}',
            'grad': ['Novi Sad', 'Beograd', 'Niš'][index % 3],
          },
        );

        // Process data - filter by city
        final noviSadUsers = testData
            .where(
              (user) => user['grad'] == 'Novi Sad',
            )
            .toList();

        // Process data - search by name
        final testUsers = testData
            .where(
              (user) => user['ime']?.toString().contains('Test') == true,
            )
            .toList();

        stopwatch.stop();

        expect(noviSadUsers.length, greaterThan(300));
        expect(testUsers.length, equals(1000));
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(100),
          reason: 'Large dataset processing should be under 100ms',
        );

        print('✅ Large dataset performance: ${stopwatch.elapsedMilliseconds}ms for 1000 items');
      });

      test('🔍 Search Algorithm Performance', () async {
        final stopwatch = Stopwatch()..start();

        // Generate search data
        final searchData = List.generate(
          500,
          (index) => 'User ${Random().nextInt(1000)}',
        );

        // Test linear search
        int foundCount = 0;

        for (int i = 0; i < 100; i++) {
          foundCount += searchData
              .where(
                (item) => item.contains('User'),
              )
              .length;
        }

        stopwatch.stop();

        expect(foundCount, greaterThan(0));
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(50),
          reason: 'Search should be under 50ms for 100 iterations',
        );

        print('✅ Search performance: ${stopwatch.elapsedMilliseconds}ms for 100 searches');
      });

      test('📈 Sorting Performance', () async {
        final stopwatch = Stopwatch()..start();

        // Generate random data to sort
        final randomData = List.generate(
          1000,
          (index) => {
            'id': index,
            'name': 'User${Random().nextInt(1000)}',
            'score': Random().nextDouble() * 100,
          },
        );

        // Test sorting performance
        randomData.sort(
          (a, b) => (a['score'] as double).compareTo(b['score'] as double),
        );

        stopwatch.stop();

        expect(randomData.first['score'] as double, lessThanOrEqualTo(randomData.last['score'] as double));
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(20),
          reason: 'Sorting 1000 items should be under 20ms',
        );

        print('✅ Sorting performance: ${stopwatch.elapsedMilliseconds}ms for 1000 items');
      });
    });

    group('🎮 UI PERFORMANCE SIMULATION', () {
      test('🖼️ Widget Building Performance', () async {
        final stopwatch = Stopwatch()..start();

        // Simulate building many widgets
        for (int i = 0; i < 100; i++) {
          final widget = Container(
            key: ValueKey('container_$i'),
            width: 100,
            height: 100,
            child: Text('Item $i'),
          );

          expect(widget, isNotNull);
        }

        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(50),
          reason: 'Building 100 widgets should be under 50ms',
        );

        print('✅ Widget building performance: ${stopwatch.elapsedMilliseconds}ms for 100 widgets');
      });

      test('📱 List Rendering Simulation', () async {
        final stopwatch = Stopwatch()..start();

        // Simulate large list data
        final listData = List.generate(
          1000,
          (index) => {
            'id': 'item_$index',
            'title': 'Title $index',
            'subtitle': 'Subtitle for item $index',
          },
        );

        // Simulate processing for rendering
        final visibleItems = listData.take(20).toList();
        final processedItems = visibleItems
            .map(
              (item) => {
                ...item,
                'processed': true,
              },
            )
            .toList();

        stopwatch.stop();

        expect(processedItems.length, equals(20));
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(10),
          reason: 'List processing should be under 10ms',
        );

        print('✅ List rendering performance: ${stopwatch.elapsedMilliseconds}ms for 20 visible items');
      });
    });

    group('🔄 ASYNC OPERATIONS PERFORMANCE', () {
      test('⏱️ Concurrent Operations', () async {
        final stopwatch = Stopwatch()..start();

        // Test concurrent async operations
        final futures = List.generate(20, (index) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return 'Result $index';
        });

        final results = await Future.wait(futures);

        stopwatch.stop();

        expect(results.length, equals(20));
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(100),
          reason: 'Concurrent operations should benefit from parallelism',
        );

        print('✅ Concurrent operations performance: ${stopwatch.elapsedMilliseconds}ms for 20 operations');
      });

      test('🔄 Sequential vs Parallel Comparison', () async {
        // Sequential operations
        final sequentialStopwatch = Stopwatch()..start();

        for (int i = 0; i < 10; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }

        sequentialStopwatch.stop();

        // Parallel operations
        final parallelStopwatch = Stopwatch()..start();

        final parallelFutures = List.generate(
          10,
          (index) => Future<void>.delayed(const Duration(milliseconds: 5)),
        );

        await Future.wait(parallelFutures);

        parallelStopwatch.stop();

        expect(
          parallelStopwatch.elapsedMilliseconds,
          lessThan(sequentialStopwatch.elapsedMilliseconds),
          reason: 'Parallel should be faster than sequential',
        );

        print(
          '✅ Sequential: ${sequentialStopwatch.elapsedMilliseconds}ms, Parallel: ${parallelStopwatch.elapsedMilliseconds}ms',
        );
      });
    });

    group('🧠 MEMORY PERFORMANCE', () {
      test('📦 Memory Usage Simulation', () async {
        final stopwatch = Stopwatch()..start();

        // Create large data structure
        final largeData = <String, List<Map<String, dynamic>>>{};

        for (int i = 0; i < 100; i++) {
          largeData['category_$i'] = List.generate(
            50,
            (j) => {
              'id': 'item_${i}_$j',
              'data': 'Data for item $j in category $i',
            },
          );
        }

        // Process and clear data
        int totalItems = 0;
        largeData.forEach((category, items) {
          totalItems += items.length;
        });

        largeData.clear();

        stopwatch.stop();

        expect(totalItems, equals(5000));
        expect(largeData.isEmpty, isTrue);
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(100),
          reason: 'Memory operations should be efficient',
        );

        print('✅ Memory operations performance: ${stopwatch.elapsedMilliseconds}ms for 5000 items');
      });

      test('🔄 Object Creation and Disposal', () async {
        final stopwatch = Stopwatch()..start();

        // Test rapid object creation and disposal
        for (int i = 0; i < 1000; i++) {
          final obj = {
            'id': i,
            'timestamp': DateTime.now(),
            'data': List.generate(10, (j) => 'item_$j'),
          };

          // Simulate object usage
          expect(obj['id'], equals(i));

          // Object goes out of scope and can be garbage collected
        }

        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(100),
          reason: 'Object lifecycle should be efficient',
        );

        print('✅ Object lifecycle performance: ${stopwatch.elapsedMilliseconds}ms for 1000 objects');
      });
    });

    group('📈 BENCHMARKING AND METRICS', () {
      test('📊 Performance Metrics Collection', () async {
        final metrics = <String, double>{};

        // Collect various performance metrics
        final tests = [
          'string_operations',
          'list_operations',
          'map_operations',
          'calculation_operations',
        ];

        for (final testName in tests) {
          final stopwatch = Stopwatch()..start();

          switch (testName) {
            case 'string_operations':
              for (int i = 0; i < 1000; i++) {
                final str = 'Test string $i';
                expect(str.contains('Test'), isTrue);
              }
              break;

            case 'list_operations':
              final list = List.generate(1000, (i) => i);
              list.sort();
              expect(list.first, equals(0));
              break;

            case 'map_operations':
              final map = <String, int>{};
              for (int i = 0; i < 1000; i++) {
                map['key_$i'] = i;
              }
              expect(map.length, equals(1000));
              break;

            case 'calculation_operations':
              double result = 0;
              for (int i = 0; i < 1000; i++) {
                result += sqrt(i.toDouble());
              }
              expect(result, greaterThan(0));
              break;
          }

          stopwatch.stop();
          metrics[testName] = stopwatch.elapsedMilliseconds.toDouble();
        }

        // Validate all metrics are reasonable
        metrics.forEach((testName, time) {
          expect(
            time,
            lessThan(200),
            reason: '$testName should complete under 200ms',
          );
          print('📊 $testName: ${time.toStringAsFixed(2)}ms');
        });

        print('✅ Performance metrics collected for ${metrics.length} operations');
      });
    });
  });
}
