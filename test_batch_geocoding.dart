import 'package:gavra_android/services/address_geocoding_batch_service.dart';
import 'package:gavra_android/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Test script za pokretanje batch geocoding
void main() async {
  // Inicijalizuj Supabase klijent
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  print('🌍 GAVRA ANDROID - BATCH GEOCODING TEST');
  print('=' * 50);

  try {
    // 1. Prikaži trenutni status
    print('\n📊 TRENUTNI STATUS:');
    final status = await AddressGeocodingBatchService.getGeocodingStatus();
    print('📍 Ukupno adresa: ${status['ukupno_adresa']}');
    print('✅ Sa koordinatama: ${status['sa_koordinatama']}');
    print('❌ Bez koordinata: ${status['bez_koordinata']}');
    print('📈 Procenat kompletiran: ${status['procenat_kompletiran']}%');

    // 2. Pokretni batch geocoding ako ima adresa bez koordinata
    final bezKoordinata = status['bez_koordinata'] as int? ?? 0;
    if (bezKoordinata > 0) {
      print('\n🚀 POKRETANJE BATCH GEOCODING...');
      await AddressGeocodingBatchService.geocodeAllMissingAddresses();

      // 3. Prikaži finalni status
      print('\n📊 FINALNI STATUS:');
      final finalStatus = await AddressGeocodingBatchService.getGeocodingStatus();
      print('📍 Ukupno adresa: ${finalStatus['ukupno_adresa']}');
      print('✅ Sa koordinatama: ${finalStatus['sa_koordinatama']}');
      print('❌ Bez koordinata: ${finalStatus['bez_koordinata']}');
      print('📈 Procenat kompletiran: ${finalStatus['procenat_kompletiran']}%');
    } else {
      print('\n✅ SVE ADRESE VEĆ IMAJU KOORDINATE!');
    }
  } catch (e) {
    print('❌ GREŠKA: $e');
  }

  print('\n🏁 TEST ZAVRŠEN');
}
