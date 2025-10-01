import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gavra_android/supabase_client.dart';

void main() {
  setUpAll(() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  });

  test('Check Supabase tables existence', () async {
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

    for (final tableName in expectedTables) {
      try {
        final response = await supabase.from(tableName).select('*').limit(1);

        if (response.isNotEmpty) {
          print('✅ $tableName - postoji');
          existingTables++;
        } else {
          print('⚠️ $tableName - postoji ali je prazan');
          existingTables++;
        }
      } catch (e) {
        print(
            '❌ $tableName - ne postoji ili greška: ${e.toString().split('\n')[0]}');
      }
    }

    print(
        '\n📊 Rezultat: $existingTables/${expectedTables.length} tabela postoji');

    expect(existingTables, greaterThan(0),
        reason: 'Trebalo bi da postoji bar neka tabela');
  });
}
