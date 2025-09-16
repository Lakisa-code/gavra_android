import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

/// 🔍 DIREKTAN QUERY ZA TAČAN IZNOS NAPLAĆENOG NOVCA
/// Jednostavan script koji se direktno povezuje sa Supabase i izvlači podatke
void main() async {
  // Inicijalizuj Supabase
  await Supabase.initialize(
    url: 'https://gjtabtwudbrmfeyjiicu.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk',
  );

  final client = Supabase.instance.client;

  debugPrint('🔍 === ANALIZA NAPLAĆENOG NOVCA U SUPABASE ===');
  debugPrint('📅 Datum: ${DateFormat('dd.MM.yyyy').format(DateTime.now())}');
  debugPrint('');

  try {
    final now = DateTime.now();
    final danas = DateTime(now.year, now.month, now.day);
    final danasKraj = DateTime(now.year, now.month, now.day, 23, 59, 59);

    debugPrint(
        '🕐 Analiziram period: ${DateFormat('dd.MM.yyyy HH:mm').format(danas)} - ${DateFormat('HH:mm').format(danasKraj)}');
    debugPrint('');

    // 1. DNEVNI PUTNICI - naplaćeni danas
    debugPrint('📊 1. DNEVNI PUTNICI (tabela: putnici)');
    final dnevniQuery = await client
        .from('putnici')
        .select(
            'naplatioVozac, iznosPlacanja, vremePlacanja, mesecnaKarta, jeOtkazan, status, ime')
        .gte('vremePlacanja', danas.toIso8601String())
        .lte('vremePlacanja', danasKraj.toIso8601String())
        .neq('mesecnaKarta', true)
        .neq('jeOtkazan', true);

    debugPrint('   Broj zapisa: ${dnevniQuery.length}');

    double ukupnoDnevni = 0;
    Map<String, double> pazarDnevni = {};
    int placeniDnevni = 0;

    for (final putnik in dnevniQuery) {
      final iznos = (putnik['iznosPlacanja'] ?? 0).toDouble();
      final vozac = putnik['naplatioVozac'] ?? 'Nepoznat';
      final ime = putnik['ime'] ?? 'Nepoznato';

      if (iznos > 0) {
        ukupnoDnevni += iznos;
        pazarDnevni[vozac] = (pazarDnevni[vozac] ?? 0) + iznos;
        placeniDnevni++;
        debugPrint('     ✅ $ime -> $vozac: ${iznos.toStringAsFixed(0)} RSD');
      }
    }

    debugPrint(
        '   📈 Ukupno dnevni: ${ukupnoDnevni.toStringAsFixed(0)} RSD ($placeniDnevni plaćenih)');
    debugPrint('');

    // 2. MESEČNI PUTNICI - naplaćeni danas
    debugPrint('📊 2. MESEČNI PUTNICI (tabela: mesecni_putnici)');
    final mesecniQuery = await client
        .from('mesecni_putnici')
        .select(
            'vozac, iznosPlacanja, vremePlacanja, putnikIme, aktivan, obrisan, jePlacen')
        .eq('aktivan', true)
        .eq('obrisan', false)
        .eq('jePlacen', true)
        .gte('vremePlacanja', danas.toIso8601String())
        .lte('vremePlacanja', danasKraj.toIso8601String());

    debugPrint('   Broj zapisa: ${mesecniQuery.length}');

    double ukupnoMesecni = 0;
    Map<String, double> pazarMesecni = {};

    for (final putnik in mesecniQuery) {
      final iznos = (putnik['iznosPlacanja'] ?? 0).toDouble();
      final vozac = putnik['vozac'] ?? 'Nepoznat';
      final ime = putnik['putnikIme'] ?? 'Nepoznato';

      if (iznos > 0) {
        ukupnoMesecni += iznos;
        pazarMesecni[vozac] = (pazarMesecni[vozac] ?? 0) + iznos;
        debugPrint('     ✅ $ime -> $vozac: ${iznos.toStringAsFixed(0)} RSD');
      }
    }

    debugPrint('   📈 Ukupno mesečni: ${ukupnoMesecni.toStringAsFixed(0)} RSD');
    debugPrint('');

    // 3. UKUPNI REZULTAT
    final ukupnoSvega = ukupnoDnevni + ukupnoMesecni;
    debugPrint('🏆 === UKUPAN REZULTAT ===');
    debugPrint(
        '💰 UKUPNO NAPLAĆENO DANAS: ${ukupnoSvega.toStringAsFixed(0)} RSD');
    debugPrint('   - Dnevni putnici: ${ukupnoDnevni.toStringAsFixed(0)} RSD');
    debugPrint('   - Mesečni putnici: ${ukupnoMesecni.toStringAsFixed(0)} RSD');
    debugPrint('');

    // 4. PAZAR PO VOZAČIMA
    debugPrint('🚗 PAZAR PO VOZAČIMA:');
    final sviVozaci = {...pazarDnevni.keys, ...pazarMesecni.keys}.toSet();

    for (final vozac in sviVozaci) {
      final dnevni = pazarDnevni[vozac] ?? 0;
      final mesecni = pazarMesecni[vozac] ?? 0;
      final ukupnoVozac = dnevni + mesecni;

      if (ukupnoVozac > 0) {
        debugPrint(
            '   $vozac: ${ukupnoVozac.toStringAsFixed(0)} RSD (dnevni: ${dnevni.toStringAsFixed(0)}, mesečni: ${mesecni.toStringAsFixed(0)})');
      }
    }

    debugPrint('');
    debugPrint('✅ Analiza završena uspešno!');
  } catch (e) {
    debugPrint('❌ Greška pri analizi: $e');
    exit(1);
  }

  exit(0);
}
