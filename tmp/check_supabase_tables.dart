import 'package:supabase_flutter/supabase_flutter.dart';

const String supabaseUrl = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

Future<void> checkSupabaseTables() async {
  try {
    // Initialize Supabase
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    final supabase = Supabase.instance.client;

    print('🔍 Provera tabela u Supabase bazi...');

    // Try to query each expected table
    print('\n🔍 Provera specifičnih tabela...');
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
        // Try to select one row to check if table exists
        final response = await supabase.from(tableName).select('*').limit(1);

        if (response.isNotEmpty) {
          print('  ✅ $tableName - postoji');
          existingTables++;
        } else {
          print('  ⚠️ $tableName - postoji ali je prazan');
          existingTables++;
        }
      } catch (e) {
        print(
            '  ❌ $tableName - ne postoji ili greška: ${e.toString().split('\n')[0]}');
      }
    }

    print(
        '\n📊 Rezultat: $existingTables/${expectedTables.length} tabela postoji');
  } catch (e) {
    print('❌ Greška pri povezivanju sa Supabase: $e');
  }
}
