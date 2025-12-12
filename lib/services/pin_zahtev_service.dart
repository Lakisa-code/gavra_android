import 'package:supabase_flutter/supabase_flutter.dart';

/// 📨 Servis za upravljanje PIN zahtevima putnika
/// Putnici bez PIN-a mogu poslati zahtev adminu da im dodeli PIN
class PinZahtevService {
  static final _supabase = Supabase.instance.client;

  /// Pošalji zahtev za PIN
  /// [putnikId] - ID putnika koji šalje zahtev
  /// [email] - Email putnika za kontakt
  /// [telefon] - Telefon putnika
  static Future<bool> posaljiZahtev({
    required String putnikId,
    required String email,
    required String telefon,
  }) async {
    try {
      // Proveri da li već postoji zahtev koji čeka
      final existing =
          await _supabase.from('pin_zahtevi').select().eq('putnik_id', putnikId).eq('status', 'ceka').maybeSingle();

      if (existing != null) {
        // Već postoji zahtev koji čeka
        return true;
      }

      // Kreiraj novi zahtev
      await _supabase.from('pin_zahtevi').insert({
        'putnik_id': putnikId,
        'email': email,
        'telefon': telefon,
        'status': 'ceka',
      });

      return true;
    } catch (e) {
      print('❌ PinZahtevService.posaljiZahtev error: $e');
      return false;
    }
  }

  /// Dobavi sve zahteve koji čekaju (za admina)
  static Future<List<Map<String, dynamic>>> dohvatiZahteveKojiCekaju() async {
    try {
      final response = await _supabase.from('pin_zahtevi').select('''
            *,
            registrovani_putnici (
              id,
              putnik_ime,
              broj_telefona,
              tip,
              email
            )
          ''').eq('status', 'ceka').order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ PinZahtevService.dohvatiZahteveKojiCekaju error: $e');
      return [];
    }
  }

  /// Dobavi broj zahteva koji čekaju (za badge na dugmetu)
  static Future<int> brojZahtevaKojiCekaju() async {
    try {
      final response = await _supabase.from('pin_zahtevi').select('id').eq('status', 'ceka');

      return (response as List).length;
    } catch (e) {
      print('❌ PinZahtevService.brojZahtevaKojiCekaju error: $e');
      return 0;
    }
  }

  /// Odobri zahtev i dodeli PIN putniku
  /// [zahtevId] - ID zahteva
  /// [pin] - PIN koji se dodeljuje
  static Future<bool> odobriZahtev({
    required String zahtevId,
    required String pin,
  }) async {
    try {
      // Dohvati zahtev da dobijemo putnik_id
      final zahtev = await _supabase.from('pin_zahtevi').select('putnik_id').eq('id', zahtevId).single();

      final putnikId = zahtev['putnik_id'] as String;

      // Update PIN za putnika
      await _supabase.from('registrovani_putnici').update({'pin': pin}).eq('id', putnikId);

      // Ažuriraj status zahteva
      await _supabase.from('pin_zahtevi').update({'status': 'odobren'}).eq('id', zahtevId);

      return true;
    } catch (e) {
      print('❌ PinZahtevService.odobriZahtev error: $e');
      return false;
    }
  }

  /// Odbij zahtev
  static Future<bool> odbijZahtev(String zahtevId) async {
    try {
      await _supabase.from('pin_zahtevi').update({'status': 'odbijen'}).eq('id', zahtevId);

      return true;
    } catch (e) {
      print('❌ PinZahtevService.odbijZahtev error: $e');
      return false;
    }
  }

  /// Proveri da li putnik ima zahtev koji čeka
  static Future<bool> imaZahtevKojiCeka(String putnikId) async {
    try {
      final response =
          await _supabase.from('pin_zahtevi').select('id').eq('putnik_id', putnikId).eq('status', 'ceka').maybeSingle();

      return response != null;
    } catch (e) {
      print('❌ PinZahtevService.imaZahtevKojiCeka error: $e');
      return false;
    }
  }

  /// Ažuriraj email putnika u bazi
  static Future<bool> azurirajEmail({
    required String putnikId,
    required String email,
  }) async {
    try {
      await _supabase.from('registrovani_putnici').update({'email': email}).eq('id', putnikId);

      return true;
    } catch (e) {
      print('❌ PinZahtevService.azurirajEmail error: $e');
      return false;
    }
  }
}
