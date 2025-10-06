import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/adresa.dart';

/// Servis za upravljanje adresama
class AdresaService {
  AdresaService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;
  final SupabaseClient _supabase;

  /// Dohvata sve adrese
  Future<List<Adresa>> getAllAdrese() async {
    final response = await _supabase
        .from('adrese')
        .select()
        .eq('aktivan', true)
        .order('grad')
        .order('ulica');

    return response.map((json) => Adresa.fromMap(json)).toList();
  }

  /// Dohvata adresu po ID-u
  Future<Adresa?> getAdresaById(String id) async {
    final response =
        await _supabase.from('adrese').select().eq('id', id).single();

    return Adresa.fromMap(response);
  }

  /// Kreira novu adresu
  Future<Adresa> createAdresa(Adresa adresa) async {
    final response =
        await _supabase.from('adrese').insert(adresa.toMap()).select().single();

    return Adresa.fromMap(response);
  }

  /// Ažurira adresu
  Future<Adresa> updateAdresa(String id, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();

    final response = await _supabase
        .from('adrese')
        .update(updates)
        .eq('id', id)
        .select()
        .single();

    return Adresa.fromMap(response);
  }

  /// Deaktivira adresu (soft delete)
  Future<void> deactivateAdresa(String id) async {
    await _supabase.from('adrese').update({
      'aktivan': false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Traži adrese po ulici, broju ili gradu
  Future<List<Adresa>> searchAdrese(String query) async {
    final response = await _supabase
        .from('adrese')
        .select()
        .eq('aktivan', true)
        .or('ulica.ilike.%$query%,broj.ilike.%$query%,grad.ilike.%$query%')
        .order('grad')
        .order('ulica');

    return response.map((json) => Adresa.fromMap(json)).toList();
  }

  /// Dohvata adrese za dati grad
  Future<List<Adresa>> getAdreseZaGrad(String grad) async {
    final response = await _supabase
        .from('adrese')
        .select()
        .eq('aktivan', true)
        .eq('grad', grad)
        .order('ulica');

    return response.map((json) => Adresa.fromMap(json)).toList();
  }

  /// Dohvata adrese sa koordinatama (za mapu)
  Future<List<Adresa>> getAdreseSaKordinatama() async {
    final response = await _supabase
        .from('adrese')
        .select()
        .eq('aktivan', true)
        .not('latitude', 'is', null)
        .not('longitude', 'is', null)
        .order('grad')
        .order('ulica');

    return response.map((json) => Adresa.fromMap(json)).toList();
  }

  /// Stream za realtime ažuriranja adresa
  Stream<List<Adresa>> get adreseStream {
    return _supabase
        .from('adrese')
        .stream(primaryKey: ['id'])
        .eq('aktivan', true)
        .order('grad')
        .order('ulica')
        .map((data) => data.map((json) => Adresa.fromMap(json)).toList());
  }
}
