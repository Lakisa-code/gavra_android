import 'package:supabase/supabase.dart';

const String supabaseUrl = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

Future<void> main() async {
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);

  // Define expected columns per table and try selecting them.
  final Map<String, List<String>> expected = {
    'daily_checkins': ['id', 'vozac', 'datum', 'kusur_iznos', 'dnevni_pazari'],
    'putovanja_istorija': [
      'id',
      'putnik_ime',
      'datum',
      'tip_putnika',
      'status'
    ],
    'mesecni_putnici': ['id', 'putnik_ime', 'radni_dani', 'aktivan']
  };

  for (final entry in expected.entries) {
    final table = entry.key;
    final cols = entry.value;
    try {
      final selectExpr = cols.join(',');
      final rows = await client.from(table).select(selectExpr).limit(1)
          as List<dynamic>?;
      if (rows == null) {
        print('Table $table: select returned null (possible RLS or not found)');
      } else {
        print('Table $table: select successful (returned ${rows.length} rows)');
        if (rows.isNotEmpty) {
          print('  Sample row keys: ${rows.first.keys.join(', ')}');
        }
      }
    } catch (e) {
      print('Error selecting from $table: $e');
    }
  }

  client.dispose();
}
