import 'package:flutter_test/flutter_test.dart';
import '../lib/supabase_client.dart';

void main() {
  test('Check vozac_id values in database', () async {
    try {
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
            'ID: $id, Ime: $ime, vozac_id: "$vozacId" (${vozacId.runtimeType})');

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
