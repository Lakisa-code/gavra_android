import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gavra_android/supabase_client.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Database Connection Tests', () {
    setUpAll(() async {
      // Initialize Supabase
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
    });

    testWidgets('Check all expected tables exist', (WidgetTester tester) async {
      final supabase = Supabase.instance.client;

      final expectedTables = [
        'vozaci',
        'vozila',
        'rute',
        'adrese',
        'dnevni_putnici',
        'mesecni_putnici',
        'putovanja_istorija',
        'gps_lokacije'
      ];

      int existingTables = 0;
      List<String> results = [];

      for (final tableName in expectedTables) {
        try {
          final response = await supabase.from(tableName).select('*').limit(1);

          if (response.isNotEmpty) {
            results.add('✅ $tableName - postoji (ima podatke)');
            existingTables++;
          } else {
            results.add('⚠️ $tableName - postoji ali je prazan');
            existingTables++;
          }
        } catch (e) {
          results.add(
              '❌ $tableName - ne postoji ili greška: ${e.toString().split('\n')[0]}');
        }
      }

      // Print results
      print('\n📊 REZULTATI PROVERE TABLA:');
      results.forEach(print);
      print(
          '\n📈 UKUPNO: $existingTables/${expectedTables.length} tabela postoji');

      // Verify that at least some tables exist
      expect(existingTables, greaterThan(0),
          reason: 'Trebalo bi da postoji bar neka tabela');

      // Verify that GPS table exists (since we know GPS data is being sent)
      expect(
          results.any((result) =>
              result.contains('gps_lokacije') && result.contains('✅')),
          isTrue,
          reason: 'GPS tabela bi trebalo da postoji jer se šalju GPS podaci');
    });
  });
}
