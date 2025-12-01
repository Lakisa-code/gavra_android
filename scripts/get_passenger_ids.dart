// Script to get passenger IDs for testing
import 'dart:convert';

import 'package:http/http.dart' as http;

const String supabaseUrl = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

Future<void> main() async {
  print('🔍 Getting passenger IDs for testing...\n');

  try {
    // Get monthly passengers
    final monthlyResponse = await http.get(
      Uri.parse(
          '$supabaseUrl/rest/v1/mesecni_putnici?aktivan=eq.true&obrisan=eq.false&select=id,putnik_ime,tip,status&limit=10'),
      headers: {
        'apikey': supabaseAnonKey,
        'Authorization': 'Bearer $supabaseAnonKey',
      },
    );

    if (monthlyResponse.statusCode == 200) {
      final List<dynamic> monthlyData = jsonDecode(monthlyResponse.body);
      print('📅 Monthly Passengers:');
      for (final putnik in monthlyData) {
        final id = putnik['id'] ?? 'N/A';
        final ime = putnik['putnik_ime'] ?? 'N/A';
        final tip = putnik['tip'] ?? 'N/A';
        final status = putnik['status'] ?? 'N/A';
        print('   ID: $id | Name: $ime | Type: $tip | Status: $status');
      }
      print('');
    }

    // Get daily passengers (recent)
    final dailyResponse = await http.get(
      Uri.parse(
          '$supabaseUrl/rest/v1/putovanja_istorija?tip_putnika=eq.dnevni&obrisan=eq.false&select=id,putnik_ime,status&limit=10&order=created_at.desc'),
      headers: {
        'apikey': supabaseAnonKey,
        'Authorization': 'Bearer $supabaseAnonKey',
      },
    );

    if (dailyResponse.statusCode == 200) {
      final List<dynamic> dailyData = jsonDecode(dailyResponse.body);
      print('📆 Daily Passengers (recent):');
      for (final putnik in dailyData) {
        final id = putnik['id'] ?? 'N/A';
        final ime = putnik['putnik_ime'] ?? 'N/A';
        final status = putnik['status'] ?? 'N/A';
        print('   ID: $id | Name: $ime | Status: $status');
      }
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}
