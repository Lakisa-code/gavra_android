import 'dart:async';

import 'package:supabase/supabase.dart';

// Reuse the constants from lib/supabase_client.dart by copying here for a quick check
const String supabaseUrl = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

Future<void> main() async {
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
  try {
    final rows = await client.from('putovanja_istorija').select().limit(1)
        as List<dynamic>?;

    print('Supabase check - OK, rows: $rows');
  } catch (e) {
    print('Supabase check - Exception: $e');
  } finally {
    client.dispose();
  }
}
