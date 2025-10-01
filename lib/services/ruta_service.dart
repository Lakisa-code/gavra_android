import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ruta.dart';

/// Servis za upravljanje rutama
class RutaService {
  final SupabaseClient _supabase;

  RutaService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  /// Dohvata sve rute
  Future<List<Ruta>> getAllRute() async {
    final response = await _supabase
        .from('rute')
        .select()
        .eq('aktivan', true)
        .order('naziv');

    return response.map((json) => Ruta.fromMap(json)).toList();
  }

  /// Dohvata rutu po ID-u
  Future<Ruta?> getRutaById(String id) async {
    final response =
        await _supabase.from('rute').select().eq('id', id).single();

    return Ruta.fromMap(response);
  }

  /// Kreira novu rutu
  Future<Ruta> createRuta(Ruta ruta) async {
    final response =
        await _supabase.from('rute').insert(ruta.toMap()).select().single();

    return Ruta.fromMap(response);
  }

  /// Ažurira rutu
  Future<Ruta> updateRuta(String id, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();

    final response = await _supabase
        .from('rute')
        .update(updates)
        .eq('id', id)
        .select()
        .single();

    return Ruta.fromMap(response);
  }

  /// Deaktivira rutu (soft delete)
  Future<void> deactivateRuta(String id) async {
    await _supabase.from('rute').update({
      'aktivan': false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Traži rute po nazivu, polasku ili destinaciji
  Future<List<Ruta>> searchRute(String query) async {
    final response = await _supabase
        .from('rute')
        .select()
        .eq('aktivan', true)
        .or('naziv.ilike.%$query%,polazak.ilike.%$query%,destinacija.ilike.%$query%')
        .order('naziv');

    return response.map((json) => Ruta.fromMap(json)).toList();
  }

  /// Dohvata rute između dva grada
  Future<List<Ruta>> getRuteIzmedju(String polazak, String destinacija) async {
    final response = await _supabase
        .from('rute')
        .select()
        .eq('aktivan', true)
        .eq('polazak', polazak)
        .eq('destinacija', destinacija)
        .order('naziv');

    return response.map((json) => Ruta.fromMap(json)).toList();
  }

  /// Stream za realtime ažuriranja ruta
  Stream<List<Ruta>> get ruteStream {
    return _supabase
        .from('rute')
        .stream(primaryKey: ['id'])
        .eq('aktivan', true)
        .order('naziv')
        .map((data) => data.map((json) => Ruta.fromMap(json)).toList());
  }
}
