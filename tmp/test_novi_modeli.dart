import 'package:supabase/supabase.dart';
import '../models/vozac.dart';
import '../models/vozilo.dart';
import '../models/ruta.dart';
import '../models/adresa.dart';
import '../models/dnevni_putnik.dart';
import '../models/mesecni_putnik_novi.dart';
import '../models/gps_lokacija.dart';
import '../services/vozac_service.dart';
import '../services/vozilo_service.dart';
import '../services/ruta_service.dart';
import '../services/adresa_service.dart';
import '../services/dnevni_putnik_service.dart';
import '../services/mesecni_putnik_service_novi.dart';
import '../services/gps_lokacija_service.dart';

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
    final vozacService = VozacService();
    vozacService._supabase = supabase; // Override za test

    final vozaci = await vozacService.getAllVozaci();
    print('✅ Dohvaćeno ${vozaci.length} vozača');

    // Test 2: VoziloService
    print('\n🚗 Test 2: VoziloService...');
    final voziloService = VoziloService();
    voziloService._supabase = supabase;

    final vozila = await voziloService.getAllVozila();
    print('✅ Dohvaćeno ${vozila.length} vozila');

    // Test 3: RutaService
    print('\n🛣️ Test 3: RutaService...');
    final rutaService = RutaService();
    rutaService._supabase = supabase;

    final rute = await rutaService.getAllRute();
    print('✅ Dohvaćeno ${rute.length} ruta');

    // Test 4: AdresaService
    print('\n🏠 Test 4: AdresaService...');
    final adresaService = AdresaService();
    adresaService._supabase = supabase;

    final adrese = await adresaService.getAllAdrese();
    print('✅ Dohvaćeno ${adrese.length} adresa');

    // Test 5: DnevniPutnikService
    print('\n👥 Test 5: DnevniPutnikService...');
    final dnevniPutnikService = DnevniPutnikService();
    dnevniPutnikService._supabase = supabase;

    final dnevniPutnici =
        await dnevniPutnikService.getDnevniPutniciZaDatum(DateTime.now());
    print('✅ Dohvaćeno ${dnevniPutnici.length} dnevnih putnika za danas');

    // Test 6: MesecniPutnikService
    print('\n📅 Test 6: MesecniPutnikService...');
    final mesecniPutnikService = MesecniPutnikService();
    mesecniPutnikService._supabase = supabase;

    final mesecniPutnici =
        await mesecniPutnikService.getAktivniMesecniPutnici();
    print('✅ Dohvaćeno ${mesecniPutnici.length} aktivnih mesečnih putnika');

    // Test 7: GPSLokacijaService
    print('\n📍 Test 7: GPSLokacijaService...');
    final gpsService = GPSLokacijaService();
    gpsService._supabase = supabase;

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
