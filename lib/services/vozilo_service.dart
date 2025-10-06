import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vozilo.dart';

/// Servis za upravljanje vozilima
class VoziloService {
  VoziloService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;
  final SupabaseClient _supabase;

  /// Dohvata sva vozila
  Future<List<Vozilo>> getAllVozila() async {
    final response = await _supabase
        .from('vozila')
        .select()
        .eq('aktivan', true)
        .order('registracija');

    return response.map((json) => Vozilo.fromMap(json)).toList();
  }

  /// Dohvata vozilo po ID-u
  Future<Vozilo?> getVoziloById(String id) async {
    final response =
        await _supabase.from('vozila').select().eq('id', id).single();

    return Vozilo.fromMap(response);
  }

  /// Kreira novo vozilo
  Future<Vozilo> createVozilo(Vozilo vozilo) async {
    final response =
        await _supabase.from('vozila').insert(vozilo.toMap()).select().single();

    return Vozilo.fromMap(response);
  }

  /// Ažurira vozilo
  Future<Vozilo> updateVozilo(String id, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();

    final response = await _supabase
        .from('vozila')
        .update(updates)
        .eq('id', id)
        .select()
        .single();

    return Vozilo.fromMap(response);
  }

  /// Deaktivira vozilo (soft delete)
  Future<void> deactivateVozilo(String id) async {
    await _supabase.from('vozila').update({
      'aktivan': false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Traži vozila po registraciji ili marki
  Future<List<Vozilo>> searchVozila(String query) async {
    final response = await _supabase
        .from('vozila')
        .select()
        .eq('aktivan', true)
        .or('registracija.ilike.%$query%,marka.ilike.%$query%,model.ilike.%$query%')
        .order('registracija');

    return response.map((json) => Vozilo.fromMap(json)).toList();
  }

  /// Stream za realtime ažuriranja vozila
  Stream<List<Vozilo>> get vozilaStream {
    return _supabase
        .from('vozila')
        .stream(primaryKey: ['id'])
        .eq('aktivan', true)
        .order('registracija')
        .map((data) => data.map((json) => Vozilo.fromMap(json)).toList());
  }
}
