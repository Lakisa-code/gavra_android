import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import 'realtime_notification_service.dart';

/// 📨 Servis za upravljanje PIN zahtevima putnika
class PinZahtevService {
  static SupabaseClient get _supabase => supabase;

  static Future<bool> posaljiZahtev({
    required String putnikId,
    required String email,
    required String telefon,
  }) async {
    try {
      final existing =
          await _supabase.from('pin_zahtevi').select().eq('putnik_id', putnikId).eq('status', 'ceka').maybeSingle();

      if (existing != null) {
        return true;
      }

      await _supabase.from('pin_zahtevi').insert({
        'putnik_id': putnikId,
        'email': email,
        'telefon': telefon,
        'status': 'ceka',
      });

      // 🔔 Pošalji notifikaciju adminima
      await RealtimeNotificationService.sendNotificationToAdmins(
        title: '🔔 Novi zahtev za PIN',
        body: 'Putnik traži PIN za pristup aplikaciji',
        data: {'type': 'pin_zahtev', 'putnik_id': putnikId},
      );

      return true;
    } catch (e) {
      return false;
    }
  }

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
      return [];
    }
  }

  static Future<int> brojZahtevaKojiCekaju() async {
    try {
      final response = await _supabase.from('pin_zahtevi').select('id').eq('status', 'ceka');

      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  static Future<bool> odobriZahtev({
    required String zahtevId,
    required String pin,
  }) async {
    try {
      final zahtev = await _supabase.from('pin_zahtevi').select('putnik_id').eq('id', zahtevId).single();

      final putnikId = zahtev['putnik_id'] as String;

      await _supabase.from('registrovani_putnici').update({'pin': pin}).eq('id', putnikId);

      await _supabase.from('pin_zahtevi').update({'status': 'odobren'}).eq('id', zahtevId);

      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> odbijZahtev(String zahtevId) async {
    try {
      await _supabase.from('pin_zahtevi').update({'status': 'odbijen'}).eq('id', zahtevId);

      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> imaZahtevKojiCeka(String putnikId) async {
    try {
      final response =
          await _supabase.from('pin_zahtevi').select('id').eq('putnik_id', putnikId).eq('status', 'ceka').maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> azurirajEmail({
    required String putnikId,
    required String email,
  }) async {
    try {
      await _supabase.from('registrovani_putnici').update({'email': email}).eq('id', putnikId);

      return true;
    } catch (e) {
      return false;
    }
  }
}
