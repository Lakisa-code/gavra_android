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

  test('Check if recently added monthly passenger exists', () async {
    final supabase = Supabase.instance.client;

    try {
      // Get all monthly passengers
      final response = await supabase
          .from('mesecni_putnici')
          .select('*')
          .order('created_at', ascending: false)
          .limit(10);

      print('📊 Found ${response.length} recent monthly passengers:');

      for (final passenger in response) {
        print(
            '👤 ${passenger['putnik_ime']} - ${passenger['radni_dani']} - ${passenger['polasci_po_danu']}');
        print(
            '   Status: aktivan=${passenger['aktivan']}, obrisan=${passenger['obrisan']}');
        print('   Created: ${passenger['created_at']}');
        print('');
      }

      // Check if any passenger has working days Monday-Friday
      final weekdayPassengers = response.where((p) {
        final radniDani = p['radni_dani']?.toString().toLowerCase() ?? '';
        return radniDani.contains('pon') &&
            radniDani.contains('uto') &&
            radniDani.contains('sre') &&
            radniDani.contains('cet') &&
            radniDani.contains('pet');
      }).toList();

      print(
          '📅 Found ${weekdayPassengers.length} passengers with Monday-Friday schedule');

      expect(response.length, greaterThan(0),
          reason: 'Should have some monthly passengers');
    } catch (e) {
      print('❌ Error querying monthly passengers: $e');
      fail('Failed to query database: $e');
    }
  });
}
