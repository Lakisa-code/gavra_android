import 'dart:async';

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

    return response.map((json) => Vozac.fromMap(json)).toList();
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
      _vozaciSubscription = RealtimeManager.instance.subscribe('vozaci').listen((payload) {
        _refreshVozaciStream();
      });
      // Inicijalno učitavanje
      _refreshVozaciStream();
    }
    return _vozaciController.stream;
  }

  void _refreshVozaciStream() async {
    final vozaci = await getAllVozaci();
    if (!_vozaciController.isClosed) {
      _vozaciController.add(vozaci);
    }
  }

  /// 🧹 Čisti realtime subscription
  static void dispose() {
    _vozaciSubscription?.cancel();
    _vozaciSubscription = null;
    _vozaciController.close();
  }
}
