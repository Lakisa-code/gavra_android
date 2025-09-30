import 'package:supabase_flutter/supabase_flutter.dart';

// Supabase konfiguracija
const String supabaseUrl = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

void main() async {
  print('🔍 Provera Supabase konekcije i tabela...');

  // Inicijalizuj Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  final supabase = Supabase.instance.client;

  print('✅ Supabase inicijalizovan');

  // Lista tabela za proveru
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

  print('\n📋 Provera tabela:');
  for (final table in tables) {
    try {
      print('🔍 Proveravam tabelu: $table');
      await supabase.from(table).select('count').limit(1);
      print('✅ Tabela $table postoji i dostupna');
    } catch (e) {
      print('❌ Greška sa tabelom $table: $e');
    }
  }

  print('\n🎯 Test osnovnih operacija:');

  // Test SELECT na vozaci
  try {
    print('🔍 Test SELECT vozaci...');
    final vozaci = await supabase.from('vozaci').select('*').limit(5);
    print('✅ SELECT vozaci: ${vozaci.length} redova');
    if (vozaci.isNotEmpty) {
      print('📊 Primer reda: ${vozaci[0]}');
    }
  } catch (e) {
    print('❌ SELECT vozaci greška: $e');
  }

  // Test INSERT (ovo će verovatno pasti zbog RLS)
  try {
    print('🔍 Test INSERT vozaci...');
    await supabase
        .from('vozaci')
        .insert({'ime': 'Test Vozac', 'aktivan': true});
    print('✅ INSERT vozaci uspeo');
  } catch (e) {
    print('❌ INSERT vozaci greška (očekivano zbog RLS): $e');
  }

  // Test realtime
  print('\n📡 Test realtime pretplate:');
  try {
    final subscription =
        supabase.from('vozaci').stream(primaryKey: ['id']).listen((data) {
      print('📡 Realtime data: ${data.length} vozaca');
    });

    // Sačekaj malo za realtime
    await Future.delayed(Duration(seconds: 2));
    subscription.cancel();
    print('✅ Realtime pretplata radi');
  } catch (e) {
    print('❌ Realtime greška: $e');
  }

  print('\n🏁 Provera završena!');
}
