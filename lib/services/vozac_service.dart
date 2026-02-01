import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import '../models/vozac.dart';
import 'realtime/realtime_manager.dart';

/// Servis za upravljanje vozačima
class VozacService {
  VozacService({SupabaseClient? supabaseClient}) : _supabaseOverride = supabaseClient;
  final SupabaseClient? _supabaseOverride;

  SupabaseClient get _supabase => _supabaseOverride ?? supabase;

  static StreamSubscription? _vozaciSubscription;
  static final StreamController<List<Vozac>> _vozaciController = StreamController<List<Vozac>>.broadcast();

  /// Dohvata sve vozače
  Future<List<Vozac>> getAllVozaci() async {
    final response = await _supabase.from('vozaci').select('id, ime').order('ime');

    return response.map((json) => Vozac.fromMap(json)).toList();
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
