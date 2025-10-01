import 'package:supabase_flutter/supabase_flutter.dart';

const String supabaseUrl = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

Future<void> insertTestData() async {
  try {
    // Initialize Supabase
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    final supabase = Supabase.instance.client;

    print('🚀 Inserting test data into Supabase...');

    // First, insert a test driver if not exists
    print('\n👤 Inserting test driver...');
    final driverData = {
      'id': 'b8b1a2fa-8c32-4011-a19e-f8938cacb29f',
      'ime': 'Bojan',
      'aktivan': true,
      'boja': '#00E5FF',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      await supabase.from('vozaci').upsert(driverData);
      print('✅ Driver inserted/updated successfully');
    } catch (e) {
      print('⚠️ Driver insert failed (might already exist): $e');
    }

    // Insert test monthly passengers
    print('\n📅 Inserting test monthly passengers...');

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
        print('✅ Passenger ${passenger['ime']} inserted/updated successfully');
      } catch (e) {
        print('❌ Failed to insert passenger ${passenger['ime']}: $e');
      }
    }

    print('\n🎉 Test data insertion completed!');
    print('📊 Check your app now - passengers should be visible!');
  } catch (e) {
    print('❌ Error inserting test data: $e');
    print('Stack trace: ${StackTrace.current}');
  }
}

void main() async {
  await insertTestData();
}
