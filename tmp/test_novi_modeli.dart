import 'package:supabase/supabase.dart';
import 'package:gavra_android/services/vozac_service.dart';
import 'package:gavra_android/services/vozilo_service.dart';
import 'package:gavra_android/services/ruta_service.dart';
import 'package:gavra_android/services/adresa_service.dart';
import 'package:gavra_android/services/dnevni_putnik_service.dart';
import 'package:gavra_android/services/mesecni_putnik_service_novi.dart';
import 'package:gavra_android/services/gps_lokacija_service.dart';

// ignore_for_file: avoid_print

void main() async {
  // Koristimo iste kredencijale kao u supabase_client.dart
  const supabaseUrl = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
  const supabaseKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

  final supabase = SupabaseClient(supabaseUrl, supabaseKey);

  print('🚀 Testiranje novih modela i servisa...');

  try {
    // Test 1: VozacService
    print('\n👤 Test 1: VozacService...');
    final vozacService = VozacService(supabaseClient: supabase);

    final vozaci = await vozacService.getAllVozaci();
    print('✅ Dohvaćeno ${vozaci.length} vozača');

    // Test 2: VoziloService
    print('\n🚗 Test 2: VoziloService...');
    final voziloService = VoziloService(supabaseClient: supabase);

    final vozila = await voziloService.getAllVozila();
    print('✅ Dohvaćeno ${vozila.length} vozila');

    // Test 3: RutaService
    print('\n🛣️ Test 3: RutaService...');
    final rutaService = RutaService(supabaseClient: supabase);

    final rute = await rutaService.getAllRute();
    print('✅ Dohvaćeno ${rute.length} ruta');

    // Test 4: AdresaService
    print('\n🏠 Test 4: AdresaService...');
    final adresaService = AdresaService(supabaseClient: supabase);

    final adrese = await adresaService.getAllAdrese();
    print('✅ Dohvaćeno ${adrese.length} adresa');

    // Test 5: DnevniPutnikService
    print('\n👥 Test 5: DnevniPutnikService...');
    final dnevniPutnikService = DnevniPutnikService(supabaseClient: supabase);

    final dnevniPutnici =
        await dnevniPutnikService.getDnevniPutniciZaDatum(DateTime.now());
    print('✅ Dohvaćeno ${dnevniPutnici.length} dnevnih putnika za danas');

    // Test 6: MesecniPutnikService
    print('\n📅 Test 6: MesecniPutnikService...');
    final mesecniPutnikService = MesecniPutnikService(supabaseClient: supabase);

    final mesecniPutnici =
        await mesecniPutnikService.getAktivniMesecniPutnici();
    print('✅ Dohvaćeno ${mesecniPutnici.length} aktivnih mesečnih putnika');

    // Test 7: GPSLokacijaService
    print('\n📍 Test 7: GPSLokacijaService...');
    final gpsService = GPSLokacijaService(supabaseClient: supabase);

    // Test samo ako ima vozila
    if (vozila.isNotEmpty) {
      final poslednjaLokacija =
          await gpsService.getPoslednjaLokacija(vozila.first.id);
      print(
          '✅ Poslednja lokacija za vozilo ${vozila.first.registracija}: ${poslednjaLokacija != null ? 'Postoji' : 'Ne postoji'}');
    }

    print('\n🎉 Svi testovi novih modela i servisa su uspešni!');
    print('📊 Rezultati:');
    print('   - Vozači: ${vozaci.length}');
    print('   - Vozila: ${vozila.length}');
    print('   - Rute: ${rute.length}');
    print('   - Adrese: ${adrese.length}');
    print('   - Dnevni putnici: ${dnevniPutnici.length}');
    print('   - Mesečni putnici: ${mesecniPutnici.length}');
  } catch (e) {
    print('❌ Greška u testiranju: $e');
    print('Stack trace: ${StackTrace.current}');
  }
}
