import 'package:supabase/supabase.dart';

// ignore_for_file: avoid_print

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
        print(
            '⚠️ RLS politika: Neočekivana greška - ${e.toString().split('\n')[0]}');
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
      await Future.delayed(const Duration(seconds: 2)); // Čekamo malo za test
      await supabase.removeChannel(channel);
      print('✅ Realtime kanal odjavljen');
    } catch (e) {
      print('❌ Realtime greška: $e');
    }

    // Test 4: Insert test monthly passengers
    print('\n📅 Test 4: Insert test monthly passengers...');

    try {
      // First, ensure we have a driver
      await supabase.from('vozaci').upsert({
        'id': 'b8b1a2fa-8c32-4011-a19e-f8938cacb29f',
        'ime': 'Bojan',
        'aktivan': true,
        'boja': '#00E5FF',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      print('✅ Driver inserted/updated');

      // Insert test monthly passengers
      final testPassengers = [
        {
          'id': 'test-passenger-1',
          'ime': 'Test Putnik 1',
          'adresa_polaska': 'Bela Crkva',
          'adresa_dolaska': 'Pančevo',
          'vreme_polaska': '05:00',
          'dani_u_nedelji': ['Ponedeljak', 'Sreda', 'Petak'],
          'vozac_id': 'b8b1a2fa-8c32-4011-a19e-f8938cacb29f',
          'aktivan': true,
          'cena': 500.0,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        {
          'id': 'test-passenger-2',
          'ime': 'Test Putnik 2',
          'adresa_polaska': 'Bela Crkva',
          'adresa_dolaska': 'Beograd',
          'vreme_polaska': '05:00',
          'dani_u_nedelji': ['Sreda'],
          'vozac_id': 'b8b1a2fa-8c32-4011-a19e-f8938cacb29f',
          'aktivan': true,
          'cena': 800.0,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
      ];

      for (final passenger in testPassengers) {
        try {
          await supabase.from('mesecni_putnici').upsert(passenger);
          print(
              '✅ Passenger ${passenger['ime']} inserted/updated successfully');
        } catch (e) {
          print('❌ Failed to insert passenger ${passenger['ime']}: $e');
        }
      }

      print('✅ Test passengers insertion completed!');
    } catch (e) {
      print('❌ Test passengers insertion failed: $e');
    }

    print('\n🎉 Testiranje završeno!');
  } catch (e) {
    print('❌ Opšta greška: $e');
  }
}
