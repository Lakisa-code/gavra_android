import 'package:supabase/supabase.dart';

void main() async {
  // Using the same credentials from supabase_client.dart
  const supabaseUrl = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);

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

  print('🔍 Proveravam tabele u Supabase bazi...\n');

  int existingTables = 0;

  for (final tableName in expectedTables) {
    try {
      final response = await supabase
          .from(tableName)
          .select('*')
          .limit(1);

      if (response.isNotEmpty) {
        print('✅ $tableName - postoji');
        existingTables++;
      } else {
        print('⚠️ $tableName - postoji ali je prazan');
        existingTables++;
      }
    } catch (e) {
      print('❌ $tableName - ne postoji ili greška: ${e.toString().split('\n')[0]}');
    }
  }

  print('\n📊 Rezultat: $existingTables/${expectedTables.length} tabela postoji');

  if (existingTables == 0) {
    print('❌ Nema nijedne tabele! Proverite da li je Supabase URL i ključ ispravni.');
  } else if (existingTables < expectedTables.length) {
    print('⚠️ Neke tabele nedostaju. Proverite šemu baze.');
  } else {
    print('✅ Sve tabele postoje!');
  }
}