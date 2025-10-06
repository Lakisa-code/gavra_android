import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gavra_android/supabase_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    // Mock SharedPreferences for testing
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  });

  test('Check recent monthly passengers in database directly', () async {
    final supabase = Supabase.instance.client;

    try {
      // Get the most recent monthly passengers
      final response = await supabase
          .from('mesecni_putnici')
          .select()
          .order('created_at', ascending: false)
          .limit(5);

      print('📊 Found ${response.length} recent monthly passengers:');
      print('');

      for (final passenger in response) {
        print('👤 Name: ${passenger['putnik_ime']}');
        print('   Type: ${passenger['tip']}');
        print('   Working Days: ${passenger['radni_dani']}');
        print('   Active: ${passenger['aktivan']}');
        print('   Deleted: ${passenger['obrisan']}');
        print('   Status: ${passenger['status']}');
        print('   Schedule JSON: ${passenger['polasci_po_danu']}');
        print('   Created: ${passenger['created_at']}');
        print('   Address BC: ${passenger['adresa_bela_crkva']}');
        print('   Address VS: ${passenger['adresa_vrsac']}');
        print('');
      }

      // Check specifically for passengers with working days Monday-Friday
      final weekdayPassengers = response.where((p) {
        final radniDani = p['radni_dani']?.toString().toLowerCase() ?? '';
        return radniDani.contains('pon') &&
            radniDani.contains('uto') &&
            radniDani.contains('sre') &&
            radniDani.contains('cet') &&
            radniDani.contains('pet');
      }).toList();

      print(
        '📅 Found ${weekdayPassengers.length} passengers with Monday-Friday schedule',
      );

      // Check polasci_po_danu structure
      for (final passenger in weekdayPassengers) {
        final polasci = passenger['polasci_po_danu'];
        print('🗓️ Schedule analysis for ${passenger['putnik_ime']}:');
        if (polasci is Map) {
          polasci.forEach((day, times) {
            print('   $day: $times');
          });
        } else if (polasci is String) {
          print('   Raw JSON: $polasci');
        } else {
          print('   Type: ${polasci.runtimeType}, Value: $polasci');
        }
        print('');
      }

      if (response.isNotEmpty) {
        print('✅ Found ${response.length} monthly passengers in database');
      } else {
        print(
          'ℹ️ No monthly passengers found in database - this is OK for empty database',
        );
      }
    } catch (e) {
      print('❌ Error querying monthly passengers: $e');
      fail('Failed to query database: $e');
    }
  });
}
