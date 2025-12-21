import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/realtime/realtime_manager.dart';

/// 🔍 REALTIME DEBUGGER
/// Testira kompletan realtime flow i loguje svaki korak
/// Koristi za dijagnostiku problema sa realtime sinhronizacijom
class RealtimeDebugger {
  static final List<String> _logs = [];
  static StreamSubscription? _testSubscription;

  /// Pokreni kompletnu dijagnostiku
  static Future<List<String>> runFullDiagnostics() async {
    _logs.clear();
    _log('═══════════════════════════════════════════════════════════');
    _log('🔍 REALTIME DEBUGGER - POČETAK DIJAGNOSTIKE');
    _log('═══════════════════════════════════════════════════════════');
    _log('⏰ Vreme: ${DateTime.now()}');

    // 1. Proveri Supabase konekciju
    await _checkSupabaseConnection();

    // 2. Proveri RealtimeManager stanje
    _checkRealtimeManagerState();

    // 3. Testiraj pretplatu na tabelu
    await _testSubscription_('registrovani_putnici');

    // 4. Testiraj UPDATE i da li dolazi event
    await _testUpdateAndListen();

    _log('═══════════════════════════════════════════════════════════');
    _log('🔍 DIJAGNOSTIKA ZAVRŠENA');
    _log('═══════════════════════════════════════════════════════════');

    // Print sve logove
    for (final log in _logs) {
      debugPrint(log);
    }

    return _logs;
  }

  /// 1. Proveri Supabase konekciju
  static Future<void> _checkSupabaseConnection() async {
    _log('\n📡 KORAK 1: Provera Supabase konekcije');
    try {
      final supabase = Supabase.instance.client;
      _log('  ✅ Supabase client postoji');

      // Test query
      final result = await supabase.from('registrovani_putnici').select('id').limit(1);
      _log('  ✅ Test query uspešan (${result.length} rezultata)');
    } catch (e) {
      _log('  ❌ Supabase greška: $e');
    }
  }

  /// 2. Proveri RealtimeManager stanje
  static void _checkRealtimeManagerState() {
    _log('\n🔄 KORAK 2: Provera RealtimeManager stanja');
    try {
      final manager = RealtimeManager.instance;
      _log('  ✅ RealtimeManager singleton postoji');

      // Proveri status za ključne tabele
      final tables = ['registrovani_putnici', 'vozac_lokacije', 'daily_checkins'];
      for (final table in tables) {
        final status = manager.getStatus(table);
        _log('  📊 $table: $status');
      }

      // Debug print stanje
      manager.debugPrintState();
    } catch (e) {
      _log('  ❌ RealtimeManager greška: $e');
    }
  }

  /// 3. Testiraj pretplatu na tabelu
  static Future<void> _testSubscription_(String table) async {
    _log('\n🔔 KORAK 3: Test pretplate na "$table"');
    try {
      final manager = RealtimeManager.instance;

      // Pretplati se
      _log('  📡 Pretplaćujem se na $table...');
      final stream = manager.subscribe(table);
      _log('  ✅ Stream dobijen');

      // Čekaj 2 sekunde da se konekcija uspostavi
      _log('  ⏳ Čekam 2s da se konekcija uspostavi...');
      await Future.delayed(const Duration(seconds: 2));

      final status = manager.getStatus(table);
      _log('  📊 Status nakon pretplate: $status');

      if (status.toString().contains('connected')) {
        _log('  ✅ Uspešno konektovan na $table');
      } else {
        _log('  ⚠️ Status nije "connected" - možda problem sa konekcijom');
      }

      // Sačuvaj subscription za cleanup
      _testSubscription = stream.listen((payload) {
        _log('  🔔 PRIMLJEN EVENT: ${payload.eventType}');
      });
    } catch (e) {
      _log('  ❌ Greška pri pretplati: $e');
    }
  }

  /// 4. Testiraj UPDATE i da li dolazi event
  static Future<void> _testUpdateAndListen() async {
    _log('\n📝 KORAK 4: Test UPDATE -> EVENT flow');
    try {
      final supabase = Supabase.instance.client;

      // Pronađi jednog putnika za test
      final putnici =
          await supabase.from('registrovani_putnici').select('id, putnik_ime, updated_at').eq('aktivan', true).limit(1);

      if (putnici.isEmpty) {
        _log('  ⚠️ Nema aktivnih putnika za test');
        return;
      }

      final putnik = putnici.first;
      final id = putnik['id'];
      final ime = putnik['putnik_ime'];
      _log('  📋 Test putnik: $ime (ID: $id)');

      // Postavi listener za evente
      bool eventReceived = false;
      final completer = Completer<void>();

      _testSubscription?.cancel();
      _testSubscription = RealtimeManager.instance.subscribe('registrovani_putnici').listen((payload) {
        _log('  🔔 EVENT PRIMLJEN!');
        _log('     - Tip: ${payload.eventType}');
        _log('     - Stari podaci: ${payload.oldRecord}');
        _log('     - Novi podaci: ${payload.newRecord}');
        eventReceived = true;
        if (!completer.isCompleted) completer.complete();
      });

      // Sačekaj da se listener registruje
      await Future.delayed(const Duration(milliseconds: 500));

      // Uradi UPDATE
      _log('  📤 Šaljem UPDATE za $ime...');
      await supabase.from('registrovani_putnici').update({
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      _log('  ✅ UPDATE poslat');

      // Čekaj event (max 5 sekundi)
      _log('  ⏳ Čekam event (max 5s)...');
      try {
        await completer.future.timeout(const Duration(seconds: 5));
      } catch (_) {
        // Timeout
      }

      if (eventReceived) {
        _log('  ✅ EVENT USPEŠNO PRIMLJEN - Realtime radi!');
      } else {
        _log('  ❌ EVENT NIJE PRIMLJEN - Problem sa realtime!');
        _log('     Mogući uzroci:');
        _log('     - Realtime nije uključen za tabelu u Supabase');
        _log('     - WebSocket konekcija nije uspostavljena');
        _log('     - Firewall blokira WebSocket');
      }
    } catch (e) {
      _log('  ❌ Greška u testu: $e');
    } finally {
      // Cleanup
      _testSubscription?.cancel();
      _testSubscription = null;
    }
  }

  /// Helper za logovanje
  static void _log(String message) {
    _logs.add(message);
    debugPrint('[RealtimeDebugger] $message');
  }

  /// Dohvati sve logove
  static List<String> getLogs() => List.from(_logs);

  /// Očisti logove
  static void clearLogs() => _logs.clear();
}
