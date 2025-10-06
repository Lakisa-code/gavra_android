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
  test('Check vozac_id values in database', () async {
    try {
      final supabase = Supabase.instance.client;
      // Povuci sve mesečne putnike direktno iz baze
      final response = await supabase
          .from('mesecni_putnici')
          .select('id, putnik_ime, vozac_id')
          .limit(10);

      print('\n🔍 Provera vozac_id vrednosti u bazi:');

      for (var row in response) {
        final id = row['id'];
        final ime = row['putnik_ime'];
        final vozacId = row['vozac_id'];

        print(
          'ID: $id, Ime: $ime, vozac_id: "$vozacId" (${vozacId.runtimeType})',
        );

        // Proveri da li je prazan string
        if (vozacId is String && vozacId.isEmpty) {
          print('❌ PROBLEM: vozac_id je prazan string za $ime!');
          throw Exception('Pronađen prazan string u vozac_id koloni!');
        }
      }

      print('✅ Sve vozac_id vrednosti su OK (null ili validni UUID)');
    } catch (e) {
      print('❌ Greška pri proveri baze: $e');
      rethrow;
    }
  });
}
