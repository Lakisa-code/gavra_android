import 'package:supabase/supabase.dart';

void main() async {
  // Koristimo iste kredencijale kao u supabase_client.dart
  const supabaseUrl = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
  const supabaseKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

  final supabase = SupabaseClient(supabaseUrl, supabaseKey);

  print('🔄 Testiranje Supabase konekcije...');

  try {
    // Test 1: Provera da li možemo da pristupimo tabelama
    print('\n📋 Test 1: Provera tabela...');

    final tables = [
      'vozaci',
      'vozila',
      'rute',
      'adrese',
      'dnevni_putnici',
      'mesecni_putnici',
      'putovanja_istorija',
      'gps_lokacije'
    ];

    for (final table in tables) {
      try {
        // Pokušavamo SELECT upit da vidimo da li tabela postoji i da li možemo da čitamo
        final response = await supabase.from(table).select().limit(1);
        print(
            '✅ Tabela $table: Postoji i može se čitati (${response.length} redova)');
      } catch (e) {
        print('❌ Tabela $table: Greška - $e');
      }
    }

    // Test 2: Provera RLS politika - pokušavamo INSERT bez autentifikacije
    print('\n🔒 Test 2: Provera RLS politika (INSERT bez auth)...');

    try {
      // Pokušavamo INSERT u dnevni_putnici tabelu sa ispravnim kolonama
      await supabase.from('dnevni_putnici').insert({
        'ime': 'Test Putnik',
        'polazak': 'Bela Crkva',
        'dan': 'pon',
        'grad': 'Bela Crkva',
        'broj_telefona': '123456789',
        'datum': DateTime.now().toIso8601String().split('T')[0], // samo datum
        'iznos_placanja': 500.0,
        'placeno': false
      });
      print(
          '❌ RLS politika: INSERT dozvoljen bez autentifikacije - POTENCIJALNA SIGURNOSNA RUPE!');
    } catch (e) {
      if (e.toString().contains('permission denied') ||
          e.toString().contains('insufficient_privilege')) {
        print('✅ RLS politika: INSERT blokiran bez autentifikacije - SIGURNO');
      } else {
        print('⚠️ RLS politika: Neočekivana greška - $e');
      }
    }

    // Test 3: Provera realtime funkcionalnosti
    print('\n📡 Test 3: Provera realtime...');

    try {
      final channel = supabase
          .channel('test_channel')
          .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'dnevni_putnici',
              callback: (payload) {
                print('📡 Realtime INSERT event: $payload');
              })
          .subscribe();

      print('✅ Realtime kanal pretplaćen');
      await Future.delayed(Duration(seconds: 2)); // Čekamo malo za test
      await supabase.removeChannel(channel);
      print('✅ Realtime kanal odjavljen');
    } catch (e) {
      print('❌ Realtime greška: $e');
    }

    print('\n🎉 Testiranje završeno!');
  } catch (e) {
    print('❌ Opšta greška: $e');
  }
}
