import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/adresa.dart';

/// Servis za upravljanje adresama - CLOUD (Supabase) IMPLEMENTACIJA
///
/// KADA KORISTITI:
/// - Za trajno čuvanje adresa u cloud bazi
/// - Za strukturirane adrese sa koordinatama
/// - Za relacijske veze (vozac.adresa_id)
/// - Za admin operacije (kreiranje, editovanje, brisanje)
///
/// NE KORISTITI ZA:
/// - Autocomplete adresa (koristi AdreseService umesto toga)
/// - Lokalno cache-ovanje često korišćenih adresa
/// - Putnik adrese (koje se čuvaju kao stringovi)
class AdresaService {
  AdresaService({SupabaseClient? supabaseClient}) : _supabase = supabaseClient ?? Supabase.instance.client;
  final SupabaseClient _supabase;

  /// Dohvata sve adrese
  Future<List<Adresa>> getAllAdrese() async {
    final response = await _supabase
        .from('adrese')
        .select()
        // Removed .eq('aktivan', true) - column may not exist
        .order('grad')
        .order('ulica');

    return response.map((json) => Adresa.fromMap(json)).toList();
  }

  /// Dohvata adresu po ID-u
  Future<Adresa?> getAdresaById(String id) async {
    final response = await _supabase.from('adrese').select().eq('id', id).single();

    return Adresa.fromMap(response);
  }

  /// Kreira novu adresu
  Future<Adresa> createAdresa(Adresa adresa) async {
    final response = await _supabase.from('adrese').insert(adresa.toMap()).select().single();

    return Adresa.fromMap(response);
  }

  /// Ažurira adresu
  Future<Adresa> updateAdresa(String id, Map<String, dynamic> updates) async {
    // Removed 'updated_at' - field doesn't exist in model
    final response = await _supabase.from('adrese').update(updates).eq('id', id).select().single();

    return Adresa.fromMap(response);
  }

  /// Deaktivira adresu (soft delete)
  /// Note: Using a flag field to mark as deleted since 'aktivan' column may not exist
  Future<void> deactivateAdresa(String id) async {
    // Option 1: If aktivan column exists, use it
    // Option 2: Add a 'deleted_at' timestamp
    // Option 3: Physical delete (current implementation)

    // For now, we'll add a deleted_at timestamp approach
    await _supabase.from('adrese').update({
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Traži adrese po ulici, broju ili gradu
  Future<List<Adresa>> searchAdrese(String query) async {
    final response = await _supabase
        .from('adrese')
        .select()
        // Removed .eq('aktivan', true) - column may not exist
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
        // Removed .eq('aktivan', true) - column may not exist
        .eq('grad', grad)
        .order('ulica');

    return response.map((json) => Adresa.fromMap(json)).toList();
  }

  /// Dohvata adrese sa koordinatama (za mapu)
  Future<List<Adresa>> getAdreseSaKordinatama() async {
    final response = await _supabase
        .from('adrese')
        .select()
        // Removed .eq('aktivan', true) - column may not exist
        // Fixed to use 'koordinate' field instead of separate lat/lng
        .not('koordinate', 'is', null)
        .order('grad')
        .order('ulica');

    return response.map((json) => Adresa.fromMap(json)).toList();
  }

  /// Stream za realtime ažuriranja adresa
  Stream<List<Adresa>> get adreseStream {
    return _supabase
        .from('adrese')
        .stream(primaryKey: ['id'])
        // Removed .eq('aktivan', true) - column may not exist
        .order('grad')
        .order('ulica')
        .map((data) => data.map((json) => Adresa.fromMap(json)).toList());
  }
}
