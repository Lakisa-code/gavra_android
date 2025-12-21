import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/registrovani_putnik.dart';
import 'vozac_mapping_service.dart';
import 'voznje_log_service.dart'; // 🔄 DODATO za istoriju vožnji

/// Servis za upravljanje mesečnim putnicima (normalizovana šema)
class RegistrovaniPutnikService {
  RegistrovaniPutnikService({SupabaseClient? supabaseClient}) : _supabase = supabaseClient ?? Supabase.instance.client;
  final SupabaseClient _supabase;

  // 🔧 SINGLETON PATTERN za realtime stream
  static StreamController<List<RegistrovaniPutnik>>? _sharedController;
  static RealtimeChannel? _sharedChannel;
  static List<RegistrovaniPutnik>? _lastValue;
  static int _listenerCount = 0;
  static bool _isReconnecting = false;

  /// Dohvata sve mesečne putnike
  Future<List<RegistrovaniPutnik>> getAllRegistrovaniPutnici() async {
    final response = await _supabase.from('registrovani_putnici').select('''
          *
        ''').eq('obrisan', false).order('putnik_ime');

    return response.map((json) => RegistrovaniPutnik.fromMap(json)).toList();
  }

  /// Dohvata aktivne mesečne putnike
  Future<List<RegistrovaniPutnik>> getAktivniregistrovaniPutnici() async {
    final response = await _supabase.from('registrovani_putnici').select('''
          *
        ''').eq('aktivan', true).eq('obrisan', false).order('putnik_ime');

    return response.map((json) => RegistrovaniPutnik.fromMap(json)).toList();
  }

  /// Dohvata putnike kojima treba račun (treba_racun = true)
  Future<List<RegistrovaniPutnik>> getPutniciZaRacun() async {
    final response = await _supabase
        .from('registrovani_putnici')
        .select('*')
        .eq('aktivan', true)
        .eq('obrisan', false)
        .eq('treba_racun', true)
        .order('putnik_ime');

    return response.map((json) => RegistrovaniPutnik.fromMap(json)).toList();
  }

  /// Dohvata mesečnog putnika po ID-u
  Future<RegistrovaniPutnik?> getRegistrovaniPutnikById(String id) async {
    final response = await _supabase.from('registrovani_putnici').select('''
          *
        ''').eq('id', id).single();

    return RegistrovaniPutnik.fromMap(response);
  }

  /// Dohvata mesečnog putnika po imenu (legacy compatibility)
  static Future<RegistrovaniPutnik?> getRegistrovaniPutnikByIme(String ime) async {
    try {
      final supabase = Supabase.instance.client;
      final response =
          await supabase.from('registrovani_putnici').select().eq('putnik_ime', ime).eq('obrisan', false).single();

      return RegistrovaniPutnik.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  /// 🔧 SINGLETON STREAM za mesečne putnike - sprečava kreiranje više channel-a
  /// Svi pozivi dele isti channel i controller
  static Stream<List<RegistrovaniPutnik>> streamAktivniRegistrovaniPutnici() {
    // Ako već postoji aktivan controller, koristi ga
    if (_sharedController != null && !_sharedController!.isClosed) {
      _listenerCount++;
      debugPrint('📊 [RegistrovaniPutnikService] Reusing existing stream (listeners: $_listenerCount)');

      // Emituj poslednju vrednost novom listener-u
      if (_lastValue != null) {
        Future.microtask(() {
          if (_sharedController != null && !_sharedController!.isClosed) {
            _sharedController!.add(_lastValue!);
          }
        });
      }

      return _sharedController!.stream;
    }

    // Kreiraj novi shared controller
    _sharedController = StreamController<List<RegistrovaniPutnik>>.broadcast(
      onCancel: () {
        _listenerCount--;
        debugPrint('📊 [RegistrovaniPutnikService] Listener removed (remaining: $_listenerCount)');

        // NE UGASI channel dok ima aktivnih listener-a
        // Channel se gasi samo kroz clearRealtimeCache()
      },
    );
    _listenerCount = 1;

    final supabase = Supabase.instance.client;

    // Učitaj inicijalne podatke
    _fetchAndEmit(supabase);

    // Kreiraj channel samo ako ne postoji
    _setupRealtimeChannel(supabase);

    return _sharedController!.stream;
  }

  /// 🔄 Fetch podatke i emituj u stream
  static Future<void> _fetchAndEmit(SupabaseClient supabase) async {
    try {
      final data = await supabase
          .from('registrovani_putnici')
          .select()
          .eq('aktivan', true)
          .eq('obrisan', false)
          .order('putnik_ime');

      final putnici = data.map((json) => RegistrovaniPutnik.fromMap(json)).toList();
      _lastValue = putnici;

      if (_sharedController != null && !_sharedController!.isClosed) {
        _sharedController!.add(putnici);
      }
    } catch (e) {
      debugPrint('❌ [RegistrovaniPutnikService] Fetch error: $e');
    }
  }

  /// 🔌 Setup realtime channel sa reconnect logikom
  static void _setupRealtimeChannel(SupabaseClient supabase) {
    if (_sharedChannel != null) {
      _sharedChannel!.unsubscribe();
    }

    const channelName = 'registrovani_putnici_singleton';
    _sharedChannel = supabase.channel(channelName);
    _sharedChannel!
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'registrovani_putnici',
      callback: (payload) {
        debugPrint('🔄 [$channelName] Postgres change: ${payload.eventType}');
        _fetchAndEmit(supabase);
      },
    )
        .subscribe((status, [error]) {
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          debugPrint('✅ [$channelName] Subscribed successfully');
          _isReconnecting = false;
          break;
        case RealtimeSubscribeStatus.channelError:
          debugPrint('❌ [$channelName] Channel error: $error');
          _scheduleReconnect(supabase);
          break;
        case RealtimeSubscribeStatus.closed:
          debugPrint('🔴 [$channelName] Channel closed');
          _scheduleReconnect(supabase);
          break;
        case RealtimeSubscribeStatus.timedOut:
          debugPrint('⏰ [$channelName] Subscription timed out');
          _scheduleReconnect(supabase);
          break;
      }
    });
  }

  /// 🔄 Schedule reconnect sa delay-om
  static void _scheduleReconnect(SupabaseClient supabase) {
    if (_isReconnecting) return;
    _isReconnecting = true;

    debugPrint('🔄 [RegistrovaniPutnikService] Scheduling reconnect in 3 seconds...');
    Future.delayed(const Duration(seconds: 3), () {
      if (_sharedController != null && !_sharedController!.isClosed) {
        debugPrint('🔄 [RegistrovaniPutnikService] Attempting reconnect...');
        _setupRealtimeChannel(supabase);
      }
    });
  }

  /// 🧹 Čisti singleton cache - pozovi kad treba resetovati sve
  static void clearRealtimeCache() {
    debugPrint('🧹 [RegistrovaniPutnikService] Clearing realtime cache');
    _sharedChannel?.unsubscribe();
    _sharedChannel = null;
    _sharedController?.close();
    _sharedController = null;
    _lastValue = null;
    _listenerCount = 0;
    _isReconnecting = false;
  }

  /// Kreira novog mesečnog putnika
  Future<RegistrovaniPutnik> createRegistrovaniPutnik(RegistrovaniPutnik putnik) async {
    final response = await _supabase.from('registrovani_putnici').insert(putnik.toMap()).select('''
          *
        ''').single();

    clearCache();

    return RegistrovaniPutnik.fromMap(response);
  }

  /// Ažurira mesečnog putnika
  Future<RegistrovaniPutnik> updateRegistrovaniPutnik(
    String id,
    Map<String, dynamic> updates,
  ) async {
    updates['updated_at'] = DateTime.now().toIso8601String();

    final response = await _supabase.from('registrovani_putnici').update(updates).eq('id', id).select('''
          *
        ''').single();

    clearCache();

    return RegistrovaniPutnik.fromMap(response);
  }

  /// Toggle aktivnost mesečnog putnika
  Future<bool> toggleAktivnost(String id, bool aktivnost) async {
    try {
      await _supabase.from('registrovani_putnici').update({
        'aktivan': aktivnost,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      clearCache();

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Ažurira mesečnog putnika (legacy metoda name)
  Future<RegistrovaniPutnik?> azurirajMesecnogPutnika(RegistrovaniPutnik putnik) async {
    try {
      final result = await updateRegistrovaniPutnik(putnik.id, putnik.toMap());
      return result;
    } catch (e) {
      rethrow; // Prebaci grešku da caller može da je uhvati
    }
  }

  /// Dodaje novog mesečnog putnika (legacy metoda name)
  Future<RegistrovaniPutnik> dodajMesecnogPutnika(RegistrovaniPutnik putnik) async {
    return await createRegistrovaniPutnik(putnik);
  }

  /// Sinhronizacija broja putovanja sa istorijom
  static Future<bool> sinhronizujBrojPutovanjaSaIstorijom(String id) async {
    try {
      final brojIzIstorije = await izracunajBrojPutovanjaIzIstorije(id);

      final supabase = Supabase.instance.client;
      await supabase.from('registrovani_putnici').update({
        'broj_putovanja': brojIzIstorije,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      clearCache();

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Ažurira plaćanje za mesec (vozacId je UUID)
  /// Koristi voznje_log za praćenje vožnji
  Future<bool> azurirajPlacanjeZaMesec(
    String putnikId,
    double iznos,
    String vozacId,
    DateTime pocetakMeseca,
    DateTime krajMeseca,
  ) async {
    String? validVozacId;

    try {
      if (vozacId.isNotEmpty && vozacId != 'Nepoznat vozač') {
        if (_isValidUuid(vozacId)) {
          validVozacId = vozacId;
        } else {
          try {
            await VozacMappingService.initialize();
            final converted = VozacMappingService.getVozacUuidSync(vozacId);
            if (converted != null && _isValidUuid(converted)) {
              validVozacId = converted;
            }
          } catch (_) {}
        }
      }

      await VoznjeLogService.dodajUplatu(
        putnikId: putnikId,
        datum: DateTime.now(),
        iznos: iznos,
        vozacId: validVozacId,
      );

      await updateRegistrovaniPutnik(putnikId, {
        'vreme_placanja': DateTime.now().toIso8601String(),
        'cena': iznos,
        'placeno': true,
        'placeni_mesec': pocetakMeseca.month,
        'placena_godina': pocetakMeseca.year,
        'ukupna_cena_meseca': iznos,
        'vozac_id': validVozacId,
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Helper funkcija za validaciju UUID formata
  bool _isValidUuid(String str) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(str);
  }

  /// Briše mesečnog putnika (soft delete)
  Future<bool> obrisiRegistrovaniPutnik(String id) async {
    try {
      await _supabase.from('registrovani_putnici').update({
        'obrisan': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      clearCache();

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Traži mesečne putnike po imenu, prezimenu ili broju telefona
  Future<List<RegistrovaniPutnik>> searchregistrovaniPutnici(String query) async {
    final response = await _supabase.from('registrovani_putnici').select('''
          *
        ''').eq('obrisan', false).or('putnik_ime.ilike.%$query%,broj_telefona.ilike.%$query%').order('putnik_ime');

    return response.map((json) => RegistrovaniPutnik.fromMap(json)).toList();
  }

  /// Dohvata sva plaćanja za mesečnog putnika
  /// 🔄 POJEDNOSTAVLJENO: Koristi voznje_log + registrovani_putnici
  Future<List<Map<String, dynamic>>> dohvatiPlacanjaZaPutnika(
    String putnikIme,
  ) async {
    try {
      List<Map<String, dynamic>> svaPlacanja = [];

      final putnik = await _supabase
          .from('registrovani_putnici')
          .select('id, cena, vreme_placanja, vozac_id, placeni_mesec, placena_godina')
          .eq('putnik_ime', putnikIme)
          .maybeSingle();

      if (putnik == null) return [];

      final placanjaIzLoga = await _supabase
          .from('voznje_log')
          .select()
          .eq('putnik_id', putnik['id'])
          .eq('tip', 'uplata')
          .order('datum', ascending: false) as List<dynamic>;

      for (var placanje in placanjaIzLoga) {
        svaPlacanja.add({
          'cena': placanje['iznos'],
          'created_at': placanje['created_at'],
          'vozac_ime': await _getVozacImeByUuid(placanje['vozac_id'] as String?),
          'putnik_ime': putnikIme,
          'datum': placanje['datum'],
        });
      }

      if (svaPlacanja.isEmpty && putnik['vreme_placanja'] != null) {
        svaPlacanja.add({
          'cena': putnik['cena'],
          'created_at': putnik['vreme_placanja'],
          'vozac_ime': await _getVozacImeByUuid(putnik['vozac_id'] as String?),
          'putnik_ime': putnikIme,
          'placeniMesec': putnik['placeni_mesec'],
          'placenaGodina': putnik['placena_godina'],
        });
      }

      return svaPlacanja;
    } catch (e) {
      return [];
    }
  }

  /// Helper funkcija za dobijanje imena vozača iz UUID-a
  Future<String?> _getVozacImeByUuid(String? vozacUuid) async {
    if (vozacUuid == null || vozacUuid.isEmpty) return null;

    try {
      final response = await _supabase.from('vozaci').select('ime').eq('id', vozacUuid).single();
      return response['ime'] as String?;
    } catch (e) {
      return VozacMappingService.getVozacIme(vozacUuid);
    }
  }

  /// Dohvata zakupljene putnike za današnji dan
  /// 🔄 POJEDNOSTAVLJENO: Koristi registrovani_putnici direktno
  static Future<List<Map<String, dynamic>>> getZakupljenoDanas() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('registrovani_putnici')
          .select()
          .eq('status', 'zakupljeno')
          .eq('aktivan', true)
          .eq('obrisan', false)
          .order('putnik_ime');

      return response.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Stream za realtime ažuriranja mesečnih putnika
  /// Koristi direktan Supabase Realtime
  Stream<List<RegistrovaniPutnik>> get registrovaniPutniciStream {
    return streamAktivniRegistrovaniPutnici();
  }

  /// Izračunava broj putovanja iz voznje_log
  static Future<int> izracunajBrojPutovanjaIzIstorije(
    String mesecniPutnikId,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      final response =
          await supabase.from('voznje_log').select('datum').eq('putnik_id', mesecniPutnikId).eq('tip', 'voznja');

      final jedinstveniDatumi = <String>{};
      for (final red in response) {
        if (red['datum'] != null) {
          jedinstveniDatumi.add(red['datum'] as String);
        }
      }

      return jedinstveniDatumi.length;
    } catch (e) {
      return 0;
    }
  }

  /// Izračunava broj otkazivanja iz voznje_log
  static Future<int> izracunajBrojOtkazivanjaIzIstorije(
    String mesecniPutnikId,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      final response =
          await supabase.from('voznje_log').select('datum').eq('putnik_id', mesecniPutnikId).eq('tip', 'otkazivanje');

      final jedinstveniDatumi = <String>{};
      for (final red in response) {
        if (red['datum'] != null) {
          jedinstveniDatumi.add(red['datum'] as String);
        }
      }

      return jedinstveniDatumi.length;
    } catch (e) {
      return 0;
    }
  }

  // ==================== ENHANCED CAPABILITIES ====================

  static final Map<String, dynamic> _cache = {};

  static void clearCache() {
    _cache.clear();
  }

  /// 🔍 Dobija vozača iz poslednjeg plaćanja za mesečnog putnika
  /// Koristi direktan Supabase stream
  static Stream<String?> streamVozacPoslednjegPlacanja(String putnikId) {
    return streamAktivniRegistrovaniPutnici().map((putnici) {
      try {
        final putnik = putnici.where((p) => p.id == putnikId).firstOrNull;
        if (putnik == null) return null;
        final vozacId = putnik.vozacId;
        if (vozacId != null && vozacId.isNotEmpty) {
          return VozacMappingService.getVozacImeWithFallbackSync(vozacId);
        }
        return null;
      } catch (e) {
        return null;
      }
    });
  }
}
