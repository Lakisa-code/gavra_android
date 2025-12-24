import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/vozac.dart';

/// Servis za upravljanje vozačima
class VozacService {
  VozacService({SupabaseClient? supabaseClient}) : _supabase = supabaseClient ?? Supabase.instance.client;
  final SupabaseClient _supabase;

  /// Dohvata sve vozače
  Future<List<Vozac>> getAllVozaci() async {
    final response = await _supabase.from('vozaci').select('id, ime, kusur').order('ime');

    return response.map((json) => Vozac.fromMap(json)).toList();
  }
}
