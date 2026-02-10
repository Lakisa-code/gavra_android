import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import '../models/vozac.dart';
import 'realtime/realtime_manager.dart';

/// Servis za upravljanje vozačima
class VozacService {
  // Singleton pattern
  static final VozacService _instance = VozacService._internal();

  factory VozacService() {
    return _instance;
  }

  VozacService._internal();

  SupabaseClient get _supabase => supabase;

  static StreamSubscription? _vozaciSubscription;
  static final StreamController<List<Vozac>> _vozaciController = StreamController<List<Vozac>>.broadcast();

  /// Dohvata sve vozače
  Future<List<Vozac>> getAllVozaci() async {
    final response = await _supabase.from('vozaci').select('id, ime, email, telefon, sifra, boja').order('ime');
    final vozaci = response.map((json) => Vozac.fromMap(json)).toList();
    if (kDebugMode && vozaci.isNotEmpty) {
      debugPrint('✅ [VozacService] Učitano ${vozaci.length} vozača iz Supabase');
    }
    return vozaci;
  }

  /// Dodaje novog vozača
  Future<Vozac> addVozac(Vozac vozac) async {
    final response = await _supabase.from('vozaci').insert(vozac.toMap()).select().single();
    return Vozac.fromMap(response);
  }

  /// Ažurira postojećeg vozača
  Future<Vozac> updateVozac(Vozac vozac) async {
    final response = await _supabase.from('vozaci').update(vozac.toMap()).eq('id', vozac.id).select().single();
    return Vozac.fromMap(response);
  }

  /// Briše vozača
  Future<void> deleteVozac(String id) async {
    await _supabase.from('vozaci').delete().eq('id', id);
  }

  /// 🛰️ REALTIME STREAM: Dohvata sve vozače u realnom vremenu
  Stream<List<Vozac>> streamAllVozaci() {
    if (_vozaciSubscription == null) {
      // Emituj praznu listu odmah ako Supabase nije spreman
      if (!isSupabaseReady) {
        if (!_vozaciController.isClosed) {
          _vozaciController.add([]);
        }
        // Periodično proveravaj da li je Supabase postao spreman
        _waitForSupabaseAndSubscribe();
      } else {
        _vozaciSubscription = RealtimeManager.instance.subscribe('vozaci').listen((payload) {
          _refreshVozaciStream();
        });
        // Inicijalno učitavanje
        _refreshVozaciStream();
      }
    }
    return _vozaciController.stream;
  }

  /// Čeka da Supabase postane spreman, pa se pretplati
  void _waitForSupabaseAndSubscribe() {
    const checkInterval = Duration(milliseconds: 500);
    const maxAttempts = 20; // 10 sekundi maksimum
    int attempts = 0;

    Timer.periodic(checkInterval, (timer) {
      attempts++;
      if (isSupabaseReady || attempts >= maxAttempts) {
        timer.cancel();
        if (isSupabaseReady && _vozaciSubscription == null) {
          _vozaciSubscription = RealtimeManager.instance.subscribe('vozaci').listen((payload) {
            _refreshVozaciStream();
          });
          // Inicijalno učitavanje
          _refreshVozaciStream();
        }
      }
    });
  }

  void _refreshVozaciStream() async {
    try {
      final vozaci = await getAllVozaci();
      if (!_vozaciController.isClosed) {
        _vozaciController.add(vozaci);
      }
    } catch (e) {
      debugPrint('❌ [VozacService] Greška pri osvežavanju stream-a: $e');
      // Emituj praznu listu u slučaju greške da se ne zaglavi loading
      if (!_vozaciController.isClosed) {
        _vozaciController.add([]);
      }
    }
  }

  /// 🧹 Čisti realtime subscription
  static void dispose() {
    _vozaciSubscription?.cancel();
    _vozaciSubscription = null;
    _vozaciController.close();
  }
}
