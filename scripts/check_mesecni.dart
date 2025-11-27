// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;

const String supabaseUrl = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

Future<void> main() async {
  print('🔍 Proveravam mesečne putnike u bazi...\n');

  try {
    final response = await http.get(
      Uri.parse(
          '$supabaseUrl/rest/v1/mesecni_putnici?aktivan=eq.true&obrisan=eq.false&select=id,putnik_ime,tip,radni_dani,grad,status,aktivan&limit=20'),
      headers: {
        'apikey': supabaseAnonKey,
        'Authorization': 'Bearer $supabaseAnonKey',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      print('✅ Nađeno ${data.length} aktivnih mesečnih putnika:\n');
      
      int ucenikCount = 0;
      int radnikCount = 0;
      int otherCount = 0;
      
      for (final putnik in data) {
        final ime = putnik['putnik_ime'] ?? 'N/A';
        final tip = putnik['tip'] ?? 'N/A';
        final radniDani = putnik['radni_dani'] ?? 'N/A';
        final grad = putnik['grad'] ?? 'N/A';
        final status = putnik['status'] ?? 'N/A';
        
        // Brojanje po tipu
        final tipLower = tip.toString().toLowerCase();
        if (tipLower.contains('ucenik') || tipLower.contains('djak') || tipLower.contains('student')) {
          ucenikCount++;
        } else if (tipLower.contains('radnik')) {
          radnikCount++;
        } else {
          otherCount++;
        }
        
        print('📍 $ime');
        print('   tip: $tip');
        print('   radni_dani: $radniDani');
        print('   grad: $grad');
        print('   status: $status');
        print('');
      }
      
      print('📊 STATISTIKA:');
      print('   Učenici (ucenik/djak/student): $ucenikCount');
      print('   Radnici: $radnikCount');
      print('   Ostalo: $otherCount');
      print('   UKUPNO: ${data.length}');
      
      // Provera za četvrtak
      print('\n🗓️ ČETVRTAK (cet) filter:');
      int cetCount = 0;
      for (final putnik in data) {
        final radniDani = (putnik['radni_dani'] ?? '').toString().toLowerCase();
        if (radniDani.contains('cet')) {
          cetCount++;
          print('   ✅ ${putnik['putnik_ime']} - radni dani: $radniDani');
        }
      }
      print('   Ukupno sa "cet": $cetCount');
      
    } else {
      print('❌ Greška: ${response.statusCode}');
      print(response.body);
    }
  } catch (e) {
    print('❌ Greška pri konekciji: $e');
  }
}
