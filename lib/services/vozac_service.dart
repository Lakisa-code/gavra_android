import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vozac.dart';

/// Servis za upravljanje vozačima
class VozacService {
  final SupabaseClient _supabase;

  VozacService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  /// Dohvata sve vozače
  Future<List<Vozac>> getAllVozaci() async {
    final response = await _supabase
        .from('vozaci')
        .select()
        .eq('aktivan', true)
        .order('ime');

    return response.map((json) => Vozac.fromMap(json)).toList();
  }

  /// Dohvata vozača po ID-u
  Future<Vozac?> getVozacById(String id) async {
    final response =
        await _supabase.from('vozaci').select().eq('id', id).single();

    return Vozac.fromMap(response);
  }

  /// Kreira novog vozača
  Future<Vozac> createVozac(Vozac vozac) async {
    final response =
        await _supabase.from('vozaci').insert(vozac.toMap()).select().single();

    return Vozac.fromMap(response);
  }

  /// Ažurira vozača
  Future<Vozac> updateVozac(String id, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();

    final response = await _supabase
        .from('vozaci')
        .update(updates)
        .eq('id', id)
        .select()
        .single();

    return Vozac.fromMap(response);
  }

  /// Deaktivira vozača (soft delete)
  Future<void> deactivateVozac(String id) async {
    await _supabase.from('vozaci').update({
      'aktivan': false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Traži vozače po imenu ili prezimenu
  Future<List<Vozac>> searchVozaci(String query) async {
    final response = await _supabase
        .from('vozaci')
        .select()
        .eq('aktivan', true)
        .or('ime.ilike.%$query%,prezime.ilike.%$query%')
        .order('ime');

    return response.map((json) => Vozac.fromMap(json)).toList();
  }

  /// Stream za realtime ažuriranja vozača
  Stream<List<Vozac>> get vozaciStream {
    return _supabase
        .from('vozaci')
        .stream(primaryKey: ['id'])
        .eq('aktivan', true)
        .order('ime')
        .map((data) => data.map((json) => Vozac.fromMap(json)).toList());
  }
}
