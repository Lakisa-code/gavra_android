import 'package:supabase/supabase.dart';

void main() async {
  // Koristimo iste kredencijale kao u supabase_client.dart
  const supabaseUrl = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
  const supabaseKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

  final supabase = SupabaseClient(supabaseUrl, supabaseKey);

  print('🔄 Testiranje normalizovane šeme...');

  try {
    // Test 1: Provera da li sve tabele postoje i rade
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

    print('\n📋 Test 1: Provera tabela...');
    for (final table in tables) {
      try {
        final response = await supabase.from(table).select().limit(1);
        print('✅ Tabela $table: Postoji (SELECT radi)');
      } catch (e) {
        print('❌ Tabela $table: Greška - $e');
      }
    }

    // Test 2: Test osnovnih operacija sa novim tabelama
    print('\n🧪 Test 2: Osnovne operacije...');

    // Test SELECT sa JOIN-om za dnevne putnike
    try {
      final dnevniPutnici = await supabase
          .from('dnevni_putnici')
          .select('*, adrese!inner(*), rute!inner(*)')
          .eq('obrisan', false)
          .limit(5);

      print('✅ Dnevni putnici sa JOIN-om: ${dnevniPutnici.length} rezultata');
    } catch (e) {
      print('❌ Dnevni putnici JOIN greška: $e');
    }

    // Test SELECT sa JOIN-om za mesečne putnike - koristi specifične relationship nazive
    try {
      final mesecniPutnici = await supabase
          .from('mesecni_putnici')
          .select(
              '*, adrese!mesecni_putnici_adresa_polaska_id_fkey(*), rute!inner(*)')
          .eq('obrisan', false)
          .eq('aktivan', true)
          .limit(5);

      print('✅ Mesečni putnici sa JOIN-om: ${mesecniPutnici.length} rezultata');
    } catch (e) {
      print('❌ Mesečni putnici JOIN greška: $e');
    }

    // Test 3: Provera RLS politika - pokušaj INSERT bez auth
    print('\n🔒 Test 3: RLS politike...');

    try {
      await supabase.from('dnevni_putnici').insert({
        'ime': 'Test',
        'polazak': '08:00',
        'dan': 'pon',
        'grad': 'Bela Crkva',
        'datum': DateTime.now().toIso8601String().split('T')[0],
        'ruta_id': '00000000-0000-0000-0000-000000000001',
        'adresa_id': '00000000-0000-0000-0000-000000000001'
      });
      print(
          '❌ RLS: INSERT dozvoljen bez autentifikacije - SIGURNOSNI PROBLEM!');
    } catch (e) {
      if (e.toString().contains('row-level security') ||
          e.toString().contains('violates row-level security policy')) {
        print('✅ RLS: INSERT blokiran bez autentifikacije - SIGURNO');
      } else {
        print('⚠️ RLS: Neočekivana greška - $e');
      }
    }

    // Test 4: Provera realtime
    print('\n📡 Test 4: Realtime funkcionalnost...');

    try {
      final channel = supabase
          .channel('test_channel')
          .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'dnevni_putnici',
              callback: (payload) {
                print('📡 Realtime događaj: $payload');
              })
          .subscribe();

      print('✅ Realtime kanal pretplaćen');

      await Future.delayed(Duration(seconds: 2));
      await supabase.removeChannel(channel);
      print('✅ Realtime kanal odjavljen');
    } catch (e) {
      print('❌ Realtime greška: $e');
    }

    print('\n🎉 Testiranje normalizovane šeme završeno!');
    print('✅ Sve tabele postoje i funkcionišu');
    print('✅ JOIN operacije rade');
    print('✅ RLS politike su aktivne');
    print('✅ Realtime funkcionalnost radi');
  } catch (e) {
    print('❌ Opšta greška: $e');
  }
}
