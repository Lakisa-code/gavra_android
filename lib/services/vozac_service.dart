import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/adresa.dart';
import '../models/vozac.dart';
import 'adresa_service.dart';

/// Servis za upravljanje vozačima
class VozacService {
  VozacService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;
  final SupabaseClient _supabase;

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
    // Ako je query prazan, vrati sve vozače
    if (query.trim().isEmpty) {
      return getAllVozaci();
    }

    final response = await _supabase
        .from('vozaci')
        .select()
        .eq('aktivan', true)
        .or('ime.ilike.%$query%,prezime.ilike.%$query%')
        .order('ime');

    return response.map((json) => Vozac.fromMap(json)).toList();
  }

  /// Traži vozača po punom imenu (ime + prezime)
  Future<Vozac?> getVozacByPunoIme(String punoIme) async {
    final parts = punoIme.trim().split(' ');
    if (parts.isEmpty) return null;

    if (parts.length == 1) {
      // Samo ime
      final response = await _supabase
          .from('vozaci')
          .select()
          .eq('aktivan', true)
          .eq('ime', parts[0])
          .maybeSingle();

      return response != null ? Vozac.fromMap(response) : null;
    } else {
      // Ime i prezime
      final ime = parts[0];
      final prezime = parts.sublist(1).join(' ');

      final response = await _supabase
          .from('vozaci')
          .select()
          .eq('aktivan', true)
          .eq('ime', ime)
          .eq('prezime', prezime)
          .maybeSingle();

      return response != null ? Vozac.fromMap(response) : null;
    }
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

  /// Address relationship methods

  /// Dohvata adresu vozača
  Future<Adresa?> getVozacAdresa(String vozacId) async {
    final vozac = await getVozacById(vozacId);
    if (vozac == null) return null;

    // Since Vozac model doesn't have adresaId, return null for now
    // This should be implemented when address relationship is added to Vozac model
    return null;
  }

  /// Dodeljuje adresu vozaču
  Future<Vozac> assignAddressToVozac(String vozacId, String adresaId) async {
    return await updateVozac(vozacId, {'adresa_id': adresaId});
  }

  /// Uklanja adresu od vozača
  Future<Vozac> removeAddressFromVozac(String vozacId) async {
    return await updateVozac(vozacId, {'adresa_id': null});
  }

  /// Dohvata sve vozače sa adresama
  Future<List<Map<String, dynamic>>> getVozaciSaAdresama() async {
    final vozaci = await getAllVozaci();

    final List<Map<String, dynamic>> result = [];

    for (final vozac in vozaci) {
      // Since Vozac model doesn't have adresaId, skip address lookup for now
      result.add({
        'vozac': vozac,
        'adresa': null,
      });
    }

    return result;
  }

  /// Traži vozače po adresi (grad ili ulica)
  Future<List<Vozac>> searchVozaciByAddress(String addressQuery) async {
    final adresaService = AdresaService(supabaseClient: _supabase);
    final adrese = await adresaService.searchAdrese(addressQuery);
    final adresaIds = adrese.map((a) => a.id).toList();

    if (adresaIds.isEmpty) return [];

    // Use OR conditions for each address ID instead of in_ if method doesn't exist
    if (adresaIds.length == 1) {
      final response = await _supabase
          .from('vozaci')
          .select()
          .eq('aktivan', true)
          .eq('adresa_id', adresaIds.first)
          .order('ime');

      return response.map((json) => Vozac.fromMap(json)).toList();
    } else {
      // For multiple IDs, we'd need to make multiple queries or use a different approach
      final List<Vozac> results = [];
      for (final adresaId in adresaIds) {
        final response = await _supabase
            .from('vozaci')
            .select()
            .eq('aktivan', true)
            .eq('adresa_id', adresaId)
            .order('ime');

        final vozaci = response.map((json) => Vozac.fromMap(json)).toList();
        results.addAll(vozaci);
      }

      // Remove duplicates and sort
      final uniqueResults = results.toSet().toList();
      uniqueResults.sort((a, b) => a.ime.compareTo(b.ime));
      return uniqueResults;
    }
  }
}
