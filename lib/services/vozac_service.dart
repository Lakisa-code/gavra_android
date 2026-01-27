import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import '../models/vozac.dart';

/// Servis za upravljanje vozačima
class VozacService {
  VozacService({SupabaseClient? supabaseClient}) : _supabaseOverride = supabaseClient;
  final SupabaseClient? _supabaseOverride;

  SupabaseClient get _supabase => _supabaseOverride ?? supabase;

  /// Dohvata sve vozače
  Future<List<Vozac>> getAllVozaci() async {
    final response = await _supabase.from('vozaci').select('id, ime').order('ime');

    return response.map((json) => Vozac.fromMap(json)).toList();
  }

  /// 🛰️ REALTIME STREAM: Dohvata sve vozače u realnom vremenu
  Stream<List<Vozac>> streamAllVozaci() {
    return _supabase
        .from('vozaci')
        .stream(primaryKey: ['id'])
        .order('ime')
        .map((data) => data.map((json) => Vozac.fromMap(json)).toList());
  }
}
